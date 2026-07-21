import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spots_app/config/ad_config.dart';
import 'package:spots_app/services/ad_service.dart';

/// Bannière adaptative AdMob. Aucun objet publicitaire n'est créé tant que le
/// statut UMP n'autorise pas les requêtes.
class AdaptiveBannerAd extends StatefulWidget {
  const AdaptiveBannerAd({super.key});

  @override
  State<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends State<AdaptiveBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _generation = 0;
  int _requestedWidth = 0;

  @override
  void initState() {
    super.initState();
    AdService.instance.consentChanges.addListener(_reloadAfterConsentChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) return;

    if (_requestedWidth != 0 && _requestedWidth != width) {
      _generation++;
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      _isLoading = false;
    }
    _requestedWidth = width;
    _loadBanner();
  }

  void _reloadAfterConsentChange() {
    if (!mounted) {
      debugPrint('[AdaptiveBannerAd] reload skip: not mounted');
      return;
    }
    debugPrint('[AdaptiveBannerAd] reload after consent change');
    _generation++;
    _bannerAd?.dispose();
    setState(() {
      _bannerAd = null;
      _isLoaded = false;
      _isLoading = false;
    });
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (_isLoading || _bannerAd != null || _requestedWidth <= 0) {
      debugPrint('[AdaptiveBannerAd] _loadBanner skip: isLoading=$_isLoading hasBanner=${_bannerAd != null} width=$_requestedWidth');
      return;
    }
    debugPrint('[AdaptiveBannerAd] _loadBanner start');
    _isLoading = true;
    final generation = _generation;

    try {
      // Laisse le premier frame attacher l'activité Android avant UMP.
      await WidgetsBinding.instance.endOfFrame;
      await AdService.instance.ready;

      if (!mounted || generation != _generation) {
        _isLoading = false;
        return;
      }
      if (!AdService.instance.adsAllowed) {
        debugPrint('[AdaptiveBannerAd] Publicités désactivées (UMP).');
        _isLoading = false;
        return;
      }

      final size = AdSize.banner;
      if (!mounted || generation != _generation) {
        debugPrint('[AdaptiveBannerAd] _loadBanner aborted: mounted=$mounted gen=$generation currentGen=$_generation');
        _isLoading = false;
        return;
      }

      late final BannerAd banner;
      banner = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        size: size,
        request: AdService.instance.adRequest,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted ||
                generation != _generation ||
                !AdService.instance.adsAllowed ||
                !identical(_bannerAd, ad)) {
              ad.dispose();
              return;
            }
            debugPrint('[AdaptiveBannerAd] Banniere chargee avec succes');
            setState(() => _isLoaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint(
              '[AdaptiveBannerAd] Échec de chargement: ${error.code}',
            );
            ad.dispose();
            if (mounted && identical(_bannerAd, ad)) {
              setState(() {
                _bannerAd = null;
                _isLoaded = false;
              });
            }
          },
        ),
      );
      _bannerAd = banner;
      await banner.load();
    } catch (error) {
      debugPrint('[AdaptiveBannerAd] Bannière indisponible: $error');
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
    } finally {
      debugPrint('[AdaptiveBannerAd] _loadBanner end (success=${_bannerAd != null})');
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    AdService.instance.consentChanges.removeListener(_reloadAfterConsentChange);
    _generation++;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    if (!_isLoaded || banner == null) return const SizedBox.shrink();

    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}
