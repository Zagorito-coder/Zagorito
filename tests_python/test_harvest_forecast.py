import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

import requests

import harvest_forecast


def _valid_days(day_count=10):
    """Payload GFS local UTC+1 : 01/04/.../22, huit pas natifs par jour."""
    first_day = datetime(2026, 8, 1)
    days = []
    for day_index in range(day_count):
        current_day = first_day + timedelta(days=day_index)
        slots = []
        for hour in range(1, 24, 3):
            slot_time = current_day.replace(hour=hour)
            slots.append(
                {
                    "hour": slot_time.isoformat(timespec="minutes"),
                    "wind_speed_kt": 10.0,
                    "wind_dir_deg": 320.0,
                    "wave_height_m": 1.1,
                    "wave_period_s": 9.0,
                    "wave_dir_deg": 305.0,
                    "temp_c": 24,
                    "weather_code": 1.0,
                    "is_day": 1.0,
                    "rating": 4,
                    "models": {
                        "wind": {
                            "wind_speed_kt": 10.0,
                            "wind_gust_kt": 12.0,
                            "wind_dir_deg": 320.0,
                            "pressure_msl": 1014.0,
                            "precipitation_mm": 0.0,
                            "precip_prob_pct": 0.0,
                            "rel_humidity_pct": 70.0,
                            "cloud_total_pct": 5.0,
                            "visibility_m": 20000.0,
                        },
                        "hires": {"wind_speed_kt": 9.0},
                        "wave": {
                            "wave_height_m": 1.1,
                            "wave_period_s": 9.0,
                            "wave_dir_deg": 305.0,
                            "swell_height_m": 0.8,
                            "swell_period_s": 10.0,
                            "swell_dir_deg": 300.0,
                        },
                    },
                }
            )
        days.append(
            {
                "date": current_day.date().isoformat(),
                "slots": slots,
            }
        )
    return days


class _FakeSnapshot:
    def __init__(self, data):
        self.exists = data is not None
        self._data = data

    def to_dict(self):
        return self._data


class _FakeDocument:
    def __init__(self, database, collection_name, document_id):
        self.database = database
        self.collection_name = collection_name
        self.document_id = document_id

    @property
    def key(self):
        return self.collection_name, self.document_id

    def get(self):
        return _FakeSnapshot(self.database.documents.get(self.key))


class _FakeCollection:
    def __init__(self, database, name):
        self.database = database
        self.name = name

    def document(self, document_id):
        return _FakeDocument(self.database, self.name, document_id)


class _FakeBatch:
    def __init__(self, database):
        self.database = database
        self.operations = []
        self.commit_count = 0

    def set(self, reference, data, merge=False):
        self.operations.append((reference.key, data, merge))

    def commit(self):
        self.commit_count += 1
        self.database.commit_attempt_count += 1
        if (
            self.database.fail_commit_number is not None
            and self.database.commit_attempt_count
            == self.database.fail_commit_number
        ):
            raise RuntimeError("échec commit Firestore simulé")


class _FakeDatabase:
    def __init__(self, documents=None, *, fail_commit_number=None):
        self.documents = {} if documents is None else documents
        self.fail_commit_number = fail_commit_number
        self.commit_attempt_count = 0
        self.last_batch = None
        self.batches = []
        self.batch_count = 0

    def collection(self, name):
        return _FakeCollection(self, name)

    def batch(self):
        self.batch_count += 1
        self.last_batch = _FakeBatch(self)
        self.batches.append(self.last_batch)
        return self.last_batch


class FakeResponse:
    def __init__(self, status_code=200, payload=None):
        self.status_code = status_code
        self.ok = 200 <= status_code < 300
        self._payload = {} if payload is None else payload

    def json(self):
        if isinstance(self._payload, Exception):
            raise self._payload
        return self._payload


