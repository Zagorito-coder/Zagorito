import '../models/tide_data.dart';
import 'astronomy_service.dart';

/// Convertit le document Firestore `conditions/{station}` en données marines.
///
/// Le champ de marée accepté est exclusivement `tide.hourly[].height`, produit
/// côté serveur depuis Open-Meteo `sea_level_height_msl`. Les hauteurs de
/// vagues ne sont jamais utilisées comme hauteur de marée.
class TideConditionsMapper {
  const TideConditionsMapper._();

  static TideData fromDocument(
    Map<String, dynamic> data, {
    required String fallbackLocation,
    DateTime? now,
  }) {
    final tide = _asMap(data['tide']);
    final weather = _asMap(data['weather']);
    final tideSlots = tide?['hourly'];
    final weatherSlots = weather?['hourly'];

    if (tideSlots is! List<dynamic>) {
      throw const FormatException('Prévisions de marée absentes.');
    }

    final weatherByTime = <int, Map<String, dynamic>>{};
    if (weatherSlots is List<dynamic>) {
      for (final raw in weatherSlots) {
        final slot = _asMap(raw);
        final time = _parseForecastTime(slot?['time']);
        if (slot != null && time != null) {
          weatherByTime[time.millisecondsSinceEpoch] = slot;
        }
      }
    }

    final points = <TidePoint>[];
    for (final raw in tideSlots) {
      final slot = _asMap(raw);
      final time = _parseForecastTime(slot?['time']);
      final height = _number(slot, 'height');
      if (slot == null ||
          time == null ||
          height == null ||
          !height.isFinite ||
          height < -10 ||
          height > 10) {
        continue;
      }

      final weatherAtTime = weatherByTime[time.millisecondsSinceEpoch];
      final totalWaveHeight = _number(slot, 'waveHeightM');
      final windWaveHeight = _number(slot, 'windWaveHeightM');
      final wavePeriod = _number(slot, 'wavePeriodS');

      points.add(
        TidePoint(
          time: time,
          height: height,
          windDirectionDeg: _number(weatherAtTime, 'windDirectionDeg') ??
              _number(slot, 'windDirectionDeg') ??
              0,
          wavePeriod:
              wavePeriod != null && wavePeriod.isFinite && wavePeriod >= 0
                  ? wavePeriod
                  : 0,
          windWaveHeight: totalWaveHeight ?? windWaveHeight ?? 0,
          temperatureC: _number(weatherAtTime, 'temperatureC'),
          windSpeedKmh: _number(weatherAtTime, 'windSpeedKmh'),
        ),
      );
    }

    if (points.length < 3) {
      throw const FormatException('Prévisions de marée insuffisantes.');
    }
    points.sort((a, b) => a.time.compareTo(b.time));

    final referenceTime = now ?? DateTime.now();
    const coverageTolerance = Duration(minutes: 90);
    if (referenceTime.isBefore(points.first.time.subtract(coverageTolerance)) ||
        referenceTime.isAfter(points.last.time.add(coverageTolerance))) {
      throw const FormatException(
        'La série de marée ne couvre pas l’heure actuelle.',
      );
    }

    var low = double.infinity;
    var high = -double.infinity;
    for (final point in points) {
      if (point.height < low) low = point.height;
      if (point.height > high) high = point.height;
    }

    final nearest = points.reduce(
      (a, b) => a.time.difference(referenceTime).abs() <=
              b.time.difference(referenceTime).abs()
          ? a
          : b,
    );
    final next = points
            .where((point) => point.time.isAfter(referenceTime))
            .firstOrNull ??
        points.last;

    final computedAstro = AstronomyService.calculate(
      referenceTime,
      low,
      high,
    );
    final moon = _asMap(data['moon']);
    final serverScore = (data['activityScore'] as num?)?.toDouble();
    final safeScore = serverScore?.isFinite == true
        ? serverScore!.clamp(0, 100) / 100
        : computedAstro.fishActivity;
    final phaseName = (moon?['phaseName'] as String?)?.trim();
    final ageDays = _number(moon, 'ageDays');
    final phase = ageDays == null
        ? computedAstro.moonPhase
        : (ageDays / 29.5305882).clamp(0.0, 1.0);

    final location = (data['name'] as String?)?.trim();
    return TideData(
      hourlyPoints: points,
      low: low,
      high: high,
      next: next.height,
      waveHeight: nearest.windWaveHeight,
      location:
          location == null || location.isEmpty ? fallbackLocation : location,
      generatedAt: _parseTimestamp(data['timestamp']),
      astro: AstroData(
        moonPhase: phase,
        moonPhaseName: phaseName == null || phaseName.isEmpty
            ? computedAstro.moonPhaseName
            : _translateMoonPhase(phaseName),
        coefficient: computedAstro.coefficient,
        fishActivity: safeScore,
        activityLabel: _activityLabel(safeScore),
        moonRise: computedAstro.moonRise,
        moonSet: computedAstro.moonSet,
        sunRise: computedAstro.sunRise,
        sunSet: computedAstro.sunSet,
        lunarTransit: computedAstro.lunarTransit,
        lunarUnder: computedAstro.lunarUnder,
      ),
    );
  }

  static DateTime? _parseForecastTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final raw = value.trim();
    final hasOffset =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    final parsed = DateTime.tryParse(hasOffset ? raw : '${raw}Z');
    return parsed?.toLocal();
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map<dynamic, dynamic>) return null;
    return Map<String, dynamic>.from(value);
  }

  static double? _number(Map<String, dynamic>? map, String key) {
    return (map?[key] as num?)?.toDouble();
  }

  static String _activityLabel(double score) {
    if (score >= 0.75) return 'Excellente';
    if (score >= 0.55) return 'Bonne';
    if (score >= 0.35) return 'Moyenne';
    return 'Faible';
  }

  static String _translateMoonPhase(String value) {
    return switch (value) {
      'New Moon' => 'Nouvelle Lune',
      'Waxing Crescent' => 'Croissante',
      'First Quarter' => 'Premier Quartier',
      'Waxing Gibbous' => 'Gibbeuse Croissante',
      'Full Moon' => 'Pleine Lune',
      'Waning Gibbous' => 'Gibbeuse Décroissante',
      'Last Quarter' => 'Dernier Quartier',
      'Waning Crescent' => 'Décroissante',
      _ => value,
    };
  }
}
