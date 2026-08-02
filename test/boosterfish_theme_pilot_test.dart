import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/pages/community_page.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'theme_is_dark': false,
      'app_language': 'fr',
    });
    ThemeController.instance.setDark(false);
  });

  testWidgets('la page pilote Communauté reprend le thème BoosterFish',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_communityApp());
    await tester.pumpAndSettle();

    expect(find.byType(BoosterFishPageShell), findsOneWidget);
    expect(find.byType(BoosterFishPageHeader), findsOneWidget);
    expect(find.byType(BoosterFishGlassCard), findsOneWidget);
    expect(find.text('Communauté'), findsWidgets);
    expect(find.text('Mes prises'), findsOneWidget);
    expect(find.text('Fonctionnalité à venir...'), findsNothing);
    expect(tester.takeException(), isNull);

    ThemeController.instance.setDark(true);
    await tester.pumpAndSettle();

    expect(find.text('Mes prises'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpWidget(
      _communityApp(textScaler: const TextScaler.linear(1.4)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BoosterFishPageShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('le thème opt-in reste absent des pages protégées', () {
    const protectedFiles = [
      'lib/main.dart',
      'lib/pages/spot_finder_page.dart',
      'lib/pages/shops_map_page.dart',
      'lib/pages/splash_map_page.dart',
      'lib/pages/tide_page.dart',
      'lib/pages/forecast_page.dart',
    ];

    for (final path in protectedFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('widgets/boosterfish_page.dart')),
        reason: 'Le thème opt-in ne doit pas être appliqué à $path',
      );
      expect(
        source,
        isNot(contains('BoosterFishPageShell')),
        reason: 'La page protégée $path doit conserver son rendu actuel',
      );
    }
  });

  test('les parcours demandés utilisent le thème et leurs bannières dédiées',
      () {
    const themedPages = {
      'lib/pages/species_page.dart':
          'assets/page_heroes/species_boosterfish_hero.webp',
      'lib/pages/techniques_page.dart':
          'assets/page_heroes/techniques_boosterfish_hero.webp',
      'lib/pages/shops_page.dart':
          'assets/page_heroes/shops_boosterfish_hero.webp',
    };

    for (final entry in themedPages.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains('BoosterFishPageShell'));
      expect(source, contains('BoosterFishPageHeader'));
      expect(source, contains('BoosterFishPageHero'));
      expect(source, contains(entry.value));

      final hero = File(entry.value);
      expect(hero.existsSync(), isTrue);
      expect(
        hero.lengthSync(),
        greaterThan(100 * 1024),
        reason: 'La bannière ${entry.value} doit rester nette sur téléphone',
      );
    }
  });

  test('Paramètres conserve ses images et adopte uniquement la couche visuelle',
      () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();
    expect(source, contains('BoosterFishPageShell'));
    expect(source, contains('animation: ThemeController.instance'));
    expect(source, contains('assets/settings_hero.webp'));
    expect(source, contains('assets/settings_fishing_banner.webp'));
    expect(source, contains('_openPrivacyPolicy'));
    expect(source, contains('_openTermsOfService'));
    expect(source, contains('_showEditProfileDialog'));
    expect(source, contains('_confirmDeleteAccount'));
    expect(source, contains('_openPrivacyOptions'));
  });
}

Widget _communityApp({
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    key: UniqueKey(),
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: textScaler),
        child: child!,
      );
    },
    home: CommunityPage(key: UniqueKey()),
  );
}
