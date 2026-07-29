import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Prevents a transient invalid gesture value from corrupting the map camera.
///
/// flutter_map 8.3.1 may occasionally calculate a NaN/Infinity center or zoom
/// during a scale gesture. Once stored, that value can make both the tile and
/// marker layers enter unbounded update loops. Keeping the last valid camera is
/// safer than allowing one malformed gesture frame to poison later frames.
class FiniteMapController extends MapControllerImpl {
  static bool _isFinitePoint(LatLng point) =>
      point.latitude.isFinite && point.longitude.isFinite;

  static bool _isFiniteOffset(Offset offset) =>
      offset.dx.isFinite && offset.dy.isFinite;

  @override
  bool moveRaw(
    LatLng newCenter,
    double newZoom, {
    Offset offset = Offset.zero,
    required bool hasGesture,
    required MapEventSource source,
    String? id,
  }) {
    if (!_isFinitePoint(newCenter) ||
        !newZoom.isFinite ||
        !_isFiniteOffset(offset)) {
      return false;
    }

    return super.moveRaw(
      newCenter,
      newZoom,
      offset: offset,
      hasGesture: hasGesture,
      source: source,
      id: id,
    );
  }

  @override
  bool rotateRaw(
    double newRotation, {
    required bool hasGesture,
    required MapEventSource source,
    String? id,
  }) {
    if (!newRotation.isFinite) return false;
    return super.rotateRaw(
      newRotation,
      hasGesture: hasGesture,
      source: source,
      id: id,
    );
  }

  @override
  bool setNonRotatedSizeWithoutEmittingEvent(Size nonRotatedSize) {
    if (!nonRotatedSize.width.isFinite ||
        !nonRotatedSize.height.isFinite ||
        nonRotatedSize.width < 0 ||
        nonRotatedSize.height < 0) {
      return false;
    }
    return super.setNonRotatedSizeWithoutEmittingEvent(nonRotatedSize);
  }
}
