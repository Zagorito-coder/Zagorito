import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/models.dart';

@visibleForTesting
const double spotNameMinimumZoom = 14.0;

@visibleForTesting
const int maximumVisibleSpotNames = 60;

@visibleForTesting
bool shouldPaintSpotNames(
  double zoom, {
  bool hasSelectedSpot = false,
}) =>
    zoom >= spotNameMinimumZoom && !hasSelectedSpot;

@visibleForTesting
Rect? findSpotNameLabelRect({
  required Offset markerPosition,
  required double markerRadius,
  required Size labelSize,
  required Rect viewport,
  required List<Rect> occupiedLabels,
  required List<Offset> markerPositions,
  required int markerIndex,
}) {
  const markerGap = 5.0;
  const collisionGap = 2.0;
  const markerClearance = 8.0;
  final horizontalOffset = markerRadius + markerGap;
  final verticalOffset = markerRadius + markerGap;
  final candidates = <Rect>[
    Rect.fromLTWH(
      markerPosition.dx + horizontalOffset,
      markerPosition.dy - labelSize.height / 2,
      labelSize.width,
      labelSize.height,
    ),
    Rect.fromLTWH(
      markerPosition.dx - horizontalOffset - labelSize.width,
      markerPosition.dy - labelSize.height / 2,
      labelSize.width,
      labelSize.height,
    ),
    Rect.fromLTWH(
      markerPosition.dx - labelSize.width / 2,
      markerPosition.dy - verticalOffset - labelSize.height,
      labelSize.width,
      labelSize.height,
    ),
    Rect.fromLTWH(
      markerPosition.dx - labelSize.width / 2,
      markerPosition.dy + verticalOffset,
      labelSize.width,
      labelSize.height,
    ),
  ];

  for (final candidate in candidates) {
    if (!viewport.contains(candidate.topLeft) ||
        !viewport.contains(candidate.bottomRight)) {
      continue;
    }

    final collisionRect = candidate.inflate(collisionGap);
    if (occupiedLabels.any(collisionRect.overlaps)) continue;

    var overlapsAnotherMarker = false;
    for (var i = 0; i < markerPositions.length; i++) {
      if (i == markerIndex) continue;
      if (collisionRect.inflate(markerClearance).contains(markerPositions[i])) {
        overlapsAnotherMarker = true;
        break;
      }
    }
    if (!overlapsAnotherMarker) return candidate;
  }

  return null;
}

class _MapRepaintNotifier extends ChangeNotifier {
  void repaint() => notifyListeners();
}

class SpotsCanvasLayer extends StatefulWidget {
  final List<Spot> visibleSpots;
  final MapController mapController;
  final Spot? selectedSpot;
  final Function(Spot) onSpotTap;
  final Function(LatLng)? onMapTap;

  const SpotsCanvasLayer({
    super.key,
    required this.visibleSpots,
    required this.mapController,
    this.selectedSpot,
    required this.onSpotTap,
    this.onMapTap,
  });

  @override
  State<SpotsCanvasLayer> createState() => _SpotsCanvasLayerState();
}

class _SpotsCanvasLayerState extends State<SpotsCanvasLayer> {
  StreamSubscription? _mapEventSubscription;
  final _MapRepaintNotifier _repaintNotifier = _MapRepaintNotifier();
  int? _pointerId;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  static const double _tapSlop = 18.0;

  @override
  void initState() {
    super.initState();
    _mapEventSubscription = widget.mapController.mapEventStream.listen((_) {
      if (mounted) _repaintNotifier.repaint();
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // Track only one pointer. Multi-touch remains entirely managed by
    // flutter_map's scale recognizer.
    if (_pointerId != null) return;
    _pointerId = event.pointer;
    _pointerDownPosition = event.localPosition;
    _pointerMoved = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointerId || _pointerDownPosition == null) return;
    if ((event.localPosition - _pointerDownPosition!).distance > _tapSlop) {
      _pointerMoved = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointerId || _pointerDownPosition == null) return;
    final wasTap = !_pointerMoved &&
        (event.localPosition - _pointerDownPosition!).distance <= _tapSlop;
    if (wasTap) _handleTap(event.localPosition);
    _resetPointer();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointerId) _resetPointer();
  }

