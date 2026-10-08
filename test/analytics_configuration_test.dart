import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/analytics_service.dart';

void main() {
  group('Configuration Google Analytics', () {
    test('la collecte applicative est réservée à Android Release', () {
      expect(
        AnalyticsService.shouldEnableCollection(
          releaseMode: true,
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );

      for (final platform in const [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          AnalyticsService.shouldEnableCollection(
            releaseMode: true,
            isWeb: false,
            platform: platform,
          ),
          isFalse,
        );
      }

      expect(
        AnalyticsService.shouldEnableCollection(
          releaseMode: false,
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        AnalyticsService.shouldEnableCollection(
          releaseMode: true,
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('le SDK et les garde-fous natifs sont verrouillés', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final release =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final debug =
          File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
      final profile = File('android/app/src/profile/AndroidManifest.xml')
          .readAsStringSync();
      final ios = File('ios/Runner/Info.plist').readAsStringSync();
      final macos = File('macos/Runner/Info.plist').readAsStringSync();

      expect(pubspec, contains('firebase_analytics: 12.4.5'));
      expect(release, contains('firebase_analytics_collection_enabled'));
      expect(release, contains('google_analytics_adid_collection_enabled'));
      expect(
        release,
        contains('google_analytics_default_allow_analytics_storage'),
      );
      expect(release, contains('google_analytics_default_allow_ad_storage'));
      expect(release, contains('google_analytics_default_allow_ad_user_data'));
      expect(
        release,
        contains(
          'google_analytics_default_allow_ad_personalization_signals',
        ),
      );
      expect(
        'android:value="false"'.allMatches(release).length,
        greaterThanOrEqualTo(5),
      );
      expect(debug, contains('firebase_analytics_collection_enabled'));
      expect(profile, contains('firebase_analytics_collection_enabled'));
      expect(ios, contains('FIREBASE_ANALYTICS_COLLECTION_ENABLED'));
      expect(macos, contains('FIREBASE_ANALYTICS_COLLECTION_ENABLED'));
      expect(ios, contains('<false/>'));
      expect(macos, contains('<false/>'));
    });

    test('Firebase et Analytics précèdent le démarrage UMP', () {
      final splash = File('lib/splash_bootstrap.dart').readAsStringSync();
      final shell = File('lib/app_shell.dart').readAsStringSync();
      final firebase = splash.indexOf('await Firebase.initializeApp');
      final analytics = splash.indexOf('await _initializeAnalyticsSafely();');

      expect(firebase, greaterThanOrEqualTo(0));
      expect(analytics, greaterThan(firebase));
      expect(splash, contains('await AnalyticsService.initialize();'));
      expect(shell, contains('AdService.instance.initialize()'));
      expect(shell, contains('addPostFrameCallback'));
    });

    test('aucune identité ni donnée métier n est envoyée', () {
      final analytics =
          File('lib/services/analytics_service.dart').readAsStringSync();
      final shell = File('lib/app_shell.dart').readAsStringSync();

      expect(analytics, isNot(contains('setUserId')));
      expect(analytics, isNot(contains('setUserProperty')));
      expect(analytics, isNot(contains('setDefaultEventParameters')));
      expect(analytics, isNot(contains('logEvent')));
      expect(analytics, contains('logScreenView'));
      for (final screen in const [
        "'home'",
        "'tides'",
        "'my_spots'",
        "'map'",
        "'settings'",
      ]) {
        expect(shell, contains(screen));
      }
    });

    test('hors zone réglementée seule la mesure est autorisée', () {
      final analytics =
          File('lib/services/analytics_service.dart').readAsStringSync();
      final ads = File('lib/services/ad_service.dart').readAsStringSync();

      expect(ads, contains('ConsentStatus.notRequired'));
      expect(
        ads,
        contains('allowMeasurementOutsideRegulatedRegion'),
      );
      expect(analytics, contains('analyticsStorageConsentGranted: true'));
      expect(analytics, contains('adStorageConsentGranted: false'));
      expect(analytics, contains('adUserDataConsentGranted: false'));
      expect(
        analytics,
        contains('adPersonalizationSignalsConsentGranted: false'),
      );
    });
  });
}
