import 'dart:math' as math;

/// Convertit une direction météorologique (origine du vent) en angle visuel
/// de déplacement (direction vers laquelle le vent souffle).
///
/// Open-Meteo publie 0° pour un vent venant du nord. L'icône Material
/// `navigation_rounded` pointe initialement vers le nord ; une rotation
/// de 180° est donc nécessaire pour adopter la convention visuelle utilisée
/// par les cartes de vent et par Windfinder.
double windFlowAngleRadians(double meteorologicalDirectionDegrees) {
  final normalized = ((meteorologicalDirectionDegrees + 180) % 360 + 360) % 360;
  return normalized * math.pi / 180;
}
