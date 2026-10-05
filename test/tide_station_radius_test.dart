import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/tide_service.dart';

void main() {
  group('rayon des stations de marée', () {
    test('utilise le seuil côtier conservateur de 75 km', () {
      expect(TideService.maximumTideStationDistanceKm, 75.0);
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

    test('retourne null lorsque la station la plus proche dépasse 75 km', () {
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
        latitude: 40.0,
        longitude: -100.0,
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
        latitude: 40.0,
        longitude: -100.0,
        locationName: 'Position intérieure de test',
      );

      expect(result.hourlyPoints, isEmpty);
      expect(result.location, 'Position intérieure de test');
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

    test('le repli Casablanca reste utilisable sans réseau', () {
      final now = DateTime(2026, 9, 30, 14, 25);
      final result = TideService.casablancaOfflineFallback(now: now);

      expect(result.location, 'Casablanca, Maroc');
      expect(result.generatedAt, isNull);
      expect(result.hourlyPoints, hasLength(49));
      expect(result.hourlyPoints.first.time, DateTime(2026, 9, 30));
      expect(result.hourlyPoints.last.time, DateTime(2026, 10, 2));
      expect(result.low, lessThan(result.high));
      expect(result.next, isNonZero);
      expect(result.waveHeight, 0);
      expect(
        now.isAfter(
          result.hourlyPoints.first.time.subtract(const Duration(minutes: 90)),
        ),
        isTrue,
      );
      expect(
        now.isBefore(
          result.hourlyPoints.last.time.add(const Duration(minutes: 90)),
        ),
        isTrue,
      );
    });
  });
}