class FetchJsonTests(unittest.TestCase):
    def test_read_timeout_is_retried_then_succeeds(self):
        requester = mock.Mock(
            side_effect=[
                requests.ReadTimeout("secret URL must not be logged"),
                FakeResponse(payload={"hourly": {"time": []}}),
            ]
        )
        delays = []

        result = harvest_forecast._fetch_json(
            "https://example.invalid",
            {"apikey": "top-secret"},
            requester=requester,
            sleeper=delays.append,
            jitter=lambda: 0.0,
        )

        self.assertEqual({"hourly": {"time": []}}, result)
        self.assertEqual(2, requester.call_count)
        self.assertEqual([1.0], delays)
        self.assertEqual(
            harvest_forecast.HTTP_TIMEOUT,
            requester.call_args_list[0].kwargs["timeout"],
        )

    def test_retryable_http_status_is_retried(self):
        requester = mock.Mock(
            side_effect=[
                FakeResponse(status_code=429),
                FakeResponse(payload={"ok": True}),
            ]
        )
        delays = []

        result = harvest_forecast._fetch_json(
            "https://example.invalid",
            {},
            requester=requester,
            sleeper=delays.append,
            jitter=lambda: 0.0,
        )

        self.assertEqual({"ok": True}, result)
        self.assertEqual(2, requester.call_count)
        self.assertEqual([1.0], delays)

    def test_permanent_http_status_fails_without_retry(self):
        requester = mock.Mock(return_value=FakeResponse(status_code=400))
        delays = []

        with self.assertRaises(harvest_forecast.OpenMeteoHttpError) as context:
            harvest_forecast._fetch_json(
                "https://example.invalid",
                {},
                requester=requester,
                sleeper=delays.append,
                jitter=lambda: 0.0,
            )

        self.assertEqual(400, context.exception.status_code)
        self.assertEqual(1, requester.call_count)
        self.assertEqual([], delays)

    def test_invalid_json_is_retried(self):
        requester = mock.Mock(
            side_effect=[
                FakeResponse(payload=ValueError("truncated")),
                FakeResponse(payload={"ok": True}),
            ]
        )

        result = harvest_forecast._fetch_json(
            "https://example.invalid",
            {},
            requester=requester,
            sleeper=lambda _: None,
            jitter=lambda: 0.0,
        )

        self.assertEqual({"ok": True}, result)
        self.assertEqual(2, requester.call_count)

    def test_error_summary_never_echoes_request_details(self):
        error = requests.ReadTimeout(
            "https://example.invalid?apikey=top-secret timed out"
        )

        self.assertEqual("ReadTimeout", harvest_forecast._error_summary(error))


class StationCollectionTests(unittest.TestCase):
    def test_station_model_failure_stops_following_model_calls(self):
        spot = {"id": "test", "name": "Test", "lat": 1.0, "lon": 2.0}

        def success(_lat, _lon):
            return {"hourly": {"time": []}}

        def failure(_lat, _lon):
            raise requests.ReadTimeout("timeout")

        wave_fetcher = mock.Mock(side_effect=AssertionError("appel interdit"))
        result = harvest_forecast._fetch_station_models(
            spot,
            fetchers=(
                ("wind", success),
                ("hires", failure),
                ("wave", wave_fetcher),
            ),
        )

        self.assertIs(result["spot"], spot)
        self.assertIsNone(result["models"]["hires"])
        self.assertIsInstance(result["errors"]["hires"], requests.ReadTimeout)
        self.assertIsNotNone(result["models"]["wind"])
        self.assertNotIn("wave", result["models"])
        wave_fetcher.assert_not_called()

    def test_parallel_iterator_is_bounded_and_returns_every_spot(self):
        spots = [
            {"id": str(index), "name": str(index), "lat": 0.0, "lon": 0.0}
            for index in range(12)
        ]
        active = 0
        maximum_active = 0
        lock = threading.Lock()

        def fake_fetch(spot):
            nonlocal active, maximum_active
            with lock:
                active += 1
                maximum_active = max(maximum_active, active)
            time.sleep(0.005)
            with lock:
                active -= 1
            return {"spot": spot, "models": {}, "errors": {}}

        with mock.patch.object(
            harvest_forecast,
            "_fetch_station_models",
            side_effect=fake_fetch,
        ):
            results = list(
                harvest_forecast._iter_station_results(spots, max_workers=3)
            )

        self.assertEqual(
            {spot["id"] for spot in spots},
            {result["spot"]["id"] for result in results},
        )
        self.assertLessEqual(maximum_active, 3)
        self.assertGreater(maximum_active, 1)


