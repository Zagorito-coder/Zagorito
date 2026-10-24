"""Bounded private incident memory; never changes a public forecast document.

One document per catalogue station, including resolved tombstones. Scheduled
full collections can reassess blocked incidents; hourly recovery respects their
block and the next permitted retry. No query or additional index is required.
"""

import math
import re
from datetime import datetime, timedelta, timezone

from collector_diagnostics import sanitize_diagnostic_fields


_SUCCESS_STATES = {"verified", "verified_after_uncertain_commit", "superseded_by_healthy_run"}
_STATES = {"pending", "blocked", "resolved"}
_CATEGORIES = {"authentication", "inconsistent_publication", "permanent_http",
               "validation", "temporary_or_unknown"}


def _utc(value):
    if not isinstance(value, datetime) or value.tzinfo is None:
        raise ValueError("recovery metadata requires an aware datetime")
    return value.astimezone(timezone.utc)


def _iso(value):
    return _utc(value).isoformat(timespec="seconds").replace("+00:00", "Z")


def recovery_reference(db, spot_id):
    if not isinstance(spot_id, str) or not re.fullmatch(r"[a-z0-9_]{1,100}", spot_id):
        raise ValueError("invalid recovery station identifier")
    return db.collection("collector_health").document("recovery-" + spot_id)


def _safe_error(info):
    info = info if isinstance(info, dict) else {}
    name = info.get("error_type")
    status = info.get("http_status")
    result = {
        "category": info.get("category") if info.get("category") in _CATEGORIES else "temporary_or_unknown",
        "error_type": name if isinstance(name, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,79}", name) else "UnknownError",
        "http_status": status if type(status) is int and 100 <= status <= 599 else None,
        "retryable": info.get("retryable") is not False,
        "fatal": info.get("fatal") is True,
    }
    delay = info.get("retry_after_seconds")
    if (not isinstance(delay, bool) and isinstance(delay, (int, float))
            and math.isfinite(delay) and delay > 0):
        result["retry_after_seconds"] = delay
    result.update(sanitize_diagnostic_fields(info))
    return result


def _validate_record(value, spot_id):
    if (not isinstance(value, dict) or type(value.get("schema_version")) is not int
            or value["schema_version"] != 1 or value.get("spot_id") != spot_id
            or value.get("state") not in _STATES
            or not isinstance(value.get("run_id"), str) or not value["run_id"].strip()
            or type(value.get("cycles")) is not int or not 0 <= value["cycles"] <= 32):
        raise ValueError("invalid private recovery record")
    _utc(value.get("run_started_at"))
    _utc(value.get("updated_at"))
    if value["state"] == "pending":
        _utc(value.get("next_retry_at"))
        if value["cycles"] < 1 or not isinstance(value.get("error"), dict):
            raise ValueError("invalid pending recovery record")
    elif value.get("next_retry_at") is not None:
        raise ValueError("non-pending recovery record has a retry date")
    return value


def load_recovery(db, spots):
    """Read only catalogue-addressed private records, never scan user data."""
    references = {recovery_reference(db, spot["id"]).path: spot["id"] for spot in spots}
    result = {}
    refs = [recovery_reference(db, spot_id) for spot_id in references.values()]
    seen = set()
    for snapshot in db.get_all(refs):
        path = snapshot.reference.path
        if path not in references or path in seen:
            raise ValueError("unexpected private recovery document")
        seen.add(path)
        if snapshot.exists:
            spot_id = references[path]
            result[spot_id] = _validate_record(snapshot.to_dict(), spot_id)
    if seen != set(references):
        raise ValueError("incomplete private recovery read")
    return result


def select_recovery(health, entries, spots, *, now):
    """Union health failures with incident memory, then apply every hold."""
    now = _utc(now)
    allowed = {spot["id"] for spot in spots}
    health_ids = set(health.get("recovery_ids", [])) & allowed
    selected, deferred = [], []
    for spot in spots:
        spot_id = spot["id"]
        entry = entries.get(spot_id)
        if entry is not None:
            _validate_record(entry, spot_id)
        if spot_id not in health_ids and (entry is None or entry["state"] == "resolved"):
            continue
        if entry is not None and entry["state"] == "blocked":
            deferred.append({"spot_id": spot_id, "reason": "blocked"})
        elif entry is not None and entry["state"] == "pending" and _utc(entry["next_retry_at"]) > now:
            deferred.append({"spot_id": spot_id, "reason": "retry_not_due",
                             "next_retry_at": _iso(entry["next_retry_at"])})
        else:
            selected.append(spot_id)
    return {"selected_ids": selected, "deferred": deferred}


