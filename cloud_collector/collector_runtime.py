"""Station-isolated cloud collection, bounded recovery and truthful health reports.

This module never changes client permissions, the station catalogue, API secrets,
or old documents when a new forecast is invalid. The engine remains the single
source of payload validation. All writes for one station share one transaction.
"""

import argparse
import json
import math
import os
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


@dataclass(frozen=True)
class RecoveryPolicy:
    max_attempts: int = 3
    retry_delays: tuple = (60.0, 300.0)
    max_workers: int = 4
    max_elapsed_seconds: float = 1800.0
    health_max_age_hours: float = 8.0

    def validate(self):
        if not 1 <= self.max_attempts <= 3:
            raise ValueError("max_attempts must be between 1 and 3")
        if not 1 <= self.max_workers <= 6:
            raise ValueError("max_workers must be between 1 and 6")
        if not 0 < self.max_elapsed_seconds <= 1800:
            raise ValueError("collection budget must be at most 30 minutes")
        if not 0 < self.health_max_age_hours <= 24:
            raise ValueError("health age must be greater than zero and at most 24 hours")
        if len(self.retry_delays) < self.max_attempts - 1 or any(
            isinstance(delay, bool) or not isinstance(delay, (int, float))
            or not 0 <= delay <= 600 for delay in self.retry_delays
        ):
            raise ValueError("retry delays must be bounded between 0 and 600 seconds")


class ModelFetchError(RuntimeError):
    def __init__(self, error):
        super().__init__("station model unavailable")
        self.original_error = error


class InconsistentPublication(RuntimeError):
    """A same-run station is incomplete; never re-date its surviving documents."""


def _utc(value):
    if not isinstance(value, datetime) or value.tzinfo is None:
        raise ValueError("an aware datetime is required")
    return value.astimezone(timezone.utc)


def _iso(value):
    return _utc(value).isoformat(timespec="seconds").replace("+00:00", "Z")


def _exception_info(error):
    """Never stringify network exceptions: their URLs can contain API keys."""
    original = error
    seen = set()
    while id(error) not in seen:
        seen.add(id(error))
        nested = getattr(error, "original_error", None) or getattr(error, "__cause__", None)
        if nested is None:
            break
        error = nested
    status = getattr(error, "status_code", None)
    if status is None:
        status = getattr(getattr(error, "response", None), "status_code", None)
    code = getattr(error, "code", None)
    try:
        code = code() if callable(code) else code
    except Exception:
        code = None
    code_name = getattr(code, "name", "")
    name = type(error).__name__
    auth = status in (401, 403) or name in {
        "PermissionDenied", "Forbidden", "Unauthenticated", "Unauthorized"
    } or code_name in {"PERMISSION_DENIED", "UNAUTHENTICATED"}
    permanent_http = isinstance(status, int) and 400 <= status < 500 and status not in {
        408, 425, 429
    }
    result = {
        "category": "authentication" if auth else (
            "inconsistent_publication" if isinstance(original, InconsistentPublication)
            else "permanent_http" if permanent_http else "validation" if isinstance(error, ValueError)
            else "temporary_or_unknown"
        ),
        "error_type": name,
        "http_status": status if isinstance(status, int) else None,
        "retryable": not (auth or permanent_http or isinstance(original, InconsistentPublication)),
        "fatal": auth,
    }
    retry_after = getattr(error, "retry_after_seconds", None)
    if (status in {429, 503} and not isinstance(retry_after, bool)
            and isinstance(retry_after, (int, float)) and math.isfinite(retry_after)
            and retry_after > 0):
        result["retry_after_seconds"] = retry_after
    return result


def _read_provider_cooldown(db, now):
    snapshot = db.collection("collector_health").document("provider-cooldown").get()
    if not snapshot.exists:
        return None
    data = snapshot.to_dict()
    if not isinstance(data, dict) or data.get("provider") != "open-meteo":
        raise ValueError("provider cooldown metadata is invalid")
    until = _utc(data.get("until"))
    return until if until > _utc(now) else None


