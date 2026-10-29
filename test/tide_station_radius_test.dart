import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/casablanca_tide_reference.dart';
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
      final now = DateTime.utc(2026, 9, 30, 13, 25);
      final result = TideService.casablancaOfflineFallback(now: now);

      expect(result.location, 'Casablanca, Maroc');
      expect(result.generatedAt, isNull);
      expect(
        result.utcOffsetSeconds,
        0,
      );
      expect(result.timeZoneId, TideService.casablancaTimeZoneId);
      expect(result.stationTimeAt(now), DateTime(2026, 9, 30, 13, 25));
      expect(result.hourlyPoints, hasLength(49));
      expect(result.hourlyPoints.first.time, DateTime(2026, 9, 30));
      expect(result.hourlyPoints.last.time, DateTime(2026, 10, 2));
      expect(
        result.stationInstantAt(result.hourlyPoints.first.time),
        DateTime.utc(2026, 9, 30),
      );
      expect(
        result.hourlyPoints.first.height,
        closeTo(
          CasablancaTideReference.heightAtUtc(
            DateTime.utc(2026, 9, 30),
          ),
          0.000000001,
        ),
      );
      expect(result.low, lessThan(result.high));
      expect(result.next, isNonZero);
      expect(result.waveHeight, 0);
      expect(result.hourlyPoints.first.windDirectionDeg, isNull);
      expect(result.hourlyPoints.first.windSpeedKmh, isNull);
      expect(result.hourlyPoints.first.temperatureC, isNull);
      expect(result.hourlyPoints.first.wavePeriod, isNull);
      expect(result.hourlyPoints.first.windWaveHeight, isNull);
      expect(
        result.stationTimeAt(now).isAfter(
              result.hourlyPoints.first.time
                  .subtract(const Duration(minutes: 90)),
            ),
        isTrue,
      );
      expect(
        result.stationTimeAt(now).isBefore(
              result.hourlyPoints.last.time.add(const Duration(minutes: 90)),
            ),
        isTrue,
      );
    });

    test('le repli Casablanca ne dépend pas du fuseau du téléphone', () {
      final sameInstantUtc = DateTime.utc(2026, 9, 30, 23, 30);
      final sameInstantWithOffset = DateTime.parse('2026-10-01T01:30:00+02:00');

      final fromUtc =
          TideService.casablancaOfflineFallback(now: sameInstantUtc);
      final fromOtherZone =
          TideService.casablancaOfflineFallback(now: sameInstantWithOffset);

      expect(fromUtc.hourlyPoints.first.time, DateTime(2026, 9, 30));
      expect(fromOtherZone.hourlyPoints.first.time, DateTime(2026, 9, 30));
      expect(
        fromOtherZone.hourlyPoints.map((point) => point.time),
        orderedEquals(fromUtc.hourlyPoints.map((point) => point.time)),
      );
      for (var index = 0; index < fromUtc.hourlyPoints.length; index++) {
        expect(
          fromOtherZone.hourlyPoints[index].height,
          closeTo(fromUtc.hourlyPoints[index].height, 0.000000001),
        );
      }
    });

    test('le repli Casablanca respecte la suspension Ramadan', () {
      final instantDuringSuspension = DateTime.utc(2026, 2, 20, 12, 30);
      final result = TideService.casablancaOfflineFallback(
        now: instantDuringSuspension,
      );

      expect(result.timeZoneId, 'Africa/Casablanca');
      expect(result.utcOffsetSeconds, 0);
      expect(
        result.stationTimeAt(instantDuringSuspension),
        DateTime(2026, 2, 20, 12, 30),
      );
      expect(result.hourlyPoints.first.time, DateTime(2026, 2, 20));
      expect(result.hourlyPoints.first.instantUtc, DateTime.utc(2026, 2, 20));
    });
  });
}
