import '../models/tide_data.dart';

/// Extrême détecté dans une série de hauteurs marines ordonnée.
class DetectedTideExtremum {
  const DetectedTideExtremum({
    required this.time,
    required this.instantUtc,
    required this.height,
    required this.isHigh,
  });

  final DateTime time;
  final DateTime instantUtc;
  final double height;
  final bool isHigh;
}

/// Détecte les hautes et basses mers sans inventer d'extrême aux bornes.
///
/// Les prévisions horaires peuvent contenir deux valeurs identiques autour du
/// retournement. Une comparaison stricte point par point ignore alors
/// l'extrême. Ce service regroupe ces plateaux et place l'événement au milieu
/// de leurs instants absolus.
class TideExtremaService {
  const TideExtremaService._();

  // Les plateaux des prévisions horaires sont des répétitions réellement
  // quantifiées (par exemple -0,57 m deux heures de suite). Une tolérance
  // millimétrique regrouperait à tort les points voisins d'une courbe
  // harmonique continue et ferait disparaître ses extrema.
  static const double _heightEqualityToleranceMeters = 1e-9;

  static List<DetectedTideExtremum> detect(
    Iterable<TidePoint> source, {
    required DateTime Function(TidePoint point) instantOf,
    required DateTime Function(DateTime instant) civilAt,
  }) {
    final points = source
        .where((point) => point.height.isFinite)
        .map(
          (point) => _TimedTidePoint(
            point: point,
            instantUtc: instantOf(point).toUtc(),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.instantUtc.compareTo(b.instantUtc));
    if (points.length < 3) return const [];

    final extrema = <DetectedTideExtremum>[];
    var groupStart = 0;
    while (groupStart < points.length) {
      var groupEnd = groupStart;
      final referenceHeight = points[groupStart].point.height;
      while (groupEnd + 1 < points.length &&
          (points[groupEnd + 1].point.height - referenceHeight).abs() <=
              _heightEqualityToleranceMeters) {
        groupEnd++;
      }

      if (groupStart > 0 && groupEnd < points.length - 1) {
        final group = points.sublist(groupStart, groupEnd + 1);
        final height =
            group.map((entry) => entry.point.height).reduce((a, b) => a + b) /
                group.length;
        final previousHeight = points[groupStart - 1].point.height;
        final nextHeight = points[groupEnd + 1].point.height;
        final isHigh = height > previousHeight && height > nextHeight;
        final isLow = height < previousHeight && height < nextHeight;
        if (isHigh || isLow) {
          final firstMicros = group.first.instantUtc.microsecondsSinceEpoch;
          final lastMicros = group.last.instantUtc.microsecondsSinceEpoch;
          final instant = DateTime.fromMicrosecondsSinceEpoch(
            firstMicros + (lastMicros - firstMicros) ~/ 2,
            isUtc: true,
          );
          extrema.add(
            DetectedTideExtremum(
              time: civilAt(instant),
              instantUtc: instant,
              height: height,
              isHigh: isHigh,
            ),
          );
        }
      }
      groupStart = groupEnd + 1;
    }
    return List.unmodifiable(extrema);
  }
}

class _TimedTidePoint {
  const _TimedTidePoint({
    required this.point,
    required this.instantUtc,
  });

  final TidePoint point;
  final DateTime instantUtc;
}
