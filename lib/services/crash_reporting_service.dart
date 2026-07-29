import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Configure un diagnostic de crash minimal pour les builds Release.
///
/// Aucun identifiant de compte, e-mail, emplacement, nom de spot, texte
/// utilisateur, clé personnalisée ou journal applicatif n'est ajouté aux
/// rapports. Les builds Debug et Profile désactivent explicitement la collecte
/// afin de ne pas polluer les données de production.
class CrashReportingService {
  CrashReportingService._();

  static bool _isReady = false;

  static Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return;
    }

    final isAndroidRelease =
        kReleaseMode && defaultTargetPlatform == TargetPlatform.android;
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(isAndroidRelease);

    if (!isAndroidRelease) return;

    _isReady = true;
    FlutterError.onError = (details) {
      crashlytics.recordFlutterFatalError(
        FlutterErrorDetails(
          exception: sanitizeError(details.exception),
          stack: details.stack,
          library: 'BoosterFish',
          context: ErrorDescription('Uncaught Flutter framework error'),
          silent: details.silent,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        crashlytics.recordError(
          sanitizeError(error),
          stackTrace,
          fatal: true,
        ),
      );
      return true;
    };
  }

  /// Traite les erreurs non gérées capturées par la zone racine.
  ///
  /// Avant l'initialisation Firebase, le comportement historique est conservé :
  /// l'erreur est renvoyée avec sa pile originale. Une fois Crashlytics prêt en
  /// Release, elle est transmise comme erreur fatale sans donnée contextuelle
  /// personnalisée.
  static void handleUncaught(Object error, StackTrace stackTrace) {
    if (!_isReady) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        sanitizeError(error),
        stackTrace,
        fatal: true,
      ),
    );
  }

  /// Retire le message d'exception, qui pourrait contenir une URL de tuile,
  /// une coordonnée ou un texte saisi par l'utilisateur. Le type et la pile
  /// suffisent pour regrouper et diagnostiquer le défaut.
  @visibleForTesting
  static Object sanitizeError(Object error) {
    return StateError('BoosterFish uncaught ${error.runtimeType}');
  }
}
