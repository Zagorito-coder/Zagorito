import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/widgets/forecast_table.dart';

void main() {
  group('ForecastFirestoreService.parseSpotForecast', () {
    test('preserves missing marine values without changing the published score',
        () {
      final forecast = ForecastFirestoreService.parseSpotForecast({
        'location_name': 'Station test',
        'utc_offset_seconds': -5 * 3600,
        'days': [
          {
            'sunrise': '2026-10-05T07:23',
            'sunset': '2026-10-05T19:02',
            'slots': [
              {
                'hour': '2026-10-05T06:00:00',
                'wind_speed_kt': 12.3,
                'wind_gust_kt': 15.4,
                'wind_dir_deg': 270,
                'temp_c': 21,
                'cloud_pct': 45,
                'precip_pct': 20,
                'rating': 3,
                'models': {
                  'wave': {'wave_period_s': 9},
                },
              },
              {
                'hour': '2026-10-05T09:00:00',
                'wind_speed_kt': 10,
                'wind_gust_kt': 12,
                'wind_dir_deg': 250,
                'wave_height_m': 0,
                'wave_period_s': 0,
                'wave_dir_deg': 0,
                'temp_c': 22,
                'rating': 4,
              },
              {
                'hour': '2026-10-05T12:00:00',
              },
            ],
          },
        ],
      });

      final missingWaves = forecast.slots[0];
      expect(missingWaves.waveHeightM, isNull);
      expect(missingWaves.wavePeriodS, isNull);
      expect(missingWaves.waveDirectionDeg, isNull);
      expect(missingWaves.ratingStars, 3);
      expect(missingWaves.modelWave, isNotNull);
      expect(missingWaves.modelWave!.wavePeriodS, 9);

      final measuredZeros = forecast.slots[1];
      expect(measuredZeros.waveHeightM, 0);
      expect(measuredZeros.wavePeriodS, 0);
      expect(measuredZeros.waveDirectionDeg, 0);
      expect(measuredZeros.ratingStars, 4);

      expect(forecast.slots[2].ratingStars, isNull);
      expect(forecast.slots[2].windSpeedKnots, isNull);
      expect(forecast.slots[2].windGustKnots, isNull);
      expect(forecast.slots[2].windDirectionDeg, isNull);
      expect(forecast.slots[2].temperatureC, isNull);
      expect(forecast.utcOffsetSeconds, -5 * 3600);
      expect(forecast.sunriseForDay(0), '2026-10-05T07:23');
      expect(forecast.sunsetForDay(0), '2026-10-05T19:02');
      expect(forecast.sunriseForDay(1), isNull);
      expect(
        forecast.stationTimeAt(DateTime.utc(2026, 10, 5, 5, 30)),
        DateTime(2026, 10, 5, 0, 30),
      );
    });

    test('prefers exact UTC instants with the station IANA timezone', () {
      final forecast = ForecastFirestoreService.parseSpotForecast({
        'location_name': 'Casablanca',
        'timezone': 'Africa/Casablanca',
        'utc_offset_seconds': 3600,
        'days': [
          {
            'slots': [
              {
                'hour': '2026-10-05T03:00:00',
                'hour_utc': '2026-10-05T03:00:00Z',
                'wind_speed_kt': 10,
              },
            ],
          },
        ],
      });

      expect(forecast.timeZoneId, 'Africa/Casablanca');
      expect(forecast.slots.single.instantUtc, DateTime.utc(2026, 10, 5, 3));
      expect(forecast.slots.single.dateTime, DateTime(2026, 10, 5, 3));
      expect(
        forecast.stationTimeAt(DateTime.utc(2026, 10, 5, 3)),
        DateTime(2026, 10, 5, 3),
      );
    });
  });

  testWidgets(
      'root table shows dashes for unavailable waves and keeps its score',
      (tester) async {
    final slot = ForecastFirestoreService.parseSpotForecast({
      'days': [
        {
          'slots': [
            {
              'hour': '2026-10-05T06:00:00',
              'wind_speed_kt': 12.3,
              'wind_gust_kt': 15.4,
              'wind_dir_deg': 270,
              'temp_c': 21,
              'cloud_pct': 45,
              'precip_pct': 20,
              'rating': 3,
            },
          ],
        },
      ],
    }).slots.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForecastTable(
            modelName: 'Station test',
            runLabel: '',
            slots: [slot],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('-'), findsNWidgets(3));
    expect(find.text('0.0'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(3));
  });
}
