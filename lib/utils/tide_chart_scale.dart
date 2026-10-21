import 'dart:math' as math;

/// Échelle verticale d'une courbe de niveau marin.
///
/// Casablanca utilise une référence hydrographique locale de 0 à 5 m. Les
/// autres stations suivent la même fenêtre de présentation tant que leur
/// marnage y tient ; l'axe s'étend automatiquement au lieu d'écrêter une marée
/// supérieure à 5 m.
class TideChartScale {
  const TideChartScale({
    required this.min,
    required this.max,
    required this.tickCount,
  });

  factory TideChartScale.forValues(
    Iterable<double> values, {
    required bool fixedChartDatumScale,
    required bool usesMeanSeaLevelDatum,
  }) {
    final finiteValues = values.where((value) => value.isFinite).toList();
    if (finiteValues.isEmpty) {
      return fixedChartDatumScale
          ? const TideChartScale(min: 0, max: 5, tickCount: 5)
          : const TideChartScale(min: 0, max: 1, tickCount: 4);
    }

    final minimum = finiteValues.reduce(math.min);
    final maximum = finiteValues.reduce(math.max);
    if (fixedChartDatumScale) {
      final upperBound = math.max(5.0, maximum).ceilToDouble();
      return TideChartScale(
        min: math.min(0.0, minimum).floorToDouble(),
        max: upperBound,
        tickCount: upperBound <= 5 ? 5 : upperBound.round(),
      );
    }
    final dataRange = (maximum - minimum).clamp(0.02, 100.0).toDouble();
    final paddedMinimum = minimum - dataRange * 0.1;
    final paddedMaximum = maximum + dataRange * 0.1;

    if (usesMeanSeaLevelDatum) {
      // Une échelle symétrique place toujours 0 NMM au centre. Elle évite un
      // axe visuellement trompeur lorsque les niveaux passent de part et
      // d'autre de la référence, et reste stable si toute la journée se situe
      // temporairement au-dessus ou au-dessous du NMM.
      final extent = math
          .max(paddedMinimum.abs(), paddedMaximum.abs())
          .clamp(0.1, 100.0)
          .toDouble();
      return TideChartScale(min: -extent, max: extent, tickCount: 4);
    }

    return TideChartScale(
      min: paddedMinimum,
      max: paddedMaximum,
      tickCount: 4,
    );
  }

  final double min;
  final double max;
  final int tickCount;

  double get range => max - min;
  double get tickStep => range / tickCount;

  double tickAt(int index) => min + range * index / tickCount;

  bool contains(double value) => value >= min && value <= max;
}