  void _resetPointer() {
    _pointerId = null;
    _pointerDownPosition = null;
    _pointerMoved = false;
  }

  void _handleTap(Offset localOffset) {
    final MapCamera camera;
    try {
      camera = widget.mapController.camera;
    } catch (_) {
      return;
    }

    Spot? closest;
    var minDistance = 24.0;
    for (final spot in widget.visibleSpots) {
      final point = camera.latLngToScreenOffset(spot.location);
      final distance = (localOffset - Offset(point.dx, point.dy)).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closest = spot;
      }
    }
    if (closest != null) {
      widget.onSpotTap(closest);
    } else if (widget.onMapTap != null) {
      // Keep map-tap features (for example distance measurement) while
      // allowing flutter_map to receive the same pointer sequence for
      // double-tap-drag zoom.
      widget.onMapTap!(camera.screenOffsetToLatLng(localOffset));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: CustomPaint(
          painter: _SpotsPainter(
            visibleSpots: widget.visibleSpots,
            mapController: widget.mapController,
            selectedSpot: widget.selectedSpot,
            repaint: _repaintNotifier,
          ),
        ),
      ),
    );
  }
}

class _SpotsPainter extends CustomPainter {
  static const double _labelHorizontalPadding = 6.0;
  static const double _labelVerticalPadding = 3.0;
  static const double _maximumTextWidth = 144.0;

  final List<Spot> visibleSpots;
  final MapController mapController;
  final Spot? selectedSpot;
  final Map<String, TextPainter> _labelPainters = <String, TextPainter>{};

