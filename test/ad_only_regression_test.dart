import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/providers/premium_provider.dart';

void main() {
  group('Distribution gratuite financée par AdMob', () {
    test('toutes les fonctions historiques restent accessibles sans paiement',
        () async {
      final provider = PremiumProvider();

      await provider.init('test-user');

      expect(provider.hasPremiumAccess, isTrue);
      expect(provider.isPremium, isTrue);
      expect(provider.maxZoom, 16.0);
      expect(provider.isPaidSubscriber, isFalse);
      expect(provider.isOnTrial, isFalse);
    });

    test('une panne météo ne fabrique pas de prévisions', () {
      final fallback = TideData.fallback(location: 'Casablanca');

      expect(fallback.location, 'Casablanca');
      expect(fallback.hourlyPoints, isEmpty);
      expect(fallback.low, 0.0);
      expect(fallback.high, 0.0);
      expect(fallback.waveHeight, 0.0);
    });
  });
}
