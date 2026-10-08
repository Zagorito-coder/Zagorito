import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/data/marine_weather_points.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/pages/forecast_page.dart';
import 'package:spots_app/pages/tide_page.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/services/marine_location_controller.dart';
import 'package:spots_app/services/tide_service.dart';
import 'package:spots_app/widgets/forecast_table.dart';

late AppLocalizations french;

class _Locale extends LocalizationsDelegate<AppLocalizations> {
  const _Locale();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(french);
  @override
  bool shouldReload(_Locale old) => false;
}

MarineWeatherPoint point(String city) =>
    marineWeatherPoints.singleWhere((p) => p.id == '${city}_maroc');
Widget app(Widget child) => MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      _Locale(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate
    ],
    home: child);
Future<void> pump(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

SpotForecast forecast(String name) =>
    SpotForecast(locationName: name, lastUpdate: DateTime.now(), slots: [
      ForecastSlot(
          dateTime: DateTime.now(),
          windSpeedKnots: 1,
          windGustKnots: 2,
          windDirectionDeg: 3,
          waveHeightM: 1,
          wavePeriodS: 5,
          waveDirectionDeg: 0,
          temperatureC: 20,
          ratingStars: 3)
    ], dayStarts: [
      DateTime.now()
    ], dayStartIndexes: [
      0
    ]);

TideData localTideForecast(
  MarineWeatherPoint station, {
  DateTime? start,
  List<double> ranges = const [0.8, 1.0, 1.2, 1.4, 1.1, 0.9, 1.3, 1.5],
}) {
  final firstDay = start ?? DateTime(2026, 10, 8);
  final points = <TidePoint>[
    for (var day = 0; day < ranges.length; day++)
      for (var hour = 0; hour < 24; hour++)
        TidePoint(
          time: DateTime(
            firstDay.year,
            firstDay.month,
            firstDay.day + day,
            hour,
          ),
          instantUtc: DateTime.utc(
            firstDay.year,
            firstDay.month,
            firstDay.day + day,
            hour,
          ),
          height: 2 + ranges[day] * (1 + math.cos(2 * math.pi * hour / 24)) / 2,
        ),
  ];
  final reference = TideService.casablancaOfflineFallback();
  return TideData(
    hourlyPoints: points,
    low: points.map((point) => point.height).reduce(math.min),
    high: points.map((point) => point.height).reduce(math.max),
    next: points.first.height,
    waveHeight: 0.8,
    location: station.name,
    utcOffsetSeconds: 0,
    timeZoneId: 'UTC',
    tideHeightDatum: TideHeightDatum.globalMeanSeaLevel,
    astro: reference.astro,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    french = AppLocalizations(const Locale('fr'));
    await french.load();
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
    final root =
        Directory.fromUri(config.uri.resolve(flutter['rootUri'] as String)).uri;
    final font = File.fromUri(root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'));
    await (FontLoader('Roboto')
          ..addFont(font.readAsBytes().then(ByteData.sublistView)))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Pro conserve la nouvelle ville quand une ancienne requête se termine',
      (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final c = MarineLocationController(
        locate: (_) async => throw MarineLocationIssue.permission);
    await c.selectManual(point('casablanca'));
    final old = Completer<SpotForecast?>();
    final recent = Completer<SpotForecast?>();
    await t.pumpWidget(app(ForecastPage(
        locationController: c,
        forecastLoader: (id) =>
            id == 'casablanca_maroc' ? old.future : recent.future)));
    await pump(t);
    await c.selectManual(point('agadir'));
    await pump(t);
    recent.complete(forecast('DONNEES AGADIR'));
    await pump(t);
    expect(find.text('DONNEES AGADIR'), findsWidgets);
    old.complete(forecast('DONNEES CASABLANCA'));
    await pump(t);
    expect(find.text('DONNEES AGADIR'), findsWidgets);
    expect(find.text('DONNEES CASABLANCA'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
      'Marées ignore Casablanca tardive après choix de Dakhla ; Pro reprend Dakhla',
      (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final c = MarineLocationController(
        locate: (_) async => throw MarineLocationIssue.permission);
    await c.selectManual(point('casablanca'));
    final pendingCasablanca = Completer<TideData>();
    final calls = <String>[];
    await t.pumpWidget(app(TidePage(
        embeddedInBottomNavigation: true,
        locationController: c,
        tideLoader: (station) {
          calls.add(station.id);
          if (station.id == 'casablanca_maroc') {
            return pendingCasablanca.future;
          }
          return Future.value(localTideForecast(point('dakhla')));
        })));
    await pump(t);
    await c.selectManual(point('dakhla'));
    await pump(t);
    expect(calls, ['casablanca_maroc', 'dakhla_maroc']);
    expect(
        find.textContaining('Marées et conditions : Dakhla'), findsOneWidget);
    await t.tap(find.text('Coefficients'));
    await pump(t);
    expect(find.textContaining('ÉVOLUTION LOCALE'), findsOneWidget);
    expect(find.textContaining('Casablanca/JRC'), findsNothing);
    pendingCasablanca.complete(TideService.casablancaOfflineFallback());
    await pump(t);
    expect(
        find.textContaining('Marées et conditions : Dakhla'), findsOneWidget);
    expect(find.text('Casablanca, Maroc'), findsNothing);
    expect(find.textContaining('ÉVOLUTION LOCALE'), findsOneWidget);
    expect(find.textContaining('Casablanca/JRC'), findsNothing);
    final weatherRequests = <String>[];
    await t.pumpWidget(app(ForecastPage(
        locationController: c,
        forecastLoader: (id) async {
          weatherRequests.add(id);
          return forecast('METEO DAKHLA');
        })));
    await pump(t);
    expect(weatherRequests, ['dakhla_maroc']);
    expect(find.text('METEO DAKHLA'), findsWidgets);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('sans GPS, le choix manuel reste accessible en paysage',
      (t) async {
    t.view.physicalSize = const Size(915, 412);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = MarineLocationController(
        locate: (_) async => throw MarineLocationIssue.permission);
    await t.pumpWidget(app(TidePage(
        embeddedInBottomNavigation: true,
        locationController: c,
        tideLoader: (_) => throw StateError('Aucune station attendue'))));
    await pump(t);
    expect(find.byKey(const ValueKey('marine-choose-location')).hitTestable(),
        findsOneWidget);
    await t.tap(find.byKey(const ValueKey('marine-choose-location')));
    await pump(t);
    expect(find.byType(TextField), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Dakhla');
    await pump(t);
    await t.tap(find.widgetWithText(ListTile, 'Dakhla, Maroc'));
    await pump(t);
    expect(c.weatherPoint!.id, 'dakhla_maroc');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('Agadir conserve le volet avec son propre marnage local',
      (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final c = MarineLocationController();
    await c.selectManual(point('agadir'));
    final raw = localTideForecast(point('agadir'));
    await t.pumpWidget(app(TidePage(
        embeddedInBottomNavigation: true,
        locationController: c,
        tideLoader: (station) async =>
            TideService.applyPresentationReference(station, raw))));
    await pump(t);
    expect(
        find.textContaining('Marées et conditions : Agadir'), findsOneWidget);
    expect(find.textContaining('Casablanca'), findsNothing);
    expect(find.text('NIVEAU DE PRÉSENTATION'), findsOneWidget);
    expect(find.text('Coefficients'), findsOneWidget);
    expect(find.text('Amplitude'), findsNothing);
    await t.tap(find.text('Prévisions'));
    await pump(t);
    expect(find.textContaining('repère positif indicatif'), findsOneWidget);
    await t.tap(find.text('Coefficients'));
    await pump(t);
    expect(find.text('COEFFICIENT DES MARÉES'), findsOneWidget);
    expect(find.textContaining('/120'), findsOneWidget);
    expect(find.text('Marnage'), findsOneWidget);
    expect(find.textContaining('ÉVOLUTION LOCALE'), findsOneWidget);
    expect(find.textContaining('station sélectionnée'), findsOneWidget);
    expect(find.textContaining('modèle harmonique JRC'), findsNothing);
    expect(find.textContaining('Casablanca/JRC'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('Casablanca conserve son volet mensuel de coefficients',
      (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final c = MarineLocationController();
    await c.selectManual(point('casablanca'));

    await t.pumpWidget(app(TidePage(
      embeddedInBottomNavigation: true,
      locationController: c,
      tideLoader: (_) async => TideService.casablancaOfflineFallback(),
    )));
    await pump(t);

    expect(find.text('Coefficients'), findsOneWidget);
    expect(find.text('Amplitude'), findsNothing);
    await t.tap(find.text('Coefficients'));
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pump();
    expect(find.text('COEFFICIENT DES MARÉES'), findsOneWidget);
    expect(find.text('AMPLITUDE LOCALE'), findsNothing);
    expect(find.textContaining('CYCLE MENSUEL'), findsOneWidget);
    expect(find.text('Calcul harmonique local'), findsOneWidget);
    expect(find.textContaining('LECTURE TRADITIONNELLE ARABE'), findsOneWidget);
    expect(find.textContaining('INDICE PROPRE À CETTE STATION'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
      'Beyrouth reçoit le volet Coefficients local sur 8 jours sans contenu Casablanca',
      (t) async {
    t.view.physicalSize = const Size(1080, 2316);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = MarineLocationController();
    final station = marineWeatherPoints
        .singleWhere((point) => point.id == 'beyrouth_liban');
    await c.selectManual(station);
    final start = DateTime(2026, 10, 29);
    const ranges = [0.34, 0.42, 0.51, 0.61, 0.72, 0.68, 0.57, 0.46];
    final points = <TidePoint>[
      for (var day = 0; day < ranges.length; day++)
        for (var hour = 0; hour < 24; hour++)
          TidePoint(
            time: DateTime(
              start.year,
              start.month,
              start.day + day,
              hour,
            ),
            instantUtc: DateTime.utc(
              start.year,
              start.month,
              start.day + day,
              hour,
            ),
            height: hour == 6
                ? 2 + ranges[day]
                : hour == 18
                    ? 2
                    : 2 + ranges[day] / 2,
          ),
    ];
    final reference = TideService.casablancaOfflineFallback();
    final raw = TideData(
      hourlyPoints: points,
      low: 2,
      high: 2.72,
      next: points.first.height,
      waveHeight: 0.8,
      location: station.name,
      utcOffsetSeconds: 0,
      tideHeightDatum: TideHeightDatum.globalMeanSeaLevel,
      astro: reference.astro,
    );

    await t.pumpWidget(app(TidePage(
      embeddedInBottomNavigation: true,
      locationController: c,
      tideLoader: (selected) async =>
          TideService.applyPresentationReference(selected, raw),
    )));
    await pump(t);

    expect(find.text('Coefficients'), findsOneWidget);
    await t.tap(find.text('Coefficients'));
    await pump(t);
    expect(find.text('COEFFICIENT DES MARÉES'), findsOneWidget);
    expect(find.textContaining('ÉVOLUTION LOCALE · 8 JOURS'), findsOneWidget);
    expect(
        find.textContaining('INDICE PROPRE À CETTE STATION'), findsOneWidget);
    expect(find.text('Calcul depuis la station sélectionnée'), findsOneWidget);
    expect(find.text('Marnage relatif intermédiaire'), findsOneWidget);
    expect(find.textContaining('Open-Meteo de cette station'), findsOneWidget);
    expect(find.textContaining('LECTURE TRADITIONNELLE'), findsNothing);
    expect(find.textContaining('Casablanca/JRC'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
      'Rabat explicite le référentiel MSL sans hauteur négative ambiguë',
      (t) async {
    // Format logique du Samsung S23 Ultra utilisé pour la validation physique.
    t.view.physicalSize = const Size(1080, 2316);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = MarineLocationController(
        locate: (_) async => throw MarineLocationIssue.permission);
    await c.selectManual(point('rabat'));
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final hourlyPoints = List<TidePoint>.generate(
      8 * 24 + 1,
      (index) => TidePoint(
        time: start.add(Duration(hours: index)),
        height: -1.32,
        windWaveHeight: 1.1,
        wavePeriod: 8,
      ),
      growable: false,
    );
    final hourlyForecast = List<HourlyForecastPoint>.generate(
      8 * 8,
      (index) => HourlyForecastPoint(
        time: start.add(Duration(hours: index * 3)),
        waveHeightM: 1.1,
        wavePeriodS: 8,
      ),
      growable: false,
    );
    final reference = TideService.casablancaOfflineFallback();

    await t.pumpWidget(app(TidePage(
      embeddedInBottomNavigation: true,
      locationController: c,
      tideLoader: (_) async => TideData(
        hourlyPoints: hourlyPoints,
        hourlyForecast: hourlyForecast,
        low: -1.32,
        high: -1.32,
        next: -1.32,
        waveHeight: 1.1,
        location: 'Rabat, Maroc',
        tideHeightDatum: TideHeightDatum.globalMeanSeaLevel,
        astro: reference.astro,
      ),
    )));
    await pump(t);

    expect(find.text('-1.32 m'), findsNothing);
    expect(find.textContaining('sous le NMM'), findsWidgets);

    await t.tap(find.text('Prévisions'));
    await pump(t);
    expect(find.textContaining('Référence :'), findsOneWidget);
    // La colonne étroite conserve le signe ; la référence NMM est portée par
    // le bandeau immédiatement au-dessus pour éviter toute troncature.
    expect(find.text('−1.32 m'), findsWidgets);
    expect(find.textContaining('(NMM)'), findsOneWidget);
    expect(find.textContaining('↓ NMM'), findsNothing);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
