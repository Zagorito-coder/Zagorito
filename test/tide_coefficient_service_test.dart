import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/tide_coefficient_service.dart';

void main() {
  group('TideCoefficientService', () {
    test('construit chaque jour du mois sans valeur décorative', () {
      final month = TideCoefficientService.buildCasablancaMonth(
        DateTime(2026, 8),
      );

      expect(month.days, hasLength(31));
      expect(month.days.every((day) => day.samples.length == 49), isTrue);
      expect(month.days.every((day) => day.extrema.length >= 3), isTrue);
      expect(
        month.days
            .every((day) => day.localIndex >= 20 && day.localIndex <= 120),
        isTrue,
      );
    });

    test('le marnage du 14 août provient des extrema Casablanca', () {
      final day = TideCoefficientService.buildCasablancaMonth(
        DateTime(2026, 8),
      ).day(14);

      expect(day.lowMeters, closeTo(0.553, 0.01));
      expect(day.highMeters, closeTo(3.810, 0.01));
      expect(day.tidalRangeMeters, closeTo(3.257, 0.015));
      // Le repère externe Casablanca du même jour se situe autour de 97–99.
      // L'indice local reste indépendant, mais doit conserver le même ordre de
      // grandeur afin de ne pas induire le pêcheur en erreur.
      expect(day.localIndex, inInclusiveRange(99, 104));
    });

    test('l’indice reste proportionnel au marnage stationnel', () {
      expect(TideCoefficientService.localIndexForRange(1.0), 32);
      expect(TideCoefficientService.localIndexForRange(3.8), 120);
      expect(TideCoefficientService.localIndexForRange(2.4), 76);
    });

    test('le cycle août 2026 reste cohérent avec le repère Casablanca', () {
      final month = TideCoefficientService.buildCasablancaMonth(
        DateTime(2026, 8),
      );
      const casablancaReference = <int>[
        82,
        80,
        74,
        67,
        58,
        50,
        47,
        52,
        64,
        77,
        89,
        97,
        101,
        99,
        93,
        82,
        69,
        56,
        43,
        32,
        29,
        33,
        43,
        54,
        65,
        76,
        84,
        91,
        94,
        93,
        88,
      ];

      final absoluteErrors = <int>[];
      for (var i = 0; i < casablancaReference.length; i++) {
        absoluteErrors.add(
          (month.days[i].localIndex - casablancaReference[i]).abs(),
        );
      }
      final meanError =
          absoluteErrors.reduce((a, b) => a + b) / absoluteErrors.length;

      expect(month.day(21).localIndex, inInclusiveRange(28, 31));
      expect(month.day(22).localIndex, inInclusiveRange(31, 34));
      expect(meanError, lessThan(3));
      expect(
          absoluteErrors.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(6));
    });
  });

  group('MoroccanTideTradition', () {
    test('respecte les cinq périodes sur les deux demi-cycles', () {
      for (var lunarDay = 1; lunarDay <= 30; lunarDay++) {
        final folded = lunarDay > 15 ? lunarDay - 15 : lunarDay;
        final expected = folded <= 3
            ? MoroccanTidePeriod.alKsour
            : folded <= 6
                ? MoroccanTidePeriod.elMaSghir
                : folded <= 9
                    ? MoroccanTidePeriod.alQamrayer
                    : folded <= 12
                        ? MoroccanTidePeriod.alHamz
                        : MoroccanTidePeriod.elMaLkbir;

        final actual = MoroccanTideTradition.forLunarDay(lunarDay);
        expect(actual.period, expected, reason: 'jour lunaire $lunarDay');
      }
    });

    test('refuse un jour lunaire hors du cycle 1 à 30', () {
      expect(
        () => MoroccanTideTradition.forLunarDay(0),
        throwsRangeError,
      );
      expect(
        () => MoroccanTideTradition.forLunarDay(31),
        throwsRangeError,
      );
    });
  });
}
