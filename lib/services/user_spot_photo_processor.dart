import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:spots_app/models/user_spot.dart';

enum UserSpotPhotoFailure { invalid, tooLarge }

class UserSpotPhotoException implements Exception {
  const UserSpotPhotoException(this.failure);

  final UserSpotPhotoFailure failure;
}

class ProcessedUserSpotPhoto {
  const ProcessedUserSpotPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  String get contentType => 'image/jpeg';
}

class UserSpotPhotoProcessor {
  const UserSpotPhotoProcessor();

  static const maximumSourceBytes = 20 * 1024 * 1024;

  Future<ProcessedUserSpotPhoto> process(Uint8List source) async {
    if (source.isEmpty || source.lengthInBytes > maximumSourceBytes) {
      throw const UserSpotPhotoException(UserSpotPhotoFailure.tooLarge);
    }
    try {
      final result = await compute(_compressUserSpotPhoto, source);
      final bytes = result['bytes'];
      final width = result['width'];
      final height = result['height'];
      if (bytes is! Uint8List || width is! int || height is! int) {
        throw const FormatException('Invalid processed spot photo');
      }
      return ProcessedUserSpotPhoto(
        bytes: bytes,
        width: width,
        height: height,
      );
    } on UserSpotPhotoException {
      rethrow;
    } catch (_) {
      throw const UserSpotPhotoException(UserSpotPhotoFailure.invalid);
    }
  }
}

String? detectUserSpotPhotoContentType(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= pngSignature.length) {
    var matches = true;
    for (var index = 0; index < pngSignature.length; index += 1) {
      if (bytes[index] != pngSignature[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

Map<String, Object> _compressUserSpotPhoto(Uint8List source) {
  var decoded = image.decodeImage(source);
  if (decoded == null || decoded.width < 2 || decoded.height < 2) {
    throw const FormatException('Unsupported spot photo');
  }
  decoded = image.bakeOrientation(decoded);

  const targetLongestEdges = [1600, 1440, 1280, 1080, 900];
  const qualities = [86, 80, 74, 68, 62];

  for (final targetLongest in targetLongestEdges) {
    final longest = math.max(decoded.width, decoded.height);
    final scale = math.min(1.0, targetLongest / longest);
    final width = math.max(1, (decoded.width * scale).round());
    final height = math.max(1, (decoded.height * scale).round());
    final resized = width == decoded.width && height == decoded.height
        ? decoded
        : image.copyResize(
            decoded,
            width: width,
            height: height,
            interpolation: image.Interpolation.average,
          );

    for (final quality in qualities) {
      final encoded = Uint8List.fromList(
        image.encodeJpg(resized, quality: quality),
      );
      if (encoded.lengthInBytes <= UserSpot.maximumPhotoBytes) {
        return {
          'bytes': encoded,
          'width': resized.width,
          'height': resized.height,
        };
      }
    }
  }

  throw const UserSpotPhotoException(UserSpotPhotoFailure.tooLarge);
}
