import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/pages/home_dashboard.dart';
import 'package:spots_app/services/astronomy_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';

late AppLocalizations _frenchLocalizations;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'theme_is_dark': false,
      'app_language': 'fr',
    });
    // Stabilise les deux singletons avant que le premier arbre de widgets
    // commence à les écouter.
    ThemeController.instance;
    LanguageController.instance;
    _frenchLocalizations = AppLocalizations(const Locale('fr'));
    await _frenchLocalizations.load();
  });

  setUp(() {
    ThemeController.instance.setDark(false);
  });

  testWidgets('affiche uniquement les données marines réellement fournies',
      (tester) async {
    await _setViewport(tester, const Size(430, 932));
    await tester.pumpWidget(_testApp(tideData: _marineData()));
    await tester.pumpAndSettle();

    expect(find.text('78%'), findsOneWidget);
    expect(find.text('22 km/h'), findsOneWidget);
    // La même mesure alimente la hauteur de marée et la hauteur de vague.
    expect(find.text('1.4 m'), findsNWidgets(2));
    expect(find.text('92%'), findsNothing);
  });

  testWidgets('ne fabrique aucune métrique quand les données sont absentes',
      (tester) async {
    await _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_testApp(tideData: TideData.fallback()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeDashboard), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('92%'), findsNothing);
    expect(find.text('--'), findsWidgets);
  });

  testWidgets('préserve tous les callbacks des cartes expédition',
      (tester) async {
    await _setViewport(tester, const Size(430, 1600));
    final calls = <String>[];
    await tester.pumpWidget(
      _testApp(
        tideData: _marineData(),
        onTides: () => calls.add('tides'),
        onTidesV2: () => calls.add('tidesV2'),
        onSpecies: () => calls.add('species'),
        onTechniques: () => calls.add('techniques'),
        onCommunity: () => calls.add('community'),
        onShops: () => calls.add('shops'),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCard(tester, 'tides');
    await _tapCard(tester, 'forecast');
    await _tapCard(tester, 'fish');
    await _tapCard(tester, 'techniques');
    await _tapCard(tester, 'community');
    await _tapCard(tester, 'shops');

    expect(
      calls,
      equals([
        'tides',
        'tidesV2',
        'species',
        'techniques',
        'community',
        'shops',
      ]),
    );
  });

  testWidgets('affiche les six cartes sans aucun défilement', (tester) async {
    const viewport = Size(360, 640);
    await _setViewport(tester, viewport);
    await tester.pumpWidget(_testApp(tideData: _marineData()));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0,
    );

    for (final key in _expeditionKeys) {
      final card = find.byKey(ValueKey<String>(key));
      expect(card, findsOneWidget);
      final bounds = tester.getRect(card);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(viewport.height));
    }
  });

  testWidgets('affiche chaque titre et description sans troncature',
      (tester) async {
    await _setViewport(tester, const Size(360, 640));
    await tester.pumpWidget(_testApp(tideData: _marineData()));
    await tester.pumpAndSettle();

    const visibleTexts = <String>[
      'Marées',
      'Consultez les marées\nen temps réel pour\nmieux planifier.',
      'Marées avancées',
      'Prévisions détaillées\net coefficients pour\nles experts.',
      'Espèces de poissons',
      '72 espèces répertoriées\navec conseils et périodes\nfavorables.',
      'Techniques de pêche',
      'Guides pratiques pour\nmaîtriser chaque\ntechnique.',
      'Communauté',
      'Rejoignez les pêcheurs,\npartagez vos prises et\nastuces.',
      'Magasins d’articles',
      'Trouvez le matériel\nidéal près de\nvos spots.',
    ];

    final truncated = <String>[];
    for (final value in visibleTexts) {
      final text = find.text(value);
      expect(text, findsOneWidget, reason: 'Texte absent : $value');
      final paragraph = tester.renderObject<RenderParagraph>(text);
      if (paragraph.didExceedMaxLines) {
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: paragraph.constraints.maxWidth);
        truncated.add(
          '$value (${painter.computeLineMetrics().length} lignes requises)',
        );
      }
    }
    expect(truncated, isEmpty, reason: 'Textes tronqués : $truncated');
  });

  testWidgets('le bouton carte et le Drawer conservent leur navigation',
      (tester) async {
    await _setViewport(tester, const Size(430, 932));
    var mapCalls = 0;
    await tester.pumpWidget(
      _testApp(
        tideData: _marineData(),
        onSpots: () => mapCalls++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Carte'));
    await tester.pump();
    expect(mapCalls, 1);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Spots'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(mapCalls, 2);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('reste sans overflow en petit écran et texte agrandi',
      (tester) async {
    await _setViewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      _testApp(
        tideData: _marineData(),
        textScaler: const TextScaler.linear(1.6),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserve exactement la même structure en clair et sombre',
      (tester) async {
    await _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_testApp(tideData: _marineData()));
    await tester.pumpAndSettle();
    final lightCards = _expeditionKeys
        .where((key) => find.byKey(ValueKey<String>(key)).evaluate().isNotEmpty)
        .length;

    ThemeController.instance.setDark(true);
    await tester.pumpAndSettle();
    final darkCards = _expeditionKeys
        .where((key) => find.byKey(ValueKey<String>(key)).evaluate().isNotEmpty)
        .length;

    expect(lightCards, greaterThan(0));
    expect(darkCards, lightCards);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goldens de référence clair et sombre', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_testApp(tideData: _marineData()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeDashboard),
      matchesGoldenFile('goldens/home_dashboard_light.png'),
    );

    ThemeController.instance.setDark(true);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeDashboard),
      matchesGoldenFile('goldens/home_dashboard_dark.png'),
    );
  });
}

