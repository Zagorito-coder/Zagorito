import 'dart:math' as math;

import '../utils/station_time_zone.dart';
import 'casablanca_tide_reference.dart';

/// Une hauteur utilisée par la courbe journalière compacte.
class LocalTideSample {
  const LocalTideSample({
    required this.time,
    required this.instantUtc,
    required this.height,
  });

  final DateTime time;
  final DateTime instantUtc;
  final double height;
}

/// Un extremum (haute ou basse mer) de la station affichée.
class LocalTideExtremum {
  const LocalTideExtremum({
    required this.time,
    required this.instantUtc,
    required this.height,
    required this.isHigh,
  });

  final DateTime time;
  final DateTime instantUtc;
  final double height;
  final bool isHigh;
}

/// Origine des valeurs présentées dans le volet Coefficients.
enum TideCoefficientSource {
  /// Prédiction harmonique mensuelle du marégraphe Casablanca/JRC.
  casablancaHarmonic,

  /// Indice relatif construit depuis les jours civils complets Open-Meteo de
  /// la station.
  localForecast,
}

/// Données d'une journée civile présentées dans le volet Coefficients.
class LocalTideCoefficientDay {
  const LocalTideCoefficientDay({
    required this.date,
    required this.lowMeters,
    required this.highMeters,
    required this.localIndex,
    required this.samples,
    required this.extrema,
  });

  final DateTime date;
  final double lowMeters;
  final double highMeters;
  final int localIndex;
  final List<LocalTideSample> samples;
  final List<LocalTideExtremum> extrema;

  double get tidalRangeMeters => highMeters - lowMeters;

  /// Premier instant réellement représenté par la courbe quotidienne.
  DateTime get curveStartInstant => samples.isEmpty
      ? DateTime.utc(date.year, date.month, date.day)
      : samples.first.instantUtc;

  /// Fin réelle de la journée représentée.
  ///
  /// Casablanca fournit explicitement l'échantillon de minuit suivant. Les
  /// prévisions horaires Open-Meteo s'arrêtent à 23 h : on ajoute alors leur
  /// pas réel. Cette distinction conserve une chronologie juste pendant les
  /// journées DST de 23 ou 25 heures.
  DateTime get curveEndInstant {
    if (samples.isEmpty) {
      return curveStartInstant.add(const Duration(hours: 24));
    }
    final last = samples.last;
    final lastIsNextCivilDay = last.time.year != date.year ||
        last.time.month != date.month ||
        last.time.day != date.day;
    if (lastIsNextCivilDay) return last.instantUtc;
    final step = samples.length < 2
        ? const Duration(hours: 1)
        : samples.last.instantUtc.difference(
            samples[samples.length - 2].instantUtc,
          );
    return last.instantUtc.add(
      step > Duration.zero ? step : const Duration(hours: 1),
    );
  }

  /// Position chronologique d'un instant sur la journée, entre 0 et 1.
  /// L'heure civile n'est volontairement pas utilisée : elle se répète lors
  /// du passage à l'heure d'hiver.
  double curveProgress(DateTime instantUtc) {
    final start = curveStartInstant;
    final duration = curveEndInstant.difference(start).inMicroseconds;
    if (duration <= 0) return 0;
    return (instantUtc.toUtc().difference(start.toUtc()).inMicroseconds /
            duration)
        .clamp(0.0, 1.0);
  }
}

class LocalTideCoefficientMonth {
  const LocalTideCoefficientMonth({
    required this.month,
    required this.days,
    this.source = TideCoefficientSource.casablancaHarmonic,
    this.showMoroccanTradition = true,
  });

  final DateTime month;
  final List<LocalTideCoefficientDay> days;
  final TideCoefficientSource source;
  final bool showMoroccanTradition;

  /// [selection] est un index 1-based dans la période affichée. Pour le mois
  /// complet de Casablanca il correspond aussi au numéro du jour. Pour une
  /// prévision locale de huit jours, il reste correct lors d'un changement de
  /// mois (par exemple du 29 octobre au 5 novembre).
  LocalTideCoefficientDay day(int selection) =>
      days[(selection - 1).clamp(0, days.length - 1)];

  bool get isCasablancaHarmonic =>
      source == TideCoefficientSource.casablancaHarmonic;
}

enum MoroccanTidePeriod {
  alKsour,
  elMaSghir,
  alQamrayer,
  alHamz,
  elMaLkbir,
}

