import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le sélecteur poissons adopte le modèle 2 compact et léger', () {
    final source =
        File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final start = source.indexOf('class _FishVerticalMenu');
    final end = source.indexOf('// ══', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final selector = source.substring(start, end);
    expect(selector, contains('static const double _collapsedWidth = 62'));
    expect(selector, contains('static const double _selectedWidth = 184'));
    expect(selector, contains('width: isSelected'));
    expect(selector, contains("'map-fish-tile-\${fish.id}'"));
    expect(selector, contains('BorderRadius.circular(16)'));
    expect(selector, contains('if (isSelected) ...['));
    expect(
        selector, contains('child: Text(\n                        fish.name'));
    expect(selector, contains('RepaintBoundary('));
    expect(selector, contains('ListView.builder('));
    expect(selector, contains('cacheWidth:'));
    expect(selector, isNot(contains('BoxShape.circle')));
    expect(selector, isNot(contains('ClipOval')));
    expect(selector, isNot(contains('fish.scientificName')));
    expect(selector, isNot(contains('BackdropFilter')));
  });
}