def _persist_provider_cooldown(engine, db, until, run_id, now):
    """Private server state: respect Retry-After across separate workflow runs."""
    reference = db.collection("collector_health").document("provider-cooldown")
    until = _utc(until)
    @engine.firestore.transactional
    def extend(transaction):
        snapshot = reference.get(transaction=transaction)
        previous = snapshot.to_dict() if snapshot.exists else None
        if isinstance(previous, dict):
            previous_until = previous.get("until")
            if isinstance(previous_until, datetime) and previous_until.tzinfo is not None:
                until_to_write = max(until, _utc(previous_until))
            else:
                until_to_write = until
        else:
            until_to_write = until
        transaction.set(reference, {
            "provider": "open-meteo", "until": until_to_write,
            "reason": "provider_retry_after", "forecast_run_id": run_id,
            "updated_at": engine.firestore.SERVER_TIMESTAMP,
        })
        return until_to_write
    return extend(db.transaction())


def _station_config(engine, spot):
    spot_id = spot["id"]
    conditions = {
        spot_id: engine.CONDITIONS_SPOT_IDS[spot_id]
    } if spot_id in engine.CONDITIONS_SPOT_IDS else {}
    aliases = {
        spot_id: engine.LEGACY_CONDITIONS_ALIASES[spot_id]
    } if spot_id in engine.LEGACY_CONDITIONS_ALIASES else {}
    return conditions, aliases


def _station_documents(engine, db, publication, run_id, run_started_at, now):
    spot = publication["spot"]
    spot_id = spot["id"]
    conditions, aliases = _station_config(engine, spot)
    engine._validate_publications_before_commit([publication], run_id, conditions)
    aliases = engine._effective_conditions_aliases(conditions, aliases)
    generated_at = _utc(run_started_at)
    weather = {**publication["weather_doc"], "forecast_generated_at": generated_at}
    index = {
        "forecast_run_id": run_id,
        "forecast_generated_at": generated_at,
        "spot_id": spot_id,
        "last_update": engine.firestore.SERVER_TIMESTAMP,
        "name": spot["name"],
        "latitude": spot["lat"],
        "longitude": spot["lon"],
    }
    documents = [
        (db.collection("spots_meteo").document(spot_id), weather),
        (db.collection("spots_index").document(spot_id), index),
    ]
    if conditions:
        condition_doc = {
            **publication["conditions_doc"],
            "forecast_generated_at": generated_at,
        }
        documents.append((db.collection("conditions").document(conditions[spot_id]), condition_doc))
        if aliases:
            # Version 24 expects an ISO timestamp only in historical aliases.
            alias = {**condition_doc, "timestamp": _iso(now)}
            documents.append((db.collection("conditions").document(aliases[spot_id]), alias))
    paths = [reference.path for reference, _ in documents]
    if len(paths) != len(set(paths)):
        raise ValueError("station document identifiers must be distinct")
    return documents


def publish_station_atomic(engine, db, publication, run_id, run_started_at, *, now=None):
    """Atomically replace a station unless a newer generation already exists.

    The transaction reads every affected document before any write. Firestore
    retries on concurrent updates, so a late old worker cannot pass a stale
    freshness check and overwrite a newer station. Same-run retries are no-ops;
    the caller must still verify their existing payloads.
    """
    now = _utc(now or datetime.now(timezone.utc))
    documents = _station_documents(engine, db, publication, run_id, run_started_at, now)

    @engine.firestore.transactional
    def commit(transaction):
        snapshots = [reference.get(transaction=transaction) for reference, _ in documents]
        existing = [snapshot.to_dict() if snapshot.exists else None for snapshot in snapshots]
        weather = existing[0]
        if weather and weather.get("forecast_run_id") == run_id:
            if not all(data and data.get("forecast_run_id") == run_id for data in existing):
                raise InconsistentPublication("same-run station documents disagree")
            return {"state": "already_committed", "writes": 0}
        if weather:
            # Invalid historical metadata must be recoverable. Prefer the
            # generation field, then an aware legacy last_update; malformed
            # dates cannot claim ownership of an otherwise invalid station.
            previous_generation = next((value for value in (
                weather.get("forecast_generated_at"), weather.get("last_update")
            ) if isinstance(value, datetime) and value.tzinfo is not None), None)
            if previous_generation is not None and _utc(previous_generation) > _utc(run_started_at):
                return {"state": "superseded", "writes": 0}
        for reference, document in documents:
            transaction.set(reference, document)
        return {"state": "written", "writes": len(documents)}

    return commit(db.transaction())


