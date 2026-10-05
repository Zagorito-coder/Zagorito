import '../models/tide_page_models.dart';
import '../models/tide_data.dart' as source;
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

  /// Associe aux créneaux météo les niveaux marins horaires publiés par le
  /// backend pour la même station. Aucun calcul Casablanca ni hauteur de vague
  /// n'est utilisé comme substitut de marée.
  static List<HourlyForecastDay> attachPublishedTides(
    List<HourlyForecastDay> days,
    List<source.TidePoint> sourcePoints,
  ) {
    if (sourcePoints.length < 3) return days;
    final points = List<source.TidePoint>.of(sourcePoints)
      ..sort((a, b) => a.time.compareTo(b.time));
    final extrema = <source.TidePoint, bool>{};
    for (var index = 1; index < points.length - 1; index++) {
      final previous = points[index - 1].height;
      final current = points[index].height;
      final next = points[index + 1].height;
      if (current > previous && current > next) {
        extrema[points[index]] = true;
      } else if (current < previous && current < next) {
        extrema[points[index]] = false;
      }
    }

    return days.map((day) {
      final enriched = day.slots.map((slot) {
        var nearestIndex = -1;
        var nearestDifference = const Duration(days: 365);
        for (var index = 0; index < points.length; index++) {
          final difference = points[index].time.difference(slot.time).abs();
          if (difference < nearestDifference) {
            nearestDifference = difference;
            nearestIndex = index;
          }
        }
        if (nearestIndex < 0 ||
            nearestDifference >
                const Duration(minutes: _maximumExtremumDistanceMinutes)) {
          return slot;
        }
        final point = points[nearestIndex];
        final after = points[nearestIndex == points.length - 1
                ? points.length - 1
                : nearestIndex + 1]
            .height;

        TideForecastExtremum? attachedExtremum;
        source.TidePoint? closestExtremum;
        var extremumDifference = const Duration(days: 365);
        for (final candidate in extrema.keys) {
          final difference = candidate.time.difference(slot.time).abs();
          if (difference < extremumDifference) {
            extremumDifference = difference;
            closestExtremum = candidate;
          }
        }
        if (closestExtremum != null &&
            extremumDifference <=
                const Duration(minutes: _maximumExtremumDistanceMinutes)) {
          attachedExtremum = TideForecastExtremum(
            time: closestExtremum.time,
            heightM: closestExtremum.height,
            isHigh: extrema[closestExtremum]!,
          );
        }

        return slot.copyWithTide(
          tideHeightM: point.height,
          tideIsRising: after >= point.height,
          tideExtremum: attachedExtremum,
        );
      }).toList(growable: false);
      return HourlyForecastDay(date: day.date, slots: enriched);
    }).toList(growable: false);
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
