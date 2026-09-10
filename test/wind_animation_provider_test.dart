import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/widgets/forecast_table.dart';

void main() {
  test('un échec ne déclenche pas de nouvelle requête automatique', () async {
    var calls = 0;
    final provider = WindAnimationProvider(
      availableSpotsLoader: () async {
        calls++;
        throw StateError('permission-denied');
      },
    );

    await provider.fetchForPanel(33.5, -7.6);

    expect(provider.isLoading, isFalse);
    expect(provider.currentVector, isNull);
    expect(provider.error, contains('permission-denied'));
    expect(calls, 1);

    await provider.fetchForPanel(33.5, -7.6);
    expect(calls, 1);

    await provider.retryForPanel(33.5, -7.6);
    expect(calls, 2);
  });

  test('un changement de spot charge la station correspondante', () async {
    var indexCalls = 0;
    final provider = WindAnimationProvider(
      availableSpotsLoader: () async {
        indexCalls++;
        return [
          {
            'id': 'north',
            'name': 'North',
            'latitude': 35.0,
            'longitude': -6.0,
          },
          {
            'id': 'south',
            'name': 'South',
            'latitude': 30.0,
            'longitude': -9.0,
          },
        ];
      },
      spotForecastLoader: (spotId) async => _forecast(spotId),
    );

    await provider.fetchForPanel(35.0, -6.0);
    expect(provider.spotId, 'north');
    expect(provider.forecast?.locationName, 'north');

    await provider.fetchForPanel(30.0, -9.0);
    expect(provider.spotId, 'south');
    expect(provider.forecast?.locationName, 'south');
    expect(indexCalls, 2);
  });

  test('une réponse ancienne ne remplace pas le spot courant', () async {
    final firstRequest = Completer<List<Map<String, dynamic>>>();
    var calls = 0;
    final provider = WindAnimationProvider(
      availableSpotsLoader: () {
        calls++;
        if (calls == 1) return firstRequest.future;
        return Future.value([
          {
            'id': 'current',
            'name': 'Current',
            'latitude': 30.0,
            'longitude': -9.0,
          },
        ]);
      },
      spotForecastLoader: (spotId) async => _forecast(spotId),
    );

    final staleLoad = provider.fetchForPanel(35.0, -6.0);
    await provider.fetchForPanel(30.0, -9.0);
    firstRequest.complete([
      {
        'id': 'stale',
        'name': 'Stale',
        'latitude': 35.0,
        'longitude': -6.0,
      },
    ]);
    await staleLoad;

    expect(provider.spotId, 'current');
    expect(provider.forecast?.locationName, 'current');
  });
}

SpotForecast _forecast(String name) {
  final date = DateTime(2026, 9, 9, 12);
  return SpotForecast(
    locationName: name,
    lastUpdate: date,
    slots: [
      ForecastSlot(
        dateTime: date,
        windSpeedKnots: 12,
        windGustKnots: 16,
        windDirectionDeg: 270,
        waveHeightM: 1,
        wavePeriodS: 8,
        waveDirectionDeg: 280,
        temperatureC: 22,
        ratingStars: 3,
        isNewDay: true,
      ),
    ],
    dayStarts: [date],
    dayStartIndexes: const [0],
  );
}
