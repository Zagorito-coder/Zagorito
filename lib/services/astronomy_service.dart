// ============================================================
//  astronomy_service.dart — Calculs astronomiques pour pêcheurs
//  Phase lunaire, transit solunaire, coefficient, activité
// ============================================================

import 'dart:math' as math;

/// Données astronomiques pour une journée de pêche
class AstroData {
  final double moonPhase;       // 0.0 = nouvelle, 0.5 = pleine, 1.0 = nouvelle
  final String moonPhaseName;   // "Nouvelle Lune", "Pleine Lune"...
  final double coefficient;     // 20 - 120
  final double fishActivity;    // 0.0 - 1.0
  final String activityLabel;   // "Excellente", "Bonne", "Moyenne", "Faible"
  final String moonRise;
  final String moonSet;
  final String sunRise;
  final String sunSet;
  final String lunarTransit;    // Lune au méridien (major)
  final String lunarUnder;      // Lune au nadir (minor)

  const AstroData({
    required this.moonPhase,
    required this.moonPhaseName,
    required this.coefficient,
    required this.fishActivity,
    required this.activityLabel,
    required this.moonRise,
    required this.moonSet,
    required this.sunRise,
    required this.sunSet,
    required this.lunarTransit,
    required this.lunarUnder,
  });

  factory AstroData.fallback() {
    return const AstroData(
      moonPhase: 0.25,
      moonPhaseName: 'Premier Quartier',
      coefficient: 72,
      fishActivity: 0.65,
      activityLabel: 'Bonne',
      moonRise: '14:32',
      moonSet: '03:15',
      sunRise: '06:45',
      sunSet: '20:12',
      lunarTransit: '21:18',
      lunarUnder: '09:42',
    );
  }
}

class AstronomyService {
  // Référence : nouvelle lune connue (6 jan 2000, 18:14 UTC)
  static final _knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
  static const double _synodicMonthDays = 29.5305882;

  /// Calcule toutes les données astronomiques pour une date
  static AstroData calculate(DateTime date, double tideLow, double tideHigh) {
    final localDate = DateTime(date.year, date.month, date.day);

    // ── Phase lunaire ──
    final phase = _moonPhase(localDate);
    final phaseName = _moonPhaseName(phase);

    // ── Coefficient (basé sur l'amplitude relative) ──
    // Amplitude max théorique pour la côte marocaine ~3.8m
    final amplitude = (tideHigh - tideLow).clamp(0.1, 10.0);
    final coeff = ((amplitude / 3.8) * 120).clamp(20.0, 120.0);

    // ── Lever/coucher Soleil & Lune (approximatifs) ──
    final sunTimes = _sunTimes(localDate);
    final moonTimes = _moonTimes(localDate, phase);

    // ── Transit solunaire (Major / Minor) ──
    final transit = _lunarTransit(localDate);
    final under = _lunarUnder(localDate);

    // ── Activité de poisson ──
    final activity = _fishActivityScore(
      coeff: coeff,
      phase: phase,
      now: date,
      transit: transit,
      under: under,
    );

    return AstroData(
      moonPhase: phase,
      moonPhaseName: phaseName,
      coefficient: coeff,
      fishActivity: activity.score,
      activityLabel: activity.label,
      moonRise: moonTimes.rise,
      moonSet: moonTimes.set_,
      sunRise: sunTimes.rise,
      sunSet: sunTimes.set_,
      lunarTransit: transit,
      lunarUnder: under,
    );
  }

  // ─────────────────────────────────────────────
  //  PHASE LUNAIRE
  // ─────────────────────────────────────────────
  static double _moonPhase(DateTime date) {
    final diff = date.difference(_knownNewMoon).inMinutes;
    const synodicMinutes = _synodicMonthDays * 24 * 60;
    final age = (diff % synodicMinutes) / synodicMinutes;
    return age < 0 ? age + 1.0 : age;
  }

  static String _moonPhaseName(double phase) {
    if (phase < 0.03 || phase > 0.97) return 'Nouvelle Lune';
    if (phase < 0.22) return 'Croissante';
    if (phase < 0.28) return 'Premier Quartier';
    if (phase < 0.47) return 'Gibbeuse Croissante';
    if (phase < 0.53) return 'Pleine Lune';
    if (phase < 0.72) return 'Gibbeuse Décroissante';
    if (phase < 0.78) return 'Dernier Quartier';
    return 'Décroissante';
  }

