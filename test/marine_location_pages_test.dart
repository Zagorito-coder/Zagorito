import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    final reference = TideService.casablancaOfflineFallback();
    final calls = <String>[];
    await t.pumpWidget(app(TidePage(
        embeddedInBottomNavigation: true,
        locationController: c,
        tideLoader: (station) {
          calls.add(station.id);
          if (station.id == 'casablanca_maroc') {
            return pendingCasablanca.future;
          }
          return Future.value(TideData(
            hourlyPoints: reference.hourlyPoints,
            low: reference.low,
            high: reference.high,
            next: reference.next,
            waveHeight: reference.waveHeight,
            location: station.name,
            astro: reference.astro,
          ));
        })));
    await pump(t);
    await c.selectManual(point('dakhla'));
    await pump(t);
    expect(calls, ['casablanca_maroc', 'dakhla_maroc']);
    expect(
        find.textContaining('Marées et conditions : Dakhla'), findsOneWidget);
    pendingCasablanca.complete(TideService.casablancaOfflineFallback());
    await pump(t);
    expect(
        find.textContaining('Marées et conditions : Dakhla'), findsOneWidget);
    expect(find.text('Casablanca, Maroc'), findsNothing);
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

  testWidgets('Agadir affiche sa source et aucun coefficient de Casablanca',
      (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final c = MarineLocationController();
    await c.selectManual(point('agadir'));
    final reference = TideService.casablancaOfflineFallback();
    await t.pumpWidget(app(TidePage(
        embeddedInBottomNavigation: true,
        locationController: c,
        tideLoader: (station) async => TideData(
            hourlyPoints: reference.hourlyPoints,
            low: reference.low,
            high: reference.high,
            next: reference.next,
            waveHeight: reference.waveHeight,
            location: station.name,
            astro: reference.astro))));
    await pump(t);
    expect(
        find.textContaining('Marées et conditions : Agadir'), findsOneWidget);
    expect(find.textContaining('Casablanca'), findsNothing);
    expect(find.text('Coefficients'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
