import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/shop_service.dart';

void main() {
  group('politique de cache des magasins', () {
    final now = DateTime.utc(2026, 8, 1, 12);

    test('accepte un cache âgé de moins de quatorze jours', () {
      expect(
        ShopService.isCacheTimestampFresh(
          now.subtract(const Duration(days: 13, hours: 23)),
          now: now,
        ),
        isTrue,
      );
    });

    test('refuse un cache ancien ou daté dans le futur', () {
      expect(
        ShopService.isCacheTimestampFresh(
          now.subtract(const Duration(days: 15)),
          now: now,
        ),
        isFalse,
      );
      expect(
        ShopService.isCacheTimestampFresh(
          now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
