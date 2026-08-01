import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Plan de vol cinématique économe en tuiles.
///
/// La caméra recule d'abord vers un zoom de croisière adapté à la distance,
/// traverse ensuite la carte avec peu de tuiles visibles, puis se rapproche du
/// point final. Les interpolations restent pures afin d'être testables.
final class MapFlightPlan {
  MapFlightPlan._({
    required this.start,
    required this.target,
    required this.startZoom,
    required this.targetZoom,
    required this.cruiseZoom,
    required this.duration,
  });

  static const frameInterval = Duration(milliseconds: 40);

  final LatLng start;
  final LatLng target;
  final double startZoom;
  final double targetZoom;
  final double cruiseZoom;
  final Duration duration;

  factory MapFlightPlan.adaptive({
    required LatLng start,
    required LatLng target,
    required double startZoom,
    required double targetZoom,
    required double distanceKm,
  }) {
    final safeDistance = distanceKm.isFinite ? math.max(0.0, distanceKm) : 0.0;
    final safeTargetZoom = targetZoom.clamp(3.0, 22.0).toDouble();
    final safeStartZoom =
        startZoom.clamp(3.0, math.max(3.0, safeTargetZoom)).toDouble();
    final suggestedCruiseZoom = switch (safeDistance) {
      < 0.75 => safeTargetZoom - 0.35,
      < 5 => 14.5,
      < 25 => 12.5,
      < 100 => 10.5,
      < 400 => 8.5,
      < 1200 => 6.5,
      _ => 4.5,
    };
    final cruiseZoom = math
        .min(safeStartZoom, suggestedCruiseZoom)
        .clamp(3.0, safeTargetZoom)
        .toDouble();
    final durationMs = (750 + (math.log(1 + safeDistance) / math.ln10) * 300)
        .round()
        .clamp(750, 1800)
        .toInt();

    return MapFlightPlan._(
      start: start,
      target: target,
      startZoom: safeStartZoom,
      targetZoom: safeTargetZoom,
      cruiseZoom: cruiseZoom,
      duration: Duration(milliseconds: durationMs),
    );
  }

  LatLng centerAt(double progress) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    final travelProgress = ((p - 0.10) / 0.72).clamp(0.0, 1.0).toDouble();
    final eased = _easeInOutCubic(travelProgress);
    final longitudeDelta =
        ((target.longitude - start.longitude + 540) % 360) - 180;
    final longitude = _normalizeLongitude(
      start.longitude + longitudeDelta * eased,
    );
    return LatLng(
      start.latitude + (target.latitude - start.latitude) * eased,
      longitude,
    );
  }

  double zoomAt(double progress) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0.24) {
      return _lerp(
        startZoom,
        cruiseZoom,
        _easeOutCubic(p / 0.24),
      );
    }
    if (p < 0.62) return cruiseZoom;
    return _lerp(
      cruiseZoom,
      targetZoom,
      _easeInOutCubic((p - 0.62) / 0.38),
    );
  }

  static double _lerp(double start, double end, double t) =>
      start + (end - start) * t;

  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();

  static double _easeInOutCubic(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

  static double _normalizeLongitude(double longitude) =>
      ((longitude + 180) % 360 + 360) % 360 - 180;
}
