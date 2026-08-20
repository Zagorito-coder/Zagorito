import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/config/ad_config.dart';

void main() {
  group('Préparation native iOS', () {
    test('le nom affiché est BoosterFish', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plist,
        contains(
          '<key>CFBundleDisplayName</key>\n\t<string>BoosterFish</string>',
        ),
      );
      expect(plist, isNot(contains('<string>Spots App</string>')));
    });

    test('les autorisations système existent dans les quatre langues', () {
      for (final language in const ['fr', 'en', 'ar', 'es']) {
        final file = File('ios/Runner/$language.lproj/InfoPlist.strings');
        expect(file.existsSync(), isTrue, reason: 'Langue native $language');

        final source = file.readAsStringSync();
        expect(source, contains('CFBundleDisplayName'));
        expect(source, contains('NSLocationWhenInUseUsageDescription'));
        expect(source, contains('NSPhotoLibraryUsageDescription'));
        expect(source, contains('NSCameraUsageDescription'));
      }
    });

    test('la configuration Firebase iOS est embarquée dans Runner', () {
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      expect(File('ios/Runner/GoogleService-Info.plist').existsSync(), isTrue);
      expect(
        project,
        contains('GoogleService-Info.plist in Resources'),
      );
    });

    test('toutes les icônes App Store sont opaques', () {
      final iconDirectory =
          Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final icons = iconDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList();

      expect(icons, isNotEmpty);
      for (final icon in icons) {
        final bytes = icon.readAsBytesSync();
        expect(bytes.length, greaterThan(25), reason: icon.path);
        // Octet « color type » de l'en-tête PNG : 2 = RGB sans alpha.
        expect(bytes[25], equals(2), reason: '${icon.path} contient un alpha');
      }
    });

    test('les identifiants AdMob Android ne sont jamais utilisés sur iOS', () {
      expect(AdConfig.supportsPlatform(TargetPlatform.android), isTrue);
      expect(AdConfig.supportsPlatform(TargetPlatform.iOS), isFalse);
      expect(AdConfig.supportsPlatform(TargetPlatform.macOS), isFalse);
    });
  });
}
