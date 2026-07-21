import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/spot_service.dart';

const _releaseKey = String.fromEnvironment('CSV_ENCRYPTION_KEY');

void main() {
  testWidgets(
    'le catalogue release embarqué se déchiffre intégralement',
    (tester) async {
      final spots = await tester.runAsync(SpotService.loadSpots);

      expect(spots, hasLength(6365));
      expect(spots!.every((spot) => spot.name.isNotEmpty), isTrue);
      expect(spots.every((spot) => spot.latitude.isFinite), isTrue);
      expect(spots.every((spot) => spot.longitude.isFinite), isTrue);
      expect(
        spots.every(
          (spot) =>
              spot.latitude >= -90 &&
              spot.latitude <= 90 &&
              spot.longitude >= -180 &&
              spot.longitude <= 180,
        ),
        isTrue,
      );
    },
    // Sans dart-define, le test reste compatible avec un `flutter test`
    // standard. La validation Release l'exécute avec `.env`.
    skip: _releaseKey.isEmpty,
  );
}