def _verify_station(engine, db, spot, run_id, run_started_at, now):
    conditions, aliases = _station_config(engine, spot)
    engine.verify_production_state(
        db, [spot], run_id, run_started_at,
        conditions_spot_ids=conditions, conditions_aliases=aliases, now=now,
    )


def _prioritized(spots):
    return sorted(spots, key=lambda spot: not spot["id"].endswith("_maroc"))


def _require_current_station_day(engine, db, spot, weather, now):
    zone = engine._open_meteo_timezone(weather.get("timezone"), weather.get("utc_offset_seconds", 0))
    current_day = _utc(now).astimezone(zone).date()
    weather_dates = {day.get("date") for day in weather.get("days", []) if isinstance(day, dict)}
    if current_day.isoformat() not in weather_dates:
        raise ValueError("weather does not cover the current station day")
    conditions, _ = _station_config(engine, spot)
    if not conditions:
        return
    snapshot = db.collection("conditions").document(conditions[spot["id"]]).get()
    data = snapshot.to_dict() if snapshot.exists else {}
    series = (data.get("tide") or {}).get("hourly") or []
    if not series:
        raise ValueError("marine series is absent")
    start = datetime.combine(current_day, datetime.min.time(), tzinfo=zone).astimezone(timezone.utc)
    end = datetime.combine(current_day + timedelta(days=1), datetime.min.time(), tzinfo=zone).astimezone(timezone.utc)
    first = engine._parse_utc_instant(series[0].get("time"))
    last = engine._parse_utc_instant(series[-1].get("time"))
    if first > start or last < end - timedelta(hours=1):
        raise ValueError("marine series does not cover the complete current station day")


def check_health(engine, db, spots=None, *, now=None, max_age_hours=8.0):
    """Read-only check of freshness AND the full existing station contract."""
    now = _utc(now or datetime.now(timezone.utc))
    if not 0 < max_age_hours <= 24:
        raise ValueError("health maximum age must be between zero and 24 hours")
    results = []
    for spot in _prioritized(list(spots if spots is not None else engine.SPOTS)):
        result = {"spot_id": spot["id"], "state": "healthy", "age_seconds": None}
        try:
            snapshot = db.collection("spots_meteo").document(spot["id"]).get()
            if not snapshot.exists:
                raise ValueError("weather document missing")
            weather = snapshot.to_dict()
            if not isinstance(weather, dict):
                raise ValueError("weather document invalid")
            updated_at = _utc(weather.get("last_update"))
            age = (now - updated_at).total_seconds()
            result["age_seconds"] = round(age, 3)
            if age < -300:
                raise ValueError("weather date in future")
            run_id = weather.get("forecast_run_id")
            if not isinstance(run_id, str) or not run_id.strip():
                raise ValueError("weather run id missing")
            # Even a stale station is checked for corruption and mixed runs.
            _verify_station(engine, db, spot, run_id, updated_at, now)
            _require_current_station_day(engine, db, spot, weather, now)
            if age > max_age_hours * 3600:
                result["state"] = "stale"
        except Exception as error:
            info = _exception_info(error)
            result.update(state="invalid", error=info)
            results.append(result)
            if info["fatal"]:
                return {"state": "aborted", "checked_at": _iso(now), "stations": results,
                        "fatal_error": info, "recovery_ids": []}
            continue
        results.append(result)
    recovery_ids = [row["spot_id"] for row in results if row["state"] != "healthy"]
    return {
        "state": "healthy" if not recovery_ids else "recovery_required",
        "checked_at": _iso(now), "max_age_hours": max_age_hours,
        "stations": results, "recovery_ids": recovery_ids,
    }


