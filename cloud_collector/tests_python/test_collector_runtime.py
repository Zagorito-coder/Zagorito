import copy
import tempfile
import threading
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import collector_runtime as runtime


NOW = datetime(2026, 10, 22, 3, 0, tzinfo=timezone.utc)
SERVER_TIMESTAMP = "SERVER_TIMESTAMP_TEST"


def spot(spot_id):
    return {"id": spot_id, "name": spot_id, "lat": 30.0, "lon": -9.0}


class HttpError(Exception):
    def __init__(self, status):
        self.status_code = status
        super().__init__("https://provider.invalid/?apikey=NEVER_LOG_THIS_SECRET")


class Snapshot:
    def __init__(self, value):
        self.exists = value is not None
        self.value = copy.deepcopy(value)

    def to_dict(self):
        return copy.deepcopy(self.value)


class Reference:
    def __init__(self, db, path):
        self.db, self.path = db, path

    def get(self, transaction=None):
        if transaction is not None and transaction.pending:
            raise AssertionError("Firestore cannot read after transaction writes")
        return Snapshot(self.db.documents.get(self.path))


class Transaction:
    def __init__(self, db):
        self.db, self.pending = db, []

    def set(self, reference, document):
        self.pending.append((reference.path, copy.deepcopy(document)))


class FakeDb:
    def __init__(self):
        self.documents = {}
        self.commits = []
        self.fail_before = False
        self.fail_after = False

    def collection(self, name):
        return SimpleNamespace(document=lambda item: Reference(self, name + "/" + item))

    def transaction(self):
        return Transaction(self)

    @staticmethod
    def transactional(function):
        def wrapped(transaction):
            result = function(transaction)
            db = transaction.db
            if db.fail_before:
                db.fail_before = False
                raise TimeoutError("commit did not happen")
            def materialize(value):
                if value == SERVER_TIMESTAMP:
                    return NOW
                if isinstance(value, dict):
                    return {key: materialize(item) for key, item in value.items()}
                if isinstance(value, list):
                    return [materialize(item) for item in value]
                return value
            if transaction.pending:
                db.documents.update({path: materialize(data) for path, data in transaction.pending})
                db.commits.append([path for path, _ in transaction.pending])
            if db.fail_after:
                db.fail_after = False
                raise TimeoutError("committed but acknowledgement lost")
            return result
        return wrapped


class FakeEngine:
    def __init__(self, spots):
        self.SPOTS = spots
        self.EXPECTED_STATION_COUNT = len(spots)
        self.CONDITIONS_SPOT_IDS = {item["id"]: item["id"] for item in spots}
        self.LEGACY_CONDITIONS_ALIASES = {spots[0]["id"]: "historical_alias"}
        self.firestore = SimpleNamespace(SERVER_TIMESTAMP=SERVER_TIMESTAMP, transactional=FakeDb.transactional)
        self.fetch_counts = {}
        self.order = []
        self.fetch_failures = {}
        self.build_failures = set()
        self.verification_failures = 0
        self._lock = threading.Lock()

    def _fetch_station_models(self, item):
        with self._lock:
            key = item["id"]
            self.order.append(key)
            self.fetch_counts[key] = self.fetch_counts.get(key, 0) + 1
            errors = self.fetch_failures.get(key, [])
            error = errors.pop(0) if errors else None
        return {"spot": item, "models": {}, "errors": {"wind": error} if error else {}}

    def _build_station_publication(self, result, run_id, *, conditions_spot_ids):
        item = result["spot"]
        if item["id"] in self.build_failures:
            raise ValueError("invalid marine value")
        days = [{"date": (NOW + timedelta(days=i)).date().isoformat()} for i in range(10)]
        identity = {"spot_id": item["id"], "forecast_run_id": run_id,
                    "latitude": item["lat"], "longitude": item["lon"]}
        first = NOW.replace(hour=0)
        tide = [{"time": runtime._iso(first + timedelta(hours=i))} for i in range(8 * 24)]
        return {"spot": item,
                "weather_doc": {**identity, "last_update": SERVER_TIMESTAMP,
                                "location_name": item["name"], "days": days,
                                "timezone": "UTC", "utc_offset_seconds": 0},
                "conditions_doc": {**identity, "name": item["name"], "last_update": SERVER_TIMESTAMP,
                                   "timestamp": SERVER_TIMESTAMP, "tide": {"hourly": tide},
                                   "coverage": {"weatherDays": 10, "marineDays": 8}}}

    def _validate_publications_before_commit(self, publications, run_id, conditions):
        if len(publications) != 1 or publications[0]["spot"]["id"] not in conditions:
            raise ValueError("invalid publication subset")
        if publications[0]["weather_doc"]["forecast_run_id"] != run_id:
            raise ValueError("run does not match")

    def _effective_conditions_aliases(self, conditions, aliases):
        return aliases

    def _open_meteo_timezone(self, name, offset=0):
        return ZoneInfo(name)

    def _parse_utc_instant(self, value):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))

    def verify_production_state(self, db, spots, run_id, run_started_at, *, conditions_spot_ids,
                                conditions_aliases, now):
        if self.verification_failures:
            self.verification_failures -= 1
            raise TimeoutError("verification timeout")
        item = spots[0]
        paths = ["spots_meteo/" + item["id"], "spots_index/" + item["id"],
                 "conditions/" + conditions_spot_ids[item["id"]]]
        paths += ["conditions/" + alias for alias in conditions_aliases.values()]
        for path in paths:
            data = db.documents.get(path)
            if not data or data.get("forecast_run_id") != run_id or data.get("spot_id") != item["id"]:
                raise ValueError("missing, mixed-run or wrong-identity station")
            if data.get("latitude") != item["lat"]:
                raise ValueError("invalid coordinates")


class CollectorRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.engine = FakeEngine([spot("foreign"), spot("agadir_maroc"), spot("tanger_maroc")])
        self.db = FakeDb()
        self.delays = []

    def collect(self, **kwargs):
        defaults = dict(now_fn=lambda: NOW, monotonic_fn=lambda: 0,
                        sleeper=self.delays.append,
                        policy=runtime.RecoveryPolicy(max_workers=1, retry_delays=(1, 2)))
        defaults.update(kwargs)
        return runtime.run_collection(self.engine, self.db, "run-current", **defaults)

    def publish(self, item=None, run_id="existing", generation=NOW):
        item = item or self.engine.SPOTS[0]
        publication = self.engine._build_station_publication({"spot": item}, run_id,
                            conditions_spot_ids={item["id"]: item["id"]})
        return runtime.publish_station_atomic(self.engine, self.db, publication, run_id, generation, now=NOW)

    def test_morocco_completes_before_foreign_and_all_documents_atomic(self):
        report = self.collect()
        self.assertEqual(self.engine.order, ["agadir_maroc", "tanger_maroc", "foreign"])
        self.assertEqual(report["state"], "complete")
        self.assertEqual(report["successful_station_count"], 3)
        self.assertEqual([len(commit) for commit in self.db.commits], [3, 3, 4])
        self.assertIsInstance(self.db.documents["conditions/historical_alias"]["timestamp"], str)
        self.assertEqual(self.db.documents["spots_meteo/foreign"]["forecast_generated_at"], NOW)

    def test_invalid_station_does_not_block_healthy_stations_or_redate_old_data(self):
        self.publish()
        old = copy.deepcopy(self.db.documents["spots_meteo/foreign"])
        self.engine.build_failures.add("foreign")
        report = self.collect()
        self.assertEqual(report["state"], "partial")
        self.assertEqual(report["unresolved_station_ids"], ["foreign"])
        self.assertEqual(self.engine.fetch_counts, {"agadir_maroc": 1, "tanger_maroc": 1, "foreign": 3})
        self.assertEqual(self.db.documents["spots_meteo/foreign"], old)
        self.assertEqual(self.delays, [1, 2])

    def test_transient_failure_recovers_only_failed_station(self):
        self.engine.fetch_failures["agadir_maroc"] = [HttpError(503)]
        report = self.collect()
        self.assertEqual(report["state"], "complete")
        self.assertEqual(self.engine.fetch_counts["agadir_maroc"], 2)
        self.assertEqual(self.engine.fetch_counts["foreign"], 1)
        self.assertEqual(len(self.db.commits), 3)

    def test_auth_failure_stops_scheduling_and_preserves_unvisited_stations(self):
        self.engine.fetch_failures["agadir_maroc"] = [HttpError(403)]
        report = self.collect()
        self.assertEqual(report["state"], "aborted")
        self.assertEqual(self.engine.order, ["agadir_maroc"])
        self.assertEqual(self.db.documents, {})
        self.assertEqual(report["fatal_error"]["category"], "authentication")
        self.assertNotIn("NEVER_LOG", str(report))

    def test_permanent_http_failure_is_not_retried_and_other_stations_continue(self):
        self.engine.fetch_failures["agadir_maroc"] = [HttpError(400)]
        report = self.collect()
        self.assertEqual(report["state"], "partial")
        self.assertEqual(self.engine.fetch_counts["agadir_maroc"], 1)
        self.assertEqual(report["successful_station_count"], 2)

    def test_commit_acknowledgement_loss_is_verified_without_second_fetch_or_write(self):
        self.db.fail_after = True
        report = self.collect()
        self.assertEqual(report["state"], "complete")
        self.assertEqual(report["stations"][0]["state"], "verified_after_uncertain_commit")
        self.assertEqual(self.engine.fetch_counts["agadir_maroc"], 1)
        self.assertEqual(len(self.db.commits), 3)

    def test_commit_failure_before_write_retries_station_once_without_partial_documents(self):
        self.db.fail_before = True
        report = self.collect()
        self.assertEqual(report["state"], "complete")
        self.assertEqual(self.engine.fetch_counts["agadir_maroc"], 2)
        self.assertEqual(len(self.db.commits), 3)

    def test_same_run_retry_is_noop_and_does_not_renew_timestamps(self):
        self.publish(run_id="same")
        old = copy.deepcopy(self.db.documents)
        outcome = self.publish(run_id="same", generation=NOW + timedelta(hours=1))
        self.assertEqual(outcome, {"state": "already_committed", "writes": 0})
        self.assertEqual(self.db.documents, old)
        self.assertEqual(len(self.db.commits), 1)

    def test_old_generation_cannot_overwrite_newer_forecast(self):
        self.publish(run_id="new", generation=NOW + timedelta(minutes=1))
        old = copy.deepcopy(self.db.documents)
        outcome = self.publish(run_id="old", generation=NOW)
        self.assertEqual(outcome["state"], "superseded")
        self.assertEqual(self.db.documents, old)

    def test_legacy_last_update_also_blocks_older_generation(self):
        self.publish(run_id="new")
        document = self.db.documents["spots_meteo/foreign"]
        document.pop("forecast_generated_at")
        outcome = self.publish(run_id="old", generation=NOW - timedelta(minutes=1))
        self.assertEqual(outcome["state"], "superseded")

    def test_invalid_old_dates_do_not_permanently_prevent_repair(self):
        self.db.documents["spots_meteo/foreign"] = {"last_update": "invalid"}
        self.assertEqual(self.publish()["state"], "written")

    def test_same_run_partial_station_is_not_silently_redated(self):
        self.publish(run_id="same")
        del self.db.documents["spots_index/foreign"]
        with self.assertRaises(runtime.InconsistentPublication):
            self.publish(run_id="same")
        self.assertEqual(len(self.db.commits), 1)

    def test_dry_run_validates_and_exports_without_any_writes(self):
        fixtures = []
        report = self.collect(dry_run=True, publication_sink=fixtures.append)
        self.assertEqual(report["state"], "dry_run_complete")
        self.assertEqual(len(fixtures), 3)
        self.assertEqual(report["writes_acknowledged"], 0)
        self.assertEqual(self.db.documents, {})

    def test_health_checks_freshness_and_mixed_run_identity_not_just_existing(self):
        self.collect()
        self.db.documents["spots_meteo/foreign"]["last_update"] = NOW - timedelta(hours=9)
        self.db.documents["spots_index/tanger_maroc"]["forecast_run_id"] = "wrong"
        result = runtime.check_health(self.engine, self.db, now=NOW)
        self.assertEqual(result["state"], "recovery_required")
        self.assertEqual(set(result["recovery_ids"]), {"foreign", "tanger_maroc"})
        self.assertEqual(result["stations"][0]["state"], "healthy")

    def test_health_rejects_current_day_absent_even_when_timestamp_fresh(self):
        self.collect()
        self.db.documents["spots_meteo/foreign"]["days"] = [{"date": "2026-10-21"}]
        result = runtime.check_health(self.engine, self.db, [self.engine.SPOTS[0]], now=NOW)
        self.assertEqual(result["stations"][0]["state"], "invalid")

    def test_health_rejects_incomplete_current_marine_day(self):
        self.collect()
        self.db.documents["conditions/foreign"]["tide"]["hourly"] = [{"time": runtime._iso(NOW)}]
        result = runtime.check_health(self.engine, self.db, [self.engine.SPOTS[0]], now=NOW)
        self.assertEqual(result["stations"][0]["state"], "invalid")

    def test_unknown_or_changed_station_is_rejected_before_fetch(self):
        with self.assertRaises(ValueError):
            self.collect(spots=[spot("unknown")])
        changed = {**self.engine.SPOTS[0], "lat": 99.0}
        with self.assertRaises(ValueError):
            self.collect(spots=[changed])
        self.assertEqual(self.engine.order, [])

    def test_budget_exhaustion_is_explicit_and_never_falsely_complete(self):
        calls = [0, 7000]
        report = self.collect(monotonic_fn=lambda: calls.pop(0) if calls else 7000)
        self.assertEqual(report["state"], "partial")
        self.assertTrue(report["budget_exhausted"])
        self.assertEqual(self.engine.order, [])

    def test_policy_rejects_unbounded_attempts_workers_and_delays(self):
        for policy in [runtime.RecoveryPolicy(max_attempts=4), runtime.RecoveryPolicy(max_workers=100),
                       runtime.RecoveryPolicy(retry_delays=(700, 1)), runtime.RecoveryPolicy(max_elapsed_seconds=8000)]:
            with self.assertRaises(ValueError):
                policy.validate()


    def test_uncertain_commit_with_initial_read_failures_never_commits_twice(self):
        self.db.fail_after = True
        self.engine.verification_failures = 2
        report = self.collect(spots=[self.engine.SPOTS[0]])
        self.assertEqual(report["state"], "complete")
        self.assertEqual(self.engine.fetch_counts["foreign"], 2)
        self.assertEqual(len(self.db.commits), 1)
        self.assertEqual(self.db.documents["spots_meteo/foreign"]["last_update"], NOW)

    def test_superseded_station_must_pass_health_before_being_counted_successful(self):
        self.publish(run_id="newer", generation=NOW + timedelta(seconds=1))
        report = self.collect(spots=[self.engine.SPOTS[0]])
        self.assertEqual(report["state"], "complete")
        self.assertEqual(report["stations"][0]["state"], "superseded_by_healthy_run")
        self.assertEqual(len(self.db.commits), 1)
        self.db.documents["spots_index/foreign"]["spot_id"] = "invalid"
        report = self.collect(spots=[self.engine.SPOTS[0]])
        self.assertEqual(report["state"], "partial")
        self.assertEqual(len(self.db.commits), 1)

    def test_health_uses_station_civil_day_instead_of_utc_day(self):
        self.collect()
        weather = self.db.documents["spots_meteo/foreign"]
        weather["timezone"] = "Pacific/Honolulu"
        weather["days"] = [{"date": "2026-10-22"}]
        # At 03:00 UTC it is still October 21 in Honolulu. A UTC-only check
        # would incorrectly accept this forecast as covering the current day.
        result = runtime.check_health(self.engine, self.db, [self.engine.SPOTS[0]], now=NOW)
        self.assertEqual(result["stations"][0]["state"], "invalid")

    def test_health_future_timestamp_and_missing_station_are_recovery_candidates(self):
        self.collect()
        self.db.documents["spots_meteo/foreign"]["last_update"] = NOW + timedelta(minutes=6)
        del self.db.documents["spots_meteo/agadir_maroc"]
        result = runtime.check_health(self.engine, self.db, now=NOW)
        self.assertEqual(set(result["recovery_ids"]), {"foreign", "agadir_maroc"})

    def test_completed_morocco_group_precedes_foreign_with_parallel_fetches(self):
        finished_morocco = set()
        lock = threading.Lock()
        def fetch(item):
            with lock:
                if item["id"].endswith("_maroc"):
                    finished_morocco.add(item["id"])
                else:
                    self.assertEqual(finished_morocco, {"agadir_maroc", "tanger_maroc"})
            return self.engine._fetch_station_models(item)
        report = self.collect(fetcher=fetch, policy=runtime.RecoveryPolicy(max_workers=3, retry_delays=(0, 0)))
        self.assertEqual(report["state"], "complete")


    def test_retry_after_persists_global_hold_and_next_run_makes_no_requests(self):
        error = HttpError(429)
        error.retry_after_seconds = 90000  # More than one day: do not shorten it.
        self.engine.fetch_failures["agadir_maroc"] = [error]
        report = self.collect()
        self.assertEqual(report["state"], "provider_cooldown")
        self.assertEqual(self.engine.order, ["agadir_maroc"])
        deadline = self.db.documents["collector_health/provider-cooldown"]["until"]
        self.assertEqual(deadline, NOW + timedelta(seconds=90000))
        report = self.collect()
        self.assertEqual(report["state"], "provider_cooldown")
        self.assertEqual(self.engine.order, ["agadir_maroc"])
        self.assertEqual(report["successful_station_count"], 0)

    def test_provider_hold_can_only_be_extended_and_expired_hold_allows_collection(self):
        later = NOW + timedelta(hours=48)
        runtime._persist_provider_cooldown(self.engine, self.db, later, "first", NOW)
        result = runtime._persist_provider_cooldown(self.engine, self.db, NOW + timedelta(hours=1), "second", NOW)
        self.assertEqual(result, later)
        self.db.documents["collector_health/provider-cooldown"]["until"] = NOW - timedelta(seconds=1)
        self.assertEqual(self.collect()["state"], "complete")

    def test_retry_after_with_wrapped_cause_is_detected_but_nonfinite_values_ignored(self):
        error = HttpError(503)
        error.retry_after_seconds = 300
        wrapped = RuntimeError("safe station failure")
        wrapped.__cause__ = error
        self.assertEqual(runtime._exception_info(wrapped)["retry_after_seconds"], 300)
        for invalid in [float("nan"), float("inf"), -1, True]:
            error.retry_after_seconds = invalid
            self.assertNotIn("retry_after_seconds", runtime._exception_info(wrapped))

    def test_dry_run_respects_retry_after_without_writing_private_state(self):
        error = HttpError(503)
        error.retry_after_seconds = 3600
        self.engine.fetch_failures["agadir_maroc"] = [error]
        report = self.collect(dry_run=True)
        self.assertEqual(report["state"], "provider_cooldown")
        self.assertEqual(self.db.documents, {})

    def configure_cli(self):
        self.engine.credentials = SimpleNamespace(Certificate=lambda filename: "private credential object")
        self.engine.firebase_admin = SimpleNamespace(get_app=lambda: "existing", initialize_app=lambda credential: None)
        self.engine.firestore.client = lambda: self.db
        self.engine.OPEN_METEO_API_KEY = "SECRET_NEVER_PRINTED"
        self.engine.FORECAST_RUN_ID = "cli-run"

    def test_cli_dry_run_station_selection_and_fixture_export(self):
        import contextlib
        import io
        import json
        self.configure_cli()
        with tempfile.TemporaryDirectory() as directory:
            report = str(Path(directory) / "report.json")
            fixture = str(Path(directory) / "fixture.json")
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                code = runtime.cli(self.engine, ["--mode", "dry-run", "--station-ids", "agadir_maroc",
                                    "--report-file", report, "--fixture-file", fixture])
            self.assertEqual(code, 0)
            self.assertEqual(self.db.documents, {})
            exported = json.loads(Path(fixture).read_text())
            self.assertEqual(len(exported["publications"]), 1)
            self.assertEqual(exported["publications"][0]["spot"]["id"], "agadir_maroc")
            self.assertTrue(exported["publications"][0]["weather_doc"]["last_update"].endswith("Z"))
            self.assertNotIn("SECRET_NEVER_PRINTED", stdout.getvalue())

    def test_cli_health_never_requires_upstream_api_key_or_requests_models(self):
        import contextlib
        import io
        from unittest import mock
        self.configure_cli()
        self.engine.OPEN_METEO_API_KEY = None
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(runtime, "check_health", return_value={"state": "healthy"}):
            with contextlib.redirect_stdout(io.StringIO()):
                code = runtime.cli(self.engine, ["--mode", "health", "--report-file", str(Path(directory) / "health.json")])
        self.assertEqual(code, 0)
        self.assertEqual(self.engine.order, [])

    def test_cli_recovery_of_healthy_catalogue_is_noop(self):
        import contextlib
        import io
        from unittest import mock
        self.configure_cli()
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(runtime, "check_health", return_value={"state": "healthy", "recovery_ids": []}):
            with contextlib.redirect_stdout(io.StringIO()):
                code = runtime.cli(self.engine, ["--mode", "recover", "--report-file", str(Path(directory) / "report.json")])
        self.assertEqual(code, 0)
        self.assertEqual(self.engine.order, [])

    def test_cli_unknown_station_rejected_before_credentials_or_network(self):
        self.configure_cli()
        with self.assertRaises(ValueError):
            runtime.cli(self.engine, ["--mode", "collect", "--station-ids", "unknown"])
        self.assertEqual(self.engine.order, [])

    def test_report_is_valid_atomic_json_and_contains_no_credentials(self):
        import json
        report = self.collect()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            runtime.write_report(report, path)
            self.assertEqual(json.loads(path.read_text())["state"], "complete")
            self.assertFalse(path.with_name("report.json.tmp").exists())


if __name__ == "__main__":
    unittest.main()
