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
  });
}

/// Données de marées complètes pour affichage, enrichies avec données astronomiques
class TideData {
  final List<TidePoint> hourlyPoints;
  final double low; // Marée basse (minimum)
  final double high; // Marée haute (maximum)
  final double next; // Prochaine hauteur prévue
  final double waveHeight; // Hauteur significative des vagues (m)
  final String location;
  final DateTime? generatedAt;
  final AstroData astro; // Phase lune, coef, activité, transit...

  const TideData({
    required this.hourlyPoints,
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
