import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/main.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/models/user_spot_selection_request.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/spots_canvas_layer.dart';
import 'package:spots_app/theme.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'app_language': 'fr',
      'theme_mode': 'light',
    });
  });

  testWidgets(
    'un appui long propose le spot et un toucher extérieur annule',
    (tester) async {
      const officialSpot = Spot(
        id: 'official-away-from-test-point',
        name: 'Spot officiel',
        latitude: 28,
        longitude: -12,
        location: LatLng(28, -12),
      );
      final personalSelection = ValueNotifier<UserSpotSelectionRequest?>(null);
      addTearDown(personalSelection.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FishProvider>.value(value: FishProvider()),
            ChangeNotifierProvider<WindAnimationProvider>(
              create: (_) => WindAnimationProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('fr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MapScreen(
              initialSpots: const [officialSpot],
              userSpotSelectionRequests: personalSelection,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final map = find.byType(FlutterMap);
      expect(map, findsOneWidget);
      final flutterMap = tester.widget<FlutterMap>(map);
      final flags = flutterMap.options.interactionOptions.flags;
      expect(InteractiveFlag.hasPinchZoom(flags), isTrue);
      expect(InteractiveFlag.hasPinchMove(flags), isFalse);
      expect(InteractiveFlag.hasRotate(flags), isFalse);
      expect(InteractiveFlag.hasDoubleTapZoom(flags), isTrue);
      expect(InteractiveFlag.hasDoubleTapDragZoom(flags), isTrue);

      final mapController = MapController.of(
        tester.element(find.byType(SpotsCanvasLayer)),
      );
      final cameraBeforeInvalidMove = mapController.camera;
      expect(
        mapController.move(
          const LatLng(double.nan, double.infinity),
          double.nan,
        ),
        isFalse,
      );
      expect(mapController.camera.center, cameraBeforeInvalidMove.center);
      expect(mapController.camera.zoom, cameraBeforeInvalidMove.zoom);

      final zoomBeforePinch = mapController.camera.zoom;
      final center = tester.getCenter(map);
      final firstFinger =
          await tester.startGesture(center - const Offset(30, 0));
      final secondFinger =
          await tester.startGesture(center + const Offset(30, 0));
      await firstFinger.moveTo(center - const Offset(90, 0));
      await secondFinger.moveTo(center + const Offset(90, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await firstFinger.up();
      await secondFinger.up();
      await tester.pumpAndSettle();

      expect(mapController.camera.zoom, greaterThan(zoomBeforePinch));
      expect(mapController.camera.zoom.isFinite, isTrue);
      expect(mapController.camera.center.latitude.isFinite, isTrue);
      expect(mapController.camera.center.longitude.isFinite, isTrue);

      const personalSpot = UserSpot(
        id: 'private-direct-map',
        name: 'Mon spot privé',
        latitude: 31.2,
        longitude: -9.8,
        notes: '',
        dangerNotes: '',
        status: SpotModerationStatus.pending,
      );
      personalSelection.value = const UserSpotSelectionRequest(
        serial: 1,
        spot: personalSpot,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>(
            'selected-personal-map-spot-private-direct-map',
          ),
        ),
        findsOneWidget,
      );
      expect(mapController.camera.center.latitude, closeTo(31.2, 0.0001));
      expect(mapController.camera.center.longitude, closeTo(-9.8, 0.0001));

      const confirmationKey = ValueKey<String>('confirm-personal-spot');
      flutterMap.options.onLongPress?.call(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(double.nan, double.nan),
      );
      await tester.pump();
      expect(find.byKey(confirmationKey), findsNothing);

      await tester.longPressAt(center);
      await tester.pump();

      expect(find.byKey(confirmationKey), findsOneWidget);
      expect(find.text('Ajouter à mes spots'), findsOneWidget);
      final pendingPin = find.byIcon(Icons.location_on_rounded);
      expect(pendingPin, findsOneWidget);
      expect(
        tester.getBottomLeft(pendingPin).dy,
        closeTo(center.dy, 1),
      );

      await tester.tapAt(center + const Offset(180, 0));
      await tester.pump();

      expect(find.byKey(confirmationKey), findsNothing);

      // AppMapAttribution displays its source popup briefly on first mount.
      // Let that one-shot timer complete before disposing the map.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
