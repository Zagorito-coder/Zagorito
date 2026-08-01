import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';

void main() {
  test('extrait uniquement les trois mesures du modèle Vent GFS', () {
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
  });

  test('ne conserve ni les valeurs invalides ni les prévisions lointaines', () {
    final now = DateTime(2026, 8, 1, 10);
    final timeline = ForecastFirestoreService.parseGfsWeather(
      _document([
        _slot('2026-08-01T09:00', pressure: 400, rain: 180, humidity: -2),
        _slot('2026-08-04T09:00', pressure: 1015, rain: 0, humidity: 60),
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
}) {
  return {
    'hour': hour,
    'models': {
      'wind': {
        'pressure_msl': pressure,
        'precip_prob_pct': rain,
        'rel_humidity_pct': humidity,
      },
      'hires': {
        'pressure_msl': 999,
        'precip_prob_pct': 99,
        'rel_humidity_pct': 99,
      },
    },
  };
}
