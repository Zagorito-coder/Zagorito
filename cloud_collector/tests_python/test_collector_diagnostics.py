"""Precise bounded diagnostics, using fixtures only; never API/Firebase calls."""
import copy
import json
import unittest
from datetime import date
from unittest import mock

import harvest_forecast as harvest
from collector_diagnostics import (
    DiagnosticValueError,
    diagnostic_fields,
    sanitize_diagnostic_fields,
)
from collector_runtime import ModelFetchError
from tests_python.test_marine_coverage_resilience import marine_fixture


class SafeDiagnosticTests(unittest.TestCase):
    def test_unknown_messages_are_never_stringified_or_decoded(self):
        class SecretError(ValueError):
            def __str__(self):
                raise AssertionError("must not stringify error")

        for message in (
            "https://provider.test?apikey=secret-key&token=private",
            "apikey%3Dsecret-key", "apikey&#61;secret-key", "secret-key\nFORGED",
        ):
            result = diagnostic_fields(SecretError(message))
            self.assertEqual({"validation_code": "unknown_validation"}, result)
            self.assertNotIn("secret", json.dumps(result))

    def test_constructor_and_report_boundary_allow_only_fixed_tokens(self):
        error = DiagnosticValueError(
            "https://provider.test?apikey=secret", code="number_missing",
            stage="marine_coverage", model="wave", field="sea_level_height_msl", index=167,
            url="secret", value="secret", payload={"apikey": "secret"},
        )
        expected = {
            "validation_code": "number_missing", "stage": "marine_coverage",
            "model": "wave", "field": "sea_level_height_msl", "index": 167,
        }
        self.assertEqual(expected, diagnostic_fields(error))
        self.assertEqual(expected, sanitize_diagnostic_fields({**expected, "message": "secret"}))

    def test_malicious_tokens_and_unbounded_numbers_are_discarded(self):
        for malicious in ("wave\nsecret", "wave%0Asecret", "wave&#10;secret", "Wave", "https://secret"):
            result = sanitize_diagnostic_fields({
                "validation_code": malicious, "model": malicious, "stage": malicious,
                "field": malicious, "primary_code": malicious,
                "index": True, "primary_index": -1, "expected_count": 10**50,
                "actual_count": float("inf"), "horizon_days": 32,
                "fallback_from_days": "8", "primary_horizon_days": None,
            })
            self.assertEqual({}, result)

    def test_string_and_dictionary_subclasses_cannot_execute_during_sanitizing(self):
        class MaliciousString(str):
            def __hash__(self):
                raise AssertionError("must not hash a subclass")
        class MaliciousMapping(dict):
            def get(self, *_):
                raise AssertionError("must not read a subclass")
        self.assertEqual({}, sanitize_diagnostic_fields(MaliciousMapping()))
        self.assertEqual({}, sanitize_diagnostic_fields({"model": MaliciousString("wave")}))

    def test_nested_model_fetch_and_explicit_cause_keep_the_precise_failure(self):
        leaf = DiagnosticValueError("original secret", code="array_short",
            stage="marine_coverage", model="wave", field="wave_height", index=167,
            expected_count=168, actual_count=160)
        middle = ValueError("secret middle")
        middle.__cause__ = leaf
        outer = ModelFetchError(middle)
        result = diagnostic_fields(outer, stage="fetch", model="hires")
        self.assertEqual("array_short", result["validation_code"])
        self.assertEqual("wave", result["model"])
        self.assertEqual("marine_coverage", result["stage"])
        self.assertEqual(167, result["index"])
        self.assertNotIn("secret", json.dumps(result))

    def test_context_is_whitelisted_and_does_not_override_precise_fields(self):
        leaf = DiagnosticValueError("private", code="grid_incomplete", model="wave")
        self.assertEqual({"validation_code": "grid_incomplete", "model": "wave", "stage": "build"},
            diagnostic_fields(leaf, stage="build", model="wind"))
        self.assertEqual({}, diagnostic_fields(RuntimeError("private"), stage="secret", model="secret"))

    def test_cycles_and_deep_wrappers_are_bounded(self):
        first, second = ValueError("private"), RuntimeError("private")
        first.__cause__, second.__cause__ = second, first
        self.assertEqual({"validation_code": "unknown_validation"}, diagnostic_fields(second))
        value = DiagnosticValueError("private", code="number_invalid")
        for _ in range(50):
            value = ModelFetchError(value)
        self.assertEqual({}, diagnostic_fields(value))

    def test_exception_properties_are_never_evaluated(self):
        class HostileError(ValueError):
            @property
            def __dict__(self):
                raise AssertionError("private property")
            @property
            def __cause__(self):
                raise AssertionError("private property")
        self.assertEqual({"validation_code": "unknown_validation"}, diagnostic_fields(HostileError()))

    def test_storage_mapping_mutation_is_sanitized_again(self):
        error = DiagnosticValueError("private", code="number_missing", field="wave_height")
        error.collector_diagnostic.update(index=10**50, field="apikey=secret", unexpected="secret")
        self.assertEqual({"validation_code": "number_missing"}, diagnostic_fields(error))


