// ============================================================
//  tide_data.dart — Modèle de données de marées
// ============================================================

import '../services/astronomy_service.dart';

/// Représente un point de données de marée (heure + hauteur)
class TidePoint {
  final DateTime time;
  final double height; // en mètres
  final double windDirectionDeg; // degrés météo (direction d'où vient le vent)
  final double wavePeriod; // secondes
  final double windWaveHeight; // mètres
  final double? temperatureC;
  final double? windSpeedKmh;
  final double? pressureHpa;
  final double? precipitationProbabilityPct;
  final double? relativeHumidityPct;
  final double? windGustKmh;
  final double? visibilityKm;
  final double? cloudCoverPct;
  final double? precipitationMm;
  final double? swellHeightM;
  final double? swellPeriodS;
  final double? swellDirectionDeg;
  final double? secondarySwellHeightM;
  final double? secondarySwellPeriodS;
  final double? secondarySwellDirectionDeg;
  final double? seaSurfaceTemperatureC;
  final double? oceanCurrentSpeedKmh;
  final double? oceanCurrentDirectionDeg;

  const TidePoint({
    required this.time,
    required this.height,
    this.windDirectionDeg = 0.0,
    this.wavePeriod = 7.0,
    this.windWaveHeight = 0.0,
    this.temperatureC,
    this.windSpeedKmh,
    this.pressureHpa,
    this.precipitationProbabilityPct,
    this.relativeHumidityPct,
    this.windGustKmh,
    this.visibilityKm,
    this.cloudCoverPct,
    this.precipitationMm,
    this.swellHeightM,
    this.swellPeriodS,
    this.swellDirectionDeg,
    this.secondarySwellHeightM,
    this.secondarySwellPeriodS,
    this.secondarySwellDirectionDeg,
    this.seaSurfaceTemperatureC,
    this.oceanCurrentSpeedKmh,
    this.oceanCurrentDirectionDeg,
  });
}

/// Prévision météo/marine légère à trois heures, destinée uniquement au
/// tableau vertical de la page Marées. Elle est publiée dans le même document
/// Firestore que les marées afin de ne pas ajouter de lecture côté mobile.
class HourlyForecastPoint {
  final DateTime time;
  final double? windSpeedKmh;
  final double? windGustKmh;
  final double? windDirectionDeg;
  final int? weatherCode;
  final bool? isDay;
  final double? temperatureC;
  final double? pressureHpa;
  final double? waveHeightM;
  final double? wavePeriodS;
  final double? waveDirectionDeg;
  final double? precipitationProbabilityPct;
  final double? cloudCoverPct;
  final int? activityScore;

  const HourlyForecastPoint({
    required this.time,
    this.windSpeedKmh,
    this.windGustKmh,
    this.windDirectionDeg,
    this.weatherCode,
    this.isDay,
    this.temperatureC,
    this.pressureHpa,
    this.waveHeightM,
    this.wavePeriodS,
    this.waveDirectionDeg,
    this.precipitationProbabilityPct,
    this.cloudCoverPct,
    this.activityScore,
  });
}

/// Données de marées complètes pour affichage, enrichies avec données astronomiques
class TideData {
  final List<TidePoint> hourlyPoints;
  final List<HourlyForecastPoint> hourlyForecast;
  final double low; // Marée basse (minimum)
  final double high; // Marée haute (maximum)
  final double next; // Prochaine hauteur prévue
  final double waveHeight; // Hauteur significative des vagues (m)
  final String location;
  final DateTime? generatedAt;
  final AstroData astro; // Phase lune, coef, activité, transit...

  const TideData({
    required this.hourlyPoints,
    this.hourlyForecast = const [],
    required this.low,
    required this.high,
    required this.next,
    required this.waveHeight,
    required this.location,
    this.generatedAt,
    required this.astro,
  });

  /// Valeurs par défaut quand l'API échoue
  factory TideData.fallback({String location = 'Casablanca Morocco'}) {
    return TideData(
      hourlyPoints: const [],
      hourlyForecast: const [],
      low: 0.0,
      high: 0.0,
      next: 0.0,
      waveHeight: 0.0,
      location: location,
      generatedAt: null,
      astro: AstroData.fallback(),
    );
  }
}
