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
  };
}
