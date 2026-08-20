import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;

/// Configuration centralisée des identifiants publicitaires AdMob.
/// Bascule automatique test/prod basée sur kDebugMode.
class AdConfig {
  AdConfig._();

  /// La configuration publiée à ce jour appartient exclusivement à Android.
  /// iOS reste volontairement sans publicité jusqu'à la création de son app
  /// AdMob et de ses unités dédiées. Cela évite d'initialiser le SDK Apple avec
  /// les identifiants Android et ne modifie pas le comportement Android.
  static bool supportsPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android;
  }

  static bool get supportsCurrentPlatform {
    return !kIsWeb && supportsPlatform(defaultTargetPlatform);
  }

  /// App ID principal (identique debug/release)
  static const String appId = 'ca-app-pub-1896524761738024~1931424108';

  // ── Ad Unit IDs ──────────────────────────────────────────────
  // IDs de test officiels Google (debug) vs IDs réels (release)

  /// Bannière adaptive
  static String get bannerAdUnitId => !kReleaseMode
      ? 'ca-app-pub-3940256099942544/6300978111' // test Android
      : 'ca-app-pub-1896524761738024/2747214694';

  /// Interstitiel
  static String get interstitialAdUnitId => !kReleaseMode
      ? 'ca-app-pub-3940256099942544/1033173712' // test Android
      : 'ca-app-pub-1896524761738024/2096598143';

  /// Vidéo récompensée (Rewarded)
  static String get rewardedAdUnitId => !kReleaseMode
      ? 'ca-app-pub-3940256099942544/5224354917' // test Android
      : 'ca-app-pub-1896524761738024/3820743355';
}
