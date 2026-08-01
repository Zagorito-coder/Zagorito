import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le détail personnel reste lisible et défilable', () {
    final source = File(
      'lib/pages/my_spots_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final start = source.indexOf('class _DetailLine');
    final end = source.indexOf('class _FavoriteShelfCard', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final personalDetails = source.substring(start, end);

    expect(personalDetails, contains('fontSize: 13'));
    expect(personalDetails, contains('fontSize: 16'));
    expect(personalDetails, contains('fontSize: 11'));
    expect(personalDetails, contains('Scrollbar('));
    expect(personalDetails, contains('SingleChildScrollView('));
    expect(personalDetails, contains('BouncingScrollPhysics()'));
  });

  test('le bouton Ajouter un spot reste compact sans rogner son texte', () {
    final source = File(
      'lib/pages/my_spots_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final start = source.indexOf("'add-personal-spot-from-shelf'");
    final end = source.indexOf('class _SpotPreviewTile', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final addButton = source.substring(start, end);

    expect(addButton, contains('minimumSize: const Size(0, 36)'));
    expect(addButton, contains('MaterialTapTargetSize.shrinkWrap'));
    expect(addButton, contains('fontSize: 13.5'));
    expect(addButton, contains('height: 1.05'));
    expect(addButton, contains('size: 19'));
  });

  test('la fiche laisse environ la moitié de l écran à la carte', () {
    final source = File(
      'lib/pages/my_spots_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(source, contains('constraints.maxHeight * 0.55'));
    expect(source, contains('(mapHeight - 14)'));
    expect(source, contains('(mapHeight - 48)'));
    expect(source, isNot(contains('mapHeight - 92')));
    expect(source, contains('width: 136'));
    expect(source, contains('height: 29'));
    expect(source, contains('padding: const EdgeInsets.all(5)'));
    expect(source, contains("'clear-shelf-selection'"));
  });
}
