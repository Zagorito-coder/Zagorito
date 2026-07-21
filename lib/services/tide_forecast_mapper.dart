import '../models/tide_data.dart';
import 'astronomy_service.dart';

/// Convertit le format Firestore produit par `harvest_forecast.py` vers le
/// modele historique consomme par les ecrans de marees.
class TideForecastMapper {
  const TideForecastMapper._();

  static TideData fromDocument(
    Map<String, dynamic> data, {
    required String fallbackLocation,
    DateTime? now,
  }) {
    final points = <TidePoint>[];
    final days = data['days'];
    if (days is List<dynamic>) {
      for (final rawDay in days) {
        final day = _asMap(rawDay);
        final slots = day?['slots'];
        if (slots is! List<dynamic>) continue;
        for (final rawSlot in slots) {
          final slot = _asMap(rawSlot);
          if (slot == null) continue;
          final time = DateTime.tryParse(slot['hour'] as String? ?? '');
          final models = _asMap(slot['models']);
          final waveModel = _asMap(models?['wave']);
          final windModel = _asMap(models?['hires']) ?? _asMap(models?['wind']);
          final height = _number(slot, 'wave_height_m') ??
              _number(waveModel, 'wave_height_m');
          if (time == null || height == null || !height.isFinite || height < 0) {
            continue;
          }

          final windSpeedKnots = _number(slot, 'wind_speed_kt') ??
              _number(windModel, 'wind_speed_kt');
          points.add(TidePoint(
            time: time,
            height: height,
            windDirectionDeg: _number(waveModel, 'windwave_dir_deg') ??
                _number(slot, 'wave_dir_deg') ??
                0,
            wavePeriod: _number(waveModel, 'windwave_period_s') ??
                _number(slot, 'wave_period_s') ??
                7,
            windWaveHeight: _number(waveModel, 'windwave_height_m') ?? height,
            temperatureC: _number(windModel, 'temp_c') ??
                _number(slot, 'temp_c'),
            windSpeedKmh:
                windSpeedKnots == null ? null : windSpeedKnots * 1.852,
          ));
        }
      }
    }

    if (points.isEmpty) {
      throw const FormatException('Aucune condition marine exploitable.');
    }
    points.sort((a, b) => a.time.compareTo(b.time));

    // L'ancien endpoint demandait `forecast_days=1`. On conserve exactement
    // ce contrat en ne transmettant au modele que le premier jour disponible.
    final firstDate = points.first.time;
    final firstDayPoints = points.where((point) {
      return point.time.year == firstDate.year &&
          point.time.month == firstDate.month &&
          point.time.day == firstDate.day;
    }).toList(growable: false);

    var low = double.infinity;
    var high = -double.infinity;
    for (final point in firstDayPoints) {
      if (point.height < low) low = point.height;
      if (point.height > high) high = point.height;
    }

    final referenceTime = now ?? DateTime.now();
    final next = firstDayPoints
        .where((point) => point.time.isAfter(referenceTime))
        .map((point) => point.height)
        .firstOrNull;
    final resolvedNext = next ?? firstDayPoints.last.height;
    final resolvedLocation = (data['location_name'] as String?)?.trim();

    return TideData(
      hourlyPoints: firstDayPoints,
      low: low,
      high: high,
      next: resolvedNext,
      waveHeight: (high - low) / 2,
      location: resolvedLocation == null || resolvedLocation.isEmpty
          ? fallbackLocation
          : resolvedLocation,
      astro: AstronomyService.calculate(referenceTime, low, high),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map<dynamic, dynamic>) return null;
    return Map<String, dynamic>.from(value);
  }

  static double? _number(Map<String, dynamic>? map, String key) {
    return (map?[key] as num?)?.toDouble();
  }
}
