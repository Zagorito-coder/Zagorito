import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/optional_update_service.dart';

void main() {
  group('OptionalUpdateService.shouldOfferUpdate', () {
    test('offers an enabled update when a newer build exists', () {
      expect(
        OptionalUpdateService.shouldOfferUpdate(
          enabled: true,
          currentBuild: 16,
          latestBuild: 17,
        ),
        isTrue,
      );
    });

    test('does not offer an update for the current build', () {
      expect(
        OptionalUpdateService.shouldOfferUpdate(
          enabled: true,
          currentBuild: 17,
          latestBuild: 17,
        ),
        isFalse,
      );
    });

    test('does not offer a disabled update', () {
      expect(
        OptionalUpdateService.shouldOfferUpdate(
          enabled: false,
          currentBuild: 16,
          latestBuild: 17,
        ),
        isFalse,
      );
    });

    test('does not offer an update when the installed build is unknown', () {
      expect(
        OptionalUpdateService.shouldOfferUpdate(
          enabled: true,
          currentBuild: 0,
          latestBuild: 17,
        ),
        isFalse,
      );
    });
  });
}
