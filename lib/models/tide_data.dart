// ============================================================
//  tide_data.dart — Modèle de données de marées
// ============================================================

import '../services/astronomy_service.dart';

/// Représente un point de données de marée (heure + hauteur)
class TidePoint {
  final DateTime time;
  final double height; // en mètres

  const TidePoint({required this.time, required this.height});
}

/// Données de marées complètes pour affichage, enrichies avec données astronomiques
class TideData {
  final List<TidePoint> hourlyPoints;
  final double low;      // Marée basse (minimum)
  final double high;     // Marée haute (maximum)
  final double next;     // Prochaine hauteur prévue
  final double waveHeight; // Hauteur significative des vagues (m)
  final String location;
  final AstroData astro; // Phase lune, coef, activité, transit...

  const TideData({
    required this.hourlyPoints,
    required this.low,
    required this.high,
    required this.next,
    required this.waveHeight,
    required this.location,
    required this.astro,
  });

  /// Valeurs par défaut quand l'API échoue
  factory TideData.fallback() {
    return TideData(
      hourlyPoints: const [],
      low: 0.4,
      high: 3.9,
      next: 2.1,
      waveHeight: 1.2,
      location: 'Casablanca Morocco',
      astro: AstroData.fallback(),
    );
  }
}