/// Lecture culturelle marocaine, volontairement indépendante de l'indice
/// harmonique local. Elle ne modifie jamais une hauteur ou un coefficient.
class MoroccanTideTradition {
  const MoroccanTideTradition({
    required this.lunarDay,
    required this.period,
    required this.activityScore,
  });

  final int lunarDay;
  final MoroccanTidePeriod period;
  final int activityScore;

  static MoroccanTideTradition forDate(DateTime date) {
    return forLunarDay(_tabularHijriDay(date));
  }

  static MoroccanTideTradition forLunarDay(int lunarDay) {
    if (lunarDay < 1 || lunarDay > 30) {
      throw RangeError.range(lunarDay, 1, 30, 'lunarDay');
    }
    final halfMonthDay = lunarDay > 15 ? lunarDay - 15 : lunarDay;
    if (halfMonthDay <= 3) {
      return MoroccanTideTradition(
        lunarDay: lunarDay,
        period: MoroccanTidePeriod.alKsour,
        activityScore: 2,
      );
    }
    if (halfMonthDay <= 6) {
      return MoroccanTideTradition(
        lunarDay: lunarDay,
        period: MoroccanTidePeriod.elMaSghir,
        activityScore: 2,
      );
    }
    if (halfMonthDay <= 9) {
      return MoroccanTideTradition(
        lunarDay: lunarDay,
        period: MoroccanTidePeriod.alQamrayer,
        activityScore: 3,
      );
    }
    if (halfMonthDay <= 12) {
      return MoroccanTideTradition(
        lunarDay: lunarDay,
        period: MoroccanTidePeriod.alHamz,
        activityScore: 5,
      );
    }
    return MoroccanTideTradition(
      lunarDay: lunarDay,
      period: MoroccanTidePeriod.elMaLkbir,
      activityScore: 4,
    );
  }

  /// Conversion grégorienne vers le calendrier hégirien civil/tabulaire.
  /// La date religieuse officielle marocaine, fondée sur l'observation, peut
  /// différer d'un jour ; cette limite est explicitée dans l'interface.
  static int _tabularHijriDay(DateTime input) {
    final date = DateTime.utc(input.year, input.month, input.day, 12);
    var year = date.year;
    var month = date.month;
    final day = date.day;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = year ~/ 100;
    final b = 2 - a + (a ~/ 4);
    final julianDay = (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;

    var l = julianDay - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final hijriMonth = (24 * l) ~/ 709;
    return l - (709 * hijriMonth) ~/ 24;
  }
}

/// Construit l'indice local BoosterFish à partir des seules hauteurs du modèle
/// harmonique Casablanca/JRC. Aucun appel réseau n'est effectué.
class TideCoefficientService {
  const TideCoefficientService._();

  // Marnage stationnel de référence de Casablanca : 4,10 m - 0,30 m.
  //
  // L'ancienne formule soustrayait artificiellement 1 m avant la conversion.
  // Elle écrasait donc toutes les petites marées au plancher 20 (par exemple
  // autour du 21–22 août 2026), alors qu'un marnage proche de 1 m correspond à
  // un indice voisin de 30. La conversion est désormais proportionnelle au
  // marnage harmonique réellement calculé, sur une échelle locale 0–120.
  //
  // Cet indice reste un indice local BoosterFish, distinct d'un coefficient
  // officiel SHOM calculé sur le port de référence de Brest.
  static const double _referenceTidalRangeMeters = 3.8;

  static LocalTideCoefficientMonth buildCasablancaMonth(
    DateTime input, {
    int? utcOffsetSeconds,
    String? timeZoneId,
  }) {
    final month = DateTime(input.year, input.month);
    final dayCount = DateTime(input.year, input.month + 1, 0).day;
    final days = List<LocalTideCoefficientDay>.generate(
      dayCount,
      (index) => _buildDay(
        DateTime(input.year, input.month, index + 1),
        utcOffsetSeconds,
        timeZoneId,
      ),
      growable: false,
    );
    return LocalTideCoefficientMonth(month: month, days: days);
  }

  /// Construit une seule journée pour les tableaux horaires. Cette entrée
  /// évite de calculer un mois entier lorsqu'une vue n'a besoin que des dix
  /// jours de prévision affichés.
  static LocalTideCoefficientDay buildCasablancaDay(
    DateTime input, {
    int? utcOffsetSeconds,
    String? timeZoneId,
  }) {
    return _buildDay(
      DateTime(input.year, input.month, input.day),
      utcOffsetSeconds,
      timeZoneId,
    );
  }

