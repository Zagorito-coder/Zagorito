import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/casablanca_tide_reference.dart';

void main() {
  test('retrouve les quatre extrema de Casablanca au plus près de la table',
      () {
    // Le 07/08/2026, Casablanca est à UTC+1. La journée locale commence donc
    // le 06/08 à 23:00 UTC.
    final startUtc = DateTime.utc(2026, 8, 6, 23);
    final heights = List<double>.generate(
      24 * 60,
      (minute) => CasablancaTideReference.heightAtUtc(
        startUtc.add(Duration(minutes: minute)),
      ),
      growable: false,
    );

    final extrema = <({String type, int minute, double height})>[];
    for (var index = 1; index < heights.length - 1; index++) {
      final previous = heights[index - 1];
      final current = heights[index];
      final next = heights[index + 1];
      if (current < previous && current < next) {
        extrema.add((type: 'low', minute: index, height: current));
      } else if (current > previous && current > next) {
        extrema.add((type: 'high', minute: index, height: current));
      }
    }

    expect(extrema, hasLength(4));
    const expected = [
      (type: 'low', minute: 3 * 60, height: 1.4),
      (type: 'high', minute: 9 * 60 + 24, height: 2.9),
      (type: 'low', minute: 15 * 60 + 47, height: 1.4),
      (type: 'high', minute: 22 * 60 + 6, height: 2.8),
    ];

    for (var index = 0; index < expected.length; index++) {
      expect(extrema[index].type, expected[index].type);
      expect(
        (extrema[index].minute - expected[index].minute).abs(),
        lessThanOrEqualTo(10),
      );
      expect(
        (extrema[index].height - expected[index].height).abs(),
        lessThanOrEqualTo(0.1),
      );
    }
  });

  test('la courbe Casablanca utilise une échelle fixe 0 à 5 sans écrêtage', () {
    final source = File('lib/pages/tide_page.dart').readAsStringSync();

    expect(source, contains('fixedChartDatumScale ? 0.0 : paddedMin'));
    expect(source, contains('fixedChartDatumScale ? 5.0 : paddedRange'));
    expect(source, contains("context.tr('tide.tideCurveJrcSource')"));
    expect(
      source,
      isNot(contains('height.clamp(0.0, 5.0)')),
      reason: 'Écrêter les valeurs fausserait les extrema de marée.',
    );
  });
}
