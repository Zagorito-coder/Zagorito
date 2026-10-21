import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_page_models.dart';
import 'package:spots_app/services/tide_event_timeline.dart';

TideEvent event({
  required DateTime instantUtc,
  DateTime? civilTime,
  String type = 'high',
}) {
  final displayedTime = civilTime ?? instantUtc;
  return TideEvent(
    type: type,
    time: displayedTime.hour + displayedTime.minute / 60,
    height: 1,
    label: type == 'high' ? 'Haute Mer' : 'Basse Mer',
    dateTime: displayedTime,
    instantUtc: instantUtc,
  );
}

void main() {
  test('retire un événement dès que son instant est dépassé', () {
    final first = event(instantUtc: DateTime.utc(2026, 10, 6, 10));
    final second = event(
      instantUtc: DateTime.utc(2026, 10, 6, 11),
      type: 'low',
    );

    expect(
      TideEventTimeline.upcoming(
        [first, second],
        referenceInstant: DateTime.utc(2026, 10, 6, 10),
      ),
      [first, second],
    );
    expect(
      TideEventTimeline.upcoming(
        [first, second],
        referenceInstant: DateTime.utc(2026, 10, 6, 10, 0, 1),
      ),
      [second],
    );
  });

  test('distingue deux heures civiles identiques pendant le recul DST', () {
    final repeatedCivilTime = DateTime(2026, 10, 25, 2, 30);
    final firstOccurrence = event(
      instantUtc: DateTime.utc(2026, 10, 25, 0, 30),
      civilTime: repeatedCivilTime,
    );
    final secondOccurrence = event(
      instantUtc: DateTime.utc(2026, 10, 25, 1, 30),
      civilTime: repeatedCivilTime,
      type: 'low',
    );

    final upcoming = TideEventTimeline.upcoming(
      [secondOccurrence, firstOccurrence],
      referenceInstant: DateTime.utc(2026, 10, 25, 0, 45),
    );

    expect(upcoming, [secondOccurrence]);
  });

  test('calcule correctement un libellé à J+2', () {
    expect(
      TideEventTimeline.dayDifference(
        referenceCivilTime: DateTime(2026, 10, 6, 23, 50),
        eventCivilTime: DateTime(2026, 10, 8, 0, 20),
      ),
      2,
    );
  });

  test('conserve J+1 pendant le changement d’heure du téléphone', () {
    expect(
      TideEventTimeline.dayDifference(
        referenceCivilTime: DateTime(2026, 3, 22, 0, 30),
        eventCivilTime: DateTime(2026, 3, 23, 0, 30),
      ),
      1,
    );
  });
}
