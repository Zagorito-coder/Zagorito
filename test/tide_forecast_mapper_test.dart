import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/tide_forecast_mapper.dart';

void main() {
  test('convertit un jour Firestore sans modifier les calculs historiques', () {
    final data = <String, dynamic>{
      'location_name': 'Casablanca, Maroc',
      'days': [
        {
          'slots': [
            _slot('2026-07-21T00:00', 1, windKnots: 10),
            _slot('2026-07-21T01:00', 3, windKnots: 12),
            _slot('2026-07-21T02:00', 2, windKnots: 14),
          ],
        },
        {
          'slots': [_slot('2026-07-22T00:00', 9, windKnots: 16)],
        },
      ],
    };

    final result = TideForecastMapper.fromDocument(
      data,
      fallbackLocation: 'Fallback',
      now: DateTime(2026, 7, 21, 0, 30),
    );

    expect(result.location, 'Casablanca, Maroc');
    expect(result.hourlyPoints, hasLength(3));
    expect(result.low, 1);
    expect(result.high, 3);
    expect(result.next, 3);
    expect(result.waveHeight, 1);
    expect(result.hourlyPoints.first.windSpeedKmh, closeTo(18.52, 0.001));
    expect(result.hourlyPoints.first.windWaveHeight, 0.4);
    expect(result.hourlyPoints.first.wavePeriod, 6);
  });

  test('rejette un document sans condition marine exploitable', () {
    expect(
      () => TideForecastMapper.fromDocument(
        const {'days': []},
        fallbackLocation: 'Casablanca',
      ),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _slot(
  String hour,
  double waveHeight, {
  required double windKnots,
}) {
  return {
    'hour': hour,
    'wave_height_m': waveHeight,
    'wave_period_s': 8,
    'wave_dir_deg': 220,
    'wind_speed_kt': windKnots,
    'temp_c': 24,
    'models': {
      'wave': {
        'wave_height_m': waveHeight,
        'windwave_height_m': 0.4,
        'windwave_period_s': 6,
        'windwave_dir_deg': 210,
      },
    },
  };
}