def _weather_generation(weather):
    if not isinstance(weather, dict):
        return None
    for value in (weather.get("forecast_generated_at"), weather.get("last_update")):
        if isinstance(value, datetime) and value.tzinfo is not None:
            return _utc(value)
    return None


def record_outcome(engine, db, spot, row, run_id, run_started_at, *, now,
                   provider_cooldown=None, fatal_error=None):
    """Record a final cycle outcome with transactional generation guards.

    The caller marks success only AFTER the complete station has been reread
    and validated. A later generation wins; ambiguous equal-time different
    runs are preserved rather than guessed. Replaying one run is idempotent.
    """
    started, now = _utc(run_started_at), _utc(now)
    reference = recovery_reference(db, spot["id"])
    weather_reference = db.collection("spots_meteo").document(spot["id"])
    successful = row.get("state") in _SUCCESS_STATES
    errors = row.get("errors") or []
    info = _safe_error(errors[-1] if errors else fatal_error)

    @engine.firestore.transactional
    def update(transaction):
        # Firestore requires every read before the first transaction write.
        previous_snapshot = reference.get(transaction=transaction)
        weather_snapshot = weather_reference.get(transaction=transaction)
        previous = _validate_record(previous_snapshot.to_dict(), spot["id"]) if previous_snapshot.exists else None
        weather = weather_snapshot.to_dict() if weather_snapshot.exists else None
        weather_started = _weather_generation(weather)
        effective_started, effective_run = started, run_id
        if previous and row.get("state") != "superseded_by_healthy_run":
            previous_started = _utc(previous["run_started_at"])
            if (previous_started > started or
                    (previous_started == started and previous["run_id"] != run_id)):
                return {"state": "superseded", "cycles": previous["cycles"]}
        if successful:
            if weather_started is None or not isinstance(weather.get("forecast_run_id"), str):
                raise ValueError("verified recovery outcome has no published generation")
            if row["state"] == "superseded_by_healthy_run":
                verified_generation = row.get("verified_generation")
                if not isinstance(verified_generation, str):
                    raise ValueError("replacement recovery outcome has no verified generation")
                effective_started = _utc(datetime.fromisoformat(verified_generation.replace("Z", "+00:00")))
                effective_run = row.get("verified_run_id")
                if effective_run != weather["forecast_run_id"] or effective_started != weather_started:
                    # Never resolve a replacement that changed AFTER the
                    # caller's successful health check; that newer run was not
                    # part of this validation.
                    return {"state": "superseded", "cycles": previous["cycles"] if previous else 0}
            elif weather["forecast_run_id"] != run_id or weather_started != started:
                # The successful reread has itself been superseded meanwhile.
                return {"state": "superseded", "cycles": previous["cycles"] if previous else 0}
        elif weather_started is not None and (
                weather_started > started or (weather_started == started and weather.get("forecast_run_id") != run_id)):
            return {"state": "superseded", "cycles": previous["cycles"] if previous else 0}
        if previous:
            previous_started = _utc(previous["run_started_at"])
            if (previous_started > effective_started or
                    (previous_started == effective_started and previous["run_id"] != effective_run)):
                return {"state": "superseded", "cycles": previous["cycles"]}
            same_run = previous_started == effective_started and previous["run_id"] == effective_run
            if same_run and (previous["state"] == "resolved" or not successful):
                return {"state": previous["state"], "cycles": previous["cycles"],
                        "next_retry_at": _iso(previous["next_retry_at"]) if previous["next_retry_at"] else None}
        cycles = previous["cycles"] if previous and previous["state"] != "resolved" else 0
        if successful:
            state, next_retry, error = "resolved", None, None
        else:
            cycles = min(32, cycles + 1)
            error = info
            state = "pending" if info["retryable"] and not info["fatal"] else "blocked"
            next_retry = None
            if state == "pending":
                delay_hours = (1, 2, 4, 6)[min(cycles - 1, 3)]
                next_retry = now + timedelta(hours=delay_hours)
                if provider_cooldown is not None:
                    next_retry = max(next_retry, _utc(provider_cooldown))
                if "retry_after_seconds" in info:
                    next_retry = max(next_retry, now + timedelta(seconds=info["retry_after_seconds"]))
        transaction.set(reference, {
            "schema_version": 1, "spot_id": spot["id"], "state": state,
            "run_id": effective_run, "run_started_at": effective_started,
            "cycles": cycles, "next_retry_at": next_retry, "error": error,
            "attempts_in_run": row.get("attempts", 0), "updated_at": now,
        })
        return {"state": state, "cycles": cycles,
                "next_retry_at": _iso(next_retry) if next_retry else None}

    return update(db.transaction())
