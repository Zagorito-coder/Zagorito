import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le build Release protège WorkManager contre la version 2.7 obsolète',
      () {
    final gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(
      gradle,
      contains('force("androidx.work:work-runtime:2.11.2")'),
    );
    expect(
      gradle,
      isNot(contains('force("androidx.work:work-runtime:2.7.0")')),
    );
  });

  test('le build Android refuse une configuration CARTO absente', () {
    final gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(gradle, contains('CARTO_BASEMAP_API_KEY='));
    expect(
      gradle,
      contains('Build Android refuse : CARTO_BASEMAP_API_KEY est absente.'),
    );
  });
}
