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

/// Convertit la direction d'origine de la houle publiée par Open-Meteo vers
/// son sens de propagation visuel. La convention est identique à celle du
/// vent : une houle annoncée à 330° se propage vers 150°.
double waveFlowAngleRadians(double meteorologicalDirectionDegrees) {
  return windFlowAngleRadians(meteorologicalDirectionDegrees);
}
