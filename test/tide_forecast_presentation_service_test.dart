import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_data.dart' as source;
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

  test('associe les marées horaires publiées à une station hors Casablanca',
      () {
    final date = DateTime(2026, 8, 20);
    final forecast = HourlyForecastDay(
      date: date,
      slots: [
        HourlyForecastSlot(time: date.add(const Duration(hours: 1))),
        HourlyForecastSlot(time: date.add(const Duration(hours: 4))),
        HourlyForecastSlot(time: date.add(const Duration(hours: 7))),
      ],
    );
    final published = List.generate(
      10,
      (index) => source.TidePoint(
        time: date.add(Duration(hours: index)),
        height: index <= 4 ? index / 4 : (8 - index) / 4,
      ),
    );

    final result = TideForecastPresentationService.attachPublishedTides(
      [forecast],
      published,
    ).single;

    expect(result.slots.map((slot) => slot.tideHeightM), [0.25, 1.0, 0.25]);
    expect(result.slots.map((slot) => slot.tideIsRising), [true, false, false]);
    expect(result.slots[1].tideExtremum?.isHigh, isTrue);
    expect(
        result.slots[1].tideExtremum?.time, date.add(const Duration(hours: 4)));
  });
}
