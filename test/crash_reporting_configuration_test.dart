import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:spots_app/services/crash_reporting_service.dart';

void main() {
  test('Crashlytics est actif uniquement dans le manifeste Release', () {
    final release =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final debug =
        File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
    final profile =
        File('android/app/src/profile/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final macos = File('macos/Runner/Info.plist').readAsStringSync();

    expect(
      release,
      contains('android:name="firebase_crashlytics_collection_enabled"'),
    );
    expect(release, contains('android:value="true"'));
    expect(debug, contains('android:value="false"'));
    expect(profile, contains('android:value="false"'));
    expect(ios, contains('<key>FirebaseCrashlyticsCollectionEnabled</key>'));
    expect(macos, contains('<key>FirebaseCrashlyticsCollectionEnabled</key>'));
    expect(ios, contains('<false/>'));
    expect(macos, contains('<false/>'));
  });

  test('le diagnostic ne reçoit aucune donnée utilisateur personnalisée', () {
    final source =
        File('lib/services/crash_reporting_service.dart').readAsStringSync();

    expect(source, isNot(contains('setUserIdentifier')));
    expect(source, isNot(contains('setCustomKey')));
    expect(source, isNot(contains('FirebaseAnalytics')));
    expect(source, isNot(contains('.log(')));
  });

  test('les messages d exception sont supprimés avant envoi', () {
    final sanitized = CrashReportingService.sanitizeError(
      StateError(
        'https://tiles.example/12/345/678 avec coordonnée et note privée',
      ),
    ).toString();

    expect(sanitized, contains('StateError'));
    expect(sanitized, isNot(contains('tiles.example')));
    expect(sanitized, isNot(contains('coordonnée')));
    expect(sanitized, isNot(contains('note privée')));
  });

  test('une erreur réseau de tuile est reconnue comme récupérable', () {
    final tileStack = StackTrace.fromString(
      'NetworkTileImageProvider._loadImage '
      '(package:flutter_map/src/layer/tile_layer/image_provider.dart:224)',
    );

    expect(
      CrashReportingService.isRecoverableTileNetworkError(
        ClientException('connexion interrompue'),
        tileStack,
      ),
      isTrue,
    );
  });

  test('une erreur réseau étrangère aux tuiles reste diagnostiquée', () {
    final serviceStack = StackTrace.fromString(
      'CommunityRepository.publish '
      '(package:spots_app/features/community/repository.dart:120)',
    );

    expect(
      CrashReportingService.isRecoverableTileNetworkError(
        ClientException('connexion interrompue'),
        serviceStack,
      ),
      isFalse,
    );
  });

  test('une vraie erreur applicative de tuile reste diagnostiquée', () {
    final tileStack = StackTrace.fromString(
      'NetworkTileImageProvider._loadImage '
      '(package:flutter_map/src/layer/tile_layer/image_provider.dart:224)',
    );

    expect(
      CrashReportingService.isRecoverableTileNetworkError(
        StateError('invariant applicatif invalide'),
        tileStack,
      ),
      isFalse,
    );
  });

  test('le SDK et les plugins Gradle officiels sont verrouillés', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(pubspec, contains('firebase_crashlytics: ^5.2.6'));
    expect(
      settings,
      contains(
        'id("com.google.firebase.crashlytics") version("3.0.7") apply false',
      ),
    );
    expect(
      settings,
      contains(
        'id("com.google.gms.google-services") version("4.5.0") apply false',
      ),
    );
    expect(appGradle, contains('id("com.google.firebase.crashlytics")'));
  });
}
