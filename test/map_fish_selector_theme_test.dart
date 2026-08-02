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
import 'package:spots_app/widgets/fish_intelligence_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'app_language': 'fr',
      'theme_mode': 'light',
    });
  });

  test('le sélecteur applique les familles modèle 4 clair et modèle 3 sombre',
      () {
    final source =
        File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final start = source.indexOf('class _FishVerticalMenu');
    final end = source.indexOf('// ══', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final selector = source.substring(start, end);
    expect(selector, contains('static const double _collapsedWidth = 68'));
    expect(selector, contains('static const double _selectedWidth = 190'));
    expect(selector, contains('width: isSelected'));
    expect(selector, contains("'map-fish-tile-\${fish.id}'"));
    expect(selector, contains('BorderRadius.circular(17)'));
    expect(selector, contains('if (isSelected) ...['));
    expect(selector,
        contains('child: Text(\n                              fish.name'));
    expect(selector, contains('class _FishSelectorPalette'));
    expect(selector, contains('surfaceTop: Color(0xFFFDFEFE)'));
    expect(selector, contains('accent: Color(0xFF087D88)'));
    expect(selector, contains('surfaceTop: Color(0xFF080B11)'));
    expect(selector, contains('accent: Color(0xFF168BFF)'));
    expect(selector, contains('class _FishCompassGridPainter'));
    expect(
      selector,
      contains('Theme.of(context).brightness == Brightness.dark'),
    );
    expect(selector, contains("'assets/fish_selector_thumbnails/'"));
    expect(selector, contains('fit: BoxFit.contain'));
    expect(selector, contains('RepaintBoundary('));
    expect(selector, contains('ListView.builder('));
    expect(selector, contains('cacheWidth:'));
    expect(selector, isNot(contains('BoxShape.circle')));
    expect(selector, isNot(contains('ClipOval')));
    expect(selector, isNot(contains('fish.scientificName')));
    expect(selector, isNot(contains('BackdropFilter')));

    final shell =
        File('lib/app_shell.dart').readAsStringSync().replaceAll('\r\n', '\n');
    expect(shell, contains('_mapIsActive.value = index == 3;'));
    expect(shell, contains('isActive: _mapIsActive'));

    final spotFinder = File('lib/pages/spot_finder_page.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(spotFinder, contains('final ValueListenable<bool>? isActive;'));
    expect(spotFinder, contains('isActive: isActive'));
  });

  test('la sélection d un spot officiel ferme le sélecteur poissons', () {
    final source =
        File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final selectSpotStart = source.indexOf('Future<void> _selectSpot');
    final selectUserSpotStart = source.indexOf(
      'Future<void> _selectUserSpot',
      selectSpotStart,
    );
    expect(selectSpotStart, greaterThanOrEqualTo(0));
    expect(selectUserSpotStart, greaterThan(selectSpotStart));
    expect(
      source.substring(selectSpotStart, selectUserSpotStart),
      contains('_isFishBarVisible = false;'),
    );
  });

  testWidgets(
    'la fiche et un changement d onglet ferment réellement le sélecteur',
    (tester) async {
      const spot = Spot(
        id: 'fish-selector-test-spot',
        name: 'Spot test',
        latitude: 31.5,
        longitude: -9.7,
        location: LatLng(31.5, -9.7),
      );
      final isMapActive = ValueNotifier<bool>(true);
      addTearDown(isMapActive.dispose);

      final fishProvider = FishProvider();
      fishProvider.deselectFish();
      await fishProvider.loadFishData();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FishProvider>.value(value: fishProvider),
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
              initialSpots: const [spot],
              isActive: isMapActive,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      const buttonKey = ValueKey<String>('map-fish-filter-button');
      const selectorKey = ValueKey<String>('map-fish-selector');
      expect(find.byKey(selectorKey), findsNothing);

      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(find.byKey(selectorKey), findsOneWidget);

      final fish = fishProvider.allFish.first;
      await tester.tap(
        find.byKey(ValueKey<String>('map-fish-tile-${fish.id}')),
      );
      await tester.pump();
      expect(find.byType(FishIntelligenceModal), findsOneWidget);
      expect(find.byKey(selectorKey), findsNothing);

      fishProvider.closeFishModal();
      await tester.pump();
      expect(find.byType(FishIntelligenceModal), findsNothing);
      expect(find.byKey(selectorKey), findsNothing);

      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(find.byKey(selectorKey), findsOneWidget);

      isMapActive.value = false;
      await tester.pump();
      expect(find.byKey(selectorKey), findsNothing);

      isMapActive.value = true;
      await tester.pump();
      expect(find.byKey(selectorKey), findsNothing);

      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(find.byKey(selectorKey), findsOneWidget);

      fishProvider.deselectFish();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
