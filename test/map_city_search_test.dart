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
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/spots_canvas_layer.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/utils/map_zoom_limits.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'app_language': 'fr',
      'theme_mode': 'light',
    });
  });

  testWidgets(
    'une ville centre la caméra et liste seulement les spots dans les 30 km',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const closest = Spot(
        id: 'casablanca-near',
        name: 'Port de Casablanca',
        latitude: 33.60,
        longitude: -7.62,
        location: LatLng(33.60, -7.62),
      );
      const nearby = Spot(
        id: 'casablanca-radius',
        name: 'Plage dans le périmètre',
        latitude: 33.58,
        longitude: -7.78,
        location: LatLng(33.58, -7.78),
      );
      const outside = Spot(
        id: 'casablanca-outside',
        name: 'Spot très éloigné',
        latitude: 34.10,
        longitude: -7.60,
        location: LatLng(34.10, -7.60),
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
            home: const MapScreen(
              initialSpots: [closest, nearby, outside],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final mapSizeBeforeKeyboard = tester.getSize(find.byType(FlutterMap));
      final searchTopBeforeKeyboard = tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('map-search-bar-surface')),
          )
          .dy;

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      final logicalKeyboardInset = 300 / tester.view.devicePixelRatio;
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(
        tester.getSize(find.byType(FlutterMap)),
        mapSizeBeforeKeyboard,
        reason: "Le clavier ne doit jamais redimensionner la carte.",
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('map-search-bar-surface')),
            )
            .dy,
        closeTo(searchTopBeforeKeyboard - logicalKeyboardInset, 0.1),
        reason: "Seule la barre doit remonter au-dessus du clavier.",
      );

      tester.view.resetViewInsets();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Casablanca');
      await tester.pump();

      final cityResult = find.byKey(
        const ValueKey<String>('city-search-result-MA-casablanca'),
      );
      expect(cityResult, findsOneWidget);

      await tester.tap(cityResult);
      await tester.pump();

      expect(find.text('Port de Casablanca'), findsOneWidget);
      expect(find.text('Plage dans le périmètre'), findsOneWidget);
      expect(find.text('Spot très éloigné'), findsNothing);
      expect(find.byKey(const ValueKey<String>('city-search-summary')),
          findsOneWidget);

      await tester.pump(const Duration(seconds: 3));

      final mapController = MapController.of(
        tester.element(find.byType(SpotsCanvasLayer)),
      );
      expect(mapController.camera.center.latitude, closeTo(33.5731, 0.0001));
      expect(mapController.camera.center.longitude, closeTo(-7.5898, 0.0001));
      expect(
        mapController.camera.zoom,
        closeTo(MapZoomLimits.automaticCitySearch, 0.01),
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
