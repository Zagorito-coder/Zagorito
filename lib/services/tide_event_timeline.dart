import '../models/tide_page_models.dart';

/// Opérations temporelles sur les événements de marée.
///
/// Le tri et le filtrage utilisent exclusivement les instants UTC. Les heures
/// civiles restent réservées à l'affichage, car elles peuvent se répéter lors
/// d'un changement d'heure.
class TideEventTimeline {
  const TideEventTimeline._();

  static List<TideEvent> upcoming(
    Iterable<TideEvent> source, {
    required DateTime referenceInstant,
  }) {
    final referenceUtc = referenceInstant.toUtc();
    final events = source
        .where(
          (event) => !event.instantUtc.toUtc().isBefore(referenceUtc),
        )
        .toList()
      ..sort(
        (a, b) => a.instantUtc.toUtc().compareTo(b.instantUtc.toUtc()),
      );
    return List.unmodifiable(events);
  }

  static int dayDifference({
    required DateTime eventCivilTime,
    required DateTime referenceCivilTime,
  }) {
    // UTC neutralise le fuseau du téléphone : seules les composantes de date
    // civile de la station doivent déterminer J+1/J+2.
    final eventDay = DateTime.utc(
      eventCivilTime.year,
      eventCivilTime.month,
      eventCivilTime.day,
    );
    final referenceDay = DateTime.utc(
      referenceCivilTime.year,
      referenceCivilTime.month,
      referenceCivilTime.day,
    );
    return eventDay.difference(referenceDay).inDays;
  }
}
