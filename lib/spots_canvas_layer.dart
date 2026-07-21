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

  @override
  Widget build(BuildContext context) {
    final MapCamera camera;
    try {
      camera = widget.mapController.camera;
    } catch (_) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (TapUpDetails details) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset localOffset = box.globalToLocal(details.globalPosition);

          Spot? closest;
          double minDistance = 24.0;

          for (final spot in widget.visibleSpots) {
            final point = camera.latLngToScreenOffset(spot.location);
            final pos = Offset(point.dx, point.dy);
            final dist = (localOffset - pos).distance;
            if (dist < minDistance) {
              minDistance = dist;
              closest = spot;
            }
          }
          if (closest != null) {
            widget.onSpotTap(closest);
          } else if (widget.onMapTap != null) {
            final latLng = camera.screenOffsetToLatLng(localOffset);
            widget.onMapTap!(latLng);
          }
        },
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
        ..maskFilter = isSelected
            ? const MaskFilter.blur(BlurStyle.normal, 5)
            : null;
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
