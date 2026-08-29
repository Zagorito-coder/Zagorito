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

  test('la carte Communauté refuse les caméras non finies', () {
    final source = File(
      'lib/features/community/widgets/community_map_view.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(source, contains('final _mapController = FiniteMapController();'));
    expect(source, contains('if (!camera.zoom.isFinite) return;'));
    expect(source, isNot(contains('final _mapController = MapController();')));
  });

  test('toutes les images Communauté possèdent un fallback local', () {
    final source = File(
      'lib/features/community/widgets/community_map_view.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(source, isNot(contains('CachedNetworkImageProvider(')));
    expect(source, contains('class _CommunityAvatar extends StatelessWidget'));
    expect(
      source,
      contains('class _CommunityImageFallback extends StatelessWidget'),
    );

    final imageCount =
        RegExp(r'CachedNetworkImage\(').allMatches(source).length;
    final errorFallbackCount =
        RegExp(r'errorWidget:').allMatches(source).length;
    expect(errorFallbackCount, imageCount);
  });
}
