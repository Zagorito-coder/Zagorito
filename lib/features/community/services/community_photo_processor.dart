import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:spots_app/features/community/models/private_catch.dart';

class ProcessedCommunityPhoto {
  const ProcessedCommunityPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  String get contentType => 'image/jpeg';
}

class CommunityPhotoProcessor {
  const CommunityPhotoProcessor();

  Future<ProcessedCommunityPhoto> process(Uint8List source) async {
    if (source.isEmpty) {
      throw const PrivateCatchException(PrivateCatchFailure.invalidPhoto);
    }
    try {
      final result = await compute(_compressCommunityPhoto, source);
      final bytes = result['bytes'];
      final width = result['width'];
      final height = result['height'];
      if (bytes is! Uint8List || width is! int || height is! int) {
        throw const FormatException('Invalid processed photo');
      }
      return ProcessedCommunityPhoto(
        bytes: bytes,
        width: width,
        height: height,
      );
    } catch (error) {
      if (error is PrivateCatchException) rethrow;
      throw const PrivateCatchException(PrivateCatchFailure.invalidPhoto);
    }
  }
}

Map<String, Object> _compressCommunityPhoto(Uint8List source) {
  var decoded = image.decodeImage(source);
  if (decoded == null || decoded.width < 2 || decoded.height < 2) {
    throw const FormatException('Unsupported image');
  }
  decoded = image.bakeOrientation(decoded);

  const targetLongestEdges = [1920, 1600, 1440, 1280, 1080];
  const qualities = [88, 82, 76, 70, 64];
  image.Image? lastResized;

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
    lastResized = resized;

    for (final quality in qualities) {
      final encoded = Uint8List.fromList(
        image.encodeJpg(resized, quality: quality),
      );
      if (encoded.lengthInBytes <= PrivateCatch.maximumPhotoBytes) {
        return {
          'bytes': encoded,
          'width': resized.width,
          'height': resized.height,
        };
      }
    }
  }

  if (lastResized == null) {
    throw const FormatException('Image processing failed');
  }
  throw const PrivateCatchException(PrivateCatchFailure.invalidPhoto);
}
