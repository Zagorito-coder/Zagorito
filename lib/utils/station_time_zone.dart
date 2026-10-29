import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// Conversions d'horaires de station indépendantes du fuseau du téléphone.
///
/// Les documents récents publient un identifiant IANA (`Africa/Casablanca`,
/// par exemple). Le décalage fixe reste accepté pour lire les documents déjà
/// présents dans Firestore et pour assurer la compatibilité avec la version
/// 1.0.9 (24).
class StationTimeZone {
  const StationTimeZone._();

  static bool _initialized = false;
  static const String _casablanca = 'Africa/Casablanca';
  static final DateTime _moroccoPermanentUtcStart =
      DateTime.utc(2026, 9, 20, 1);
  static final DateTime _moroccoFirstUnambiguousUtcCivilTime =
      DateTime(2026, 9, 20, 2);

  static bool _usesMoroccoPermanentUtc(String? timeZoneId, DateTime instant) =>
      timeZoneId?.trim() == _casablanca &&
      !instant.toUtc().isBefore(_moroccoPermanentUtcStart);

  static timezone.Location? _location(String? timeZoneId) {
    final name = timeZoneId?.trim();
    if (name == null || name.isEmpty) return null;
    if (!_initialized) {
      timezone_data.initializeTimeZones();
      _initialized = true;
    }
    try {
      return timezone.getLocation(name);
    } on timezone.LocationNotFoundException {
      return null;
    }
  }

  static DateTime civilAt(
    DateTime instant, {
    String? timeZoneId,
    int? fallbackOffsetSeconds,
  }) {
    if (_usesMoroccoPermanentUtc(timeZoneId, instant)) {
      final utc = instant.toUtc();
      return DateTime(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second,
        utc.millisecond,
        utc.microsecond,
      );
    }
    final location = _location(timeZoneId);
    if (location != null) {
      final zoned = timezone.TZDateTime.from(instant.toUtc(), location);
      return DateTime(
        zoned.year,
        zoned.month,
        zoned.day,
        zoned.hour,
        zoned.minute,
        zoned.second,
        zoned.millisecond,
        zoned.microsecond,
      );
    }

    final offset = fallbackOffsetSeconds;
    if (offset == null) return instant.toLocal();
    final shifted = instant.toUtc().add(Duration(seconds: offset));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static DateTime instantAt(
    DateTime civilTime, {
    String? timeZoneId,
    int? fallbackOffsetSeconds,
  }) {
    if (timeZoneId?.trim() == _casablanca &&
        !civilTime.isBefore(_moroccoFirstUnambiguousUtcCivilTime)) {
      return DateTime.utc(
        civilTime.year,
        civilTime.month,
        civilTime.day,
        civilTime.hour,
        civilTime.minute,
        civilTime.second,
        civilTime.millisecond,
        civilTime.microsecond,
      );
    }
    final location = _location(timeZoneId);
    if (location != null) {
      return timezone.TZDateTime(
        location,
        civilTime.year,
        civilTime.month,
        civilTime.day,
        civilTime.hour,
        civilTime.minute,
        civilTime.second,
        civilTime.millisecond,
        civilTime.microsecond,
      ).toUtc();
    }

    final offset = fallbackOffsetSeconds;
    if (offset == null) return civilTime.toUtc();
    return DateTime.utc(
      civilTime.year,
      civilTime.month,
      civilTime.day,
      civilTime.hour,
      civilTime.minute,
      civilTime.second,
      civilTime.millisecond,
      civilTime.microsecond,
    ).subtract(Duration(seconds: offset));
  }

  static int offsetSecondsAt(
    DateTime instant, {
    String? timeZoneId,
    int? fallbackOffsetSeconds,
  }) {
    if (_usesMoroccoPermanentUtc(timeZoneId, instant)) return 0;
    final location = _location(timeZoneId);
    if (location != null) {
      return timezone.TZDateTime.from(instant.toUtc(), location)
          .timeZoneOffset
          .inSeconds;
    }
    return fallbackOffsetSeconds ?? instant.toLocal().timeZoneOffset.inSeconds;
  }
}
