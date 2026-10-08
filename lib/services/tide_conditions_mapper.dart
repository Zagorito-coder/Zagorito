import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tide_data.dart';
import '../utils/station_time_zone.dart';
import 'astronomy_service.dart';

/// Convertit le document Firestore `conditions/{station}` en données marines.
///
/// Le champ de marée accepté est exclusivement `tide.hourly[].height`, produit
/// côté serveur depuis Open-Meteo `sea_level_height_msl`. Les hauteurs de
/// vagues ne sont jamais utilisées comme hauteur de marée.
class TideConditionsMapper {
  const TideConditionsMapper._();

  static const int _maximumDetailedForecastDays = 8;

  static TideData fromDocument(
    Map<String, dynamic> data, {
    required String fallbackLocation,
    DateTime? now,
  }) {
    final utcOffsetSeconds = _utcOffsetSeconds(data['utc_offset_seconds']);
    final timeZoneId = _timeZoneId(data['timezone']);
    final referenceInstant = (now ?? DateTime.now()).toUtc();
    final referenceTime = StationTimeZone.civilAt(
      referenceInstant,
      timeZoneId: timeZoneId,
      fallbackOffsetSeconds: utcOffsetSeconds,
    );
    final tide = _asMap(data['tide']);
    final weather = _asMap(data['weather']);
    final gfs = _asMap(data['gfs']);
    final tideSlots = tide?['hourly'];
    final weatherSlots = weather?['hourly'];
    final gfsSlots = gfs?['hourly'];

    if (tideSlots is! List<dynamic>) {
      throw const FormatException('Prévisions de marée absentes.');
    }

    final weatherByTime = <int, Map<String, dynamic>>{};
    if (weatherSlots is List<dynamic>) {
      for (final raw in weatherSlots) {
        final slot = _asMap(raw);
        final time = _parseStationForecastTime(
          slot?['time'],
          utcOffsetSeconds,
          timeZoneId: timeZoneId,
          legacyUnzonedIsUtc: true,
        );
        if (slot != null && time != null) {
          weatherByTime[time.instantUtc.millisecondsSinceEpoch] = slot;
        }
      }
    }

    final gfsByTime = <int, Map<String, dynamic>>{};
    if (gfsSlots is List<dynamic>) {
      for (final raw in gfsSlots) {
        final slot = _asMap(raw);
        final time = _parseStationForecastTime(
          slot?['time'],
          utcOffsetSeconds,
          timeZoneId: timeZoneId,
        );
        if (slot != null && time != null) {
          gfsByTime[time.instantUtc.millisecondsSinceEpoch] = slot;
        }
      }
    }

    final points = <TidePoint>[];
    for (final raw in tideSlots) {
      final slot = _asMap(raw);
      final time = _parseStationForecastTime(
        slot?['time'],
        utcOffsetSeconds,
        timeZoneId: timeZoneId,
        legacyUnzonedIsUtc: true,
      );
      final height = _number(slot, 'height');
      if (slot == null ||
          time == null ||
          height == null ||
          !height.isFinite ||
          height < -10 ||
          height > 10) {
        continue;
      }

      final weatherAtTime =
          weatherByTime[time.instantUtc.millisecondsSinceEpoch];
      final gfsAtTime = _nearestSlot(gfsByTime, time.instantUtc);
      final totalWaveHeight = _boundedNumber(
        slot,
        'waveHeightM',
        minimum: 0,
        maximum: 40,
      );
      final wavePeriod = _boundedNumber(
        slot,
        'wavePeriodS',
        minimum: 0,
        maximum: 60,
      );
      final windDirection = _boundedNumber(
            weatherAtTime,
            'windDirectionDeg',
            minimum: 0,
            maximum: 360,
          ) ??
          _boundedNumber(
            slot,
            'windWaveDirectionDeg',
            minimum: 0,
            maximum: 360,
          );
      final temperature = _boundedNumber(
        weatherAtTime,
        'temperatureC',
        minimum: -90,
        maximum: 60,
      );
      final windSpeed = _boundedNumber(
        weatherAtTime,
        'windSpeedKmh',
        minimum: 0,
        maximum: 400,
      );

      if (totalWaveHeight == null ||
          wavePeriod == null ||
          windDirection == null ||
          temperature == null ||
          windSpeed == null) {
        throw const FormatException(
          'Créneau marin incomplet : publication refusée.',
        );
      }

      points.add(
        TidePoint(
          time: time.civil,
          instantUtc: time.instantUtc,
          height: height,
          windDirectionDeg: windDirection,
          wavePeriod: wavePeriod,
          windWaveHeight: totalWaveHeight,
          temperatureC: temperature,
          windSpeedKmh: windSpeed,
          pressureHpa: _boundedNumber(
                weatherAtTime,
                'pressureHpa',
                minimum: 800,
                maximum: 1200,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'pressureHpa',
                minimum: 800,
                maximum: 1200,
              ),
          precipitationProbabilityPct: _boundedNumber(
                weatherAtTime,
                'precipitationProbabilityPct',
                minimum: 0,
                maximum: 100,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'precipitationProbabilityPct',
                minimum: 0,
                maximum: 100,
              ),
          relativeHumidityPct: _boundedNumber(
                weatherAtTime,
                'relativeHumidityPct',
                minimum: 0,
                maximum: 100,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'relativeHumidityPct',
                minimum: 0,
                maximum: 100,
              ),
          windGustKmh: _boundedNumber(
                weatherAtTime,
                'windGustKmh',
                minimum: 0,
                maximum: 500,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'windGustKmh',
                minimum: 0,
                maximum: 500,
              ),
          visibilityKm: _boundedNumber(
                weatherAtTime,
                'visibilityKm',
                minimum: 0,
                maximum: 100,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'visibilityKm',
                minimum: 0,
                maximum: 100,
              ),
          cloudCoverPct: _boundedNumber(
                weatherAtTime,
                'cloudCoverPct',
                minimum: 0,
                maximum: 100,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'cloudCoverPct',
                minimum: 0,
                maximum: 100,
              ),
          precipitationMm: _boundedNumber(
                weatherAtTime,
                'precipitationMm',
                minimum: 0,
                maximum: 500,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'precipitationMm',
                minimum: 0,
                maximum: 500,
              ),
          swellHeightM: _boundedNumber(
                slot,
                'swellHeightM',
                minimum: 0,
                maximum: 40,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'swellHeightM',
                minimum: 0,
                maximum: 40,
              ),
          swellPeriodS: _boundedNumber(
                slot,
                'swellPeriodS',
                minimum: 0,
                maximum: 60,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'swellPeriodS',
                minimum: 0,
                maximum: 60,
              ),
          swellDirectionDeg: _boundedNumber(
                slot,
                'swellDirectionDeg',
                minimum: 0,
                maximum: 360,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'swellDirectionDeg',
                minimum: 0,
                maximum: 360,
              ),
          secondarySwellHeightM: _boundedNumber(
                slot,
                'secondarySwellHeightM',
                minimum: 0,
                maximum: 40,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'secondarySwellHeightM',
                minimum: 0,
                maximum: 40,
              ),
          secondarySwellPeriodS: _boundedNumber(
                slot,
                'secondarySwellPeriodS',
                minimum: 0,
                maximum: 60,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'secondarySwellPeriodS',
                minimum: 0,
                maximum: 60,
              ),
          secondarySwellDirectionDeg: _boundedNumber(
                slot,
                'secondarySwellDirectionDeg',
                minimum: 0,
                maximum: 360,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'secondarySwellDirectionDeg',
                minimum: 0,
                maximum: 360,
              ),
          seaSurfaceTemperatureC: _boundedNumber(
                slot,
                'seaSurfaceTemperatureC',
                minimum: -5,
                maximum: 45,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'seaSurfaceTemperatureC',
                minimum: -5,
                maximum: 45,
              ),
          oceanCurrentSpeedKmh: _boundedNumber(
                slot,
                'oceanCurrentSpeedKmh',
                minimum: 0,
                maximum: 30,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'oceanCurrentSpeedKmh',
                minimum: 0,
                maximum: 30,
              ),
          oceanCurrentDirectionDeg: _boundedNumber(
                slot,
                'oceanCurrentDirectionDeg',
                minimum: 0,
                maximum: 360,
              ) ??
              _boundedNumber(
                gfsAtTime,
                'oceanCurrentDirectionDeg',
                minimum: 0,
                maximum: 360,
              ),
        ),
      );
    }

    if (points.length < 3) {
      throw const FormatException('Prévisions de marée insuffisantes.');
    }
    points.sort(
      (a, b) => a.instantUtc!.compareTo(b.instantUtc!),
    );

    const coverageTolerance = Duration(minutes: 90);
    if (referenceInstant.isBefore(
          points.first.instantUtc!.subtract(coverageTolerance),
        ) ||
        referenceInstant.isAfter(
          points.last.instantUtc!.add(coverageTolerance),
        )) {
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
      (a, b) => a.instantUtc!.difference(referenceInstant).abs() <=
              b.instantUtc!.difference(referenceInstant).abs()
          ? a
          : b,
    );
    final next = points
            .where((point) => point.instantUtc!.isAfter(referenceInstant))
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

    final sun = _sunTimesForDate(_asMap(data['sun']), referenceTime);
    final sunrise = sun?.sunrise ?? '--:--';
    final sunset = sun?.sunset ?? '--:--';
    final location = (data['name'] as String?)?.trim();
    return TideData(
      hourlyPoints: points,
      hourlyForecast: _parseHourlyForecast(
        gfsSlots,
        referenceTime,
        utcOffsetSeconds,
        timeZoneId,
      ),
      low: low,
      high: high,
      next: next.height,
      waveHeight: nearest.windWaveHeight!,
      location:
          location == null || location.isEmpty ? fallbackLocation : location,
      generatedAt: _parseTimestamp(data['timestamp']),
      utcOffsetSeconds: utcOffsetSeconds,
      timeZoneId: timeZoneId,
      tideHeightDatum: _tideHeightDatum(data['tide_datum']),
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
        sunRise: sunrise,
        sunSet: sunset,
        lunarTransit: computedAstro.lunarTransit,
        lunarUnder: computedAstro.lunarUnder,
      ),
    );
  }

  /// Les documents historiques proviennent du même champ Open-Meteo
  /// `sea_level_height_msl`, mais ont été publiés avant l'ajout explicite de
  /// `tide_datum`. Seule l'absence du champ bénéficie de cette compatibilité ;
  /// toute valeur présente mais inconnue reste volontairement non qualifiée.
  static TideHeightDatum _tideHeightDatum(dynamic value) {
    if (value == null) return TideHeightDatum.globalMeanSeaLevel;
    if (value is! String) return TideHeightDatum.unknown;

    return switch (value.trim()) {
      'global_mean_sea_level' => TideHeightDatum.globalMeanSeaLevel,
      'casablanca_bmi' => TideHeightDatum.casablancaBmi,
      'casablanca_presentation_model' =>
        TideHeightDatum.casablancaPresentationModel,
      'morocco_casablanca_model' => TideHeightDatum.moroccoCasablancaModel,
      _ => TideHeightDatum.unknown,
    };
  }

  /// Convertit un instant ISO explicite vers l'heure civile de la station.
  ///
  /// Les anciens résumés GFS ne possédaient pas de suffixe UTC : ils étaient
  /// déjà exprimés dans l'heure locale Open-Meteo et restent donc inchangés.
  /// Les nouveaux documents utilisent tous un ISO UTC explicite et le
  /// décalage publié avec la station.
  static _ParsedStationTime? _parseStationForecastTime(
    dynamic value,
    int? utcOffsetSeconds, {
    String? timeZoneId,
    bool legacyUnzonedIsUtc = false,
  }) {
    if (value is! String || value.trim().isEmpty) return null;
    final raw = value.trim();
    final hasOffset =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    final parsed =
        DateTime.tryParse(!hasOffset && legacyUnzonedIsUtc ? '${raw}Z' : raw);
    if (parsed == null) return null;

    final instantUtc = hasOffset || legacyUnzonedIsUtc
        ? parsed.toUtc()
        : StationTimeZone.instantAt(
            parsed,
            timeZoneId: timeZoneId,
            fallbackOffsetSeconds: utcOffsetSeconds,
          );
    return _ParsedStationTime(
      instantUtc: instantUtc,
      civil: StationTimeZone.civilAt(
        instantUtc,
        timeZoneId: timeZoneId,
        fallbackOffsetSeconds: utcOffsetSeconds,
      ),
    );
  }

  static int? _utcOffsetSeconds(dynamic value) {
    if (value is! num || !value.isFinite) return null;
    final rounded = value.round();
    if ((value.toDouble() - rounded).abs() > 0.001 ||
        rounded < -18 * 3600 ||
        rounded > 18 * 3600) {
      return null;
    }
    return rounded;
  }

  static String? _timeZoneId(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static Map<String, dynamic>? _nearestSlot(
    Map<int, Map<String, dynamic>> slots,
    DateTime target,
  ) {
    Map<String, dynamic>? nearest;
    var shortestDifference = const Duration(days: 365);
    for (final entry in slots.entries) {
      final difference = DateTime.fromMillisecondsSinceEpoch(
        entry.key,
        isUtc: true,
      ).difference(target).abs();
      if (difference < shortestDifference) {
        shortestDifference = difference;
        nearest = entry.value;
      }
    }
    // Les créneaux GFS sont espacés de trois heures. Une tolérance de
    // 90 minutes associe chaque heure au créneau le plus proche sans réutiliser
    // une prévision ancienne ou appartenant à un autre jour.
    return shortestDifference <= const Duration(minutes: 90) ? nearest : null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  static String? _timeOfDay(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  static ({String sunrise, String sunset})? _sunTimesForDate(
    Map<String, dynamic>? sun,
    DateTime stationTime,
  ) {
    if (sun == null) return null;
    final dateKey = '${stationTime.year.toString().padLeft(4, '0')}-'
        '${stationTime.month.toString().padLeft(2, '0')}-'
        '${stationTime.day.toString().padLeft(2, '0')}';

    final daily = sun['daily'];
    if (daily is List<dynamic>) {
      for (final raw in daily) {
        final entry = _asMap(raw);
        if (entry?['date'] != dateKey) continue;
        final sunrise = _timeOfDay(entry?['sunrise']);
        final sunset = _timeOfDay(entry?['sunset']);
        if (sunrise != null && sunset != null) {
          return (sunrise: sunrise, sunset: sunset);
        }
      }
    }

    // Compatibilité avec les documents antérieurs : les champs racine ne
    // sont utilisés que s'ils appartiennent réellement au jour affiché.
    final legacyDate = sun['date'];
    if (legacyDate != null && legacyDate != dateKey) return null;
    final sunrise = _timeOfDay(sun['sunrise']);
    final sunset = _timeOfDay(sun['sunset']);
    return sunrise == null || sunset == null
        ? null
        : (sunrise: sunrise, sunset: sunset);
  }

  static List<HourlyForecastPoint> _parseHourlyForecast(
    dynamic rawSlots,
    DateTime referenceTime,
    int? utcOffsetSeconds,
    String? timeZoneId,
  ) {
    if (rawSlots is! List<dynamic>) return const [];

    final firstDay = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
    );
    final parsed = <HourlyForecastPoint>[];
    for (final raw in rawSlots) {
      final slot = _asMap(raw);
      final time = _parseStationForecastTime(
        slot?['time'],
        utcOffsetSeconds,
        timeZoneId: timeZoneId,
      );
      if (slot == null || time == null) continue;
      final day = DateTime(time.civil.year, time.civil.month, time.civil.day);
      if (day.isBefore(firstDay)) continue;

      final weatherCode = _boundedNumber(
        slot,
        'weatherCode',
        minimum: 0,
        maximum: 99,
      );
      final activity = _boundedNumber(
        slot,
        'activityScore',
        minimum: 0,
        maximum: 100,
      );
      final isDayValue = _boundedNumber(
        slot,
        'isDay',
        minimum: 0,
        maximum: 1,
      );
      parsed.add(
        HourlyForecastPoint(
          time: time.civil,
          instantUtc: time.instantUtc,
          windSpeedKmh: _boundedNumber(
            slot,
            'windSpeedKmh',
            minimum: 0,
            maximum: 400,
          ),
          windGustKmh: _boundedNumber(
            slot,
            'windGustKmh',
            minimum: 0,
            maximum: 400,
          ),
          windDirectionDeg: _boundedNumber(
            slot,
            'windDirectionDeg',
            minimum: 0,
            maximum: 360,
          ),
          weatherCode: weatherCode?.round(),
          isDay: isDayValue == null ? null : isDayValue.round() == 1,
          temperatureC: _boundedNumber(
            slot,
            'temperatureC',
            minimum: -60,
            maximum: 60,
          ),
          pressureHpa: _boundedNumber(
            slot,
            'pressureHpa',
            minimum: 800,
            maximum: 1200,
          ),
          waveHeightM: _boundedNumber(
                slot,
                'waveHeightM',
                minimum: 0,
                maximum: 40,
              ) ??
              _boundedNumber(
                slot,
                'swellHeightM',
                minimum: 0,
                maximum: 40,
              ),
          wavePeriodS: _boundedNumber(
                slot,
                'wavePeriodS',
                minimum: 0,
                maximum: 60,
              ) ??
              _boundedNumber(
                slot,
                'swellPeriodS',
                minimum: 0,
                maximum: 60,
              ),
          waveDirectionDeg: _boundedNumber(
                slot,
                'waveDirectionDeg',
                minimum: 0,
                maximum: 360,
              ) ??
              _boundedNumber(
                slot,
                'swellDirectionDeg',
                minimum: 0,
                maximum: 360,
              ),
          precipitationProbabilityPct: _boundedNumber(
            slot,
            'precipitationProbabilityPct',
            minimum: 0,
            maximum: 100,
          ),
          cloudCoverPct: _boundedNumber(
            slot,
            'cloudCoverPct',
            minimum: 0,
            maximum: 100,
          ),
          activityScore: activity?.round(),
        ),
      );
    }

    parsed.sort(
      (a, b) => a.instantUtc!.compareTo(b.instantUtc!),
    );
    final acceptedDays = <String>{};
    final result = <HourlyForecastPoint>[];
    for (final point in parsed) {
      final key = '${point.time.year}-${point.time.month}-${point.time.day}';
      if (!acceptedDays.contains(key) &&
          acceptedDays.length >= _maximumDetailedForecastDays) {
        break;
      }
      acceptedDays.add(key);
      result.add(point);
    }
    return List.unmodifiable(result);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map<dynamic, dynamic>) return null;
    return Map<String, dynamic>.from(value);
  }

  static double? _number(Map<String, dynamic>? map, String key) {
    return (map?[key] as num?)?.toDouble();
  }

  static double? _boundedNumber(
    Map<String, dynamic>? map,
    String key, {
    required double minimum,
    required double maximum,
  }) {
    final value = _number(map, key);
    if (value == null ||
        !value.isFinite ||
        value < minimum ||
        value > maximum) {
      return null;
    }
    return value;
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

class _ParsedStationTime {
  final DateTime instantUtc;
  final DateTime civil;

  const _ParsedStationTime({
    required this.instantUtc,
    required this.civil,
  });
}
