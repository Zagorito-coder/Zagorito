import 'dart:math' as math;

import '../models/tide_data.dart' as source;
import '../utils/station_time_zone.dart';
import 'tide_coefficient_service.dart';

/// Construit le volet Coefficients mondial depuis les hauteurs horaires déjà
/// publiées pour la station sélectionnée.
///
/// Aucun appel réseau n'est effectué et aucune valeur Casablanca n'est
/// réutilisée. L'indice 20–120 est relatif au plus fort marnage de la fenêtre
/// locale disponible : il facilite la comparaison des jours civils complets,
/// mais ne constitue pas un coefficient officiel SHOM.
class LocalTideCoefficientService {
  const LocalTideCoefficientService._();

  static LocalTideCoefficientMonth? build(
    Iterable<source.TidePoint> sourcePoints, {
    int? utcOffsetSeconds,
    String? timeZoneId,
    bool showMoroccanTradition = false,
  }) {
    final grouped = <DateTime, List<source.TidePoint>>{};
    for (final point in sourcePoints) {
      if (!point.height.isFinite) continue;
      final date = DateTime(point.time.year, point.time.month, point.time.day);
      grouped.putIfAbsent(date, () => <source.TidePoint>[]).add(point);
    }

    final orderedEntries = grouped.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final candidates = orderedEntries
        .map(
          (entry) => _completeDay(
            entry.key,
            entry.value,
            utcOffsetSeconds: utcOffsetSeconds,
            timeZoneId: timeZoneId,
          ),
        )
        .toList(growable: false);
    final firstCompleteIndex = candidates.indexWhere((day) => day != null);
    final lastCompleteIndex = candidates.lastIndexWhere((day) => day != null);
    if (firstCompleteIndex < 0 || lastCompleteIndex < 0) return null;

    // Les séries serveur sont alignées en UTC. Dans un fuseau non UTC, elles
    // commencent et finissent donc naturellement par une journée civile
    // partielle (Laâyoune reçoit par exemple 23 h, puis 7 jours complets, puis
    // le minuit suivant). Seuls ces deux bords sont écartés. Une journée
    // incomplète entre deux journées valides reste une rupture bloquante :
    // aucune heure manquante n'est inventée ou masquée dans la période rendue.
    final completeDays = <_CompleteLocalDay>[];
    for (var index = firstCompleteIndex; index <= lastCompleteIndex; index++) {
      final complete = candidates[index];
      if (complete == null) return null;
      completeDays.add(complete);
    }
    if (completeDays.length < 2) return null;
    for (var index = 1; index < completeDays.length; index++) {
      final expected = DateTime(
        completeDays[index - 1].date.year,
        completeDays[index - 1].date.month,
        completeDays[index - 1].date.day + 1,
      );
      if (completeDays[index].date != expected) return null;
    }

    final referenceRange = completeDays
        .map((day) => day.high.height - day.low.height)
        .fold<double>(0, math.max);
    if (!referenceRange.isFinite || referenceRange <= 0) return null;

    final days = completeDays.map((day) {
      final range = day.high.height - day.low.height;
      final index = ((range / referenceRange) * 120).clamp(20.0, 120.0).round();
      return LocalTideCoefficientDay(
        date: day.date,
        lowMeters: day.low.height,
        highMeters: day.high.height,
        localIndex: index,
        samples: List.unmodifiable(
          day.points.map(
            (point) => LocalTideSample(
              time: point.time,
              instantUtc: _instantOf(
                point,
                utcOffsetSeconds: utcOffsetSeconds,
                timeZoneId: timeZoneId,
              ),
              height: point.height,
            ),
          ),
        ),
        extrema: List.unmodifiable(
          _extrema(
            day,
            utcOffsetSeconds: utcOffsetSeconds,
            timeZoneId: timeZoneId,
          ),
        ),
      );
    }).toList(growable: false);

    return LocalTideCoefficientMonth(
      month: DateTime(days.first.date.year, days.first.date.month),
      days: List.unmodifiable(days),
      source: TideCoefficientSource.localForecast,
      showMoroccanTradition: showMoroccanTradition,
    );
  }

