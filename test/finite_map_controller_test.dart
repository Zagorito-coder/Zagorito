import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/widgets/finite_map_controller.dart';

void main() {
  group('FiniteMapController', () {
    late FiniteMapController controller;

    setUp(() => controller = FiniteMapController());
    tearDown(() => controller.dispose());

    test('refuse un centre non fini avant de modifier la caméra', () {
      final moved = controller.moveRaw(
        const LatLng(double.nan, -9.7),
        6,
        hasGesture: true,
        source: MapEventSource.flingAnimationController,
      );

      expect(moved, isFalse);
    });

    test('refuse un zoom ou un décalage non fini', () {
      final invalidZoom = controller.moveRaw(
        const LatLng(30.5, -9.7),
        double.infinity,
        hasGesture: true,
        source: MapEventSource.onMultiFinger,
      );
      final invalidOffset = controller.moveRaw(
        const LatLng(30.5, -9.7),
        6,
        offset: const Offset(double.nan, 0),
        hasGesture: true,
        source: MapEventSource.flingAnimationController,
      );

      expect(invalidZoom, isFalse);
      expect(invalidOffset, isFalse);
    });

    test('refuse une rotation ou une taille non finie', () {
      final rotated = controller.rotateRaw(
        double.nan,
        hasGesture: true,
        source: MapEventSource.onMultiFinger,
      );
      final resized = controller.setNonRotatedSizeWithoutEmittingEvent(
        const Size(double.infinity, 800),
      );

      expect(rotated, isFalse);
      expect(resized, isFalse);
    });
  });
}
