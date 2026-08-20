import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';

void main() {
  group('rayon des stations météo', () {
    test('utilise le seuil professionnel de 75 km', () {
      expect(
        ForecastFirestoreService.maximumWeatherStationDistanceKm,
        75.0,
      );
    });

    test('sélectionne uniquement la station la plus proche dans le rayon', () {
      final result =
          ForecastFirestoreService.nearestWeatherStationIdWithinRadius(
        stations: const [
          {
            'id': 'station-55-km',
            'latitude': 0.5,
            'longitude': 0.0,
          },
          {
            'id': 'station-11-km',
            'latitude': 0.1,
            'longitude': 0.0,
          },
        ],
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(result, 'station-11-km');
    });

    test('retourne null lorsque la station la plus proche dépasse 75 km', () {
      final result =
          ForecastFirestoreService.nearestWeatherStationIdWithinRadius(
        stations: const [
          {
            'id': 'station-111-km',
            'latitude': 1.0,
            'longitude': 0.0,
          },
        ],
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(result, isNull);
    });

    test('accepte la même position et ignore les stations invalides', () {
      final stations = <Map<String, dynamic>>[
        {'id': '', 'latitude': 0.0, 'longitude': 0.0},
        {'id': 'latitude-invalide', 'latitude': 91.0, 'longitude': 0.0},
        {'id': 'exacte', 'latitude': 0.0, 'longitude': 0.0},
      ];

      expect(
        ForecastFirestoreService.nearestWeatherStationIdWithinRadius(
          stations: stations,
          latitude: 0.0,
          longitude: 0.0,
        ),
        'exacte',
      );
      expect(
        ForecastFirestoreService.nearestWeatherStationIdWithinRadius(
          stations: stations,
          latitude: double.nan,
          longitude: 0.0,
        ),
        isNull,
      );
    });
  });
}
