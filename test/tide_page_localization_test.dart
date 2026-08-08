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
      'tide.marineConditions',
      'tide.atmosphereVisibility',
      'tide.waterTemperature',
      'tide.oceanCurrent',
      'tide.primarySwell',
      'tide.secondarySwell',
      'tide.windGusts',
      'tide.visibility',
      'tide.cloudCover',
      'tide.activityFishIndicator',
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

  test('l’indicateur visuel respecte les trois niveaux d’activité', () {
    final tideSource = File('lib/pages/tide_page.dart').readAsStringSync();

    expect(tideSource, contains("'high' => 3"));
    expect(tideSource, contains("'mid' => 2"));
    expect(tideSource, contains("_ => 1"));
    expect(
        tideSource, contains('const Color _activityHigh = Color(0xFF0B8F6A)'));
  });

  test('les panneaux météo partagent la même échelle typographique', () {
    final tideSource = File('lib/pages/tide_page.dart').readAsStringSync();

    expect(
      RegExp('fontSize: _conditionSectionTitleFontSize')
          .allMatches(tideSource)
          .length,
      3,
    );
    expect(
      RegExp('fontSize: _conditionLabelFontSize').allMatches(tideSource).length,
      3,
    );
    expect(
      RegExp('_conditionValueFontSize').allMatches(tideSource).length,
      5,
    );
  });
}