  static LocalTideCoefficientDay _buildDay(
    DateTime date,
    int? utcOffsetSeconds,
    String? timeZoneId,
  ) {
    const precisionMinutes = 5;
    const curveMinutes = 30;
    final precision = <LocalTideSample>[];
    final curve = <LocalTideSample>[];

    final startInstant = _stationInstantAt(
      date,
      utcOffsetSeconds,
      timeZoneId,
    );
    final endInstant = _stationInstantAt(
      DateTime(date.year, date.month, date.day + 1),
      utcOffsetSeconds,
      timeZoneId,
    );
    final actualMinutes = endInstant.difference(startInstant).inMinutes;
    for (var minute = 0; minute <= actualMinutes; minute += precisionMinutes) {
      final instant = startInstant.add(Duration(minutes: minute));
      final time = StationTimeZone.civilAt(
        instant,
        timeZoneId: timeZoneId,
        fallbackOffsetSeconds: utcOffsetSeconds,
      );
      final sample = LocalTideSample(
        time: time,
        instantUtc: instant,
        height: CasablancaTideReference.heightAtUtc(instant),
      );
      precision.add(sample);
      if (minute % curveMinutes == 0) curve.add(sample);
    }

    final extrema = <LocalTideExtremum>[];
    for (var i = 1; i < precision.length - 1; i++) {
      final previous = precision[i - 1];
      final current = precision[i];
      final next = precision[i + 1];
      final isHigh =
          current.height >= previous.height && current.height > next.height;
      final isLow =
          current.height <= previous.height && current.height < next.height;
      if (!isHigh && !isLow) continue;
      final refined = _refineExtremum(
        previous.instantUtc,
        next.instantUtc,
        utcOffsetSeconds: utcOffsetSeconds,
        timeZoneId: timeZoneId,
        findHigh: isHigh,
      );
      extrema.add(refined);
    }

    final heights = precision.map((sample) => sample.height);
    final low = heights.reduce(math.min);
    final high = heights.reduce(math.max);
    return LocalTideCoefficientDay(
      date: date,
      lowMeters: low,
      highMeters: high,
      localIndex: localIndexForRange(high - low),
      samples: List.unmodifiable(curve),
      extrema: List.unmodifiable(extrema),
    );
  }

  static LocalTideExtremum _refineExtremum(
    DateTime startInstant,
    DateTime endInstant, {
    int? utcOffsetSeconds,
    String? timeZoneId,
    required bool findHigh,
  }) {
    var bestInstant = startInstant;
    var bestHeight = CasablancaTideReference.heightAtUtc(bestInstant);
    final duration = endInstant.difference(startInstant).inMinutes;
    for (var minute = 1; minute <= duration; minute++) {
      final instant = startInstant.add(Duration(minutes: minute));
      final height = CasablancaTideReference.heightAtUtc(instant);
      final isBetter = findHigh ? height > bestHeight : height < bestHeight;
      if (isBetter) {
        bestInstant = instant;
        bestHeight = height;
      }
    }
    return LocalTideExtremum(
      time: StationTimeZone.civilAt(
        bestInstant,
        timeZoneId: timeZoneId,
        fallbackOffsetSeconds: utcOffsetSeconds,
      ),
      instantUtc: bestInstant,
      height: bestHeight,
      isHigh: findHigh,
    );
  }

  static DateTime _stationInstantAt(
    DateTime civilTime,
    int? offsetSeconds,
    String? timeZoneId,
  ) =>
      StationTimeZone.instantAt(
        civilTime,
        timeZoneId: timeZoneId,
        fallbackOffsetSeconds: offsetSeconds,
      );

  static int localIndexForRange(double tidalRangeMeters) {
    final normalized = tidalRangeMeters / _referenceTidalRangeMeters;
    return (normalized * 120).clamp(20.0, 120.0).round();
  }
}

/// Point d'entrée top-level compatible avec `compute` de Flutter.
LocalTideCoefficientMonth buildCasablancaTideCoefficientMonth(
  Map<String, dynamic> request,
) {
  final year = request['year'];
  final month = request['month'];
  if (year == null || month == null) {
    throw const FormatException('Mois de coefficients invalide.');
  }
  return TideCoefficientService.buildCasablancaMonth(
    DateTime(year, month),
    utcOffsetSeconds: request['utcOffsetSeconds'],
    timeZoneId: request['timeZoneId'],
  );
}