  _SpotsPainter({
    required this.visibleSpots,
    required this.mapController,
    this.selectedSpot,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final MapCamera camera;
    try {
      camera = mapController.camera;
    } catch (_) {
      return;
    }
    final cameraBounds = camera.visibleBounds;
    final canvasBounds = (Offset.zero & size).inflate(12);

    // Reuse Paint instances for the whole frame. Allocating and configuring
    // four Paints for every spot creates significant garbage at wide zooms.
    final shadowPaint = Paint()..style = PaintingStyle.fill;
    final mainPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()..style = PaintingStyle.stroke;
    final highlightPaint = Paint()..style = PaintingStyle.fill;
    final borderColor = Colors.white.withValues(alpha: 0.92);
    final highlightColor = Colors.white.withValues(alpha: 0.55);
    final paintedMarkers = <_PaintedSpot>[];

    for (final spot in visibleSpots) {
      // visibleSpots is deliberately refreshed only after an 80 ms debounce.
      // During a continuous pinch it can therefore still describe the old,
      // much wider viewport. Cull against the live camera before doing any
      // paint work so obsolete markers cannot saturate the UI thread.
      if (!cameraBounds.contains(spot.location)) continue;

      final point = camera.latLngToScreenOffset(spot.location);
      final pos = Offset(point.dx, point.dy);
      if (!canvasBounds.contains(pos)) continue;

      final isSelected = spot == selectedSpot;
      final radius = isSelected ? 11.0 : 6.0;
      final baseColor = spot.type.color;
      paintedMarkers.add(
        _PaintedSpot(
          spot: spot,
          position: pos,
          radius: radius,
          isSelected: isSelected,
        ),
      );

      // Ombre portée douce (neumorphique)
      // A blurred shadow for every marker is disproportionately expensive on
      // mobile GPUs. Keep the blur for the single selected marker only and use
      // a cheap translucent offset circle for the normal marker set.
      shadowPaint
        ..color = baseColor.withValues(alpha: isSelected ? 0.4 : 0.22)
        ..maskFilter =
            isSelected ? const MaskFilter.blur(BlurStyle.normal, 5) : null;
      canvas.drawCircle(pos.translate(0, 1.5), radius, shadowPaint);

      // Cercle principal avec couleur unie (simplifié pour compatibilité GPU)
      mainPaint.color = baseColor.withValues(alpha: 0.9);
      canvas.drawCircle(pos, radius, mainPaint);

      // Bordure nette blanche (glassmorphique)
      borderPaint
        ..color = borderColor
        ..strokeWidth = isSelected ? 2.2 : 1.3;
      canvas.drawCircle(pos, radius, borderPaint);

      // Reflet highlight en haut à gauche (effet liquide)
      if (!isSelected) {
        highlightPaint
          ..color = highlightColor
          ..maskFilter = null;
        canvas.drawCircle(
          Offset(pos.dx - radius * 0.35, pos.dy - radius * 0.35),
          radius * 0.28,
          highlightPaint,
        );
      }
    }

    if (!shouldPaintSpotNames(
          camera.zoom,
          hasSelectedSpot: selectedSpot != null,
        ) ||
        paintedMarkers.isEmpty) {
      return;
    }

    _paintSpotNames(canvas, size, paintedMarkers);
  }

  void _paintSpotNames(
    Canvas canvas,
    Size size,
    List<_PaintedSpot> paintedMarkers,
  ) {
    // Keep labels out of the permanent right-side controls and the lower
    // search/ad/navigation area. The proportional fallback preserves enough
    // map space on small landscape displays.
    final proportionalRightInset = size.width * 0.20;
    final rightInset =
        proportionalRightInset < 64.0 ? proportionalRightInset : 64.0;
    final proportionalBottomInset = size.height * 0.30;
    final bottomInset =
        proportionalBottomInset < 210.0 ? proportionalBottomInset : 210.0;
    final viewport = Rect.fromLTRB(
      4,
      4,
      size.width - rightInset,
      size.height - bottomInset,
    );
    if (viewport.isEmpty) return;

    final viewportCenter = viewport.center;
    final markerPositions = paintedMarkers
        .map((paintedSpot) => paintedSpot.position)
        .toList(growable: false);
    final priorityOrder = List<int>.generate(
      paintedMarkers.length,
      (index) => index,
      growable: false,
    )..sort((a, b) {
        final first = paintedMarkers[a];
        final second = paintedMarkers[b];
        if (first.isSelected != second.isSelected) {
          return first.isSelected ? -1 : 1;
        }
        final firstDistance = (first.position - viewportCenter).distanceSquared;
        final secondDistance =
            (second.position - viewportCenter).distanceSquared;
        return firstDistance.compareTo(secondDistance);
      });

    final occupiedLabels = <Rect>[];
    final labelFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xE61A2036);
    final labelBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final markerIndex in priorityOrder) {
      if (occupiedLabels.length >= maximumVisibleSpotNames) break;

      final paintedSpot = paintedMarkers[markerIndex];
      final label = _normalizedSpotName(paintedSpot.spot.name);
      if (label.isEmpty) continue;

      final textPainter = _labelPainter(label);
      final labelSize = Size(
        textPainter.width + _labelHorizontalPadding * 2,
        textPainter.height + _labelVerticalPadding * 2,
      );
      final labelRect = findSpotNameLabelRect(
        markerPosition: paintedSpot.position,
        markerRadius: paintedSpot.radius,
        labelSize: labelSize,
        viewport: viewport,
        occupiedLabels: occupiedLabels,
        markerPositions: markerPositions,
        markerIndex: markerIndex,
      );
      if (labelRect == null) continue;

      final background = RRect.fromRectAndRadius(
        labelRect,
        const Radius.circular(6),
      );
      canvas.drawRRect(background, labelFillPaint);
      labelBorderPaint.color =
          paintedSpot.spot.type.color.withValues(alpha: 0.9);
      canvas.drawRRect(background, labelBorderPaint);
      textPainter.paint(
        canvas,
        labelRect.topLeft +
            const Offset(_labelHorizontalPadding, _labelVerticalPadding),
      );
      occupiedLabels.add(labelRect);
    }
  }

  String _normalizedSpotName(String name) {
    return name.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  TextPainter _labelPainter(String label) {
    return _labelPainters.putIfAbsent(label, () {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        maxLines: 1,
        ellipsis: '\u2026',
        textDirection: TextDirection.ltr,
      );
      painter.layout(maxWidth: _maximumTextWidth);
      return painter;
    });
  }

  @override
  bool shouldRepaint(_SpotsPainter oldDelegate) {
    return oldDelegate.visibleSpots != visibleSpots ||
        oldDelegate.selectedSpot != selectedSpot ||
        oldDelegate.mapController != mapController;
  }
}

class _PaintedSpot {
  final Spot spot;
  final Offset position;
  final double radius;
  final bool isSelected;

  const _PaintedSpot({
    required this.spot,
    required this.position,
    required this.radius,
    required this.isSelected,
  });
}
