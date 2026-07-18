import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spots_app/config/ad_config.dart';

/// Service singleton gérant l'initialisation AdMob et le préchargement
/// des pubs interstitielles et rewarded.
///
/// Consentement RGPD : en l'absence de UMP SDK séparé, les pubs sont
/// chargées avec `AdRequest` standard. Le paramètre `nonPersonalizedAds`
/// peut être activé via `AdService.useNonPersonalizedAds`.
class AdService {
  static final AdService _instance = AdService._();
  static AdService get instance => _instance;
  AdService._();

  bool _initialized = false;
  bool _consentReady = false;
  Completer<void>? _initCompleter;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  DateTime _lastInterstitialShown = DateTime(2000);

  /// Activer les pubs non personnalisées (RGPD).
  bool useNonPersonalizedAds = false;

  /// Attendre que le SDK soit prêt avant tout chargement de pub.
  Future<void> get ready async {
    if (_consentReady) return;
    _initCompleter ??= Completer<void>();
    await _initCompleter!.future;
  }

  /// Initialise le SDK AdMob. À appeler au démarrage.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _initCompleter = Completer<void>();

    try {
      await MobileAds.instance.initialize();
      debugPrint('[AdService] MobileAds initialized');
    } catch (e) {
      debugPrint('[AdService] Initialization error: $e');
    } finally {
      _consentReady = true;
      _initCompleter?.complete();
    }
  }

  AdRequest get _adRequest => AdRequest(
        nonPersonalizedAds: useNonPersonalizedAds,
      );

  // ═══════════════════════════════════════════════════════════════
  // INTERSTITIEL
  // ═══════════════════════════════════════════════════════════════

  /// Précharge un interstitiel en arrière-plan.
  Future<void> loadInterstitial() async {
    await ready;
    if (_interstitialAd != null) return;

    try {
      await InterstitialAd.load(
        adUnitId: AdConfig.interstitialAdUnitId,
        request: _adRequest,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[AdService] Interstitial loaded');
            _interstitialAd = ad;
            _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (_) {
                _interstitialAd = null;
                loadInterstitial();
              },
              onAdFailedToShowFullScreenContent: (_, error) {
                debugPrint('[AdService] Interstitial show failed: ${error.message}');
                _interstitialAd = null;
                loadInterstitial();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('[AdService] Interstitial load failed: ${error.message}');
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdService] Interstitial load error: $e');
    }
  }

  /// Affiche l'interstitiel si disponible et si le délai minimum est respecté.
  bool showInterstitialIfReady({int minSecondsBetweenAds = 60}) {
    final now = DateTime.now();
    if (now.difference(_lastInterstitialShown).inSeconds < minSecondsBetweenAds) {
      return false;
    }
    if (_interstitialAd == null) return false;

    _interstitialAd!.show();
    _interstitialAd = null;
    _lastInterstitialShown = now;
    loadInterstitial();
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // REWARDED VIDEO
  // ═══════════════════════════════════════════════════════════════

  /// Précharge une vidéo récompensée en arrière-plan.
  Future<void> loadRewarded() async {
    await ready;
    if (_rewardedAd != null) return;

    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedAdUnitId,
        request: _adRequest,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[AdService] Rewarded loaded');
            _rewardedAd = ad;
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (_) {
                _rewardedAd = null;
                loadRewarded();
              },
              onAdFailedToShowFullScreenContent: (_, error) {
                debugPrint('[AdService] Rewarded show failed: ${error.message}');
                _rewardedAd = null;
                loadRewarded();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('[AdService] Rewarded load failed: ${error.message}');
            _rewardedAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdService] Rewarded load error: $e');
    }
  }

  /// Affiche la vidéo récompensée et exécute le callback si le reward est gagné.
  void showRewarded({required VoidCallback onReward}) {
    if (_rewardedAd == null) return;
    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        onReward();
      },
    );
    _rewardedAd = null;
    loadRewarded();
  }

  bool get hasRewardedReady => _rewardedAd != null;

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}