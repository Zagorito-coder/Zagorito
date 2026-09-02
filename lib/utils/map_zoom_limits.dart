/// Limites de zoom de la carte principale BoosterFish.
///
/// La sélection d'un spot reste volontairement moins détaillée afin de limiter
/// le nombre de tuiles chargées pendant le déplacement de caméra. Le niveau le
/// plus détaillé est réservé à une action explicite de l'utilisateur.
abstract final class MapZoomLimits {
  static const double minimum = 3.0;
  // Un rayon de 30 km reste visible sur un téléphone sans charger les tuiles
  // détaillées utilisées pour la fiche d'un spot individuel.
  static const double automaticCitySearch = 9.5;
  static const double automaticSpotSelection = 16.0;
  // La source satellite gratuite actuelle fournit, sur les zones côtières
  // contrôlées, ses derniers vrais détails au niveau 18. Le zoom manuel peut
  // néanmoins agrandir cette tuile jusqu'à 20 sans requêter les niveaux
  // indisponibles, ce qui évite les tuiles blanches ou grises.
  static const double manualMaximum = 20.0;

  static double clampManual(double zoom) =>
      zoom.clamp(minimum, manualMaximum).toDouble();
}
