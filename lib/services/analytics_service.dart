import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Mesure d'audience minimale pour la version Android Release.
///
/// BoosterFish ne transmet à Analytics aucun UID Firebase, nom, e-mail,
/// emplacement, nom de spot, texte, photo ou propriété utilisateur. Seuls les
/// événements automatiques du SDK et les noms statiques des cinq onglets
/// principaux sont autorisés.
///
/// Les manifestes refusent par défaut les quatre états du Consent Mode v2.
/// UMP applique le choix réglementaire lorsqu'un formulaire est requis. Dans
/// une région où UMP confirme qu'aucun formulaire n'est requis, seule la
/// mesure Analytics est autorisée ; les usages publicitaires restent refusés.
class AnalyticsService {
  AnalyticsService._();

  static bool _isReady = false;

  @visibleForTesting
  static bool shouldEnableCollection({
    required bool releaseMode,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    return releaseMode && !isWeb && platform == TargetPlatform.android;
  }

  static Future<void> initialize() async {
    final enabled = shouldEnableCollection(
      releaseMode: kReleaseMode,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      _isReady = false;
      return;
    }

    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    _isReady = enabled;
  }

  /// Applique les valeurs conservatrices prévues hors zone réglementée UMP.
  ///
  /// Cette méthode n'est appelée que si UMP retourne `notRequired`. Lorsque
  /// les règles européennes s'appliquent, UMP reste l'unique source du choix
  /// et met lui-même à jour le Consent Mode.
  static Future<void> allowMeasurementOutsideRegulatedRegion() async {
    if (!_isReady) return;

    await FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: true,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
  }

  /// Journalise uniquement un nom d'écran constant défini dans le code.
  static Future<void> logScreenView({required String screenName}) async {
    if (!_isReady) return;
    try {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: screenName,
        screenClass: 'BoosterFishTab',
      );
    } catch (error) {
      // La mesure d'audience ne doit jamais bloquer l'interface.
      debugPrint('[AnalyticsService] Screen view indisponible: $error');
    }
  }
}
