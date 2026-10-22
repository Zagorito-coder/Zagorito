"""Contrats des horizons marins, sans API ni accès Firebase."""
import copy
import unittest
from datetime import date, datetime, timedelta, timezone
from unittest import mock
from zoneinfo import ZoneInfo

import harvest_forecast as harvest
from tests_python.test_harvest_forecast import _FakeDatabase
from tests_python.test_harvest_forecast import FakeResponse
from tests_python.test_open_meteo_epoch_dst import fixed_offset_response


def marine_fixture(zone="Africa/Casablanca", first_day=date(2026, 10, 22)):
    spot, wind, wave, _ = fixed_offset_response(zone, first_day, epochs=True)
    spot = {**spot, "id": "agadir_maroc", "name": "Agadir, Maroc"}
    if zone == "Africa/Casablanca":
        spot.update(lat=30.42, lon=-9.60)
    wave.update(latitude=spot["lat"], longitude=spot["lon"])
    # L'API Marine renvoie au plus192 heures, indépendamment d'une journée
    # civile supplémentaire lors du retour à l'heure d'hiver.
    wave["hourly"] = {key: values[:192] for key, values in wave["hourly"].items()}
    return spot, wind, wave


def build_fixture_publication(spot, wind, wave, *, run_id="coverage-test"):
    instant = datetime.fromtimestamp(wind["hourly"]["time"][12], timezone.utc)
    return harvest._build_station_publication(
        {"spot": spot, "models": {"wind": wind, "hires": wind, "wave": wave}},
        run_id,
        conditions_spot_ids={spot["id"]: spot["id"]},
        reference_time=instant,
    )


def committed_fixture(publication, when):
    """Matérialise le Timestamp serveur uniquement dans une fausse base."""
    def convert(value):
        if value is harvest.firestore.SERVER_TIMESTAMP:
            return when
        if isinstance(value, dict):
            return {key: convert(item) for key, item in value.items()}
        if isinstance(value, list):
            return [convert(item) for item in value]
        return value

    result = copy.deepcopy(publication)
    # deepcopy du sentinel n'est pas nécessaire : repartir des objets originaux.
    result["weather_doc"] = convert(publication["weather_doc"])
    result["conditions_doc"] = convert(publication["conditions_doc"])
    spot = result["spot"]
    return _FakeDatabase({
        ("spots_meteo", spot["id"]): result["weather_doc"],
        ("conditions", spot["id"]): result["conditions_doc"],
        ("spots_index", spot["id"]): {
            "forecast_run_id": result["weather_doc"]["forecast_run_id"],
            "spot_id": spot["id"], "name": spot["name"],
            "latitude": spot["lat"], "longitude": spot["lon"],
            "last_update": when,
        },
    })