class SpotCatalogTests(unittest.TestCase):
    def test_spot_ids_are_unique_and_coordinates_are_valid(self):
        ids = [spot["id"] for spot in harvest_forecast.SPOTS]

        self.assertEqual(123, len(ids))
        self.assertEqual(len(ids), len(set(ids)))
        for spot in harvest_forecast.SPOTS:
            self.assertGreaterEqual(spot["lat"], -90)
            self.assertLessEqual(spot["lat"], 90)
            self.assertGreaterEqual(spot["lon"], -180)
            self.assertLessEqual(spot["lon"], 180)

    def test_known_inland_cells_keep_their_validated_coastal_coordinates(self):
        by_id = {spot["id"]: spot for spot in harvest_forecast.SPOTS}
        expected = {
            "casablanca_maroc": (33.5971, -7.6315),
            "tunis_tunisie": (36.82, 10.30),
            "basra_irak": (29.97, 48.47),
            "tetouan_maroc": (35.62, -5.27),
            "portharcourt_nigeria": (4.45, 7.17),
            "aqaba_jordanie": (29.45, 35.00),
            "eilat_israel": (29.48, 34.94),
        }

        for spot_id, coordinates in expected.items():
            self.assertEqual(
                coordinates,
                (by_id[spot_id]["lat"], by_id[spot_id]["lon"]),
            )


class NativeGfsStepTests(unittest.TestCase):
    def test_casablanca_utc_plus_one_uses_01_04_07_local_slots(self):
        self.assertTrue(
            harvest_forecast._is_native_gfs_step(
                "2026-08-14T01:00",
                3600,
            )
        )
        self.assertTrue(
            harvest_forecast._is_native_gfs_step(
                "2026-08-14T04:00",
                3600,
            )
        )
        self.assertFalse(
            harvest_forecast._is_native_gfs_step(
                "2026-08-14T00:00",
                3600,
            )
        )

    def test_utc_and_negative_offsets_remain_aligned_to_gfs(self):
        self.assertTrue(
            harvest_forecast._is_native_gfs_step(
                "2026-08-14T03:00",
                0,
            )
        )
        self.assertTrue(
            harvest_forecast._is_native_gfs_step(
                "2026-08-13T23:00",
                -3600,
            )
        )


class PayloadValidationTests(unittest.TestCase):
    def test_ten_complete_consecutive_native_gfs_days_are_valid(self):
        harvest_forecast.validate_payload(_valid_days(), utc_offset_seconds=3600)

    def test_less_than_ten_days_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "10 requis"):
            harvest_forecast.validate_payload(
                _valid_days(day_count=9),
                utc_offset_seconds=3600,
            )

    def test_day_with_less_than_eight_slots_is_rejected(self):
        days = _valid_days()
        days[3]["slots"].pop()

        with self.assertRaisesRegex(ValueError, "exactement 8"):
            harvest_forecast.validate_payload(days, utc_offset_seconds=3600)

    def test_non_native_local_slot_is_rejected(self):
        days = _valid_days()
        days[0]["slots"][0]["hour"] = "2026-08-01T00:00"

        with self.assertRaisesRegex(ValueError, "pas GFS UTC"):
            harvest_forecast.validate_payload(days, utc_offset_seconds=3600)

    def test_duplicate_or_unsorted_dates_are_rejected(self):
        duplicated = _valid_days()
        duplicated[1]["date"] = duplicated[0]["date"]
        with self.assertRaisesRegex(ValueError, "uniques"):
            harvest_forecast.validate_payload(
                duplicated,
                utc_offset_seconds=3600,
            )

        unsorted = _valid_days()
        unsorted[0], unsorted[1] = unsorted[1], unsorted[0]
        with self.assertRaisesRegex(ValueError, "triées"):
            harvest_forecast.validate_payload(
                unsorted,
                utc_offset_seconds=3600,
            )


