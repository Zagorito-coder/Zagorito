import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/utils/station_time_zone.dart';

void main() {
  const casablanca = 'Africa/Casablanca';

  test('Casablanca reste à GMT après le 20 septembre 2026', () {
    final instant = DateTime.utc(2026, 10, 5, 12, 30);

    expect(
      StationTimeZone.civilAt(instant, timeZoneId: casablanca),
      DateTime(2026, 10, 5, 12, 30),
    );
    expect(
      StationTimeZone.instantAt(
        DateTime(2026, 10, 5, 12, 30),
        timeZoneId: casablanca,
      ),
      instant,
    );
    expect(
      StationTimeZone.offsetSecondsAt(instant, timeZoneId: casablanca),
      0,
    );
  });

  test('le retour définitif à GMT conserve les deux occurrences de 01h30', () {
    expect(
      StationTimeZone.civilAt(
        DateTime.utc(2026, 9, 20, 0, 30),
        timeZoneId: casablanca,
      ),
      DateTime(2026, 9, 20, 1, 30),
    );
    expect(
      StationTimeZone.civilAt(
        DateTime.utc(2026, 9, 20, 1, 30),
        timeZoneId: casablanca,
      ),
      DateTime(2026, 9, 20, 1, 30),
    );
  });

  test('la suspension Ramadan 2026 reste à UTC', () {
    final instant = DateTime.utc(2026, 2, 20, 12);

    expect(
      StationTimeZone.civilAt(instant, timeZoneId: casablanca),
      DateTime(2026, 2, 20, 12),
    );
    expect(
      StationTimeZone.offsetSecondsAt(instant, timeZoneId: casablanca),
      0,
    );
  });
}
