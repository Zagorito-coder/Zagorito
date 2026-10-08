import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

class ProcessedProfileAvatar {
  const ProcessedProfileAvatar({required this.bytes});

  final Uint8List bytes;
  static const width = 512;
  static const height = 512;
  static const contentType = 'image/jpeg';
}

class ProfileAvatarProcessor {
  const ProfileAvatarProcessor();

  static const maximumSourceBytes = 15 * 1024 * 1024;
  static const maximumOutputBytes = 350 * 1024;

  Future<ProcessedProfileAvatar> process(Uint8List source) async {
    if (source.isEmpty || source.lengthInBytes > maximumSourceBytes) {
      throw const FormatException('Invalid profile photo size');
    }
    try {
      final bytes = await compute(_processProfileAvatar, source);
      return ProcessedProfileAvatar(bytes: bytes);
    } catch (error) {
      if (error is FormatException) rethrow;
      throw const FormatException('Unsupported profile photo');
    }
  }
}

Uint8List _processProfileAvatar(Uint8List source) {
  var decoded = image.decodeImage(source);
  if (decoded == null || decoded.width < 2 || decoded.height < 2) {
    throw const FormatException('Unsupported profile photo');
  }
  decoded = image.bakeOrientation(decoded);

  final side = math.min(decoded.width, decoded.height);
  final cropped = image.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = image.copyResize(
    cropped,
    width: ProcessedProfileAvatar.width,
    height: ProcessedProfileAvatar.height,
    interpolation: image.Interpolation.average,
  );

  for (final quality in const [88, 82, 76, 70, 64]) {
    final encoded = Uint8List.fromList(
      image.encodeJpg(resized, quality: quality),
    );
    if (encoded.lengthInBytes <= ProfileAvatarProcessor.maximumOutputBytes) {
      return encoded;
    }
  }
  throw const FormatException('Profile photo cannot be compressed safely');
}
