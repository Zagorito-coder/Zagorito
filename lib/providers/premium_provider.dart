import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Compatibilité : l'app est 100% gratuite (AdMob). Cette classe ne fait rien.
class PremiumProvider extends ChangeNotifier {
  bool get isLoading => false;
  bool get isPremium => true;
  bool get hasPremiumAccess => true;
  bool get isPaidSubscriber => false;
  double get maxZoom => 16.0;
  bool get isForcePremium => false;
  int get trialDaysRemaining => 0;
  bool get isOnTrial => false;

  Future<void> init(String userId) async {}
  Future<void> toggleForcePremium() async {}
  void reset() => notifyListeners();
}
