import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/models/subscription_model.dart';
import 'package:spots_app/services/subscription_service.dart';

class PremiumProvider extends ChangeNotifier {
  SubscriptionModel? _subscription;
  StreamSubscription<SubscriptionModel>? _streamSub;
  bool _isLoading = false;
  bool _forcePremium = false;

  bool get isLoading => _isLoading;
  bool get isPremium => (kDebugMode && _forcePremium) || (_subscription?.hasPremiumAccess ?? false);
  bool get hasPremiumAccess => (kDebugMode && _forcePremium) || (_subscription?.hasPremiumAccess ?? false);
  bool get isPaidSubscriber => _subscription?.isPaidActive ?? false;
  double get maxZoom => (kDebugMode && _forcePremium) ? 16.0 : (_subscription?.maxZoom ?? 8.0);
  bool get isForcePremium => _forcePremium;
  int get trialDaysRemaining =>
      _subscription?.trialDaysRemaining.clamp(0, 30) ?? 0;
  bool get isOnTrial => _subscription?.isTrialActive ?? false;
  PlanType get planType => _subscription?.planType ?? PlanType.free;

  Future<void> init(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadForcePremium();
      _subscription = await SubscriptionService.getOrCreateSubscription(userId);
      debugPrint('[PremiumProvider] init: userId=$userId plan=${_subscription?.planType} registration=${_subscription?.registrationDate} hasPremium=${_subscription?.hasPremiumAccess}');
      notifyListeners();
      await _streamSub?.cancel();
      _streamSub = SubscriptionService.subscriptionStream(userId).listen(
        (sub) {
          _subscription = sub;
          debugPrint('[PremiumProvider] stream update: userId=$userId plan=${sub.planType} registration=${sub.registrationDate} hasPremium=${sub.hasPremiumAccess}');
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[PremiumProvider] stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[PremiumProvider] Erreur init: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadForcePremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _forcePremium = prefs.getBool('force_premium') ?? false;
    } catch (e) {
      debugPrint('[PremiumProvider] Erreur lecture force_premium: $e');
    }
  }

  Future<void> toggleForcePremium() async {
    _forcePremium = !_forcePremium;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('force_premium', _forcePremium);
    } catch (e) {
      debugPrint('[PremiumProvider] Erreur sauvegarde force_premium: $e');
    }
    notifyListeners();
  }

  void reset() {
    _streamSub?.cancel();
    _streamSub = null;
    _subscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