class MarineCoverageResilienceTests(unittest.TestCase):
    def test_full_eight_day_response_keeps_eight_days(self):
        spot, wind, wave = marine_fixture()
        publication = build_fixture_publication(spot, wind, wave)
        self.assertEqual(8, publication["conditions_doc"]["coverage"]["marineDays"])
        self.assertEqual(192, len(publication["conditions_doc"]["tide"]["hourly"]))

    def test_null_at_production_slots_169_and_171_recovers_seven_complete_days(self):
        for index in (169, 171):
            with self.subTest(index=index):
                spot, wind, wave = marine_fixture()
                wave["hourly"]["sea_level_height_msl"][index] = None
                result = build_fixture_publication(spot, wind, wave)
                self.assertEqual(192, len(wave["hourly"]["time"]))
                self.assertEqual(7, result["weather_doc"]["coverage"]["marineDays"])
                self.assertEqual(168, len(result["conditions_doc"]["tide"]["hourly"]))
                self.assertEqual(56, len(result["conditions_doc"]["gfs"]["hourly"]))

    def test_every_required_marine_variable_controls_the_selected_horizon(self):
        for field, _, _, _ in harvest._MARINE_CONDITIONS_FIELDS:
            with self.subTest(field=field):
                spot, wind, wave = marine_fixture()
                wave["hourly"][field][169] = None
                result = build_fixture_publication(spot, wind, wave)
                self.assertEqual(7, result["conditions_doc"]["coverage"]["marineDays"])

    def test_bad_first_seven_days_are_rejected_not_filled(self):
        for invalid in (None, float("nan"), float("inf"), 50.0, True, "0.4"):
            with self.subTest(invalid=str(invalid)):
                spot, wind, wave = marine_fixture()
                wave["hourly"]["sea_level_height_msl"][167] = invalid
                with self.assertRaisesRegex(ValueError, "Moins de 7 jours marins complets"):
                    build_fixture_publication(spot, wind, wave)

    def test_missing_hour_in_first_seven_days_is_rejected(self):
        spot, wind, wave = marine_fixture()
        for values in wave["hourly"].values():
            values.pop(100)
        with self.assertRaisesRegex(ValueError, "Moins de 7 jours marins complets"):
            build_fixture_publication(spot, wind, wave)

    def test_missing_final_hour_recovers_without_claiming_partial_eighth_day(self):
        spot, wind, wave = marine_fixture()
        for values in wave["hourly"].values():
            values.pop()
        result = build_fixture_publication(spot, wind, wave)
        self.assertEqual(7, result["conditions_doc"]["coverage"]["marineDays"])

    def test_short_value_array_with_full_timestamp_array_still_recovers_seven_days(self):
        spot, wind, wave = marine_fixture()
        wave["hourly"]["wave_height"] = wave["hourly"]["wave_height"][:168]
        result = build_fixture_publication(spot, wind, wave)
        self.assertEqual(192, len(wave["hourly"]["time"]))
        self.assertEqual(7, result["conditions_doc"]["coverage"]["marineDays"])

    def test_cairo_fall_back_uses_169_real_hours_for_seven_civil_days(self):
        spot, wind, wave = marine_fixture("Africa/Cairo", date(2026, 10, 25))
        result = build_fixture_publication(spot, wind, wave)
        conditions = result["conditions_doc"]
        self.assertEqual(7, conditions["coverage"]["marineDays"])
        self.assertEqual(169, len(conditions["tide"]["hourly"]))
        actual = [slot["time"] for slot in conditions["tide"]["hourly"]]
        self.assertEqual(actual, [slot["time"] for slot in conditions["weather"]["hourly"]])
        parsed = [datetime.fromisoformat(value.replace("Z", "+00:00")) for value in actual]
        self.assertTrue(all(b-a == timedelta(hours=1) for a,b in zip(parsed, parsed[1:])))
        self.assertEqual(57, len(conditions["gfs"]["hourly"]))

    def test_shorter_horizon_strips_every_marine_value_and_rating_only_after_day_seven(self):
        spot, wind, wave = marine_fixture()
        original = copy.deepcopy(wave)
        wave["hourly"]["sea_level_height_msl"][169] = None
        result = build_fixture_publication(spot, wind, wave)
        weather = result["weather_doc"]
        self.assertEqual(10, len(weather["days"]))
        for index, day in enumerate(weather["days"]):
            for slot in day["slots"]:
                if index < 7:
                    self.assertIn("wave", slot["models"])
                    self.assertIn("rating", slot)
                else:
                    self.assertNotIn("wave", slot["models"])
                    self.assertNotIn("rating", slot)
                    self.assertTrue(all(key not in slot for key,_,_ in harvest._ROOT_MARINE_FIELDS))
                self.assertIsNotNone(slot["wind_speed_kt"])
        self.assertIs(result["weather_doc"]["last_update"], harvest.firestore.SERVER_TIMESTAMP)
        self.assertIs(result["conditions_doc"]["timestamp"], harvest.firestore.SERVER_TIMESTAMP)
        # La réponse API n'est jamais complétée ou modifiée par le constructeur.
        original["hourly"]["sea_level_height_msl"][169] = None
        self.assertEqual(original, wave)

    def test_production_reread_accepts_seven_and_eight_and_rejects_false_coverage(self):
        for marine_days in (7, 8):
            with self.subTest(marine_days=marine_days):
                spot, wind, wave = marine_fixture()
                if marine_days == 7:
                    wave["hourly"]["sea_level_height_msl"][169] = None
                result = build_fixture_publication(spot, wind, wave)
                when = datetime(2026, 10, 22, 12, tzinfo=timezone.utc)
                database = committed_fixture(result, when)
                harvest.verify_production_state(database, [spot], "coverage-test", when,
                    conditions_spot_ids={spot["id"]: spot["id"]}, now=when)
                database.documents[("conditions",spot["id"])]["coverage"]["marineDays"] = 8 if marine_days == 7 else 7
                with self.assertRaises(RuntimeError):
                    harvest.verify_production_state(database, [spot], "coverage-test", when,
                        conditions_spot_ids={spot["id"]: spot["id"]}, now=when)

    def test_invented_source_and_boolean_coverage_cannot_be_published(self):
        spot, wind, wave = marine_fixture()
        for mutation in ("source", "coverage"):
            result = build_fixture_publication(spot, wind, wave)
            if mutation == "source":
                result["weather_doc"]["source"]["seaLevelVariable"] = "wave_height"
            else:
                result["weather_doc"]["coverage"]["conditionsStepHours"] = True
            with self.assertRaises(ValueError):
                harvest._validate_publications_before_commit([result], "coverage-test", {spot["id"]: spot["id"]})


class RetryAfterTests(unittest.TestCase):
    def test_short_retry_after_is_respected_before_the_next_http_attempt(self):
        response = FakeResponse(status_code=429)
        response.headers = {"Retry-After": "15"}
        requester = mock.Mock(side_effect=[response, FakeResponse(payload={"ok": True})])
        sleeper = mock.Mock()
        self.assertEqual({"ok": True}, harvest._fetch_json("https://fixture", {},
            requester=requester, sleeper=sleeper, jitter=lambda: 0))
        sleeper.assert_called_once_with(15)

    def test_long_retry_after_is_exposed_without_a_premature_retry(self):
        response = FakeResponse(status_code=503)
        response.headers = {"Retry-After": "7200"}
        requester, sleeper = mock.Mock(return_value=response), mock.Mock()
        with self.assertRaises(harvest.OpenMeteoHttpError) as raised:
            harvest._fetch_json("https://fixture?apikey=not-a-real-secret", {},
                requester=requester, sleeper=sleeper)
        self.assertEqual(7200, raised.exception.retry_after_seconds)
        self.assertEqual(1, requester.call_count)
        sleeper.assert_not_called()
        self.assertNotIn("apikey", str(raised.exception))

    def test_http_date_and_invalid_header(self):
        now = datetime(2026, 10, 22, 12, tzinfo=timezone.utc)
        self.assertEqual(120, harvest._retry_after_seconds("Thu, 22 Oct 2026 12:02:00 GMT", now=now))
        self.assertIsNone(harvest._retry_after_seconds("malformed"))
        self.assertIsNone(harvest._retry_after_seconds("-1"))


if __name__ == "__main__":
    unittest.main()
