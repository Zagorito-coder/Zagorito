import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spots_app/config/ad_config.dart';

/// Gère le consentement UMP, puis initialise AdMob uniquement lorsque Google
/// confirme que les publicités peuvent être demandées.
///
/// Une erreur réseau, un refus ou un formulaire indisponible désactive les
/// publicités pour la session sans bloquer le reste de l'application.
class AdService {
  static final AdService _instance = AdService._();
  static AdService get instance => _instance;
  AdService._();

  Future<void>? _initializationFuture;
  bool _mobileAdsInitialized = false;
  bool _adsAllowed = false;
  bool _privacyOptionsRequired = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  DateTime _lastInterstitialShown = DateTime(2000);

  final ValueNotifier<int> _consentRevision = ValueNotifier<int>(0);

  /// Compatibilité : permet de forcer explicitement une requête non
  /// personnalisée. Par défaut, le SDK utilise la décision enregistrée par UMP.
  bool useNonPersonalizedAds = false;

  bool get adsAllowed => _adsAllowed;
  ValueListenable<int> get consentChanges => _consentRevision;

  /// Une seule initialisation peut s'exécuter, même si la bannière et le shell
  /// l'appellent au même moment.
  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> get ready => initialize();

  Future<void> _initialize() async {
    if (kIsWeb) {
      _adsAllowed = false;
      return;
    }

    try {
      await _requestConsentInfoUpdate();
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) {
          debugPrint(
            '[AdService] Formulaire de consentement indisponible '
            '(code ${error.errorCode})',
          );
        }
      });
      await _refreshPrivacyOptionsRequirement();
      await _applyCurrentConsentState();
    } catch (error) {
      // Une erreur UMP ne permet jamais de conclure que l'utilisateur se
      // trouve hors EEE/UK. canRequestAds() reste l'unique source de verite et
      // peut reutiliser un consentement valide obtenu lors d'une session
      // precedente. Sans statut valide, les annonces restent desactivees.
      debugPrint('[AdService] Mise à jour UMP indisponible: $error');
      await _applyCurrentConsentState();
    } finally {
      _consentRevision.value++;
    }
  }

  Future<void> _requestConsentInfoUpdate() async {
    final completer = Completer<void>();

    void complete() {
      if (!completer.isCompleted) completer.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: false),
        complete,
        (error) {
          debugPrint(
            '[AdService] Mise à jour du consentement impossible '
            '(code ${error.errorCode})',
          );
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('UMP consent update ${error.errorCode}'),
            );
          }
        },
      );
    } catch (error) {
      debugPrint('[AdService] Canal UMP indisponible: $error');
      if (!completer.isCompleted) completer.completeError(error);
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('UMP consent update timeout'),
    );
  }

  Future<bool> _canRequestAdsSafely() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      debugPrint('[AdService] Statut UMP illisible: $error');
      return false;
    }
  }

  Future<void> _refreshPrivacyOptionsRequirement() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint(
          '[AdService] Statut des options de confidentialité illisible: $error');
    }
  }

  Future<void> _applyCurrentConsentState() async {
    final canRequestAds = await _canRequestAdsSafely();
    if (!canRequestAds) {
      _adsAllowed = false;
      _disposeFullScreenAds();
      debugPrint('[AdService] Publicités désactivées par le statut UMP');
      return;
    }

    try {
      await _initializeMobileAds();
      _adsAllowed = true;
    } catch (error) {
      _adsAllowed = false;
      _disposeFullScreenAds();
      debugPrint('[AdService] Initialisation Mobile Ads impossible: $error');
    }
  }

  Future<void> _initializeMobileAds() async {
    if (_mobileAdsInitialized) return;
    await MobileAds.instance.initialize();
    _mobileAdsInitialized = true;
    debugPrint('[AdService] Mobile Ads initialisé après consentement UMP');
  }

  /// Indique si Google exige un accès aux options de confidentialité.
  Future<bool> isPrivacyOptionsRequired() async {
    await ready;
    return _privacyOptionsRequired;
  }

  /// Ouvre le formulaire permettant de modifier ou retirer le consentement.
  /// Retourne false lorsque le formulaire n'est pas requis ou n'a pas pu être
  /// affiché.
  Future<bool> showPrivacyOptionsForm() async {
    await ready;
    if (kIsWeb || !_privacyOptionsRequired) return false;

    FormError? formError;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        formError = error;
      });

      await _refreshPrivacyOptionsRequirement();
      // Une publicité préchargée ne doit pas survivre à un changement de
      // consentement. Les widgets bannières seront aussi avertis.
      _disposeFullScreenAds();
      await _applyCurrentConsentState();
      _consentRevision.value++;

      if (formError != null) {
        debugPrint(
          '[AdService] Options de confidentialité non mises à jour '
          '(code ${formError!.errorCode})',
        );
        return false;
      }
      return true;
    } catch (error) {
      _disposeFullScreenAds();
      await _applyCurrentConsentState();
      _consentRevision.value++;
      debugPrint(
          '[AdService] Options de confidentialité indisponibles: $error');
      return false;
    }
  }

  AdRequest get adRequest => useNonPersonalizedAds
      ? const AdRequest(nonPersonalizedAds: true)
      : const AdRequest();

  /// Précharge un interstitiel en arrière-plan.
  Future<void> loadInterstitial() async {
    await ready;
    if (!_adsAllowed || _interstitialAd != null) return;

    try {
      await InterstitialAd.load(
        adUnitId: AdConfig.interstitialAdUnitId,
        request: adRequest,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!_adsAllowed) {
              ad.dispose();
              return;
            }
            debugPrint('[AdService] Interstitiel chargé');
            _interstitialAd = ad;
            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (_) {
                _interstitialAd = null;
                loadInterstitial();
              },
              onAdFailedToShowFullScreenContent: (_, error) {
                debugPrint(
                  '[AdService] Échec affichage interstitiel: ${error.code}',
                );
                _interstitialAd = null;
                loadInterstitial();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              '[AdService] Échec chargement interstitiel: ${error.code}',
            );
            _interstitialAd = null;
          },
        ),
      );
    } catch (error) {
      debugPrint('[AdService] Interstitiel indisponible: $error');
    }
  }

  bool showInterstitialIfReady({int minSecondsBetweenAds = 60}) {
    if (!_adsAllowed) return false;
    final now = DateTime.now();
    if (now.difference(_lastInterstitialShown).inSeconds <
        minSecondsBetweenAds) {
      return false;
    }
    if (_interstitialAd == null) return false;

    _interstitialAd!.show();
    _interstitialAd = null;
    _lastInterstitialShown = now;
    loadInterstitial();
    return true;
  }

  /// Précharge une vidéo récompensée en arrière-plan.
  Future<void> loadRewarded() async {
    await ready;
    if (!_adsAllowed || _rewardedAd != null) return;

    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedAdUnitId,
        request: adRequest,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!_adsAllowed) {
              ad.dispose();
              return;
            }
            debugPrint('[AdService] Vidéo récompensée chargée');
            _rewardedAd = ad;
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (_) {
                _rewardedAd = null;
                loadRewarded();
              },
              onAdFailedToShowFullScreenContent: (_, error) {
                debugPrint(
                  '[AdService] Échec affichage récompensé: ${error.code}',
                );
                _rewardedAd = null;
                loadRewarded();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              '[AdService] Échec chargement récompensé: ${error.code}',
            );
            _rewardedAd = null;
          },
        ),
      );
    } catch (error) {
      debugPrint('[AdService] Vidéo récompensée indisponible: $error');
    }
  }

  void showRewarded({required VoidCallback onReward}) {
    if (!_adsAllowed || _rewardedAd == null) return;
    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('[AdService] Récompense publicitaire accordée');
        onReward();
      },
    );
    _rewardedAd = null;
    loadRewarded();
  }

  bool get hasRewardedReady => _adsAllowed && _rewardedAd != null;

  void _disposeFullScreenAds() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  void dispose() {
    _disposeFullScreenAds();
  }
}
