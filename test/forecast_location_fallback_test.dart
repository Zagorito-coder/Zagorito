import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/pages/forecast_page.dart';

void main() {
  test('une position inconnue ne sélectionne jamais Casablanca silencieusement',
      () {
    final spotId = forecastSpotIdForPosition(
      spots: const [
        {
          'id': 'abidjan-cote-divoire',
          'name': "Abidjan, Côte d'Ivoire",
          'latitude': 5.3,
          'longitude': -4.0,
        },
        {
          'id': 'ma-casablanca',
          'name': 'Casablanca, Maroc',
          'latitude': 33.6,
          'longitude': -7.6,
        },
      ],
      latitude: null,
      longitude: null,
    );

    expect(spotId, isNull);
  });

  test('une position connue ne choisit jamais une station au-delà de 75 km',
      () {
    final spotId = forecastSpotIdForPosition(
      spots: const [
        {
          'id': 'station-distante',
          'name': 'Station distante',
          'latitude': 1.0,
          'longitude': 0.0,
        },
      ],
      latitude: 0.0,
      longitude: 0.0,
    );

    expect(spotId, isNull);
  });

  test('une position connue choisit la station valide la plus proche', () {
    final spotId = forecastSpotIdForPosition(
      spots: const [
        {
          'id': 'station-55-km',
          'name': 'Station 55 km',
          'latitude': 0.5,
          'longitude': 0.0,
        },
        {
          'id': 'station-11-km',
          'name': 'Station 11 km',
          'latitude': 0.1,
          'longitude': 0.0,
        },
      ],
      latitude: 0.0,
      longitude: 0.0,
    );

    expect(spotId, 'station-11-km');
  });
}