def _validate_spots(engine, spots):
    catalogue = {spot["id"]: spot for spot in engine.SPOTS}
    ids = [spot.get("id") for spot in spots]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError("at least one distinct station is required")
    for spot in spots:
        if catalogue.get(spot.get("id")) != spot:
            raise ValueError("station must exactly match the production catalogue")


def run_collection(
    engine, db, run_id, *, spots=None, policy=None, dry_run=False,
    now_fn=None, monotonic_fn=None, sleeper=None, fetcher=None, publisher=None,
    publication_sink=None,
):
    """Collect independent stations, then retry ONLY unresolved stations.

    Morocco completes its first pass before any foreign station is requested.
    In-flight requests are bounded by max_workers; auth failures stop further
    scheduling. A partial run is explicitly unsuccessful even when most stations
    were refreshed. The function never raises errors containing upstream URLs.
    """
    policy = policy or RecoveryPolicy()
    policy.validate()
    now_fn = now_fn or (lambda: datetime.now(timezone.utc))
    monotonic_fn = monotonic_fn or time.monotonic
    sleeper = sleeper or time.sleep
    fetcher = fetcher or engine._fetch_station_models
    publisher = publisher or publish_station_atomic
    spots = _prioritized(list(spots if spots is not None else engine.SPOTS))
    _validate_spots(engine, spots)
    if not isinstance(run_id, str) or not run_id.strip():
        raise ValueError("run_id is required")
    started_at = _utc(now_fn())
    started_monotonic = monotonic_fn()
    states = {spot["id"]: {"spot_id": spot["id"], "state": "pending", "attempts": 0,
                           "errors": [], "writes": 0} for spot in spots}
    fatal_error = None
    budget_exhausted = False
    provider_cooldown = None
    try:
        provider_cooldown = _read_provider_cooldown(db, now_fn())
    except Exception as error:
        fatal_error = _exception_info(error)

    def remaining():
        return policy.max_elapsed_seconds - (monotonic_fn() - started_monotonic)

    def fail(row, error):
        nonlocal fatal_error, provider_cooldown
        info = _exception_info(error)
        row["errors"].append(info)
        row["state"] = "retry_pending" if info["retryable"] else "failed"
        if info["fatal"]:
            fatal_error = info
        elif "retry_after_seconds" in info:
            try:
                until = _utc(now_fn()) + timedelta(seconds=info["retry_after_seconds"])
                provider_cooldown = until
                if not dry_run:
                    provider_cooldown = _persist_provider_cooldown(engine, db, until, run_id, now_fn())
                row["next_retry_at"] = _iso(provider_cooldown)
            except Exception as state_error:
                # A quota hold that cannot be saved must not turn into a storm
                # of new calls. Stop this run and surface the storage failure.
                fatal_error = _exception_info(state_error)

    for attempt in range(1, policy.max_attempts + 1):
        todo = [spot for spot in spots if states[spot["id"]]["state"] in {"pending", "retry_pending"}]
        if not todo or fatal_error or provider_cooldown:
            break
        if attempt > 1:
            delay = policy.retry_delays[attempt - 2]
            if remaining() <= delay:
                budget_exhausted = True
                break
            sleeper(delay)
        # Separate priority groups: no foreign request starts before the first
        # Morocco group has finished, even when one Moroccan model is slow.
        groups = [
            [spot for spot in todo if spot["id"].endswith("_maroc")],
            [spot for spot in todo if not spot["id"].endswith("_maroc")],
        ]
        for group in groups:
            if fatal_error or budget_exhausted or provider_cooldown:
                break
            iterator = iter(group)
            with ThreadPoolExecutor(max_workers=policy.max_workers) as executor:
                pending = {}

                def submit_next():
                    nonlocal budget_exhausted
                    if remaining() <= 0:
                        budget_exhausted = True
                        return False
                    try:
                        spot = next(iterator)
                    except StopIteration:
                        return False
                    row = states[spot["id"]]
                    row["attempts"] += 1
                    pending[executor.submit(fetcher, spot)] = spot
                    return True

                for _ in range(policy.max_workers):
                    if not submit_next():
                        break
                while pending:
                    completed, _ = wait(pending, return_when=FIRST_COMPLETED)
                    for future in completed:
                        spot = pending.pop(future)
                        row = states[spot["id"]]
                        if fatal_error or provider_cooldown:
                            # Requests already running may finish, but their data
                            # is not published after a global authorization error.
                            row["state"] = "aborted" if fatal_error else "deferred_provider_cooldown"
                            continue
                        if remaining() <= 0:
                            budget_exhausted = True
                            row["state"] = "budget_exhausted"
                            continue
                        stage = "fetch"
                        try:
                            result = future.result()
                            errors = result.get("errors") or {}
                            if errors:
                                raise ModelFetchError(next(iter(errors.values())))
                            stage = "build"
                            conditions, _ = _station_config(engine, spot)
                            publication = engine._build_station_publication(
                                result, run_id, conditions_spot_ids=conditions,
                            )
                            if publication.get("spot") != spot:
                                raise ValueError("built station identity differs")
                            coverage = (publication.get("conditions_doc") or {}).get("coverage")
                            if isinstance(coverage, dict):
                                row["coverage"] = coverage
                            if dry_run:
                                engine._validate_publications_before_commit([publication], run_id, conditions)
                                if publication_sink is not None:
                                    publication_sink(publication)
                                row["state"] = "validated"
                            else:
                                stage = "publish"
                                outcome = publisher(engine, db, publication, run_id, started_at, now=now_fn())
                                if outcome["state"] == "superseded":
                                    # A newer run owns this station; verify that
                                    # replacement rather than overwriting it.
                                    health = check_health(engine, db, [spot], now=now_fn(),
                                                          max_age_hours=policy.health_max_age_hours)
                                    if health["state"] != "healthy":
                                        raise InconsistentPublication("newer station did not pass health checks")
                                    row["state"] = "superseded_by_healthy_run"
                                else:
                                    row["writes"] += outcome.get("writes", 0)
                                    stage = "verify"
                                    _verify_station(engine, db, spot, run_id, started_at, now_fn())
                                    row["state"] = "verified"
                        except Exception as error:
                            # A timeout after commit is ambiguous. Read back the
                            # exact run before any retry; never stamp it twice.
                            if stage in {"publish", "verify"} and not _exception_info(error)["fatal"]:
                                try:
                                    _verify_station(engine, db, spot, run_id, started_at, now_fn())
                                    row["state"] = "verified_after_uncertain_commit"
                                except Exception as verification_error:
                                    if _exception_info(verification_error)["fatal"]:
                                        fail(row, verification_error)
                                    else:
                                        fail(row, error)
                            else:
                                fail(row, error)
                        if not fatal_error and not budget_exhausted and not provider_cooldown:
                            submit_next()
                    if fatal_error or budget_exhausted or provider_cooldown:
                        for future in pending:
                            future.cancel()
        if fatal_error or budget_exhausted or provider_cooldown:
            break
    successes = {"verified", "verified_after_uncertain_commit", "superseded_by_healthy_run", "validated"}
    for row in states.values():
        if row["state"] in {"pending", "retry_pending"}:
            row["state"] = ("aborted" if fatal_error else "deferred_provider_cooldown" if provider_cooldown
                            else "budget_exhausted" if budget_exhausted else "failed")
    unresolved = [spot_id for spot_id, row in states.items() if row["state"] not in successes]
    report = {
        "schema_version": 1, "run_id": run_id,
        "state": "aborted" if fatal_error else "provider_cooldown" if provider_cooldown else "partial" if unresolved else "dry_run_complete" if dry_run else "complete",
        "dry_run": dry_run, "started_at": _iso(started_at), "finished_at": _iso(now_fn()),
        "selected_station_count": len(spots),
        "successful_station_count": len(spots) - len(unresolved),
        "unresolved_station_ids": unresolved, "budget_exhausted": budget_exhausted,
        "writes_acknowledged": sum(row["writes"] for row in states.values()),
        "morocco_station_count": sum(spot["id"].endswith("_maroc") for spot in spots),
        "stations": [states[spot["id"]] for spot in spots],
    }
    if fatal_error:
        report["fatal_error"] = fatal_error
    if provider_cooldown:
        report["provider_cooldown_until"] = _iso(provider_cooldown)
    return report