  static _CompleteLocalDay? _completeDay(
    DateTime date,
    List<source.TidePoint> rawPoints, {
    int? utcOffsetSeconds,
    String? timeZoneId,
  }) {
    final start = StationTimeZone.instantAt(
      date,
      timeZoneId: timeZoneId,
      fallbackOffsetSeconds: utcOffsetSeconds,
    );
    final end = StationTimeZone.instantAt(
      DateTime(date.year, date.month, date.day + 1),
      timeZoneId: timeZoneId,
      fallbackOffsetSeconds: utcOffsetSeconds,
    );
    final expectedHours = end.difference(start).inHours;
    if (expectedHours < 23 || expectedHours > 25) return null;

    final byInstant = <int, source.TidePoint>{};
    for (final point in rawPoints) {
      final instant = _instantOf(
        point,
        utcOffsetSeconds: utcOffsetSeconds,
        timeZoneId: timeZoneId,
      );
      byInstant.putIfAbsent(instant.millisecondsSinceEpoch, () => point);
    }
    if (byInstant.length != expectedHours) return null;

    final points = byInstant.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    if (points.first.key != start.millisecondsSinceEpoch ||
        points.last.key !=
            end.subtract(const Duration(hours: 1)).millisecondsSinceEpoch) {
      return null;
    }
    for (var index = 1; index < points.length; index++) {
      if (points[index].key - points[index - 1].key !=
          const Duration(hours: 1).inMilliseconds) {
        return null;
      }
    }

    final ordered = points.map((entry) => entry.value).toList(growable: false);
    var low = ordered.first;
    var high = ordered.first;
    for (final point in ordered.skip(1)) {
      if (point.height < low.height) low = point;
      if (point.height > high.height) high = point;
    }
    if (high.height <= low.height) return null;
    return _CompleteLocalDay(
      date: date,
      points: ordered,
      low: low,
      high: high,
    );
  }

  static List<LocalTideExtremum> _extrema(
    _CompleteLocalDay day, {
    int? utcOffsetSeconds,
    String? timeZoneId,
  }) {
    final result = <LocalTideExtremum>[];
    for (var index = 1; index < day.points.length - 1; index++) {
      final previous = day.points[index - 1];
      final current = day.points[index];
      final next = day.points[index + 1];
      final isHigh =
          current.height >= previous.height && current.height > next.height;
      final isLow =
          current.height <= previous.height && current.height < next.height;
      if (!isHigh && !isLow) continue;
      result.add(
        _toExtremum(
          current,
          isHigh: isHigh,
          utcOffsetSeconds: utcOffsetSeconds,
          timeZoneId: timeZoneId,
        ),
      );
    }

    // Le minimum et le maximum journaliers doivent toujours faire partie des
    // repères affichés. Sans cela, un pic secondaire intérieur pouvait masquer
    // le vrai maximum situé à minuit. On conserve ensuite au plus deux hautes
    // et deux basses mers, comme le volet Casablanca, afin d'éviter le
    // chevauchement des étiquettes.
    void addIfMissing(LocalTideExtremum extremum) {
      if (result.any(
        (candidate) =>
            candidate.instantUtc.isAtSameMomentAs(extremum.instantUtc) &&
            candidate.isHigh == extremum.isHigh,
      )) {
        return;
      }
      result.add(extremum);
    }

    addIfMissing(
      _toExtremum(
        day.high,
        isHigh: true,
        utcOffsetSeconds: utcOffsetSeconds,
        timeZoneId: timeZoneId,
      ),
    );
    addIfMissing(
      _toExtremum(
        day.low,
        isHigh: false,
        utcOffsetSeconds: utcOffsetSeconds,
        timeZoneId: timeZoneId,
      ),
    );

    final highs = result.where((extremum) => extremum.isHigh).toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    final lows = result.where((extremum) => !extremum.isHigh).toList()
      ..sort((a, b) => a.height.compareTo(b.height));
    final selected = <LocalTideExtremum>[
      ...highs.take(2),
      ...lows.take(2),
    ]..sort((a, b) => a.instantUtc.compareTo(b.instantUtc));
    return selected;
  }

  static LocalTideExtremum _toExtremum(
    source.TidePoint point, {
    required bool isHigh,
    int? utcOffsetSeconds,
    String? timeZoneId,
  }) {
    final instant = _instantOf(
      point,
      utcOffsetSeconds: utcOffsetSeconds,
      timeZoneId: timeZoneId,
    );
    return LocalTideExtremum(
      time: point.time,
      instantUtc: instant,
      height: point.height,
      isHigh: isHigh,
    );
  }

  static DateTime _instantOf(
    source.TidePoint point, {
    int? utcOffsetSeconds,
    String? timeZoneId,
  }) =>
      point.instantUtc ??
      StationTimeZone.instantAt(
        point.time,
        timeZoneId: timeZoneId,
        fallbackOffsetSeconds: utcOffsetSeconds,
      );
}

class _CompleteLocalDay {
  const _CompleteLocalDay({
    required this.date,
    required this.points,
    required this.low,
    required this.high,
  });

  final DateTime date;
  final List<source.TidePoint> points;
  final source.TidePoint low;
  final source.TidePoint high;
}
