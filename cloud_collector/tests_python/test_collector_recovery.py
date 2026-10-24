"""Behavioral checks for the private, generation-aware station recovery memory.

These tests use the runtime's in-memory Firestore double. Ordering tests execute
old and new completions in both orders; they do not pretend to exercise real
Firestore contention or contact a provider.
"""

import copy
import unittest
from datetime import timedelta
from unittest import mock

import collector_recovery as recovery
import collector_runtime as runtime
from test_collector_runtime import FakeDb, FakeEngine, NOW, Reference, spot


def failure_info(*, category="validation", retryable=True, fatal=False, status=None):
    return {
        "category": category,
        "error_type": "ValueError" if category == "validation" else "HttpError",
        "http_status": status,
        "retryable": retryable,
        "fatal": fatal,
    }


class CollectorRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.spots = [spot("agadir_maroc"), spot("foreign")]
        self.engine = FakeEngine(self.spots)
        self.db = FakeDb()
        self.item = self.spots[0]

    def entry(self, item=None, *, state="pending", generation=NOW,
              run_id="previous-run", cycles=1, next_retry_at=None):
        item = item or self.item
        return {
            "schema_version": 1,
            "spot_id": item["id"],
            "run_id": run_id,
            "run_started_at": generation,
            "state": state,
            "cycles": cycles,
            "next_retry_at": next_retry_at,
            "error": failure_info() if state != "resolved" else None,
            "updated_at": generation,
        }

    def save_entry(self, entry):
        reference = recovery.recovery_reference(self.db, entry["spot_id"])
        self.db.documents[reference.path] = copy.deepcopy(entry)

    def stored(self, item=None):
        reference = recovery.recovery_reference(self.db, (item or self.item)["id"])
        return copy.deepcopy(self.db.documents[reference.path])

    def health(self, *unhealthy):
        return {
            "state": "recovery_required" if unhealthy else "healthy",
            "recovery_ids": list(unhealthy),
            "stations": [
                {"spot_id": item["id"],
                 "state": "stale" if item["id"] in unhealthy else "healthy"}
                for item in self.spots
            ],
        }

    def outcome(self, *, state="failed", run_id="run-current", generation=NOW,
                now=NOW, error=None, attempts=3, **kwargs):
        row = {
            "spot_id": self.item["id"],
            "state": state,
            "attempts": attempts,
            "errors": [] if state in {
                "verified", "verified_after_uncertain_commit", "superseded_by_healthy_run"
            } else [error or failure_info()],
            "writes": 0,
        }
        if state == "superseded_by_healthy_run":
            published = self.db.documents["spots_meteo/" + self.item["id"]]
            row["verified_run_id"] = published["forecast_run_id"]
            row["verified_generation"] = published["forecast_generated_at"].isoformat()
        return recovery.record_outcome(
            self.engine, self.db, self.item, row, run_id, generation,
            now=now, **kwargs,
        )

    def publish(self, *, run_id, generation):
        publication = self.engine._build_station_publication(
            {"spot": self.item}, run_id,
            conditions_spot_ids={self.item["id"]: self.item["id"]},
        )
        return runtime.publish_station_atomic(
            self.engine, self.db, publication, run_id, generation, now=generation,
        )

    def test_private_memory_load_is_bounded_to_requested_catalogue_subset(self):
        first = self.entry(next_retry_at=NOW)
        second = self.entry(self.spots[1], next_retry_at=NOW)
        self.save_entry(first)
        self.save_entry(second)
        self.assertEqual(
            recovery.recovery_reference(self.db, self.item["id"]).path,
            "collector_health/recovery-agadir_maroc",
        )
        loaded = recovery.load_recovery(self.db, [self.item])
        self.assertEqual(set(loaded), {self.item["id"]})
        self.assertEqual(loaded[self.item["id"]], first)
        self.assertEqual(self.db.commits, [])

    def test_missing_memory_is_empty_and_does_not_write(self):
        self.assertEqual(recovery.load_recovery(self.db, self.spots), {})
        self.assertEqual(self.db.documents, {})
        self.assertEqual(self.db.commits, [])

    def test_due_incident_retries_fresh_station_alongside_stale_station(self):
        entries = {self.item["id"]: self.entry(next_retry_at=NOW)}
        selected = recovery.select_recovery(
            self.health("foreign"), entries, self.spots, now=NOW,
        )
        self.assertEqual(set(selected["selected_ids"]), {"agadir_maroc", "foreign"})
        self.assertEqual(selected["deferred"], [])

    def test_future_retry_and_blocked_memory_also_suppress_stale_selection(self):
        entries = {
            self.item["id"]: self.entry(next_retry_at=NOW + timedelta(minutes=1)),
            "foreign": self.entry(self.spots[1], state="blocked"),
        }
        selected = recovery.select_recovery(
            self.health("agadir_maroc", "foreign"), entries, self.spots, now=NOW,
        )
        self.assertEqual(selected["selected_ids"], [])
        self.assertEqual({item["spot_id"] for item in selected["deferred"]},
                         {"agadir_maroc", "foreign"})

    def test_queue_and_health_cannot_expand_an_explicit_station_subset(self):
        entries = {
            self.item["id"]: self.entry(next_retry_at=NOW),
            "foreign": self.entry(self.spots[1], next_retry_at=NOW),
            "not_in_catalogue": self.entry(spot("not_in_catalogue"), next_retry_at=NOW),
        }
        selected = recovery.select_recovery(
            self.health("foreign", "not_in_catalogue"), entries, [self.item], now=NOW,
        )
        self.assertEqual(selected["selected_ids"], [self.item["id"]])

    def test_resolved_tombstone_does_not_block_a_later_stale_station(self):
        entries = {self.item["id"]: self.entry(state="resolved")}
        healthy = recovery.select_recovery(self.health(), entries, self.spots, now=NOW)
        stale = recovery.select_recovery(
            self.health(self.item["id"]), entries, self.spots, now=NOW,
        )
        self.assertEqual(healthy["selected_ids"], [])
        self.assertEqual(stale["selected_ids"], [self.item["id"]])

    def test_first_exhausted_cycle_persists_one_hour_retry_and_safe_error(self):
        result = self.outcome()
        saved = self.stored()
        self.assertEqual(result["state"], "pending")
        self.assertEqual(saved["state"], "pending")
        self.assertEqual(saved["cycles"], 1)
        self.assertEqual(saved["next_retry_at"], NOW + timedelta(hours=1))
        self.assertEqual(saved["error"]["category"], "validation")
        self.assertEqual(saved["run_started_at"], NOW)
        self.assertEqual(saved["run_id"], "run-current")

    def test_same_run_replayed_does_not_increment_cycle_or_postpone_retry(self):
        self.outcome()
        before = self.stored()
        self.outcome(now=NOW + timedelta(minutes=20))
        self.assertEqual(self.stored(), before)

    def test_backoff_counts_cycles_not_three_attempts_and_is_capped_at_six_hours(self):
        for cycle, hours in enumerate((1, 2, 4, 6, 6), start=1):
            instant = NOW + timedelta(days=cycle)
            with self.subTest(cycle=cycle):
                self.outcome(run_id=f"cycle-{cycle}", generation=instant,
                             now=instant, attempts=3)
                saved = self.stored()
                self.assertEqual(saved["cycles"], cycle)
                self.assertEqual(saved["next_retry_at"], instant + timedelta(hours=hours))

    def test_permanent_error_is_blocked_without_automatic_retry_deadline(self):
        self.outcome(error=failure_info(category="permanent_http", retryable=False,
                                        status=400))
        saved = self.stored()
        self.assertEqual(saved["state"], "blocked")
        self.assertIsNone(saved["next_retry_at"])

    def test_global_authentication_abort_blocks_an_unvisited_station(self):
        auth = failure_info(category="authentication", retryable=False,
                            fatal=True, status=403)
        row = {"spot_id": self.item["id"], "state": "aborted", "attempts": 0,
               "errors": [], "writes": 0}
        recovery.record_outcome(self.engine, self.db, self.item, row,
                                "auth-run", NOW, now=NOW, fatal_error=auth)
        saved = self.stored()
        self.assertEqual(saved["state"], "blocked")
        self.assertEqual(saved["error"]["category"], "authentication")

    def test_provider_retry_after_is_never_shortened_by_station_backoff(self):
        until = NOW + timedelta(hours=9)
        self.outcome(state="deferred_provider_cooldown", provider_cooldown=until)
        saved = self.stored()
        self.assertEqual(saved["state"], "pending")
        self.assertGreaterEqual(saved["next_retry_at"], until)

    def test_verified_success_keeps_a_resolved_tombstone(self):
        self.outcome(run_id="old-failure", generation=NOW - timedelta(hours=2),
                     now=NOW - timedelta(hours=2))
        self.publish(run_id="success", generation=NOW)
        self.outcome(state="verified", run_id="success")
        saved = self.stored()
        self.assertEqual(saved["state"], "resolved")
        self.assertEqual(saved["run_id"], "success")
        self.assertEqual(saved["run_started_at"], NOW)
        self.assertIsNone(saved["next_retry_at"])
        self.assertIsNone(saved["error"])

    def test_older_failure_finishing_after_new_success_cannot_reopen_incident(self):
        self.publish(run_id="new-success", generation=NOW)
        self.outcome(state="verified", run_id="new-success")
        tombstone = self.stored()
        self.outcome(run_id="old-failure", generation=NOW - timedelta(hours=1),
                     now=NOW + timedelta(minutes=10))
        self.assertEqual(self.stored(), tombstone)

    def test_older_success_finishing_after_new_failure_cannot_clear_incident(self):
        older = NOW - timedelta(hours=1)
        self.publish(run_id="old-success", generation=older)
        self.outcome(run_id="new-failure")
        pending = self.stored()
        self.outcome(state="verified", run_id="old-success", generation=older,
                     now=NOW + timedelta(minutes=10))
        self.assertEqual(self.stored(), pending)

    def test_equal_generation_with_different_run_is_conservative(self):
        self.outcome(run_id="known-failure")
        before = self.stored()
        self.outcome(state="verified", run_id="different-run")
        self.assertEqual(self.stored(), before)

    def test_superseded_success_uses_the_validated_replacement_generation(self):
        newer = NOW + timedelta(minutes=10)
        self.publish(run_id="replacement", generation=newer)
        self.outcome(state="superseded_by_healthy_run", run_id="superseded",
                     now=newer)
        saved = self.stored()
        self.assertEqual(saved["state"], "resolved")
        self.assertEqual(saved["run_id"], "replacement")
        self.assertEqual(saved["run_started_at"], newer)
        self.outcome(run_id="late-old-failure", generation=NOW + timedelta(minutes=5),
                     now=newer + timedelta(minutes=1))
        self.assertEqual(self.stored(), saved)

    def test_database_failures_are_not_reported_as_success_or_empty_memory(self):
        with mock.patch.object(Reference, "get", side_effect=TimeoutError("read unavailable")):
            with self.assertRaises(TimeoutError):
                self.outcome()
        self.assertEqual(self.db.documents, {})
        self.db.fail_before = True
        with self.assertRaises(TimeoutError):
            self.outcome()
        self.assertEqual(self.db.documents, {})
        with mock.patch.object(self.db, "get_all", side_effect=TimeoutError("read unavailable")):
            with self.assertRaises(TimeoutError):
                recovery.load_recovery(self.db, self.spots)

    def test_replacement_changed_after_validation_does_not_resolve_newer_incident(self):
        checked = NOW + timedelta(minutes=10)
        later = NOW + timedelta(minutes=20)
        self.publish(run_id="replacement-checked", generation=checked)
        row = {"spot_id": self.item["id"], "state": "superseded_by_healthy_run",
               "attempts": 1, "errors": [], "verified_run_id": "replacement-checked",
               "verified_generation": checked.isoformat()}
        self.publish(run_id="newer-not-checked", generation=later)
        self.outcome(run_id="newer-not-checked", generation=later, now=later)
        pending = self.stored()
        recovery.record_outcome(self.engine, self.db, self.item, row, "old-run", NOW,
                                now=later + timedelta(minutes=1))
        self.assertEqual(self.stored(), pending)

    def test_malformed_private_memory_is_not_treated_as_an_absent_incident(self):
        invalid = self.entry(next_retry_at=NOW)
        invalid["run_started_at"] = "not a timestamp"
        self.save_entry(invalid)
        with self.assertRaises(ValueError):
            recovery.load_recovery(self.db, self.spots)
        self.assertEqual(self.engine.order, [])

    def test_incomplete_or_unexpected_database_read_is_not_treated_as_empty(self):
        with mock.patch.object(self.db, "get_all", return_value=iter([])):
            with self.assertRaises(ValueError):
                recovery.load_recovery(self.db, self.spots)
        unexpected = Reference(self.db, "collector_health/recovery-unknown").get()
        with mock.patch.object(self.db, "get_all", return_value=iter([unexpected])):
            with self.assertRaises(ValueError):
                recovery.load_recovery(self.db, self.spots)


if __name__ == "__main__":
    unittest.main()
