import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _capture(String source, RegExp pattern, String field) {
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '$field doit être présent.');
  return match!.group(1)!;
}

void main() {
  test('la configuration Flutter iOS est complète et cohérente', () {
    final dartSource = File('lib/firebase_options.dart').readAsStringSync();

    final iosBlock = _capture(
      dartSource,
      RegExp(
        r'static const FirebaseOptions ios = FirebaseOptions\((.*?)\n  \);',
        dotAll: true,
      ),
      'La section FirebaseOptions iOS',
    );

    final flutterAppId = _capture(
      iosBlock,
      RegExp(r"appId: '([^']+)'"),
      'appId iOS Flutter',
    );
    final flutterApiKey = _capture(
      iosBlock,
      RegExp(r"apiKey: '([^']+)'"),
      'clé API iOS Flutter',
    );
    final flutterBundleId = _capture(
      iosBlock,
      RegExp(r"iosBundleId: '([^']+)'"),
      'Bundle ID iOS Flutter',
    );
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final configuredUrlScheme = _capture(
      infoPlist,
      RegExp(
        r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>([^<]+)</string>',
      ),
      'schéma URL Google iOS',
    );

    expect(flutterAppId, matches(RegExp(r'^1:\d+:ios:[0-9a-f]+$')));
    expect(flutterApiKey, isNotEmpty);
    expect(flutterBundleId, 'com.zagorito.boosterfish');
    expect(
      configuredUrlScheme,
      matches(RegExp(r'^com\.googleusercontent\.apps\.[A-Za-z0-9-]+$')),
    );

    // Le vrai fichier natif reste volontairement hors du dépôt public. Sur le
    // Mac de release, où il est présent, on compare aussi chaque valeur afin
    // d'empêcher toute divergence entre Flutter, Firebase et Xcode.
    final nativePlist = File('ios/Runner/GoogleService-Info.plist');
    if (!nativePlist.existsSync()) {
      return;
    }
    final plistSource = nativePlist.readAsStringSync();
    final nativeAppId = _capture(
      plistSource,
      RegExp(r'<key>GOOGLE_APP_ID</key>\s*<string>([^<]+)</string>'),
      'GOOGLE_APP_ID natif',
    );
    final nativeApiKey = _capture(
      plistSource,
      RegExp(r'<key>API_KEY</key>\s*<string>([^<]+)</string>'),
      'API_KEY native',
    );
    final nativeBundleId = _capture(
      plistSource,
      RegExp(r'<key>BUNDLE_ID</key>\s*<string>([^<]+)</string>'),
      'BUNDLE_ID natif',
    );
    final nativeReversedClientId = _capture(
      plistSource,
      RegExp(r'<key>REVERSED_CLIENT_ID</key>\s*<string>([^<]+)</string>'),
      'REVERSED_CLIENT_ID natif',
    );

    expect(flutterAppId, nativeAppId);
    expect(flutterApiKey, nativeApiKey);
    expect(flutterBundleId, nativeBundleId);
    expect(configuredUrlScheme, nativeReversedClientId);
  });
}
