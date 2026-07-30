import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/main.dart';
import 'package:spots_app/models.dart';
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
    'le compteur est isolé au-dessus de la barre uniquement si actif',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const officialSpot = Spot(
        id: 'measurement-test-spot',
        name: 'Spot de test',
        latitude: 28,
        longitude: -12,
        location: LatLng(28, -12),
      );

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
            home: const MapScreen(initialSpots: [officialSpot]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      const indicatorKey = ValueKey<String>('map-measurement-search-indicator');
      const closeKey = ValueKey<String>('map-measurement-close');
      const searchSurfaceKey = ValueKey<String>('map-search-bar-surface');
      const toolsKey = ValueKey<String>('map-tools-toggle');
      const measurementToggleKey = ValueKey<String>('map-measurement-toggle');
      expect(find.byKey(indicatorKey), findsNothing);

      await tester.tap(find.byKey(toolsKey));
      await tester.pump();
      tester
          .widget<GestureDetector>(find.byKey(measurementToggleKey))
          .onTap
          ?.call();
      await tester.pump();

      expect(find.byKey(indicatorKey), findsOneWidget);
      expect(find.text('0.00 km'), findsOneWidget);
      expect(find.text('Outils cartographiques'), findsNothing);
      final indicatorRect = tester.getRect(find.byKey(indicatorKey));
      final searchSurfaceRect = tester.getRect(find.byKey(searchSurfaceKey));
      expect(indicatorRect.top, lessThan(searchSurfaceRect.top));
      expect(
        searchSurfaceRect.top - indicatorRect.bottom,
        greaterThanOrEqualTo(12),
      );
      expect(
        indicatorRect.center.dx,
        closeTo(searchSurfaceRect.center.dx, 0.5),
      );
      expect(indicatorRect.width, greaterThanOrEqualTo(150));
      expect(indicatorRect.height, greaterThanOrEqualTo(50));
      final closeRect = tester.getRect(find.byKey(closeKey));
      expect(closeRect.center.dx, greaterThan(indicatorRect.center.dx));
      expect(closeRect.right, greaterThan(indicatorRect.right));
      expect(closeRect.center.dy, closeTo(indicatorRect.center.dy, 0.5));
      expect(
        tester.widget<IconButton>(find.byKey(closeKey)).onPressed,
        isNotNull,
      );

      final spotsLayer =
          tester.widget<SpotsCanvasLayer>(find.byType(SpotsCanvasLayer));
      spotsLayer.onMapTap!.call(const LatLng(0, 0));
      await tester.pump();
      spotsLayer.onMapTap!.call(const LatLng(0, 1));
      await tester.pump();

      final expectedDistance = '${const Distance().as(
            LengthUnit.Kilometer,
            const LatLng(0, 0),
            const LatLng(0, 1),
          ).toStringAsFixed(2)} km';
      expect(find.byKey(indicatorKey), findsOneWidget);
      expect(
        find.text(expectedDistance),
        findsOneWidget,
        reason:
            'Textes visibles : ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).whereType<String>().join(' | ')}',
      );

      await tester.tap(find.byKey(toolsKey));
      await tester.pump();
      expect(find.text(expectedDistance), findsNWidgets(2));

      tester
          .widget<GestureDetector>(find.byKey(measurementToggleKey))
          .onTap
          ?.call();
      await tester.pump();
      expect(find.byKey(indicatorKey), findsNothing);
      expect(find.text(expectedDistance), findsNothing);

      tester
          .widget<GestureDetector>(find.byKey(measurementToggleKey))
          .onTap
          ?.call();
      await tester.pump();
      expect(find.byKey(indicatorKey), findsOneWidget);
      expect(find.text('0.00 km'), findsOneWidget);
      expect(find.text('Outils cartographiques'), findsNothing);

      await tester.tap(find.byKey(closeKey));
      await tester.pump();
      expect(find.byKey(indicatorKey), findsNothing);
      expect(find.byKey(closeKey), findsNothing);
      expect(find.text('Outils cartographiques'), findsNothing);

      // AppMapAttribution starts a one-shot timer on mount.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
