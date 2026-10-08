import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android active le bord à bord avec l’API AndroidX moderne', () {
    final activity = File(
      'android/app/src/main/kotlin/com/zagorito/spots_app/MainActivity.kt',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(activity, contains('WindowCompat.enableEdgeToEdge(window)'));
    expect(activity, isNot(contains('setDecorFitsSystemWindows')));
    expect(gradle, contains('androidx.core:core-ktx:1.17.0'));
    expect(gradle, contains('force("androidx.core:core:1.17.0")'));
  });

  test('le code Flutter ne configure plus les couleurs système obsolètes', () {
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(dartSources, isNot(contains('statusBarColor:')));
    expect(dartSources, isNot(contains('systemNavigationBarColor:')));
    expect(dartSources, isNot(contains('setEnabledSystemUIMode')));
  });
}
