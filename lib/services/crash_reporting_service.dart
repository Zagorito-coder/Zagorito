import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;

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
      if (isRecoverableTileNetworkError(
        details.exception,
        details.stack,
      )) {
        return;
      }
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
      if (isRecoverableTileNetworkError(error, stackTrace)) return true;
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
    if (isRecoverableTileNetworkError(error, stackTrace)) return;
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

  /// Reconnaît uniquement une panne du client HTTP déclenchée par le chargeur
  /// de tuiles de flutter_map. `_ClientSocketException`, le type observé dans
  /// Crashlytics, hérite de [ClientException] : aucun accès à son type privé
  /// n'est nécessaire.
  ///
  /// Le type réseau seul ne suffit volontairement pas. La pile doit aussi
  /// désigner `NetworkTileImageProvider`, afin qu'une erreur HTTP provenant de
  /// l'authentification, de Firestore ou d'un autre service reste diagnostiquée.
  @visibleForTesting
  static bool isRecoverableTileNetworkError(
    Object error,
    StackTrace? stackTrace,
  ) {
    if (error is! ClientException || stackTrace == null) return false;
    return stackTrace.toString().contains('NetworkTileImageProvider');
  }

  /// Retire le message d'exception, qui pourrait contenir une URL de tuile,
  /// une coordonnée ou un texte saisi par l'utilisateur. Le type et la pile
  /// suffisent pour regrouper et diagnostiquer le défaut.
  @visibleForTesting
  static Object sanitizeError(Object error) {
    return StateError('BoosterFish uncaught ${error.runtimeType}');
  }
}
