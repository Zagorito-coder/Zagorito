import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/widgets/wind_particle_layer.dart';
import 'package:spots_app/widgets/wind_particle_painter.dart';

class _FakeWindProvider extends WindAnimationProvider {
  bool _enabled = true;

  @override
  bool get isEnabled => _enabled;

  @override
  WindVector? get currentVector => const WindVector(
        u: 8,
        v: 4,
        speedKt: 12,
        directionDeg: 245,
      );

  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }
}

Finder get _windPaint => find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is WindParticlePainter,
    );

void main() {
  testWidgets(
    'le vent redémarre dès la première trame après plusieurs désactivations',
    (tester) async {
      final provider = _FakeWindProvider();
      final mapController = MapController();
      addTearDown(provider.dispose);
      addTearDown(mapController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 700,
            child: FlutterMap(
              mapController: mapController,
              options: const MapOptions(
                initialCenter: LatLng(30.5, -9.7),
                initialZoom: 8,
              ),
              children: [
                WindParticleLayer(
                  provider: provider,
                  mapController: mapController,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 40));
      expect(_windPaint, findsOneWidget);

      // Simule une première utilisation suffisamment longue pour que l'ancien
      // compteur de trames soit nettement supérieur à zéro.
      await tester.pump(const Duration(seconds: 2));
      provider.setEnabled(false);
      await tester.pump();
      expect(_windPaint, findsNothing);

      provider.setEnabled(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_windPaint, findsOneWidget);

      provider.setEnabled(false);
      await tester.pump();
      provider.setEnabled(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_windPaint, findsOneWidget);
    },
  );
}
