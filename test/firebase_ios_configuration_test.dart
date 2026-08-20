import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _capture(String source, RegExp pattern, String field) {
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '$field doit être présent.');
  return match!.group(1)!;
}

void main() {
  test('la configuration Flutter iOS correspond au plist Firebase natif', () {
    final dartSource = File('lib/firebase_options.dart').readAsStringSync();
    final plistSource =
        File('ios/Runner/GoogleService-Info.plist').readAsStringSync();

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
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final configuredUrlScheme = _capture(
      infoPlist,
      RegExp(
        r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>([^<]+)</string>',
      ),
      'schéma URL Google iOS',
    );

    expect(flutterAppId, nativeAppId);
    expect(flutterApiKey, nativeApiKey);
    expect(flutterBundleId, nativeBundleId);
    expect(nativeBundleId, 'com.zagorito.boosterfish');
    expect(configuredUrlScheme, nativeReversedClientId);
  });
}
