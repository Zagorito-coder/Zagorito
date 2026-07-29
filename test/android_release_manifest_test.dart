import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('le manifeste Release interdit le trafic HTTP en clair', () {
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
  });

  test('aucune permission de localisation arrière-plan n’est déclarée', () {
    expect(
      manifest,
      isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')),
    );
  });

  test('aucune permission notification inutile n’est déclarée', () {
    expect(
      manifest,
      isNot(contains('android.permission.POST_NOTIFICATIONS')),
    );

    final lintConfig = File('android/app/lint.xml').readAsStringSync();
    expect(lintConfig, contains('<issue id="NotificationPermission">'));
    expect(
      lintConfig,
      contains(
        r'com\.baseflow\.geolocator\.location\.BackgroundNotification',
      ),
    );
  });
}
