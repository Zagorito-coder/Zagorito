import 'package:flutter_test/flutter_test.dart';
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
    expect(result.low, -0.35);
    expect(result.high, 1.08);
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

  test('la météo GFS absente reste rétrocompatible', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    )..remove('gfs');

    final result = TideConditionsMapper.fromDocument(
      document,
      fallbackLocation: 'Fallback',
      now: DateTime.utc(2026, 7, 26, 1).toLocal(),
    );

    expect(result.hourlyPoints.first.pressureHpa, isNull);
    expect(result.hourlyPoints.first.precipitationProbabilityPct, isNull);
    expect(result.hourlyPoints.first.relativeHumidityPct, isNull);
  });

  test('ignore les valeurs GFS hors limites', () {
    final document = _conditionsDocument(
      tideHeights: const [0.1, 0.4, 0.2],
      waveHeights: const [1.1, 1.2, 1.3],
    );
    final gfs = document['gfs'] as Map<String, dynamic>;
    final slots = gfs['hourly'] as List<Map<String, dynamic>>;
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
