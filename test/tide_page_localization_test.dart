import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la page Marées localise tous ses textes visibles et accessibles', () {
    final tideSource = File('lib/pages/tide_page.dart').readAsStringSync();
    final attributionSource =
        File('lib/widgets/open_meteo_attribution.dart').readAsStringSync();

    for (final key in const [
      'tide.title',
      'tide.updatedAt',
      'tide.activityTitle',
      'tide.currentTide',
      'tide.tideAt',
      'tide.nextExtremes',
      'tide.hourlyActivity',
      'tide.currentConditions',
      'tide.pressure',
      'tide.rain',
      'tide.humidity',
      'tide.upcomingTideEvents',
      'tide.forecastDisclaimer',
      'tide.hourSemantics',
      'tide.unavailableShort',
    ]) {
      expect(tideSource, contains(key), reason: 'Clé absente: $key');
    }

    for (final forbidden in const [
      "Text('ACTIVITÉ PAR HEURE'",
      "label: 'PRESSION'",
      "label: 'PLUIE'",
      "label: 'HUMIDITÉ'",
      "title: const Text('Prévisions marines')",
      "label: '\${card.hour} heures'",
      "'Indisponible'",
    ]) {
      expect(
        tideSource,
        isNot(contains(forbidden)),
        reason: 'Texte français encore codé en dur: $forbidden',
      );
    }

    expect(
      attributionSource,
      contains("context.tr('attribution.dataPrefix')"),
    );
    expect(
      attributionSource,
      contains("context.tr('attribution.modelsPrefix')"),
    );
    expect(
      attributionSource,
      contains("context.tr('attribution.indicativeForecasts')"),
    );
  });
}
