import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/services/local_tide_coefficient_service.dart';
import 'package:spots_app/services/tide_coefficient_service.dart';
import 'package:spots_app/utils/station_time_zone.dart';

void main() {
  test('calcule les indices depuis les seuls marnages de la station', () {
    final points = _fixedDays(
      DateTime(2026, 10, 8),
      const [1.0, 2.0, 1.5, 0.5, 1.25, 1.75, 0.8, 1.6],
    );

    final period = LocalTideCoefficientService.build(points)!;

    expect(period.source, TideCoefficientSource.localForecast);
    expect(period.days, hasLength(8));
    expect(period.days[0].localIndex, 60);
    expect(period.days[1].localIndex, 120);
    expect(period.days[3].localIndex, 30);
    expect(
      period.days.every(
        (day) => day.localIndex >= 20 && day.localIndex <= 120,
      ),
      isTrue,
    );
  });

  test('un décalage vertical ne change ni le marnage ni les indices', () {
    final raw = _fixedDays(
      DateTime(2026, 10, 8),
      const [0.8, 1.4, 1.8, 1.2, 0.6, 1.0, 1.5, 2.0],
    );
    final shifted = raw
        .map(
          (point) => TidePoint(
            time: point.time,
            instantUtc: point.instantUtc,
            height: point.height + 3.2,
          ),
        )
        .toList(growable: false);

    final first = LocalTideCoefficientService.build(raw)!;
    final second = LocalTideCoefficientService.build(shifted)!;

    expect(
      second.days.map((day) => day.localIndex),
      orderedEquals(first.days.map((day) => day.localIndex)),
    );
    for (var index = 0; index < first.days.length; index++) {
      expect(
        second.days[index].tidalRangeMeters,
        closeTo(first.days[index].tidalRangeMeters, 1e-10),
      );
    }
  });

  test('la période reste ordonnée lorsqu’elle traverse deux mois', () {
    final period = LocalTideCoefficientService.build(
      _fixedDays(
        DateTime(2026, 10, 29),
        const [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7],
      ),
    )!;

    expect(period.days.first.date, DateTime(2026, 10, 29));
    expect(period.days.last.date, DateTime(2026, 11, 5));
    expect(period.day(1).date, DateTime(2026, 10, 29));
    expect(period.day(8).date, DateTime(2026, 11, 5));
  });

  test('accepte les journées DST de 23 et 25 heures', () {
    const zone = 'Europe/Paris';
    final spring = _zonedDay(DateTime(2026, 3, 29), zone);
    final autumn = _zonedDay(DateTime(2026, 10, 25), zone);
    final companionSpring = _zonedDay(DateTime(2026, 3, 30), zone);
    final companionAutumn = _zonedDay(DateTime(2026, 10, 26), zone);

    final springPeriod = LocalTideCoefficientService.build(
      [...spring, ...companionSpring],
      timeZoneId: zone,
    )!;
    final autumnPeriod = LocalTideCoefficientService.build(
      [...autumn, ...companionAutumn],
      timeZoneId: zone,
    )!;

    expect(springPeriod.days.first.samples, hasLength(23));
    expect(autumnPeriod.days.first.samples, hasLength(25));
    final repeatedTwoOClock = autumnPeriod.days.first.samples
        .where((sample) => sample.time.hour == 2)
        .toList(growable: false);
    expect(repeatedTwoOClock, hasLength(2));
    expect(
      autumnPeriod.days.first.curveProgress(
        repeatedTwoOClock.first.instantUtc,
      ),
      lessThan(
        autumnPeriod.days.first.curveProgress(
          repeatedTwoOClock.last.instantUtc,
        ),
      ),
    );
  });

  test('écarte uniquement les bords civils partiels d’une grille UTC', () {
    const zone = 'Africa/El_Aaiun';
    final startUtc = DateTime.utc(2026, 10, 7);
    final points = List<TidePoint>.generate(8 * 24, (index) {
      final instant = startUtc.add(Duration(hours: index));
      return TidePoint(
        time: StationTimeZone.civilAt(instant, timeZoneId: zone),
        instantUtc: instant,
        height: 2 + math.cos(2 * math.pi * index / 12.42),
      );
    }, growable: false);

    final period = LocalTideCoefficientService.build(
      points,
      timeZoneId: zone,
      utcOffsetSeconds: 3600,
    )!;

    expect(period.days, hasLength(7));
    expect(period.days.first.date, DateTime(2026, 10, 8));
    expect(period.days.last.date, DateTime(2026, 10, 14));
    expect(period.days.every((day) => day.samples.length == 24), isTrue);
  });

  test('rejette une journée normale trouée au lieu de fabriquer un indice', () {
    final full = _fixedDays(
      DateTime(2026, 10, 8),
      const [1.0, 1.5],
    );
    final missingHour = full
        .where(
          (point) => point.time.day != 8 || point.time.hour != 11,
        )
        .toList(growable: false);

    expect(LocalTideCoefficientService.build(missingHour), isNull);
  });

  test('rejette une journée trouée au milieu de journées complètes', () {
    final points = _fixedDays(
      DateTime(2026, 10, 8),
      const [1.0, 1.2, 1.4],
    ).where(
      (point) => point.time.day != 9 || point.time.hour != 11,
    );

    expect(LocalTideCoefficientService.build(points), isNull);
  });

  test('rejette une fenêtre dont les journées complètes ne sont pas contiguës',
      () {
    final points = _fixedDays(
      DateTime(2026, 10, 8),
      const [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7],
    ).where((point) => point.time.day != 11);

    expect(LocalTideCoefficientService.build(points), isNull);
  });

  test('conserve les vrais minimum et maximum parmi les quatre repères', () {
    final points = _fixedDays(
      DateTime(2026, 10, 8),
      const [2.0, 1.5],
    ).map((point) {
      if (point.time.day != 8) return point;
      final height = switch (point.time.hour) {
        0 => 5.0,
        6 => 1.0,
        11 => 2.0,
        12 => 4.0,
        13 => 2.0,
        18 => 0.5,
        _ => point.height,
      };
      return TidePoint(
        time: point.time,
        instantUtc: point.instantUtc,
        height: height,
      );
    });

    final day = LocalTideCoefficientService.build(points)!.days.first;
    expect(day.extrema, hasLength(4));
    expect(
      day.extrema.any(
        (extremum) => extremum.isHigh && extremum.height == day.highMeters,
      ),
      isTrue,
    );
    expect(
      day.extrema.any(
        (extremum) => !extremum.isHigh && extremum.height == day.lowMeters,
      ),
      isTrue,
    );
  });

  test('gère un fuseau fixe fractionnaire sans instant UTC publié', () {
    final localPoints = _fixedDays(
      DateTime(2026, 10, 8),
      const [1.0, 1.5],
    )
        .map(
          (point) => TidePoint(time: point.time, height: point.height),
        )
        .toList(growable: false);

    final period = LocalTideCoefficientService.build(
      localPoints,
      utcOffsetSeconds: 5 * 3600 + 30 * 60,
    )!;

    expect(period.days, hasLength(2));
    expect(
      period.days.first.samples.first.instantUtc,
      DateTime.utc(2026, 10, 7, 18, 30),
    );
  });

  test('rejette un retour DST auquel il manque une heure répétée', () {
    const zone = 'Europe/Paris';
    final autumn = _zonedDay(DateTime(2026, 10, 25), zone);
    final companion = _zonedDay(DateTime(2026, 10, 26), zone);
    final repeated =
        autumn.where((point) => point.time.hour == 2).toList(growable: false);
    expect(repeated, hasLength(2));
    final missingRepeatedInstant = repeated.last.instantUtc;

    expect(
      LocalTideCoefficientService.build(
        [
          ...autumn.where(
            (point) => point.instantUtc != missingRepeatedInstant,
          ),
          ...companion,
        ],
        timeZoneId: zone,
      ),
      isNull,
    );
  });
}

List<TidePoint> _fixedDays(DateTime start, List<double> ranges) {
  return [
    for (var day = 0; day < ranges.length; day++)
      for (var hour = 0; hour < 24; hour++)
        TidePoint(
          time: DateTime(
            start.year,
            start.month,
            start.day + day,
            hour,
          ),
          instantUtc: DateTime.utc(
            start.year,
            start.month,
            start.day + day,
            hour,
          ),
          height: 2 + ranges[day] * (1 + math.cos(2 * math.pi * hour / 24)) / 2,
        ),
  ];
}

List<TidePoint> _zonedDay(DateTime date, String timeZoneId) {
  final start = StationTimeZone.instantAt(date, timeZoneId: timeZoneId);
  final end = StationTimeZone.instantAt(
    DateTime(date.year, date.month, date.day + 1),
    timeZoneId: timeZoneId,
  );
  final hours = end.difference(start).inHours;
  return List<TidePoint>.generate(hours, (index) {
    final instant = start.add(Duration(hours: index));
    return TidePoint(
      time: StationTimeZone.civilAt(instant, timeZoneId: timeZoneId),
      instantUtc: instant,
      height: 1 + math.cos(2 * math.pi * index / math.max(1, hours)),
    );
  }, growable: false);
}
