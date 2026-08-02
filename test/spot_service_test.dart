import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/spot_service.dart';

const _releaseKey = String.fromEnvironment('CSV_ENCRYPTION_KEY');

void main() {
  test(
    'un build sans clé échoue avant de pouvoir réutiliser un cache',
    () async {
      await expectLater(
        SpotService.loadSpots(),
        throwsA(isA<SpotCatalogConfigurationException>()),
      );
    },
    skip: _releaseKey.isNotEmpty,
  );

  testWidgets(
    'le catalogue release embarqué se déchiffre intégralement',
    (tester) async {
      final spots = await tester.runAsync(SpotService.loadSpots);

      expect(spots, hasLength(6365));
      expect(spots!.every((spot) => spot.name.isNotEmpty), isTrue);
      final arabic = RegExp(
        r'[\u0621-\u063A\u0641-\u064A\u066E-\u066F\u0671-\u06D3\u06FA-\u06FC\u06FF]',
      );
      final latin = RegExp(r'[A-Za-z\u00C0-\u024F]');
      expect(
        spots.every(
          (spot) => arabic.hasMatch(spot.name) && latin.hasMatch(spot.name),
        ),
        isTrue,
      );
      expect(spots.every((spot) => spot.fishTypes.isNotEmpty), isTrue);
      expect(spots.every((spot) => spot.notes.trim().isNotEmpty), isTrue);
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

      final coordinateBytes = BytesBuilder(copy: false);
      for (final spot in spots) {
        final pair = ByteData(16)
          ..setFloat64(0, spot.latitude, Endian.big)
          ..setFloat64(8, spot.longitude, Endian.big);
        coordinateBytes.add(pair.buffer.asUint8List());
      }
      expect(
        sha256.convert(coordinateBytes.takeBytes()).toString(),
        'e0688f295348f6cc9ec1da9a9f61d848f88e8005cc1ca7e6daace82cdcddf537',
        reason: 'Les coordonnées ou leur ordre ne doivent jamais changer.',
      );
    },
    // Sans dart-define, le test reste compatible avec un `flutter test`
    // standard. La validation Release l'exécute avec `.env`.
    skip: _releaseKey.isEmpty,
  );
}
