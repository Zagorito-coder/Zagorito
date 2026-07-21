import 'package:flutter/foundation.dart' show kReleaseMode;

/// Configuration centralisée des identifiants publicitaires AdMob.
/// Bascule automatique test/prod basée sur kDebugMode.
class AdConfig {
  AdConfig._();

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