class ValidationAnnotationTests(unittest.TestCase):
    def test_required_model_absence_keeps_runtime_semantics_and_identifies_model(self):
        for model_name in ("wind", "hires", "wave"):
            with self.subTest(model=model_name):
                spot, wind, wave = marine_fixture()
                models = {"wind": wind, "hires": copy.deepcopy(wind), "wave": wave}
                models.pop(model_name)
                with self.assertRaises(RuntimeError) as raised:
                    harvest._require_station_models({"spot": spot, "models": models})
                self.assertNotIsInstance(raised.exception, ValueError)
                self.assertEqual(
                    f"Récolte interrompue pour {spot['id']} : modèle {model_name} indisponible (réponse absente).",
                    str(raised.exception))
                self.assertEqual({"validation_code": "model_missing", "stage": "build",
                    "model": model_name, "field": "models"}, diagnostic_fields(raised.exception))

    def test_required_hourly_or_time_absence_keeps_runtime_semantics(self):
        for model_name in ("wind", "hires", "wave"):
            for replacement, field in (
                ({}, "hourly"), ({"hourly": []}, "hourly"),
                ({"hourly": {}}, "time"), ({"hourly": {"time": []}}, "time"),
                ({"hourly": {"time": "https://provider.test?apikey=secret"}}, "time"),
            ):
                with self.subTest(model=model_name, field=field, replacement=replacement):
                    spot, wind, wave = marine_fixture()
                    models = {"wind": wind, "hires": copy.deepcopy(wind), "wave": wave}
                    models[model_name] = replacement
                    with self.assertRaises(RuntimeError) as raised:
                        harvest._require_station_models({"spot": spot, "models": models})
                    self.assertNotIsInstance(raised.exception, ValueError)
                    self.assertEqual(
                        f"Récolte interrompue pour {spot['id']} : modèle {model_name} sans série horaire.",
                        str(raised.exception))
                    self.assertEqual({"validation_code": "array_missing", "stage": "build",
                        "model": model_name, "field": field}, diagnostic_fields(raised.exception))

    def test_missing_station_timezone_has_safe_wind_context(self):
        for missing in (None, "", "   "):
            with self.subTest(missing=missing):
                spot, wind, wave = marine_fixture()
                wind["timezone"] = missing
                with mock.patch.object(harvest, "_daily_sun_from_open_meteo", return_value={}):
                    with mock.patch.object(harvest, "build_days_payload", return_value=([], None)):
                        with self.assertRaises(ValueError) as raised:
                            harvest._build_station_publication(
                                {"spot": spot, "models": {"wind": wind, "hires": wind, "wave": wave}}, "test")
                self.assertEqual(f"Récolte interrompue pour {spot['id']} : fuseau IANA absent.",
                    str(raised.exception))
                self.assertEqual({"validation_code": "timezone_missing", "stage": "build",
                    "model": "wind", "field": "timezone"}, diagnostic_fields(raised.exception))

    def test_mismatched_station_timezone_identifies_model_without_remote_value(self):
        for model_name in ("hires", "wave"):
            for mismatch in (None, "", "Africa/Cairo", "https://provider.test?apikey=secret"):
                with self.subTest(model=model_name, mismatch=mismatch):
                    spot, wind, wave = marine_fixture()
                    models = {"wind": wind, "hires": copy.deepcopy(wind), "wave": wave}
                    models[model_name]["timezone"] = mismatch
                    with mock.patch.object(harvest, "_daily_sun_from_open_meteo", return_value={}):
                        with mock.patch.object(harvest, "build_days_payload", return_value=([], None)):
                            with self.assertRaises(ValueError) as raised:
                                harvest._build_station_publication({"spot": spot, "models": models}, "test")
                    self.assertEqual(
                        f"Récolte interrompue pour {spot['id']} : fuseau IANA incohérent pour {model_name}.",
                        str(raised.exception))
                    self.assertEqual({"validation_code": "timezone_mismatch", "stage": "build",
                        "model": model_name, "field": "timezone"}, diagnostic_fields(raised.exception))

    def _number_error(self, values, index=0):
        with self.assertRaises(ValueError) as raised:
            harvest._validated_number(values, "sea_level_height_msl", index, -10, 10, "Couverture marine")
        self.assertEqual(f"Couverture marine : sea_level_height_msl absent ou hors limites au créneau {index}.",
            str(raised.exception))
        return diagnostic_fields(raised.exception)

    def test_missing_short_and_invalid_source_numbers_are_distinguished(self):
        for payload, code in (
            ({}, "array_missing"), ({"sea_level_height_msl": []}, "array_short"),
            ({"sea_level_height_msl": [None]}, "number_missing"),
            ({"sea_level_height_msl": [True]}, "number_invalid"),
            ({"sea_level_height_msl": ["0.4"]}, "number_invalid"),
            ({"sea_level_height_msl": [float("nan")]}, "number_nonfinite"),
            ({"sea_level_height_msl": [float("inf")]}, "number_nonfinite"),
            ({"sea_level_height_msl": [11]}, "number_out_of_range"),
        ):
            with self.subTest(code=code):
                fields = self._number_error(payload)
                self.assertEqual(code, fields["validation_code"])
                self.assertEqual("sea_level_height_msl", fields["field"])
                self.assertEqual("wave", fields["model"])
                self.assertEqual(0, fields["index"])

    def test_payload_field_and_model_are_reported_without_the_label(self):
        with self.assertRaises(ValueError) as raised:
            harvest._validated_payload_number({"temp_c": "secret"}, "temp_c", -90, 60,
                "https://provider.test?apikey=private.models.hires")
        self.assertEqual({"validation_code": "number_invalid", "stage": "forecast_payload",
            "model": "hires", "field": "temp_c"}, diagnostic_fields(raised.exception))

    def test_rejected_marine_horizon_preserves_first_and_final_attempt(self):
        _, wind, wave = marine_fixture()
        days = harvest.build_days_payload(wind, wind, wave, harvest._daily_sun_from_open_meteo(wind))[0][:10]
        first = DiagnosticValueError("private first", code="array_short",
            stage="marine_coverage", model="wave", field="wave_height", index=169)
        final = DiagnosticValueError("private final", code="number_missing",
            stage="marine_coverage", model="wave", field="sea_level_height_msl", index=100)
        with mock.patch.object(harvest, "_validated_number", side_effect=[first, final]):
            with self.assertRaisesRegex(ValueError, "Moins de 7 jours marins complets") as raised:
                harvest._complete_marine_day_count(wave, days)
        fields = diagnostic_fields(raised.exception)
        self.assertEqual("marine_horizon_incomplete", fields["validation_code"])
        self.assertEqual("array_short", fields["primary_code"])
        self.assertEqual("wave_height", fields["primary_field"])
        self.assertEqual(169, fields["primary_index"])
        self.assertEqual(8, fields["primary_horizon_days"])
        self.assertEqual("number_missing", fields["cause_code"])
        self.assertEqual("sea_level_height_msl", fields["field"])
        self.assertEqual(100, fields["index"])
        self.assertEqual(7, fields["horizon_days"])
        self.assertEqual(8, fields["fallback_from_days"])
        self.assertIs(final, raised.exception.__cause__)
        self.assertNotIn("private", json.dumps(fields))

    def test_successful_seven_day_fallback_remains_unchanged(self):
        _, wind, wave = marine_fixture()
        days = harvest.build_days_payload(wind, wind, wave, harvest._daily_sun_from_open_meteo(wind))[0][:10]
        original = copy.deepcopy(wave)
        wave["hourly"]["sea_level_height_msl"][169] = None
        self.assertEqual(7, harvest._complete_marine_day_count(wave, days))
        original["hourly"]["sea_level_height_msl"][169] = None
        self.assertEqual(original, wave)

    def test_missing_marine_hour_includes_grid_size_and_index(self):
        _, wind, wave = marine_fixture()
        days = harvest.build_days_payload(wind, wind, wave, harvest._daily_sun_from_open_meteo(wind))[0][:10]
        for values in wave["hourly"].values():
            values.pop(100)
        with self.assertRaises(ValueError) as raised:
            harvest._complete_marine_day_count(wave, days)
        fields = diagnostic_fields(raised.exception)
        self.assertEqual("grid_incomplete", fields["cause_code"])
        self.assertEqual("time", fields["field"])
        self.assertEqual(100, fields["index"])
        self.assertEqual(168, fields["expected_count"])
        self.assertEqual(191, fields["actual_count"])

    def test_dst_grid_rejection_reports_expected_native_count(self):
        from tests_python.test_open_meteo_epoch_dst import publication
        result, _ = publication("Africa/Cairo", date(2026, 10, 21), epochs=True)
        days = result["weather_doc"]["days"]
        next(day for day in days if day["date"] == "2026-10-29")["slots"].pop()
        with self.assertRaisesRegex(ValueError, "9 créneaux GFS natifs") as raised:
            harvest.validate_payload(days, 10800, timezone_name="Africa/Cairo")
        fields = diagnostic_fields(raised.exception)
        self.assertEqual("day_slots_invalid", fields["validation_code"])
        self.assertEqual(9, fields["expected_count"])
        self.assertEqual(8, fields["actual_count"])
        self.assertEqual(8, fields["index"])

    def test_timestamp_rejection_does_not_leak_provider_value(self):
        secret = "https://provider.test?apikey=secret"
        with self.assertRaises(ValueError) as raised:
            harvest._utc_datetimes_from_open_meteo([secret], 0, "Africa/Casablanca")
        self.assertIn(secret, str(raised.exception))  # Preserve legacy exception text.
        fields = diagnostic_fields(raised.exception)
        self.assertEqual("timestamp_invalid", fields["validation_code"])
        self.assertEqual(0, fields["index"])
        self.assertNotIn("secret", json.dumps(fields))


if __name__ == "__main__":
    unittest.main()
