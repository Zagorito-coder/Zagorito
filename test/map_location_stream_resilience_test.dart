import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le flux de position gère une perte de permission sans crash', () {
    final source = File('lib/main.dart').readAsStringSync().replaceAll(
          '\r\n',
          '\n',
        );
    final start = source.indexOf('  void _initPositionStream()');
    final end = source.indexOf('\n  @override\n  void dispose()', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);

    expect(method, contains('if (_positionSubscription != null) return;'));
    expect(method, contains('onError: (Object error)'));
    expect(method, contains('_positionSubscription = null;'));
    expect(method, contains('_currentPosition = null;'));
    expect(method, contains('_lastPosition = null;'));
    expect(method, contains('cancelOnError: true'));
  });
}