Future<void> _tapCard(
  WidgetTester tester,
  String motif,
) async {
  final finder = find.byKey(ValueKey<String>('home-expedition-$motif'));
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

const _expeditionKeys = <String>[
  'home-expedition-tides',
  'home-expedition-forecast',
  'home-expedition-fish',
  'home-expedition-techniques',
  'home-expedition-community',
  'home-expedition-shops',
];

Future<void> _setViewport(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _testApp({
  required TideData tideData,
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onSpots,
  VoidCallback? onSpecies,
  VoidCallback? onTechniques,
  VoidCallback? onCommunity,
  VoidCallback? onShops,
  VoidCallback? onTides,
  VoidCallback? onTidesV2,
}) {
  return MaterialApp(
    key: UniqueKey(),
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _StaticAppLocalizationsDelegate(_frenchLocalizations),
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
    home: HomeDashboard(
      tideData: tideData,
      isLoading: false,
      spots: const <Spot>[],
      onRefresh: () async {},
      onNavigateToSpots: onSpots,
      onNavigateToSpecies: onSpecies,
      onNavigateToTechniques: onTechniques,
      onNavigateToCommunity: onCommunity,
      onNavigateToShops: onShops,
      onNavigateToTides: onTides,
      onNavigateToTidesV2: onTidesV2,
    ),
  );
}

class _StaticAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  final AppLocalizations localizations;

  const _StaticAppLocalizationsDelegate(this.localizations);

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fr';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(localizations);

  @override
  bool shouldReload(_StaticAppLocalizationsDelegate old) => false;
}

TideData _marineData() {
  final reference = DateTime(2099, 1, 1, 6);
  return TideData(
    hourlyPoints: [
      TidePoint(
        time: reference,
        height: 1.1,
        windDirectionDeg: 315,
        wavePeriod: 8,
        windWaveHeight: 1.4,
        windSpeedKmh: 22,
      ),
      TidePoint(
        time: reference.add(const Duration(hours: 1)),
        height: 1.4,
        windDirectionDeg: 315,
        wavePeriod: 8,
        windWaveHeight: 1.4,
        windSpeedKmh: 22,
      ),
    ],
    low: 0.6,
    high: 2.2,
    next: 1.4,
    waveHeight: 1.4,
    location: 'Casablanca',
    astro: const AstroData(
      moonPhase: 0.5,
      moonPhaseName: 'Pleine Lune',
      coefficient: 82,
      fishActivity: 0.78,
      activityLabel: 'Excellente',
      moonRise: '18:15',
      moonSet: '06:12',
      sunRise: '06:30',
      sunSet: '20:20',
      lunarTransit: '23:00',
      lunarUnder: '11:00',
    ),
  );
}
