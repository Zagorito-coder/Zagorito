import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';

void main() {
  test('extrait les mesures atmosphériques et marines utiles', () {
    final now = DateTime(2026, 8, 1, 10);
    final timeline = ForecastFirestoreService.parseGfsWeather(
      _document([
        _slot('2026-08-01T09:00', pressure: 1014, rain: 18, humidity: 72),
        _slot('2026-08-01T12:00', pressure: 1012, rain: 25, humidity: 68),
      ]),
      now: now,
    );

    expect(timeline, isNotNull);
    expect(timeline!.locationName, 'Casablanca, Maroc');
    expect(timeline.points, hasLength(2));
    final current = timeline.nearestTo(now);
    expect(current?.pressureHpa, 1014);
    expect(current?.precipitationProbabilityPct, 18);
    expect(current?.relativeHumidityPct, 72);
    expect(current?.windGustKmh, closeTo(37.04, 0.001));
    expect(current?.visibilityKm, 14);
    expect(current?.cloudCoverPct, 42);
    expect(current?.precipitationMm, 0.4);
    expect(current?.swellHeightM, 1.2);
    expect(current?.swellPeriodS, 11);
    expect(current?.swellDirectionDeg, 315);
    expect(current?.secondarySwellHeightM, 0.5);
    expect(current?.secondarySwellPeriodS, 7);
    expect(current?.secondarySwellDirectionDeg, 270);
    expect(current?.seaSurfaceTemperatureC, 19.2);
    expect(current?.oceanCurrentSpeedKmh, 0.8);
    expect(current?.oceanCurrentDirectionDeg, 45);
  });

  test('ne conserve ni les valeurs invalides ni les prévisions lointaines', () {
    final now = DateTime(2026, 8, 1, 10);
    final timeline = ForecastFirestoreService.parseGfsWeather(
      _document([
        _slot('2026-08-01T09:00',
            pressure: 400, rain: 180, humidity: -2, withMarine: false),
        _slot('2026-08-04T09:00',
            pressure: 1015, rain: 0, humidity: 60, withMarine: false),
      ]),
      now: now,
    );

    expect(timeline, isNull);
  });

  test('refuse de réutiliser un créneau GFS éloigné', () {
    final timeline = GfsWeatherTimeline(
      locationName: 'Casablanca, Maroc',
      points: [
        GfsWeatherPoint(
          dateTime: DateTime(2026, 8, 1, 9),
          pressureHpa: 1014,
        ),
      ],
    );

    expect(timeline.nearestTo(DateTime(2026, 8, 1, 10)), isNotNull);
    expect(timeline.nearestTo(DateTime(2026, 8, 1, 12)), isNull);
  });
}

Map<String, dynamic> _document(List<Map<String, dynamic>> slots) {
  return {
    'location_name': 'Casablanca, Maroc',
    'days': [
      {'slots': slots},
    ],
  };
}

Map<String, dynamic> _slot(
  String hour, {
  required double pressure,
  required double rain,
  required double humidity,
  bool withMarine = true,
}) {
  return {
    'hour': hour,
    'models': {
      'wind': {
        'pressure_msl': pressure,
        'precip_prob_pct': rain,
        'rel_humidity_pct': humidity,
        if (withMarine) ...{
          'wind_gust_kt': 20,
          'visibility_m': 14000,
          'cloud_total_pct': 42,
          'precipitation_mm': 0.4,
        },
      },
      if (withMarine)
        'wave': {
          'swell_height_m': 1.2,
          'swell_period_s': 11,
          'swell_dir_deg': 315,
          'swell2_height_m': 0.5,
          'swell2_period_s': 7,
          'swell2_dir_deg': 270,
          'sst_c': 19.2,
          'ocean_current_velocity_kmh': 0.8,
          'ocean_current_direction_deg': 45,
        },
      'hires': {
        'pressure_msl': 999,
        'precip_prob_pct': 99,
        'rel_humidity_pct': 99,
      },
    },
  };
}