class ProductionWriteAndVerificationTests(unittest.TestCase):
    def setUp(self):
        self.spot = {
            "id": "test_spot",
            "name": "Test côtier",
            "lat": 33.1,
            "lon": -7.2,
        }
        self.run_id = "123-2-deadbeef"
        self.started = datetime(2026, 8, 14, 10, 0, tzinfo=timezone.utc)
        self.updated = self.started + timedelta(minutes=1)

    def _documents(self):
        days = _valid_days()
        weather = {
            "forecast_run_id": self.run_id,
            "spot_id": self.spot["id"],
            "last_update": self.updated,
            "location_name": self.spot["name"],
            "latitude": self.spot["lat"],
            "longitude": self.spot["lon"],
            "utc_offset_seconds": 3600,
            "days": days,
        }
        index = {
            "forecast_run_id": self.run_id,
            "spot_id": self.spot["id"],
            "last_update": self.updated,
            "name": self.spot["name"],
            "latitude": self.spot["lat"],
            "longitude": self.spot["lon"],
        }
        gfs = harvest_forecast.build_conditions_gfs_summary(
            days,
            forecast_run_id=self.run_id,
            spot_id=self.spot["id"],
            last_update=self.updated,
        )
        return {
            ("spots_meteo", self.spot["id"]): weather,
            ("spots_index", self.spot["id"]): index,
            ("conditions", "test_condition"): {"gfs": gfs},
        }

    def test_station_publication_keeps_exactly_ten_validated_days(self):
        station_result = {
            "spot": self.spot,
            "models": {
                "wind": {"hourly": {"time": []}, "utc_offset_seconds": 3600},
                "hires": {"hourly": {"time": []}},
                "wave": {"hourly": {"time": []}},
            },
            "errors": {},
        }
        with mock.patch.object(
            harvest_forecast,
            "build_days_payload",
            return_value=(_valid_days(day_count=15), 23.0),
        ):
            publication = harvest_forecast._build_station_publication(
                station_result,
                self.run_id,
                conditions_spot_ids={self.spot["id"]: "test_condition"},
            )

        self.assertEqual(10, len(publication["weather_doc"]["days"]))
        self.assertEqual(
            80,
            len(publication["conditions_summary"]["hourly"]),
        )

    def test_global_write_uses_bounded_atomic_batches_for_251_documents(self):
        database = _FakeDatabase()
        spots = [
            {
                "id": f"spot_{index:03d}",
                "name": f"Spot {index:03d}",
                "lat": float(index) / 10,
                "lon": -float(index) / 10,
            }
            for index in range(123)
        ]
        conditions_spot_ids = {
            spot["id"]: f"condition_{index}"
            for index, spot in enumerate(spots[:5])
        }
        publications = []
        for spot in spots:
            summary = None
            if spot["id"] in conditions_spot_ids:
                summary = {
                    "forecast_run_id": self.run_id,
                    "spot_id": spot["id"],
                }
            publications.append(
                {
                    "spot": spot,
                    "weather_doc": {
                        "forecast_run_id": self.run_id,
                        "spot_id": spot["id"],
                        "location_name": spot["name"],
                        "latitude": spot["lat"],
                        "longitude": spot["lon"],
                    },
                    "conditions_summary": summary,
                }
            )

        write_count, commit_count = harvest_forecast._write_forecast_batches(
            database,
            publications,
            self.run_id,
            conditions_spot_ids=conditions_spot_ids,
        )

        self.assertEqual(251, write_count)
        self.assertEqual(7, commit_count)
        self.assertEqual(7, database.batch_count)
        self.assertTrue(all(batch.commit_count == 1 for batch in database.batches))
        self.assertTrue(
            all(len(batch.operations) <= 45 for batch in database.batches)
        )
        operations = [
            operation
            for batch in database.batches
            for operation in batch.operations
        ]
        self.assertEqual(251, len(operations))
        self.assertEqual(123, sum(op[0][0] == "spots_meteo" for op in operations))
        self.assertEqual(123, sum(op[0][0] == "spots_index" for op in operations))
        self.assertEqual(5, sum(op[0][0] == "conditions" for op in operations))

    def test_station_failure_before_publication_creates_no_batch_or_commit(self):
        database = _FakeDatabase()
        failed_result = {
            "spot": self.spot,
            "models": {"wind": None},
            "errors": {"wind": requests.ReadTimeout("timeout")},
        }

        with self.assertRaisesRegex(RuntimeError, "modèle wind indisponible"):
            harvest_forecast._prepare_and_publish_forecasts(
                database,
                [failed_result],
                self.run_id,
                expected_spot_count=1,
                conditions_spot_ids={},
            )

        self.assertEqual(0, database.batch_count)
        self.assertIsNone(database.last_batch)

    def test_commit_failure_stops_before_creating_later_batches(self):
        database = _FakeDatabase(fail_commit_number=2)
        publications = []
        for index in range(41):
            spot = {
                "id": f"spot_{index:03d}",
                "name": f"Spot {index:03d}",
                "lat": float(index) / 10,
                "lon": -float(index) / 10,
            }
            publications.append(
                {
                    "spot": spot,
                    "weather_doc": {
                        "forecast_run_id": self.run_id,
                        "spot_id": spot["id"],
                        "location_name": spot["name"],
                        "latitude": spot["lat"],
                        "longitude": spot["lon"],
                    },
                    "conditions_summary": None,
                }
            )

        with self.assertRaisesRegex(
            RuntimeError,
            "échec commit Firestore simulé",
        ):
            harvest_forecast._write_forecast_batches(
                database,
                publications,
                self.run_id,
                conditions_spot_ids={},
            )

        self.assertEqual(2, database.commit_attempt_count)
        self.assertEqual(2, database.batch_count)
        self.assertEqual([1, 1], [batch.commit_count for batch in database.batches])
        self.assertEqual(
            [40, 40],
            [len(batch.operations) for batch in database.batches],
        )

    def test_late_station_build_failure_still_creates_no_batch_or_commit(self):
        database = _FakeDatabase()
        first_spot = dict(self.spot)
        second_spot = {**self.spot, "id": "second_spot"}
        first_publication = {
            "spot": first_spot,
            "weather_doc": {"days": _valid_days()},
            "conditions_summary": None,
        }
        with mock.patch.object(
            harvest_forecast,
            "_build_station_publication",
            side_effect=[first_publication, RuntimeError("build invalide")],
        ):
            with self.assertRaisesRegex(RuntimeError, "build invalide"):
                harvest_forecast._prepare_and_publish_forecasts(
                    database,
                    [{"spot": first_spot}, {"spot": second_spot}],
                    self.run_id,
                    expected_spot_count=2,
                    conditions_spot_ids={},
                )

        self.assertEqual(0, database.batch_count)
        self.assertIsNone(database.last_batch)

    def test_post_write_verification_accepts_matching_fresh_documents(self):
        database = _FakeDatabase(self._documents())

        harvest_forecast.verify_production_state(
            database,
            [self.spot],
            self.run_id,
            self.started,
            conditions_spot_ids={self.spot["id"]: "test_condition"},
            now=self.updated + timedelta(minutes=1),
        )

    def test_post_write_verification_rejects_wrong_run_id(self):
        documents = self._documents()
        documents[("spots_index", self.spot["id"])]["forecast_run_id"] = "old-run"
        database = _FakeDatabase(documents)

        with self.assertRaisesRegex(RuntimeError, "run id incorrect"):
            harvest_forecast.verify_production_state(
                database,
                [self.spot],
                self.run_id,
                self.started,
                conditions_spot_ids={self.spot["id"]: "test_condition"},
                now=self.updated + timedelta(minutes=1),
            )

    def test_post_write_verification_rejects_stale_document(self):
        documents = self._documents()
        documents[("spots_meteo", self.spot["id"])]["last_update"] = (
            self.started - timedelta(hours=1)
        )
        database = _FakeDatabase(documents)

        with self.assertRaisesRegex(RuntimeError, "antérieur au run"):
            harvest_forecast.verify_production_state(
                database,
                [self.spot],
                self.run_id,
                self.started,
                conditions_spot_ids={self.spot["id"]: "test_condition"},
                now=self.updated + timedelta(minutes=1),
            )

    def test_missing_model_fails_fast(self):
        station_result = {
            "spot": self.spot,
            "models": {"wind": {}, "hires": None, "wave": {}},
            "errors": {"hires": requests.ReadTimeout("timeout")},
        }

        with self.assertRaisesRegex(RuntimeError, "modèle hires indisponible"):
            harvest_forecast._require_station_models(station_result)


