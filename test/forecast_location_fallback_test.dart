import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/pages/forecast_page.dart';

void main() {
  test('Casablanca reste le repli si le GPS est indisponible', () {
    final spotId = fallbackForecastSpotId([
      {
        'id': 'abidjan-cote-divoire',
        'name': "Abidjan, Côte d'Ivoire",
      },
      {
        'id': 'ma-casablanca',
        'name': 'Casablanca, Maroc',
      },
    ]);

    expect(spotId, 'ma-casablanca');
  });

  test('le repli sans Casablanca reste déterministe', () {
    final spotId = fallbackForecastSpotId([
      {'id': 'tunis', 'name': 'Tunis'},
      {'id': 'abidjan', 'name': 'Abidjan'},
    ]);

    expect(spotId, 'abidjan');
  });

  test('une liste sans identifiant valide est refusée', () {
    expect(
      () => fallbackForecastSpotId([
        {'name': 'Spot incomplet'},
      ]),
      throwsStateError,
    );
  });
}
