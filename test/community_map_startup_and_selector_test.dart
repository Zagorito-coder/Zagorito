import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la carte démarre toujours en mode satellite', () {
    final source = File('lib/main.dart').readAsStringSync().replaceAll(
          '\r\n',
          '\n',
        );
    final initStateStart = source.indexOf('void initState()');
    final loadSpots = source.indexOf('    _loadSpots();', initStateStart);

    expect(initStateStart, greaterThanOrEqualTo(0));
    expect(loadSpots, greaterThan(initStateStart));
    final startup = source.substring(initStateStart, loadSpots);

    expect(source, contains('MapStyle _mapStyle = MapStyle.satellite;'));
    expect(
      startup,
      isNot(contains('hasActiveMap')),
      reason:
          'Un fond hors ligne actif ne doit pas remplacer le satellite au démarrage.',
    );
  });

  test('le sélecteur Communauté/Mes prises reste lisible et accessible', () {
    final source = File(
      'lib/pages/community_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(source, contains('height: 64'));
    expect(source, contains('duration: const Duration(milliseconds: 220)'));
    expect(source, contains('colors: [palette.accent, palette.oceanMedium]'));
    expect(source, contains('width: 32'));
    expect(source, contains('fontSize: 14.5'));
  });
}
