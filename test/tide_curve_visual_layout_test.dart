import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    expect(
      source,
      contains('final axisMin = fixedChartDatumScale ? 0.0 : paddedMin;'),
    );
    expect(
      source,
      contains('final axisRange = fixedChartDatumScale ? 5.0 : paddedRange;'),
    );
  });
}