  // ─────────────────────────────────────────────
  //  LEVER / COUCHER (approximatifs)
  // ─────────────────────────────────────────────
  static ({String rise, String set_}) _sunTimes(DateTime date) {
    // Approximation : lever ~6h + décalage saisonnier
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final declination = 23.45 * math.sin(2 * math.pi * (284 + dayOfYear) / 365);
    const latRad = 33.57 * math.pi / 180; // Casablanca
    final hourAngle = math.acos(-math.tan(latRad) * math.tan(declination * math.pi / 180));
    final sunriseMin = (12 * 60 - (hourAngle * 180 / math.pi / 15) * 60).round();
    final sunsetMin = (12 * 60 + (hourAngle * 180 / math.pi / 15) * 60).round();

    return (
      rise: _formatTime(sunriseMin),
      set_: _formatTime(sunsetMin),
    );
  }

  static ({String rise, String set_}) _moonTimes(DateTime date, double phase) {
    // La lune se lève ~50 min plus tard chaque jour
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    const baseMoonrise = 12 * 60; // ~midi UTC pour la nouvelle lune
    const delayPerDay = 50; // minutes
    final moonriseMin = (baseMoonrise + dayOfYear * delayPerDay + phase * 24 * 60) % (24 * 60);
    final moonsetMin = (moonriseMin + 12 * 60) % (24 * 60);

    return (
      rise: _formatTime(moonriseMin.round()),
      set_: _formatTime(moonsetMin.round()),
    );
  }

  // ─────────────────────────────────────────────
  //  TRANSIT SOLUNAIRE
  // ─────────────────────────────────────────────
  static String _lunarTransit(DateTime date) {
    // Transit lunaire (major) ~ retardé de 50 min/jour
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    const baseTransit = 12 * 60 + 30; // ~12h30 le 1er jan
    final transitMin = (baseTransit + dayOfYear * 50) % (24 * 60);
    return _formatTime(transitMin.round());
  }

  static String _lunarUnder(DateTime date) {
    // Lune au nadir (minor) = transit + 12h15
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    const baseTransit = 12 * 60 + 30;
    final transitMin = (baseTransit + dayOfYear * 50) % (24 * 60);
    final underMin = (transitMin + 12 * 60 + 15) % (24 * 60);
    return _formatTime(underMin.round());
  }

  // ─────────────────────────────────────────────
  //  ACTIVITÉ DE POISSON
  // ─────────────────────────────────────────────
  static ({double score, String label}) _fishActivityScore({
    required double coeff,
    required double phase,
    required DateTime now,
    required String transit,
    required String under,
  }) {
    double score = 0.0;

    // 1. Coefficient de marée (40%)
    score += (coeff / 120) * 0.40;

    // 2. Phase lunaire — pleine/nouvelle = meilleure (30%)
    final phaseScore = 1.0 - (phase - 0.5).abs() * 2; // 1.0 à pleine, 0.0 au quartier
    score += phaseScore * 0.30;

    // 3. Proximité avec un transit solunaire (30%)
    final nowMin = now.hour * 60 + now.minute;
    final transitMin = _parseTime(transit);
    final underMin = _parseTime(under);
    final transitDist = math.min(
      (nowMin - transitMin).abs(),
      (nowMin - underMin).abs(),
    );
    final transitScore = (1.0 - (transitDist / (12 * 60)).clamp(0.0, 1.0));
    score += transitScore * 0.30;

    score = score.clamp(0.0, 1.0);

    String label;
    if (score >= 0.75) {
      label = 'Excellente';
    } else if (score >= 0.55) {
      label = 'Bonne';
    } else if (score >= 0.35) {
      label = 'Moyenne';
    } else {
      label = 'Faible';
    }

    return (score: score, label: label);
  }

  // ─────────────────────────────────────────────
  //  UTILITAIRES
  // ─────────────────────────────────────────────
  static String _formatTime(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
