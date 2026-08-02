import 'dart:io';

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
import 'package:spots_app/theme.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'app_language': 'fr',
      'theme_mode': 'light',
    });
  });

  test('tous les contrôles principaux de la carte ont un libellé traduit', () {
    final source = File('lib/main.dart').readAsStringSync();

    for (final key in [
      'map.clearSearch',
      'map.zoomIn',
      'map.zoomOut',
      'map.myLocation',
      'map.enableCompass',
      'map.disableCompass',
      'map.openTools',
      'map.closeTools',
      'map.showFish',
      'map.hideFish',
      'map.enableWind',
      'map.disableWind',
    ]) {
      expect(source, contains(key), reason: 'Libellé absent : $key');
    }
    expect(source, contains('final String semanticLabel;'));
    expect(source, contains('label: semanticLabel'));
    expect(source, contains('toggled: _isFishBarVisible'));
    expect(source, contains('toggled: isOn'));
  });

  testWidgets('les libellés français sont exposés aux lecteurs d écran',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semanticsHandle = tester.ensureSemantics();

    const spot = Spot(
      id: 'accessibility-test-spot',
      name: 'Spot test',
      latitude: 31.5,
      longitude: -9.7,
      location: LatLng(31.5, -9.7),
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
          home: const MapScreen(initialSpots: [spot]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    for (final label in [
      'Zoomer',
      'Dézoomer',
      'Centrer sur ma position',
      'Activer la boussole',
      'Ouvrir les outils cartographiques',
      'Afficher les poissons',
      'Afficher le vent',
    ]) {
      expect(
        find.bySemanticsLabel(label),
        findsOneWidget,
        reason: 'Libellé non exposé : $label',
      );
    }

    await tester.tap(find.byKey(const ValueKey('map-tools-toggle')));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Fermer les outils cartographiques'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    semanticsHandle.dispose();
  });
}
