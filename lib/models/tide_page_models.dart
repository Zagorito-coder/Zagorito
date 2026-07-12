// ============================================================
//  tide_page_models.dart — Modèles de données pour la page Marées
// ============================================================

class HourlyCard {
  final int hour;
  final String label;
  final double tideHeight;
  final String tideTrend;
  final int activityScore;
  final String activityLevel; // "high" | "mid" | "low"
  final String activityLabel;
  final int windSpeed;
  final String windDirection;
  final double waveHeight;
  final int temp;
  final bool isIdeal;
  final bool isNow;

  const HourlyCard({
    required this.hour,
    required this.label,
    required this.tideHeight,
    required this.tideTrend,
    required this.activityScore,
    required this.activityLevel,
    required this.activityLabel,
    required this.windSpeed,
    required this.windDirection,
    required this.waveHeight,
    required this.temp,
    this.isIdeal = false,
    this.isNow = false,
  });
}

class TideEvent {
  final String type; // "high" | "low"
  final double time; // heure décimale ex: 6.5 = 06h30
  final double height;
  final String label;

  const TideEvent({
    required this.type,
    required this.time,
    required this.height,
    required this.label,
  });
}

class TidePoint {
  final double time; // 0-24
  final double height;

  const TidePoint({required this.time, required this.height});
}

class MoonInfo {
  final String phaseName;
  final String influence;

  const MoonInfo({required this.phaseName, required this.influence});
}

class SunTimes {
  final String sunrise;
  final String sunset;
  final String goldenHour;

  const SunTimes({
    required this.sunrise,
    required this.sunset,
    required this.goldenHour,
  });
}

class WaveInfo {
  final double height;
  final int period;
  final String swell;

  const WaveInfo({
    required this.height,
    required this.period,
    required this.swell,
  });
}

class WindInfo {
  final int speed;
  final String direction;
  final int gust;

  const WindInfo({
    required this.speed,
    required this.direction,
    required this.gust,
  });
}

class TideData {
  final String location;
  final List<HourlyCard> hourlyCards;
  final List<TidePoint> tidePoints;
  final List<TideEvent> tideEvents;
  final int currentHour;
  final MoonInfo moonInfo;
  final SunTimes sunTimes;
  final int overallScore;
  final String overallLevel;
  final String overallLabel;
  final List<String> bestHours;
  final WaveInfo waveInfo;
  final WindInfo windInfo;

  const TideData({
    required this.location,
    required this.hourlyCards,
    required this.tidePoints,
    required this.tideEvents,
    required this.currentHour,
    required this.moonInfo,
    required this.sunTimes,
    required this.overallScore,
    required this.overallLevel,
    required this.overallLabel,
    required this.bestHours,
    required this.waveInfo,
    required this.windInfo,
  });
}
