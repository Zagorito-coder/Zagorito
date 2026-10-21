import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/data/marine_weather_points.dart';
import 'package:spots_app/services/marine_location_controller.dart';
import 'package:spots_app/services/tide_service.dart';

MarineWeatherPoint point(String id) =>
    marineWeatherPoints.singleWhere((p) => p.id == '${id}_maroc');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('permission refusée : pas de Casablanca inventée ni demande implicite',
      () async {
    final calls = <bool>[];
    final c = MarineLocationController(locate: (request) async {
      calls.add(request);
      throw MarineLocationIssue.permission;
    });
    await c.initialize();
    expect(c.coordinates, isNull);
    expect(c.weatherPoint, isNull);
    expect(c.issue, MarineLocationIssue.permission);
    expect(calls, [false]);
    await c.useMyPosition();
    expect(calls, [false, true]);
    c.dispose();
  });

  test('position à Agadir : météo et marée utilisent Agadir', () async {
    final c = MarineLocationController(
        locate: (_) async => const MarineCoordinates(30.42, -9.60));
    await c.initialize();
    expect(c.weatherPoint!.id, 'agadir_maroc');
    expect(
        TideService.stationForPosition(
                c.coordinates!.latitude, c.coordinates!.longitude)!
            .id,
        'agadir_maroc');
    expect(c.lastKnown, false);
    c.dispose();
  });

  test('Dakhla : météo et marée utilisent exactement le même point côtier',
      () async {
    final c = MarineLocationController(
        locate: (_) async => const MarineCoordinates(23.70, -15.93));
    await c.initialize();
    expect(c.weatherPoint!.id, 'dakhla_maroc');
    expect(
      TideService.stationForPosition(
              c.coordinates!.latitude, c.coordinates!.longitude)!
          .id,
      'dakhla_maroc',
    );
    c.dispose();
  });

  test('une ancienne réponse GPS ne remplace jamais le choix manuel', () async {
    final gps = Completer<MarineCoordinates>();
    final started = Completer<void>();
    final c = MarineLocationController(locate: (_) {
      started.complete();
      return gps.future;
    });
    final init = c.initialize();
    await started.future;
    await c.selectManual(point('rabat'));
    gps.complete(const MarineCoordinates(33.59, -7.61));
    await init;
    expect(c.weatherPoint!.id, 'rabat_maroc');
    expect(c.automatic, false);
    final restored = MarineLocationController(
        locate: (_) => throw StateError('GPS inattendu'));
    await restored.initialize();
    expect(restored.weatherPoint!.id, 'rabat_maroc');
    c.dispose();
    restored.dispose();
  });

  test(
      'redémarrage en mode auto : un ancien lieu est identifié si GPS en panne',
      () async {
    final c = MarineLocationController(
        locate: (_) async => const MarineCoordinates(30.42, -9.60));
    await c.initialize();
    c.dispose();
    final restored = MarineLocationController(
        locate: (_) async => throw TimeoutException('GPS'));
    await restored.initialize();
    expect(restored.weatherPoint!.id, 'agadir_maroc');
    expect(restored.lastKnown, true);
    expect(restored.issue, MarineLocationIssue.unavailable);
    restored.dispose();
  });

  test('retour application : actualise un ancien GPS sans requêtes répétées',
      () async {
    var now = DateTime(2026, 10, 3, 8);
    var calls = 0;
    final c = MarineLocationController(
        now: () => now,
        locate: (_) async => ++calls == 1
            ? const MarineCoordinates(30.42, -9.60)
            : const MarineCoordinates(34.02, -6.84));
    await Future.wait([c.initialize(), c.initialize()]);
    await c.refresh();
    expect(calls, 1);
    now = now.add(const Duration(minutes: 6));
    await c.refresh();
    expect(calls, 2);
    expect(c.weatherPoint!.id, 'rabat_maroc');
    c.dispose();
  });

  test('préférence corrompue et coordonnées invalides : aucune fausse station',
      () async {
    SharedPreferences.setMockInitialValues({
      MarineLocationController.preferenceKey:
          jsonEncode({'mode': 'auto', 'lat': 999, 'lon': 0})
    });
    final c = MarineLocationController(
        locate: (_) async => const MarineCoordinates(double.nan, 0));
    await c.initialize();
    expect(c.weatherPoint, isNull);
    expect(c.coordinates, isNull);
    c.dispose();
  });

  test(
      'le catalogue local correspond aux points déjà collectés, dont 35 au Maroc',
      () {
    final script = File('harvest_forecast.py').readAsStringSync();
    expect(marineWeatherPoints, hasLength(143));
    expect(marineWeatherPoints.where((p) => p.id.endsWith('_maroc')),
        hasLength(35));
    for (final p in marineWeatherPoints) {
      final line = script
          .split('\n')
          .singleWhere((line) => line.contains('"id": "${p.id}"'));
      expect(line, contains('"lat": ${p.latitude}'));
      // Python source may write an extra trailing zero, compare numerically.
      final lon = RegExp(r'"lon":\s*([-0-9.]+)').firstMatch(line)!;
      expect(double.parse(lon.group(1)!), p.longitude);
    }
  });
}
