import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/utils/tide_chart_scale.dart';

void main() {
  final source = File('lib/pages/tide_page.dart').readAsStringSync();

  test('la courbe des marées gagne exactement 70 pour cent en hauteur', () {
    expect(
      source,
      contains('static const _tideCurveCanvasHeight = 238.0;'),
    );
    expect(source, contains('height: _tideCurveCanvasHeight,'));
    expect(source, isNot(contains('height: 140,')));
  });

  test('les zones visuelles réservent la place des repères et des heures', () {
    expect(source, contains('_pillZoneH = 98.0,'));
    expect(source, contains('_hourZoneH = 30.0,'));
    expect(source, contains('_padR = 44.0,'));
  });

  test('l’échelle de Casablanca reste strictement inchangée de 0 à 5 m', () {
    final scale = TideChartScale.forValues(
      const [1.05, 3.39],
      fixedChartDatumScale: true,
      usesMeanSeaLevelDatum: false,
    );

    expect(scale.min, 0);
    expect(scale.max, 5);
    expect(scale.tickCount, 5);
  });

  test('l’échelle NMM est signée, symétrique et contient zéro', () {
    final scale = TideChartScale.forValues(
      const [-1.48, 0.96],
      fixedChartDatumScale: false,
      usesMeanSeaLevelDatum: true,
    );

    expect(scale.min, lessThan(-1.48));
    expect(scale.max, greaterThan(0.96));
    expect(scale.min, closeTo(-scale.max, 1e-12));
    expect(scale.tickAt(2), closeTo(0, 1e-12));
    expect(scale.contains(-1.48), isTrue);
    expect(scale.contains(0.96), isTrue);
  });

  test('l’échelle NMM montre zéro même si toute la série est du même côté', () {
    for (final values in <List<double>>[
      const [0.4, 0.8],
      const [-0.9, -0.2],
      const [0, 0],
    ]) {
      final scale = TideChartScale.forValues(
        values,
        fixedChartDatumScale: false,
        usesMeanSeaLevelDatum: true,
      );

      expect(scale.tickAt(2), closeTo(0, 1e-12));
      for (final value in values) {
        expect(scale.contains(value), isTrue);
      }
    }
  });
}
