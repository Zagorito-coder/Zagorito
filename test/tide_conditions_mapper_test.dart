import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/services/tide_conditions_mapper.dart';

void main() {
  test('sépare strictement niveau de marée, vagues et vent', () {
    final data = _conditionsDocument(
      tideHeights: const [-0.35, 0.42, 1.08],
      waveHeights: const [2.8, 2.9, 3.1],
    );

    final result = TideConditionsMapper.fromDocument(
      data,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1, 10).toLocal(),
    );

    expect(result.location, 'Casablanca');
    expect(
      result.hourlyPoints.map((point) => point.height),
      orderedEquals([-0.35, 0.42, 1.08]),
      reason: 'La hauteur de vague ne doit jamais devenir une marée.',
    );
    expect(result.hourlyPoints.first.windWaveHeight, 2.8);
    expect(result.hourlyPoints.first.windSpeedKmh, 18);
    expect(result.hourlyPoints.first.windDirectionDeg, 225);
    expect(result.hourlyPoints.first.pressureHpa, 1014);
    expect(result.hourlyPoints.first.precipitationProbabilityPct, 18);
    expect(result.hourlyPoints.first.relativeHumidityPct, 72);
    expect(result.hourlyPoints.first.windGustKmh, 32);
    expect(result.hourlyPoints.first.visibilityKm, 14);
    expect(result.hourlyPoints.first.cloudCoverPct, 42);
    expect(result.hourlyPoints.first.precipitationMm, 0.4);
    expect(result.hourlyPoints.first.swellHeightM, 1.2);
    expect(result.hourlyPoints.first.swellPeriodS, 11);
    expect(result.hourlyPoints.first.swellDirectionDeg, 315);
    expect(result.hourlyPoints.first.secondarySwellHeightM, 0.5);
    expect(result.hourlyPoints.first.secondarySwellPeriodS, 7);
    expect(result.hourlyPoints.first.secondarySwellDirectionDeg, 270);
    expect(result.hourlyPoints.first.seaSurfaceTemperatureC, 19.2);
    expect(result.hourlyPoints.first.oceanCurrentSpeedKmh, 0.8);
    expect(result.hourlyPoints.first.oceanCurrentDirectionDeg, 45);
    expect(result.hourlyForecast, hasLength(1));
    expect(result.hourlyForecast.first.windSpeedKmh, 18);
    expect(result.hourlyForecast.first.windDirectionDeg, 225);
    expect(result.hourlyForecast.first.weatherCode, 1);
    expect(result.hourlyForecast.first.isDay, isFalse);
    expect(result.hourlyForecast.first.temperatureC, 24);
    expect(result.hourlyForecast.first.waveHeightM, 1.1);
    expect(result.hourlyForecast.first.wavePeriodS, 9);
    expect(result.hourlyForecast.first.waveDirectionDeg, 310);
    expect(result.hourlyForecast.first.activityScore, 80);
    expect(result.low, -0.35);
    expect(result.high, 1.08);
    expect(result.astro.sunRise, '06:15');
    expect(result.astro.sunSet, '20:42');
    expect(
      result.tideHeightDatum,
      TideHeightDatum.globalMeanSeaLevel,
      reason: 'Un ancien document sans tide_datum reste identifié comme MSL.',
    );
  });

  test('propage le référentiel MSL explicitement publié', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )..['tide_datum'] = 'global_mean_sea_level';

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1),
    );

    expect(result.tideHeightDatum, TideHeightDatum.globalMeanSeaLevel);
  });

  test('reconnaît le repère mondial de présentation Casablanca', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )..['tide_datum'] = 'casablanca_presentation_model';

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1),
    );

    expect(
      result.tideHeightDatum,
      TideHeightDatum.casablancaPresentationModel,
    );
  });

  test('ne qualifie pas un référentiel publié inconnu', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )..['tide_datum'] = 'unsupported_local_datum';

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1),
    );

    expect(result.tideHeightDatum, TideHeightDatum.unknown);
  });

  test('interprète les heures Open-Meteo sans suffixe comme UTC', () {
    final result = TideConditionsMapper.fromDocument(
      _conditionsDocument(
        tideHeights: const [0.1, 0.2, 0.3],
        waveHeights: const [0.8, 0.9, 1],
      ),
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 0, 30).toLocal(),
    );

    expect(
      result.hourlyPoints.first.time.toUtc(),
      DateTime.utc(2026, 7, 26),
    );
    expect(result.generatedAt?.toUtc(), DateTime.utc(2026, 7, 26, 4));
  });

  test('refuse une série de marée insuffisante', () {
    final data = _conditionsDocument(
      tideHeights: const [0.5, 0.8],
      waveHeights: const [1.2, 1.3],
    );

    expect(
      () => TideConditionsMapper.fromDocument(
        data,
        fallbackLocation: 'Fallback',
      ),
      throwsFormatException,
    );
  });

  test('refuse une prévision qui ne couvre plus l’heure actuelle', () {
    final data = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    );

    expect(
      () => TideConditionsMapper.fromDocument(
        data,
        fallbackLocation: 'Fallback',
        now: DateTime.utc(2026, 7, 26, 8).toLocal(),
      ),
      throwsFormatException,
    );
  });

  test('la météo horaire reste complète sans résumé GFS', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )..remove('gfs');

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1).toLocal(),
    );

    expect(result.hourlyPoints.first.pressureHpa, 1014);
    expect(result.hourlyPoints.first.precipitationProbabilityPct, 18);
    expect(result.hourlyPoints.first.relativeHumidityPct, 72);
    expect(result.hourlyPoints.first.visibilityKm, 14);
  });

  test('ignore les valeurs GFS hors limites', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    );
    final gfs = document['gfs'] as Map<String, dynamic>;
    final slots = gfs['hourly'] as List<Map<String, dynamic>>;
    final weather = document['weather'] as Map<String, dynamic>;
    final weatherSlots = weather['hourly'] as List<Map<String, dynamic>>;
    weatherSlots.first
      ..remove('pressureHpa')
      ..remove('precipitationProbabilityPct')
      ..remove('relativeHumidityPct')
      ..remove('visibilityKm');
    slots.first
      ..['pressureHpa'] = 400
      ..['precipitationProbabilityPct'] = 150
      ..['relativeHumidityPct'] = -2
      ..['visibilityKm'] = 300
      ..['seaSurfaceTemperatureC'] = 80
      ..['oceanCurrentDirectionDeg'] = 800;

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1).toLocal(),
    );

    expect(result.hourlyPoints.first.pressureHpa, isNull);
    expect(result.hourlyPoints.first.precipitationProbabilityPct, isNull);
    expect(result.hourlyPoints.first.relativeHumidityPct, isNull);
    expect(result.hourlyPoints.first.visibilityKm, isNull);
    expect(result.hourlyPoints.first.seaSurfaceTemperatureC, isNull);
    expect(result.hourlyPoints.first.oceanCurrentDirectionDeg, isNull);
  });

  test('limite la prévision détaillée aux huit jours marins disponibles', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    );
    final gfs = document['gfs'] as Map<String, dynamic>;
    gfs['hourly'] = List.generate(11, (index) {
      final day = 26 + index;
      final time = DateTime(2026, 7, day);
      return {
        'time': time.toIso8601String(),
        'windSpeedKmh': 18,
        'waveHeightM': 1.1,
      };
    });

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime(2026, 7, 26, 1),
    );

    expect(result.hourlyForecast, hasLength(8));
    expect(result.hourlyForecast.first.time.day, 26);
    expect(result.hourlyForecast.last.time, DateTime(2026, 8, 2));
  });

  test('aligne toutes les séries sur le fuseau de la station distante', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )..['utc_offset_seconds'] = -5 * 3600;
    final tide = document['tide'] as Map<String, dynamic>;
    final weather = document['weather'] as Map<String, dynamic>;
    final tideSlots = tide['hourly'] as List<Map<String, dynamic>>;
    final weatherSlots = weather['hourly'] as List<Map<String, dynamic>>;
    for (var index = 0; index < tideSlots.length; index++) {
      final time =
          '2026-07-26T${(5 + index).toString().padLeft(2, '0')}:00:00Z';
      tideSlots[index]['time'] = time;
      weatherSlots[index]['time'] = time;
    }
    final gfs = document['gfs'] as Map<String, dynamic>;
    final gfsSlots = gfs['hourly'] as List<Map<String, dynamic>>;
    gfsSlots.first['time'] = '2026-07-26T05:00:00Z';
    document['sun'] = {
      'date': '2026-07-25',
      'sunrise': '2026-07-25T06:01',
      'sunset': '2026-07-25T20:01',
      'daily': [
        {
          'date': '2026-07-25',
          'sunrise': '2026-07-25T06:01',
          'sunset': '2026-07-25T20:01',
        },
        {
          'date': '2026-07-26',
          'sunrise': '2026-07-26T06:02',
          'sunset': '2026-07-26T20:02',
        },
      ],
    };

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 5, 15),
    );

    expect(result.utcOffsetSeconds, -5 * 3600);
    expect(result.hourlyPoints.first.time, DateTime(2026, 7, 26));
    expect(result.hourlyForecast.first.time, DateTime(2026, 7, 26));
    expect(result.hourlyPoints.first.pressureHpa, 1014);
    expect(result.stationTimeAt(DateTime.utc(2026, 7, 26, 5, 15)),
        DateTime(2026, 7, 26, 0, 15));
    expect(
      result.stationInstantAt(DateTime(2026, 7, 26, 0, 15)),
      DateTime.utc(2026, 7, 26, 5, 15),
    );
    expect(result.astro.sunRise, '06:02');
    expect(result.astro.sunSet, '20:02');
  });

  test('n’affiche pas les horaires solaires de la veille', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    );
    document['sun'] = {
      'date': '2026-07-25',
      'sunrise': '2026-07-25T06:15',
      'sunset': '2026-07-25T20:42',
    };

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime(2026, 7, 26, 1),
    );

    expect(result.astro.sunRise, '--:--');
    expect(result.astro.sunSet, '--:--');
  });

  test('utilise le fuseau IANA et les instants UTC après le retour à GMT', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )
      ..['timezone'] = 'Africa/Casablanca'
      // Simule un ancien champ de tête afin de vérifier que le fuseau daté
      // et les instants explicites ont bien priorité.
      ..['utc_offset_seconds'] = 3600;
    final tideSlots =
        (document['tide'] as Map<String, dynamic>)['hourly'] as List<dynamic>;
    final weatherSlots = (document['weather'] as Map<String, dynamic>)['hourly']
        as List<dynamic>;
    for (var index = 0; index < tideSlots.length; index++) {
      final hour = index.toString().padLeft(2, '0');
      final instant = '2026-10-05T$hour:00:00Z';
      (tideSlots[index] as Map<String, dynamic>)['time'] = instant;
      (weatherSlots[index] as Map<String, dynamic>)['time'] = instant;
    }
    final gfsSlots =
        (document['gfs'] as Map<String, dynamic>)['hourly'] as List<dynamic>;
    (gfsSlots.first as Map<String, dynamic>)['time'] = '2026-10-05T00:00:00Z';
    document['sun'] = {
      'date': '2026-10-05',
      'sunrise': '2026-10-05T06:25',
      'sunset': '2026-10-05T18:08',
    };

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 10, 5, 1, 10),
    );

    expect(result.timeZoneId, 'Africa/Casablanca');
    expect(result.hourlyPoints.first.time, DateTime(2026, 10, 5));
    expect(result.hourlyPoints.first.instantUtc, DateTime.utc(2026, 10, 5));
    expect(
      result.stationTimeAt(DateTime.utc(2026, 10, 5, 1, 10)),
      DateTime(2026, 10, 5, 1, 10),
    );
  });
}

