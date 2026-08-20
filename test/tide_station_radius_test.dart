import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/tide_service.dart';

void main() {
  group('rayon des stations de marée', () {
    test('utilise le seuil côtier de 100 km', () {
      expect(TideService.maximumTideStationDistanceKm, 100.0);
    });

    test('sélectionne uniquement la station la plus proche dans le rayon', () {
      final result = TideService.nearestTideStationIdWithinRadius(
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

    test('retourne null lorsque la station la plus proche dépasse 100 km', () {
      final result = TideService.nearestTideStationIdWithinRadius(
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

    test(
        'une position distante connue renvoie un fallback honnête, jamais Casablanca',
        () async {
      final result = await TideService.fetchTides(
        latitude: 5.35,
        longitude: -4.02,
      );

      expect(result.hourlyPoints, isEmpty);
      expect(result.hourlyForecast, isEmpty);
      expect(result.low, 0.0);
      expect(result.high, 0.0);
      expect(result.next, 0.0);
      expect(result.waveHeight, 0.0);
      expect(result.generatedAt, isNull);
      expect(result.location, TideService.unavailableLocationLabel);
      expect(result.location.toLowerCase(), isNot(contains('casablanca')));
    });

    test('une position distante conserve son nom explicite sans station locale',
        () async {
      final result = await TideService.fetchTides(
        latitude: 5.35,
        longitude: -4.02,
        locationName: "Abidjan, Côte d'Ivoire",
      );

      expect(result.hourlyPoints, isEmpty);
      expect(result.location, "Abidjan, Côte d'Ivoire");
      expect(result.location.toLowerCase(), isNot(contains('casablanca')));
    });

    test('accepte la même position et refuse les entrées invalides', () {
      final stations = <Map<String, dynamic>>[
        {'id': null, 'latitude': 0.0, 'longitude': 0.0},
        {'id': 'longitude-invalide', 'latitude': 0.0, 'longitude': 181.0},
        {'id': 'exacte', 'latitude': 0.0, 'longitude': 0.0},
      ];

      expect(
        TideService.nearestTideStationIdWithinRadius(
          stations: stations,
          latitude: 0.0,
          longitude: 0.0,
        ),
        'exacte',
      );
      expect(
        TideService.nearestTideStationIdWithinRadius(
          stations: stations,
          latitude: 90.1,
          longitude: 0.0,
        ),
        isNull,
      );
    });
  });
}
