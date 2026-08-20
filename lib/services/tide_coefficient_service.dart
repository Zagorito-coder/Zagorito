import 'dart:math' as math;

import 'casablanca_tide_reference.dart';

/// Une hauteur harmonique utilisée par la courbe journalière compacte.
class LocalTideSample {
  const LocalTideSample({required this.time, required this.height});

  final DateTime time;
  final double height;
}

/// Un extremum (haute ou basse mer) issu du moteur harmonique local.
class LocalTideExtremum {
  const LocalTideExtremum({
    required this.time,
    required this.height,
    required this.isHigh,
  });

  final DateTime time;
  final double height;
  final bool isHigh;
}

/// Données scientifiques d'une journée civile à Casablanca.
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
}

class LocalTideCoefficientMonth {
  const LocalTideCoefficientMonth({
    required this.month,
    required this.days,
  });

  final DateTime month;
  final List<LocalTideCoefficientDay> days;

  LocalTideCoefficientDay day(int dayOfMonth) =>
      days[(dayOfMonth - 1).clamp(0, days.length - 1)];
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

  static LocalTideCoefficientMonth buildCasablancaMonth(DateTime input) {
    final month = DateTime(input.year, input.month);
    final dayCount = DateTime(input.year, input.month + 1, 0).day;
    final days = List<LocalTideCoefficientDay>.generate(
      dayCount,
      (index) => _buildDay(DateTime(input.year, input.month, index + 1)),
      growable: false,
    );
    return LocalTideCoefficientMonth(month: month, days: days);
  }

  /// Construit une seule journée pour les tableaux horaires. Cette entrée
  /// évite de calculer un mois entier lorsqu'une vue n'a besoin que des dix
  /// jours de prévision affichés.
  static LocalTideCoefficientDay buildCasablancaDay(DateTime input) {
    return _buildDay(DateTime(input.year, input.month, input.day));
  }

  static LocalTideCoefficientDay _buildDay(DateTime date) {
    const precisionMinutes = 5;
    const curveMinutes = 30;
    final precision = <LocalTideSample>[];
    final curve = <LocalTideSample>[];

    for (var minute = 0; minute <= 24 * 60; minute += precisionMinutes) {
      final time = date.add(Duration(minutes: minute));
      final sample = LocalTideSample(
        time: time,
        height: CasablancaTideReference.heightAtUtc(time.toUtc()),
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
        previous.time,
        next.time,
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
    DateTime start,
    DateTime end, {
    required bool findHigh,
  }) {
    var bestTime = start;
    var bestHeight = CasablancaTideReference.heightAtUtc(start.toUtc());
    final duration = end.difference(start).inMinutes;
    for (var minute = 1; minute <= duration; minute++) {
      final time = start.add(Duration(minutes: minute));
      final height = CasablancaTideReference.heightAtUtc(time.toUtc());
      final isBetter = findHigh ? height > bestHeight : height < bestHeight;
      if (isBetter) {
        bestTime = time;
        bestHeight = height;
      }
    }
    return LocalTideExtremum(
      time: bestTime,
      height: bestHeight,
      isHigh: findHigh,
    );
  }

  static int localIndexForRange(double tidalRangeMeters) {
    final normalized = tidalRangeMeters / _referenceTidalRangeMeters;
    return (normalized * 120).clamp(20.0, 120.0).round();
  }
}

/// Point d'entrée top-level compatible avec `compute` de Flutter.
LocalTideCoefficientMonth buildCasablancaTideCoefficientMonth(
  DateTime month,
) =>
    TideCoefficientService.buildCasablancaMonth(month);