Map<String, dynamic> _conditionsDocument({
  required List<double> tideHeights,
  required List<double> waveHeights,
}) {
  final tideSlots = <Map<String, dynamic>>[];
  final weatherSlots = <Map<String, dynamic>>[];
  for (var index = 0; index < tideHeights.length; index++) {
    final hour = index.toString().padLeft(2, '0');
    final time = '2026-07-26T$hour:00';
    tideSlots.add({
      'time': time,
      'height': tideHeights[index],
      'waveHeightM': waveHeights[index],
      'windWaveHeightM': 0.4,
      'windDirectionDeg': 210,
      'wavePeriodS': 8,
    });
    weatherSlots.add({
      'time': time,
      'temperatureC': 24,
      'windSpeedKmh': 18,
      'windDirectionDeg': 225,
      'windGustKmh': 32,
      'pressureHpa': 1014,
      'precipitationProbabilityPct': 18,
      'precipitationMm': 0.4,
      'relativeHumidityPct': 72,
      'cloudCoverPct': 42,
      'visibilityKm': 14,
    });
  }
  return {
    'name': 'Casablanca',
    'timestamp': '2026-07-26T04:00:00.000Z',
    'activityScore': 62,
    'moon': {
      'phaseName': 'Waxing Gibbous',
      'ageDays': 11.2,
    },
    'sun': {
      'date': '2026-07-26',
      'sunrise': '2026-07-26T06:15',
      'sunset': '2026-07-26T20:42',
    },
    'tide': {'hourly': tideSlots},
    'weather': {'hourly': weatherSlots},
    'gfs': {
      'model': 'GFS ~13km',
      'hourly': [
        {
          'time': '2026-07-26T00:00',
          'pressureHpa': 1014,
          'precipitationProbabilityPct': 18,
          'relativeHumidityPct': 72,
          'windGustKmh': 32,
          'windSpeedKmh': 18,
          'windDirectionDeg': 225,
          'weatherCode': 1,
          'isDay': 0,
          'temperatureC': 24,
          'waveHeightM': 1.1,
          'wavePeriodS': 9,
          'waveDirectionDeg': 310,
          'activityScore': 80,
          'visibilityKm': 14,
          'cloudCoverPct': 42,
          'precipitationMm': 0.4,
          'swellHeightM': 1.2,
          'swellPeriodS': 11,
          'swellDirectionDeg': 315,
          'secondarySwellHeightM': 0.5,
          'secondarySwellPeriodS': 7,
          'secondarySwellDirectionDeg': 270,
          'seaSurfaceTemperatureC': 19.2,
          'oceanCurrentSpeedKmh': 0.8,
          'oceanCurrentDirectionDeg': 45,
        },
      ],
    },
  };
}
