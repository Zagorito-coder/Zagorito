import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/models.dart';

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
  Timer? _repaintTimer;
  int? _pointerId;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  static const double _tapSlop = 18.0;

  @override
  void initState() {
    super.initState();
    _mapEventSubscription = widget.mapController.mapEventStream.listen((_) {
      // During a pan/zoom flutter_map emits many events per frame. Rebuilding
      // the painter for each one starves the UI thread on low-end devices.
      // Keep the marker layer responsive while coalescing those events.
      if (_repaintTimer?.isActive ?? false) return;
      _repaintTimer = Timer(const Duration(milliseconds: 40), () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    _repaintTimer?.cancel();
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
    final MapCamera camera;
    try {
      camera = widget.mapController.camera;
    } catch (_) {
      return const SizedBox.shrink();
    }

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
            camera: camera,
            selectedSpot: widget.selectedSpot,
          ),
        ),
      ),
    );
  }
}

class _SpotsPainter extends CustomPainter {
  final List<Spot> visibleSpots;
  final MapCamera camera;
  final Spot? selectedSpot;

  _SpotsPainter({
    required this.visibleSpots,
    required this.camera,
    this.selectedSpot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Reuse Paint instances for the whole frame. Allocating and configuring
    // four Paints for every spot creates significant garbage at wide zooms.
    final shadowPaint = Paint()..style = PaintingStyle.fill;
    final mainPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()..style = PaintingStyle.stroke;
    final highlightPaint = Paint()..style = PaintingStyle.fill;

    for (final spot in visibleSpots) {
      final isSelected = spot == selectedSpot;
      final point = camera.latLngToScreenOffset(spot.location);
      final pos = Offset(point.dx, point.dy);
      final radius = isSelected ? 11.0 : 6.0;
      final baseColor = spot.type.color;

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
        ..color = Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = isSelected ? 2.2 : 1.3;
      canvas.drawCircle(pos, radius, borderPaint);

      // Reflet highlight en haut à gauche (effet liquide)
      if (!isSelected) {
        highlightPaint
          ..color = Colors.white.withValues(alpha: 0.55)
          ..maskFilter = null;
        canvas.drawCircle(
          Offset(pos.dx - radius * 0.35, pos.dy - radius * 0.35),
          radius * 0.28,
          highlightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpotsPainter oldDelegate) {
    return oldDelegate.visibleSpots != visibleSpots ||
        oldDelegate.selectedSpot != selectedSpot ||
        oldDelegate.camera != camera;
  }
}
