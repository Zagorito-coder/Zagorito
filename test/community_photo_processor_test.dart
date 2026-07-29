import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:spots_app/features/community/models/private_catch.dart';
import 'package:spots_app/features/community/services/community_photo_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('community photos are re-encoded as bounded JPEG files', () async {
    final sourceImage = image.Image(width: 2200, height: 1400);
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
    final result = await const CommunityPhotoProcessor().process(source);

    expect(result.contentType, 'image/jpeg');
    expect(result.bytes.lengthInBytes, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(result.bytes.take(3), [0xff, 0xd8, 0xff]);
    expect(result.width, lessThanOrEqualTo(1920));
    expect(result.height, lessThanOrEqualTo(1920));
  });

  test('community photo processor rejects invalid bytes', () async {
    expect(
      () => const CommunityPhotoProcessor().process(
        Uint8List.fromList([1, 2, 3, 4]),
      ),
      throwsA(isA<PrivateCatchException>()),
    );
  });
}
