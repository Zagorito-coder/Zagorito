import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:spots_app/services/user_spot_photo_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('une photo PNG de spot est normalisée en JPEG de moins de 2 Mo',
      () async {
    final sourceImage = image.Image(width: 1800, height: 1200);
    for (var y = 0; y < sourceImage.height; y += 1) {
      for (var x = 0; x < sourceImage.width; x += 1) {
        sourceImage.setPixelRgba(
          x,
          y,
          x % 256,
          y % 256,
          (x + y) % 256,
          255,
        );
      }
    }
    final source = Uint8List.fromList(image.encodePng(sourceImage));

    final result = await const UserSpotPhotoProcessor().process(source);

    expect(result.contentType, 'image/jpeg');
    expect(result.bytes.lengthInBytes, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(detectUserSpotPhotoContentType(result.bytes), 'image/jpeg');
    expect(result.width, lessThanOrEqualTo(1600));
    expect(result.height, lessThanOrEqualTo(1600));
  });

  test('la détection utilise la signature et non le nom du fichier', () {
    expect(
      detectUserSpotPhotoContentType(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
      ),
      'image/jpeg',
    );
    expect(
      detectUserSpotPhotoContentType(
        Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
        ]),
      ),
      'image/png',
    );
    expect(
      detectUserSpotPhotoContentType(
        Uint8List.fromList([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
      ),
      'image/webp',
    );
  });

  test('des octets non image sont refusés', () async {
    expect(
      () => const UserSpotPhotoProcessor().process(
        Uint8List.fromList([1, 2, 3, 4]),
      ),
      throwsA(isA<UserSpotPhotoException>()),
    );
  });
}
