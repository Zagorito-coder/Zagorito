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
}
