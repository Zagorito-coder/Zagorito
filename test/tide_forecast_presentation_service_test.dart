import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_page_models.dart';
import 'package:spots_app/services/tide_coefficient_service.dart';
import 'package:spots_app/services/tide_forecast_presentation_service.dart';

void main() {
  test('associe les marées Casablanca sans altérer les données météo', () {
    final date = DateTime(2026, 8, 20);
    final source = HourlyForecastDay(
      date: date,
      slots: List.generate(
        8,
        (index) => HourlyForecastSlot(
          time: date.add(Duration(hours: index * 3 + 1)),
          windSpeedKmh: 12 + index.toDouble(),
          waveHeightM: 0.7,
          waveDirectionDeg: 330,
        ),
      ),
    );

    final result = TideForecastPresentationService.attachCasablancaTides([
      source,
    ]).single;

    expect(result.slots, hasLength(8));
    expect(result.slots.every((slot) => slot.tideHeightM != null), isTrue);
    expect(result.slots.every((slot) => slot.tideIsRising != null), isTrue);
    expect(result.slots.first.windSpeedKmh, 12);
    expect(result.slots.first.waveHeightM, 0.7);
    expect(result.slots.first.waveDirectionDeg, 330);
  });

  test('place chaque haute ou basse mer sur le créneau le plus proche', () {
    final date = DateTime(2026, 8, 20);
    final source = HourlyForecastDay(
      date: date,
      slots: List.generate(
        8,
        (index) => HourlyForecastSlot(
          time: date.add(Duration(hours: index * 3 + 1)),
        ),
      ),
    );
    final expected = TideCoefficientService.buildCasablancaDay(date).extrema;
    final result = TideForecastPresentationService.attachCasablancaTides([
      source,
    ]).single;
    final attached = result.slots
        .map((slot) => slot.tideExtremum)
        .whereType<TideForecastExtremum>()
        .toList(growable: false);

    expect(attached, hasLength(expected.length));
    for (final extremum in expected) {
      expect(
        attached.any(
          (item) =>
              item.time == extremum.time &&
              item.isHigh == extremum.isHigh &&
              (item.heightM - extremum.height).abs() < 0.000001,
        ),
        isTrue,
      );
    }
  });
}
