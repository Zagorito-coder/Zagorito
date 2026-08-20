import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la page Marées localise tous ses textes visibles et accessibles', () {
    final tideSource = File('lib/pages/tide_page.dart').readAsStringSync();
    final coefficientsSource =
        File('lib/widgets/tide_coefficients_view.dart').readAsStringSync();
    final localizedTideSource = '$tideSource\n$coefficientsSource';
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
      'tide.viewSelector',
      'tide.todayTides',
      'tide.forecasts',
      'tide.availableDayForecast',
      'tide.hourlyForecastUnavailable',
      'tide.forecastDaySemantics',
      'tide.activityScoreCompact',
      'tide.maxWindCompact',
      'tide.hour',
      'tide.weather',
      'tide.air',
      'tide.coefficients',
      'tide.coefficientTitle',
      'tide.localIndex',
      'tide.tidalRange',
      'tide.localHarmonicCalculation',
      'tide.monthlyCycle',
      'tide.moroccanTraditionalReading',
      'tide.culturalReadingDisclaimer',
      'tide.localHarmonicIndicative',
      'tide.coefficientInfoBody',
    ]) {
      expect(localizedTideSource, contains(key), reason: 'Clé absente: $key');
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

  test('le modèle 10 jours reste vertical et ne construit que le jour ouvert',
      () {
    final tideSource = File('lib/pages/tide_page.dart').readAsStringSync();
    final sectionStart =
        tideSource.indexOf('Widget _buildHourlyForecastSection');
    final sectionEnd = tideSource.indexOf('Widget _buildMarineConditions');
    final sectionSource = tideSource.substring(sectionStart, sectionEnd);

    expect(sectionSource, contains('_buildForecastAccordion'));
    expect(sectionSource, contains('if (isExpanded)'));
    expect(sectionSource, isNot(contains('AnimatedSize')));
    expect(sectionSource, contains('isExpanded'));
    expect(sectionSource, isNot(contains('Axis.horizontal')));
    expect(sectionSource, contains('height: 72'));
    expect(
      sectionSource,
      isNot(contains('BoxConstraints(minHeight: 72)')),
    );
    expect(tideSource, contains('_buildHourlyScroller'));
    expect(tideSource, contains('_buildTideModeSelector'));
    expect(
      tideSource,
      contains('_selectedTideView == _TideView.forecasts'),
    );
    expect(
      tideSource,
      contains('_selectedTideView == _TideView.coefficients'),
    );
    expect(tideSource, contains('_loadCoefficientMonth'));
  });

  test('le volet Coefficients sépare calcul scientifique et lecture culturelle',
      () {
    final source =
        File('lib/services/tide_coefficient_service.dart').readAsStringSync();
    final widgetSource =
        File('lib/widgets/tide_coefficients_view.dart').readAsStringSync();

    expect(source, contains('CasablancaTideReference.heightAtUtc'));
    expect(source, contains('localIndexForRange'));
    expect(source, isNot(contains('AstronomyService')));
    expect(
      widgetSource,
      contains("context.tr('tide.culturalReadingDisclaimer')"),
    );
    expect(
      widgetSource,
      contains("context.tr('tide.localHarmonicIndicative')"),
    );
  });

  test("les panneaux retardés deviennent visibles à l'activation de l'onglet",
      () {
    final tideSource = File('lib/pages/tide_page.dart').readAsStringSync();
    final synchronizationStart =
        tideSource.indexOf('void _synchronizeActivity()');
    final synchronizationEnd =
        tideSource.indexOf('void _updateClock()', synchronizationStart);
    final synchronizationSource =
        tideSource.substring(synchronizationStart, synchronizationEnd);

    expect(synchronizationSource, contains('if (!_ctrl.isCompleted)'));
    expect(synchronizationSource, contains('_ctrl.value = 1'));
  });
}
