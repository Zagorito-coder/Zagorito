import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// A finite-safe variant of flutter_map 8.3.1's [MarkerLayer].
///
/// It keeps the same projection cache and world-wrapping behavior, but rejects
/// invalid intermediate geometry and puts a calculated upper bound on wrapped
/// marker copies. This prevents the unbounded loop tracked upstream in
/// flutter_map issue #2219.
class FiniteMarkerLayer extends StatefulWidget {
  final List<Marker> markers;
  final Alignment alignment;
  final bool rotate;

  const FiniteMarkerLayer({
    super.key,
    required this.markers,
    this.alignment = Alignment.center,
    this.rotate = false,
  });

  @override
  State<FiniteMarkerLayer> createState() => _FiniteMarkerLayerState();
}

class _FiniteMarkerLayerState extends State<FiniteMarkerLayer> {
  List<Offset?>? _projectedPoints;
  Crs? _projectionCrs;

  static bool _isFiniteOffset(Offset point) =>
      point.dx.isFinite && point.dy.isFinite;

  static bool _isFiniteRect(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;

  @override
  void didUpdateWidget(FiniteMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _projectedPoints = null;
  }

  List<Offset?> _projectPoints(Crs crs) => List<Offset?>.generate(
        widget.markers.length,
        (index) {
          final point = widget.markers[index].point;
          if (!point.latitude.isFinite || !point.longitude.isFinite) {
            return null;
          }
          final projected = crs.projection.project(point);
          return _isFiniteOffset(projected) ? projected : null;
        },
        growable: false,
      );

  @override
  Widget build(BuildContext context) {
    final map = MapCamera.of(context);
    final crs = map.crs;

    if (!map.zoom.isFinite ||
        !map.center.latitude.isFinite ||
        !map.center.longitude.isFinite ||
        !map.rotationRad.isFinite) {
      return const SizedBox.shrink();
    }

    if (_projectedPoints == null || _projectionCrs != crs) {
      _projectionCrs = crs;
      _projectedPoints = _projectPoints(crs);
    }

    final worldWidth = map.getWorldWidthAtZoom();
    final zoomScale = crs.scale(map.zoom);
    final pixelBounds = map.pixelBounds;
    final pixelOrigin = map.pixelOrigin;

    if (!zoomScale.isFinite ||
        !_isFiniteRect(pixelBounds) ||
        !_isFiniteOffset(pixelOrigin)) {
      return const SizedBox.shrink();
    }

    // At the configured minZoom (2 or greater), only a few adjacent worlds
    // can intersect the viewport. The calculated limit preserves those copies
    // while making an accidental non-terminating loop impossible.
    final maxWorldCopies = worldWidth.isFinite && worldWidth > 0
        ? (pixelBounds.width / worldWidth).ceil().clamp(1, 16) + 2
        : 0;
    final positioned = <Widget>[];

    for (var i = 0; i < widget.markers.length; i++) {
      final marker = widget.markers[i];
      final projected = _projectedPoints![i];
      if (projected == null ||
          !marker.width.isFinite ||
          !marker.height.isFinite ||
          marker.width < 0 ||
          marker.height < 0) {
        continue;
      }

      final (px, py) = crs.transform(
        projected.dx,
        projected.dy,
        zoomScale,
      );
      final pixelPoint = Offset(px, py);
      if (!_isFiniteOffset(pixelPoint)) continue;

      final alignment = marker.alignment ?? widget.alignment;
      final left = 0.5 * marker.width * (alignment.x + 1);
      final top = 0.5 * marker.height * (alignment.y + 1);
      final right = marker.width - left;
      final bottom = marker.height - top;

      Positioned? positionAt(double worldShift) {
        if (!worldShift.isFinite) return null;
        final shiftedX = pixelPoint.dx + worldShift;
        if (!shiftedX.isFinite) return null;

        final markerBounds = Rect.fromPoints(
          Offset(shiftedX + left, pixelPoint.dy - bottom),
          Offset(shiftedX - right, pixelPoint.dy + top),
        );
        if (!_isFiniteRect(markerBounds) ||
            !pixelBounds.overlaps(markerBounds)) {
          return null;
        }

        final localPoint = Offset(shiftedX, pixelPoint.dy) - pixelOrigin;
        if (!_isFiniteOffset(localPoint)) return null;

        return Positioned(
          key: marker.key,
          width: marker.width,
          height: marker.height,
          left: localPoint.dx - right,
          top: localPoint.dy - bottom,
          child: (marker.rotate ?? widget.rotate)
              ? Transform.rotate(
                  angle: -map.rotationRad,
                  alignment: alignment * -1,
                  child: marker.child,
                )
              : marker.child,
        );
      }

      final main = positionAt(0);
      if (main != null) positioned.add(main);

      if (maxWorldCopies == 0) continue;
      for (var copy = 1; copy <= maxWorldCopies; copy++) {
        final west = positionAt(-worldWidth * copy);
        if (west == null) break;
        positioned.add(west);
      }
      for (var copy = 1; copy <= maxWorldCopies; copy++) {
        final east = positionAt(worldWidth * copy);
        if (east == null) break;
        positioned.add(east);
      }
    }

    return MobileLayerTransformer(child: Stack(children: positioned));
  }
}