def write_report(report, filename):
    """Atomic local artifact; no telemetry collection or public user data."""
    path = Path(filename)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(str(temporary), str(path))


def cli(engine=None, argv=None):
    if engine is None:
        import harvest_forecast as engine
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("collect", "recover", "health", "dry-run", "retry"), default="collect")
    parser.add_argument("--station-ids", "--stations", dest="stations", help="comma-separated catalogue IDs; omitted means all stations")
    parser.add_argument("--dry-run", action="store_true", help="fetch and validate, never publish")
    parser.add_argument("--report-file", "--output-file", dest="output_file", default="collector-report.json")
    parser.add_argument("--fixture-file", help="optional dry-run payload artifact; never contains credentials")
    parser.add_argument("--max-attempts", type=int, default=3)
    parser.add_argument("--max-workers", type=int, default=4)
    parser.add_argument("--health-max-age-hours", type=float, default=8.0)
    args = parser.parse_args(argv)
    policy = RecoveryPolicy(max_attempts=args.max_attempts, max_workers=args.max_workers,
                            health_max_age_hours=args.health_max_age_hours)
    policy.validate()
    if len(engine.SPOTS) != engine.EXPECTED_STATION_COUNT:
        raise ValueError("production catalogue size changed")
    if set(engine.CONDITIONS_SPOT_IDS) != {spot["id"] for spot in engine.SPOTS}:
        raise ValueError("every catalogue station must have one conditions document")
    spots = engine.SPOTS
    if args.stations:
        requested = args.stations.split(",")
        if len(requested) != len(set(requested)) or set(requested) - {spot["id"] for spot in spots}:
            raise ValueError("unknown or duplicate station selection")
        spots = [spot for spot in spots if spot["id"] in requested]
    _validate_spots(engine, spots)
    cred = engine.credentials.Certificate("firebase-key.json")
    try:
        engine.firebase_admin.get_app()
    except ValueError:
        engine.firebase_admin.initialize_app(cred)
    db = engine.firestore.client()
    health = None
    if args.mode in {"health", "recover", "retry"}:
        health = check_health(engine, db, spots, max_age_hours=policy.health_max_age_hours)
        if args.mode == "health" or health["state"] == "aborted":
            write_report(health, args.output_file)
            print(json.dumps(health, ensure_ascii=False))
            return 0 if health["state"] == "healthy" else 2
        spots = [spot for spot in spots if spot["id"] in set(health["recovery_ids"])]
        if not spots:
            report = {"schema_version": 1, "state": "no_recovery_needed", "health": health}
            write_report(report, args.output_file)
            print(json.dumps(report, ensure_ascii=False))
            return 0
    if not engine.OPEN_METEO_API_KEY or not engine.FORECAST_RUN_ID:
        raise ValueError("server API key and immutable forecast run ID are required")
    fixtures = []
    dry_run = args.dry_run or args.mode == "dry-run"
    if args.fixture_file and not dry_run:
        raise ValueError("fixture export is restricted to dry-run mode")
    report = run_collection(engine, db, engine.FORECAST_RUN_ID, spots=spots,
                            policy=policy, dry_run=dry_run,
                            publication_sink=fixtures.append if args.fixture_file else None)
    if args.fixture_file:
        instant = datetime.now(timezone.utc)
        def fixture_value(value):
            if value is engine.firestore.SERVER_TIMESTAMP:
                return _iso(instant)
            if isinstance(value, datetime):
                return _iso(value)
            if isinstance(value, dict):
                return {key: fixture_value(item) for key, item in value.items()}
            if isinstance(value, (list, tuple)):
                return [fixture_value(item) for item in value]
            return value
        write_report({"schema_version": 1, "run_id": engine.FORECAST_RUN_ID,
                      "generated_at": _iso(instant),
                      "publications": fixture_value(fixtures)}, args.fixture_file)
    if health is not None:
        report["initial_health"] = health
    write_report(report, args.output_file)
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["state"] in {"complete", "dry_run_complete"} else 2


if __name__ == "__main__":
    raise SystemExit(cli())
