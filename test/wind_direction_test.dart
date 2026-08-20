import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/utils/wind_direction.dart';

void main() {
  test('convertit la provenance météorologique vers le sens du flux', () {
    expect(windFlowAngleRadians(0), closeTo(math.pi, 1e-12));
    expect(windFlowAngleRadians(180), closeTo(0, 1e-12));
    expect(
      windFlowAngleRadians(320),
      closeTo(140 * math.pi / 180, 1e-12),
    );
  });

  test('normalise aussi les directions négatives', () {
    expect(
      windFlowAngleRadians(-40),
      closeTo(140 * math.pi / 180, 1e-12),
    );
  });

  test('la houle utilise son sens de propagation et non sa provenance', () {
    expect(
      waveFlowAngleRadians(330),
      closeTo(150 * math.pi / 180, 1e-12),
    );
  });
}
