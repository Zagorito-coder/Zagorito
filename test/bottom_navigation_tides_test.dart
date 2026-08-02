import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appShellSource = File('lib/app_shell.dart').readAsStringSync();
  final tidePageSource = File('lib/pages/tide_page.dart').readAsStringSync();
  final speciesPageSource =
      File('lib/pages/species_page.dart').readAsStringSync();

  test('Marées remplace uniquement Poissons à l index fonctionnel 1', () {
    expect(
      appShellSource,
      contains('1 => const TidePage(embeddedInBottomNavigation: true),'),
    );
    expect(appShellSource, contains('0 => HomePageWrapper('));
    expect(appShellSource, contains('2 => MySpotsPage('));
    expect(appShellSource, contains('3 => SpotFinderPage('));
    expect(appShellSource, contains('4 => const SettingsPageWrapper()'));

    expect(appShellSource, contains("'bottom-nav-tides'"));
    expect(appShellSource, contains('Icons.waves_rounded'));
    expect(appShellSource, contains("context.tr('bottomNav.tides')"));
    expect(appShellSource, isNot(contains("'bottom-nav-fish'")));

    final homePosition = appShellSource.indexOf("'bottom-nav-home'");
    final tidesPosition = appShellSource.indexOf("'bottom-nav-tides'");
    final mapPosition = appShellSource.indexOf("'bottom-nav-spots'");
    final mySpotsPosition = appShellSource.indexOf("'bottom-nav-my-spots'");
    final settingsPosition = appShellSource.indexOf("'bottom-nav-settings'");
    expect(
      [homePosition, tidesPosition, mapPosition, mySpotsPosition],
      orderedEquals(
        [homePosition, tidesPosition, mapPosition, mySpotsPosition]..sort(),
      ),
    );
    expect(settingsPosition, greaterThan(mySpotsPosition));
  });

  test('Poissons reste accessible et la carte Accueil Marées ouvre l onglet',
      () {
    expect(
      appShellSource,
      contains(
        'onNavigateToSpecies: () => _goTo(context, const SpeciesPage()),',
      ),
    );
    expect(
      appShellSource,
      contains(
        'onNavigateToTides: () => appShellKey.currentState?.navigateTo(1),',
      ),
    );
    expect(
      speciesPageSource,
      isNot(contains('backToHome: true')),
      reason: 'Poissons est maintenant une route et son bouton doit la fermer.',
    );
    expect(speciesPageSource, contains('int _loadRequestId = 0;'));
    expect(speciesPageSource, contains('requestId != _loadRequestId'));
    expect(speciesPageSource, contains('_error = null;'));
  });

  test('Marées suspend son horloge hors écran et rafraîchit sans doublon', () {
    expect(
      tidePageSource,
      contains('this.embeddedInBottomNavigation = false'),
    );
    expect(
      tidePageSource,
      contains('final isVisible = TickerMode.valuesOf(context).enabled'),
    );
    expect(tidePageSource, contains('WidgetsBindingObserver'));
    expect(tidePageSource, contains('didChangeAppLifecycleState'));
    expect(tidePageSource, contains('_stopClock();'));
    expect(tidePageSource, contains('_clockTimer = null;'));
    expect(
      tidePageSource,
      contains('static const _clockInterval = Duration(minutes: 1);'),
    );
    expect(tidePageSource, isNot(contains('const Duration(seconds: 1)')));
    expect(tidePageSource, isNot(contains('second.toString()')));
    expect(tidePageSource, contains('elapsedInMinute'));
    expect(tidePageSource, contains('_scheduleNextClockTick();'));
    expect(tidePageSource, contains('ValueNotifier<DateTime>'));
    expect(tidePageSource, contains('currentHour: now.hour + now.minute / 60'));
    expect(tidePageSource, contains('if (_loadInProgress) return;'));
    expect(tidePageSource, contains('const Duration(seconds: 12)'));
    expect(tidePageSource, contains('_maybeRefreshData();'));
    expect(tidePageSource, contains('if (!hadUsableData)'));
    expect(
      tidePageSource,
      contains('static const _refreshAfter = Duration(minutes: 15);'),
    );
    expect(
      'if (!widget.embeddedInBottomNavigation)'.allMatches(tidePageSource),
      hasLength(3),
      reason:
          'Le bouton Retour doit disparaître dans les états chargement, normal et erreur.',
    );
  });

  test('le libellé Marées est disponible dans les quatre langues', () {
    const expected = <String, String>{
      'fr': 'Marées',
      'en': 'Tides',
      'es': 'Mareas',
      'ar': 'المد والجزر',
    };

    for (final entry in expected.entries) {
      final payload = jsonDecode(
        File('assets/lang/${entry.key}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final bottomNav = payload['bottomNav'] as Map<String, dynamic>;
      expect(bottomNav['tides'], entry.value, reason: entry.key);
    }
  });
}
