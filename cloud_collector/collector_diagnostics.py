"""Bounded diagnostics for collector errors, never provider messages or values.

Messages remain available to existing local callers, but reports must use
``diagnostic_fields``. Only fixed tokens and bounded integers cross that API.
"""

_CODES = frozenset({
    "unknown_validation", "array_missing", "array_short", "number_missing",
    "number_invalid", "number_nonfinite", "number_out_of_range",
    "number_not_integer", "number_unsupported", "model_missing",
    "timezone_invalid", "timezone_missing", "timezone_mismatch",
    "timestamp_missing", "timestamp_invalid", "local_time_unresolvable",
    "time_not_increasing", "grid_incomplete", "grid_count_mismatch",
    "grid_order_invalid", "grid_gap", "grid_alignment", "grid_local_utc_mismatch",
    "marine_horizon_invalid", "marine_horizon_incomplete", "forecast_horizon_short",
    "date_invalid", "day_slots_invalid",
})
_STAGES = frozenset({
    "fetch", "build", "validation", "publish", "verify", "timestamp",
    "marine_coverage", "forecast_payload", "conditions", "source_metadata",
    "health", "recovery_read", "recovery_write",
})
_MODELS = frozenset({"wind", "hires", "wave"})
_FIELDS = frozenset({
    "hourly", "time", "hour", "hour_utc", "timezone", "date", "days", "slots",
    "models", "marineDays", "weatherDays", "marineLatitude", "marineLongitude",
    "marineDistanceKm", "wind_speed_10m", "wind_gusts_10m", "wind_direction_10m",
    "temperature_2m", "weather_code", "is_day", "pressure_msl",
    "precipitation_probability", "precipitation", "relative_humidity_2m",
    "cloud_cover", "cloud_cover_low", "cloud_cover_mid", "cloud_cover_high",
    "visibility", "sea_level_height_msl", "wave_height", "wave_period",
    "wave_direction", "swell_wave_height", "swell_wave_period", "swell_wave_direction",
    "secondary_swell_wave_height", "secondary_swell_wave_period",
    "secondary_swell_wave_direction", "wind_wave_height", "wind_wave_period",
    "wind_wave_direction", "sea_surface_temperature", "ocean_current_velocity",
    "ocean_current_direction", "wind_speed_kt", "wind_gust_kt", "wind_dir_deg",
    "temp_c", "cloud_pct", "precip_pct", "cloud_low_pct", "cloud_mid_pct",
    "cloud_high_pct", "cloud_total_pct", "precipitation_mm", "precip_prob_pct",
    "rel_humidity_pct", "visibility_m", "wave_height_m", "wave_period_s",
    "wave_dir_deg", "swell_height_m", "swell_period_s", "swell_dir_deg",
    "swell2_height_m", "swell2_period_s", "swell2_dir_deg", "windwave_height_m",
    "windwave_period_s", "windwave_dir_deg", "sst_c", "ocean_current_velocity_kmh",
    "ocean_current_direction_deg", "rating",
})
_TOKENS = {
    "validation_code": _CODES, "stage": _STAGES, "model": _MODELS,
    "field": _FIELDS, "cause_code": _CODES, "primary_code": _CODES,
    "primary_field": _FIELDS,
}
_INTEGER_BOUNDS = {
    "index": (0, 10000), "primary_index": (0, 10000),
    "horizon_days": (0, 31), "fallback_from_days": (0, 31),
    "primary_horizon_days": (0, 31), "expected_count": (0, 10000),
    "actual_count": (0, 10000),
}


def _sanitize(fields):
    if type(fields) is not dict:
        return {}
    result = {}
    for key, allowed in _TOKENS.items():
        value = fields.get(key)
        # Reject str subclasses too: never invoke attacker-controlled methods.
        if type(value) is str and value in allowed:
            result[key] = value
    for key, (minimum, maximum) in _INTEGER_BOUNDS.items():
        value = fields.get(key)
        if type(value) is int and minimum <= value <= maximum:
            result[key] = value
    return result


def sanitize_diagnostic_fields(fields):
    """Sanitize a persisted/report mapping again at its trust boundary."""
    return _sanitize(fields)


class DiagnosticValueError(ValueError):
    """ValueError-compatible failure with a separately sanitized diagnostic."""

    def __init__(self, message, *, code, **fields):
        super().__init__(message)
        self.collector_diagnostic = _sanitize({**fields, "validation_code": code})


class DiagnosticRuntimeError(RuntimeError):
    """RuntimeError-compatible failure using the same bounded diagnostics."""

    def __init__(self, message, *, code, **fields):
        super().__init__(message)
        self.collector_diagnostic = _sanitize({**fields, "validation_code": code})


def diagnostic_fields(error, *, stage=None, model=None):
    """Return only fixed diagnostic tokens/integers, including wrapped causes.

    Never parse, stringify, encode or export an exception's message. Traversal
    is bounded and cycle-safe, including the runtime's ModelFetchError wrapper.
    """
    result = {}
    seen = set()
    queue = [error]
    saw_value_error = False
    for _ in range(16):
        if not queue:
            break
        current = queue.pop(0)
        if not isinstance(current, BaseException) or id(current) in seen:
            continue
        seen.add(id(current))
        saw_value_error = saw_value_error or isinstance(current, ValueError)
        # Access only exception instance storage, not arbitrary properties.
        stored = BaseException.__dict__["__dict__"].__get__(current)
        fields = _sanitize(stored.get("collector_diagnostic"))
        for key, value in fields.items():
            result.setdefault(key, value)
        nested = stored.get("original_error")
        if isinstance(nested, BaseException):
            queue.append(nested)
        cause = BaseException.__dict__["__cause__"].__get__(current)
        if isinstance(cause, BaseException):
            queue.append(cause)
    if "validation_code" not in result and saw_value_error:
        result["validation_code"] = "unknown_validation"
    context = _sanitize({"stage": stage, "model": model})
    for key, value in context.items():
        result.setdefault(key, value)
    return result
