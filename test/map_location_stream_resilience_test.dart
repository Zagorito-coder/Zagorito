import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le flux de position gère une perte de permission sans crash', () {
    final source = File('lib/main.dart').readAsStringSync().replaceAll(
          '\r\n',
          '\n',
        );
    final signature = RegExp(
      r'void\s+_initPositionStream\s*\(\s*\{\s*bool\s+'
      r'startedForCompass\s*=\s*false\s*\}\s*\)',
    ).firstMatch(source);

    expect(
      signature,
      isNotNull,
      reason:
          'Le flux doit conserver son paramètre nommé de propriété boussole.',
    );
    final start = signature!.start;
    final end = source.indexOf('\n  @override\n  void dispose()', start);
    expect(end, greaterThan(start));
    final method = source.substring(start, end);

    expect(method, contains('if (_positionSubscription != null) {'));
    expect(
      method,
      contains(
          'if (!startedForCompass) _positionStreamStartedForCompass = false;'),
    );
    expect(method, contains('onError: (Object error)'));
    expect(method, contains('_positionSubscription = null;'));
    expect(method, contains('_currentPosition = null;'));
    expect(method, contains('_lastPosition = null;'));
    expect(method, contains('cancelOnError: true'));
  });
}
