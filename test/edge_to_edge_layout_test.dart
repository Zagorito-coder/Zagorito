import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/main.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/user_spot_form_sheet.dart';

const _spot = Spot(
  id: 'layout-test',
  name: 'Spot test',
  latitude: 31.5,
  longitude: -9.7,
  location: LatLng(31.5, -9.7),
);

late AppLocalizations _french;

class _LoadedLocalizations extends LocalizationsDelegate<AppLocalizations> {
  const _LoadedLocalizations();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fr';
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(_french);
  @override
  bool shouldReload(_LoadedLocalizations old) => false;
}

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.lightTheme.copyWith(
        textTheme: AppTheme.lightTheme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        _LoadedLocalizations(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void _screen(WidgetTester tester, Size size, EdgeInsets insets) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewPadding = FakeViewPadding(
    left: insets.left,
    top: insets.top,
    right: insets.right,
    bottom: insets.bottom,
  );
  tester.view.padding = tester.view.viewPadding;
  addTearDown(tester.view.reset);
}

void _inside(WidgetTester tester, Finder finder, Rect safe) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(safe.left), reason: '$finder: $rect');
  expect(rect.top, greaterThanOrEqualTo(safe.top), reason: '$finder: $rect');
  expect(rect.right, lessThanOrEqualTo(safe.right), reason: '$finder: $rect');
  expect(rect.bottom, lessThanOrEqualTo(safe.bottom), reason: '$finder: $rect');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use Android's real font: the Ahem test font can invent text overflows.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final packages = (jsonDecode(await configFile.readAsString())
        as Map<String, dynamic>)['packages'] as List<dynamic>;
    final flutter = packages
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final root = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
    ).uri;
    final font = File.fromUri(root.resolve(
      '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ));
    await (FontLoader('Roboto')
          ..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
        .load();
    _french = AppLocalizations(const Locale('fr'));
    await _french.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_language': 'fr',
      'theme_is_dark': false,
    });
    ThemeController.instance.setDark(false);
  });

  for (final bottom in [24.0, 48.0]) {
    testWidgets('navigation hors de la barre système de $bottom px',
        (tester) async {
      _screen(tester, const Size(412, 915),
          EdgeInsets.only(top: 32, bottom: bottom));
      await tester.pumpWidget(_app(AppShell(
        disablePostLaunchTasksForTesting: true,
        pageBuilderForTesting: (_) => const SizedBox.expand(),
      )));
      await tester.pumpAndSettle();
      for (final key in ['home', 'tides', 'spots', 'my-spots', 'settings']) {
        _inside(tester, find.byKey(ValueKey('bottom-nav-$key')),
            Rect.fromLTRB(0, 32, 412, 915 - bottom));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Enregistrer un spot reste au-dessus de la barre de $bottom px',
        (tester) async {
      _screen(tester, const Size(412, 915),
          EdgeInsets.only(top: 32, bottom: bottom));
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
            builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showUserSpotFormSheet(
                      context: context,
                      latitude: 31.5,
                      longitude: -9.7,
                      onSubmit: (_) async {},
                    ),
                    child: const Text('Ouvrir'),
                  ),
                )),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Enregistrer');
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      _inside(tester, save, Rect.fromLTRB(0, 32, 412, 915 - bottom));
      expect(tester.takeException(), isNull);

      // Android reports zero bottom padding while the IME covers the nav bar.
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      tester.view.padding = const FakeViewPadding(top: 32);
      await tester.pumpAndSettle();
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      _inside(tester, save, const Rect.fromLTRB(0, 32, 412, 595));
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = FakeViewPadding(top: 32, bottom: bottom);
      await tester.pumpAndSettle();
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      _inside(tester, save, Rect.fromLTRB(0, 32, 412, 915 - bottom));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final landscape in [false, true]) {
    testWidgets(
        'outils carte accessibles ${landscape ? 'paysage' : 'portrait'}',
        (tester) async {
      final size = landscape ? const Size(915, 412) : const Size(412, 915);
      final insets = landscape
          ? const EdgeInsets.only(left: 48, top: 24, right: 24)
          : const EdgeInsets.only(top: 32, bottom: 48);
      _screen(tester, size, insets);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<FishProvider>.value(value: FishProvider()),
          ChangeNotifierProvider<WindAnimationProvider>(
              create: (_) => WindAnimationProvider()),
        ],
        child: _app(AppShell(
          disablePostLaunchTasksForTesting: true,
          pageBuilderForTesting: (_) => const MapScreen(initialSpots: [_spot]),
        )),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      try {
        await tester.tap(find.byKey(const ValueKey('map-tools-toggle')));
        await tester.pump();
        _inside(
            tester,
            find.byKey(const ValueKey('map-tools-scroll')),
            Rect.fromLTRB(insets.left, insets.top, size.width - insets.right,
                size.height - insets.bottom));
        await tester.ensureVisible(find.text('Standard'));
        await tester.pump();
        expect(find.text('Standard').hitTestable(), findsOneWidget,
            reason: 'La recherche ne doit pas intercepter les outils.');
        _inside(
            tester,
            find.text('Standard'),
            Rect.fromLTRB(insets.left, insets.top, size.width - insets.right,
                size.height - insets.bottom));
        _inside(
            tester,
            find.byKey(const ValueKey('map-fish-filter-button')),
            Rect.fromLTRB(insets.left, insets.top, size.width - insets.right,
                size.height - insets.bottom));
        expect(tester.takeException(), isNull);
        // The final offline-map action must remain reachable by scrolling.
        await tester.drag(find.byKey(const ValueKey('map-tools-scroll')),
            const Offset(0, -1200));
        await tester.pump();
        _inside(
            tester,
            find.text(_french.translate('offlineMaps.manage')),
            Rect.fromLTRB(insets.left, insets.top, size.width - insets.right,
                size.height - insets.bottom));
      } finally {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
      }
    });
  }
}
