import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le chargement du catalogue notifie le rendu des spots visibles', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('void _updateVisibleSpots()');
    final end = source.indexOf('void _applyBoundsFilter', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final method = source.substring(start, end);
    expect(method, contains('setState(() => _applyBoundsFilter(bounds))'));
  });
}
