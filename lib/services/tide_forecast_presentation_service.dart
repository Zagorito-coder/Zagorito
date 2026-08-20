import '../models/tide_page_models.dart';
import 'casablanca_tide_reference.dart';
import 'tide_coefficient_service.dart';

/// Enrichit les créneaux météo déjà chargés avec la marée harmonique locale.
///
/// Ce service est volontairement pur : aucun accès réseau, Firestore ou API.
/// Il réutilise exactement le moteur Casablanca/JRC des autres volets Marées.
class TideForecastPresentationService {
  const TideForecastPresentationService._();

  static const int _maximumExtremumDistanceMinutes = 90;
  static const Duration _slopeWindow = Duration(minutes: 10);

  static List<HourlyForecastDay> attachCasablancaTides(
    List<HourlyForecastDay> days,
  ) {
    return days.map(_attachDay).toList(growable: false);
  }

  static HourlyForecastDay _attachDay(HourlyForecastDay day) {
    if (day.slots.isEmpty) return day;

    final tideDay = TideCoefficientService.buildCasablancaDay(day.date);
    final extremaBySlot = <int, LocalTideExtremum>{};
    final distanceBySlot = <int, int>{};

    for (final extremum in tideDay.extrema) {
      var nearestIndex = -1;
      var nearestDistance = 1 << 30;
      for (var index = 0; index < day.slots.length; index++) {
        final distance =
            day.slots[index].time.difference(extremum.time).inMinutes.abs();
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = index;
        }
      }
      if (nearestIndex < 0 ||
          nearestDistance > _maximumExtremumDistanceMinutes) {
        continue;
      }
      final previousDistance = distanceBySlot[nearestIndex];
      if (previousDistance == null || nearestDistance < previousDistance) {
        extremaBySlot[nearestIndex] = extremum;
        distanceBySlot[nearestIndex] = nearestDistance;
      }
    }

    final enrichedSlots = <HourlyForecastSlot>[];
    for (var index = 0; index < day.slots.length; index++) {
      final slot = day.slots[index];
      final height = CasablancaTideReference.heightAtUtc(slot.time.toUtc());
      final before = CasablancaTideReference.heightAtUtc(
        slot.time.subtract(_slopeWindow).toUtc(),
      );
      final after = CasablancaTideReference.heightAtUtc(
        slot.time.add(_slopeWindow).toUtc(),
      );
      final extremum = extremaBySlot[index];
      enrichedSlots.add(
        slot.copyWithTide(
          tideHeightM: height,
          tideIsRising: after >= before,
          tideExtremum: extremum == null
              ? null
              : TideForecastExtremum(
                  time: extremum.time,
                  heightM: extremum.height,
                  isHigh: extremum.isHigh,
                ),
        ),
      );
    }

    return HourlyForecastDay(
      date: day.date,
      slots: List.unmodifiable(enrichedSlots),
    );
  }
}