class ConditionsGfsSummaryTests(unittest.TestCase):
    def test_summary_keeps_ten_days_and_all_tide_page_metrics(self):
        def slot(time, pressure):
            return {
                "hour": time,
                "wind_speed_kt": 12.5,
                "wind_dir_deg": 220.0,
                "wave_height_m": 1.4,
                "wave_period_s": 9.0,
                "wave_dir_deg": 315.0,
                "temp_c": 23,
                "weather_code": 2.0,
                "is_day": 0.0,
                "rating": 4,
                "models": {
                    "wind": {
                        "wind_speed_kt": 12.5,
                        "wind_gust_kt": 20.0,
                        "pressure_msl": pressure,
                        "precipitation_mm": 0.4,
                        "precip_prob_pct": 18.0,
                        "rel_humidity_pct": 72.0,
                        "cloud_total_pct": 42.0,
                        "visibility_m": 14000.0,
                    },
                    "wave": {
                        "swell_height_m": 1.2,
                        "swell_period_s": 11.0,
                        "swell_dir_deg": 315.0,
                        "swell2_height_m": 0.5,
                        "swell2_period_s": 7.0,
                        "swell2_dir_deg": 270.0,
                        "sst_c": 19.2,
                        "ocean_current_velocity_kmh": 0.8,
                        "ocean_current_direction_deg": 45.0,
                    },
                    "hires": {"pressure_msl": 999.0},
                },
            }

        days = [
            {
                "slots": [
                    slot(f"2026-08-{day:02d}T00:00", 1015.0 - day)
                ]
            }
            for day in range(1, 12)
        ]

        update_time = datetime(2026, 8, 14, tzinfo=timezone.utc)
        result = harvest_forecast.build_conditions_gfs_summary(
            days,
            forecast_run_id="run-1",
            spot_id="casablanca_maroc",
            last_update=update_time,
        )

        self.assertEqual("GFS ~13km", result["model"])
        self.assertEqual("run-1", result["forecast_run_id"])
        self.assertEqual("casablanca_maroc", result["spot_id"])
        self.assertEqual(update_time, result["last_update"])
        self.assertEqual(10, len(result["hourly"]))
        first = result["hourly"][0]
        self.assertEqual("2026-08-01T00:00", first["time"])
        self.assertEqual(23.2, first["windSpeedKmh"])
        self.assertEqual(220.0, first["windDirectionDeg"])
        self.assertEqual(2, first["weatherCode"])
        self.assertEqual(0, first["isDay"])
        self.assertEqual(23, first["temperatureC"])
        self.assertEqual(1.4, first["waveHeightM"])
        self.assertEqual(9.0, first["wavePeriodS"])
        self.assertEqual(315.0, first["waveDirectionDeg"])
        self.assertEqual(80, first["activityScore"])
        self.assertEqual(37.0, first["windGustKmh"])
        self.assertEqual(14.0, first["visibilityKm"])
        self.assertEqual(42.0, first["cloudCoverPct"])
        self.assertEqual(0.4, first["precipitationMm"])
        self.assertEqual(18.0, first["precipitationProbabilityPct"])
        self.assertEqual(1014.0, first["pressureHpa"])
        self.assertEqual(72.0, first["relativeHumidityPct"])
        self.assertEqual(1.2, first["swellHeightM"])
        self.assertEqual(11.0, first["swellPeriodS"])
        self.assertEqual(315.0, first["swellDirectionDeg"])
        self.assertEqual(0.5, first["secondarySwellHeightM"])
        self.assertEqual(7.0, first["secondarySwellPeriodS"])
        self.assertEqual(270.0, first["secondarySwellDirectionDeg"])
        self.assertEqual(19.2, first["seaSurfaceTemperatureC"])
        self.assertEqual(0.8, first["oceanCurrentSpeedKmh"])
        self.assertEqual(45.0, first["oceanCurrentDirectionDeg"])
        self.assertNotIn("wind_speed_kt", first)

    def test_summary_ignores_slots_without_any_requested_metric(self):
        result = harvest_forecast.build_conditions_gfs_summary([
            {
                "slots": [
                    {
                        "hour": "2026-08-01T00:00",
                        "models": {"wind": {"wind_speed_kt": 8.0}},
                    }
                ]
            }
        ])

        self.assertEqual([], result["hourly"])


if __name__ == "__main__":
    unittest.main()
