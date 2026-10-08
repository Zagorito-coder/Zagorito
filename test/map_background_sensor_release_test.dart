import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:spots_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'quitter la carte annule immédiatement le capteur de boussole',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_language': 'fr',
        'theme_mode': 'light',
      });

      const compassChannel = MethodChannel('hemanthraj/flutter_compass');
      const geolocatorChannel =
          MethodChannel('flutter.baseflow.com/geolocator');
      const positionUpdatesChannel =
          MethodChannel('flutter.baseflow.com/geolocator_updates');
      var compassListenCalls = 0;
      var compassCancelCalls = 0;
      var positionListenCalls = 0;
      var positionCancelCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        compassChannel,
        (call) async {
          if (call.method == 'listen') compassListenCalls++;
          if (call.method == 'cancel') compassCancelCalls++;
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        geolocatorChannel,
        (call) async {
          return switch (call.method) {
            'isLocationServiceEnabled' => true,
            'checkPermission' || 'requestPermission' => 2,
            'getCurrentPosition' => {
                'latitude': 31.5,
                'longitude': -9.7,
              },
            _ => null,
          };
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        positionUpdatesChannel,
        (call) async {
          if (call.method == 'listen') positionListenCalls++;
          if (call.method == 'cancel') positionCancelCalls++;
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          compassChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          geolocatorChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          positionUpdatesChannel,
          null,
        );
      });

      final mapIsActive = ValueNotifier<bool>(true);
      addTearDown(mapIsActive.dispose);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FishProvider>.value(
              value: FishProvider.instance,
            ),
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
              isActive: mapIsActive,
              initialSpots: const [
                Spot(
                  id: 'sensor-release-test',
                  name: 'Spot test',
                  latitude: 31.5,
                  longitude: -9.7,
                  location: LatLng(31.5, -9.7),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.bySemanticsLabel('Activer la boussole'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(compassListenCalls, 1);
      expect(compassCancelCalls, 0);
      expect(positionListenCalls, 1);
      expect(positionCancelCalls, 0);

      mapIsActive.value = false;
      await tester.pump();

      expect(
        compassCancelCalls,
        1,
        reason: 'Le capteur doit être arrêté sans attendre dispose().',
      );
      expect(
        positionCancelCalls,
        1,
        reason: 'Le flux GPS doit être arrêté sans attendre dispose().',
      );
      expect(find.bySemanticsLabel('Activer la boussole'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      semantics.dispose();
    },
  );
}
