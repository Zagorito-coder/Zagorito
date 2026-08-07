import 'dart:io';

import 'package:image/image.dart' as image;

const _sourcePath = 'assets/brand/boosterfish_icon_512.png';

double _smoothstep(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

image.Image _extractTransparentLogo(image.Image source) {
  const transparentScore = 30.0;
  const opaqueScore = 72.0;
  const outlineRadius = 2;
  final width = source.width;
  final height = source.height;
  final baseAlpha = List<int>.filled(width * height, 0);

  // Le fond original est bleu nuit alors que la marque est cyan/bleu vif.
  // Ce score chromatique sépare les deux sans recréer ni lisser le dessin.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = source.getPixel(x, y);
      final red = pixel.r.toDouble();
      final green = pixel.g.toDouble();
      final blue = pixel.b.toDouble();
      final chromaScore = ((green - red) + (blue - red)) / 2;
      final alpha = 255 *
          _smoothstep(
            (chromaScore - transparentScore) / (opaqueScore - transparentScore),
          );
      baseAlpha[y * width + x] = alpha.round();
    }
  }

  // Une dilatation très courte conserve les traits bleu nuit du poisson et du
  // bouclier, notamment l'œil et la bouche, sans réintroduire le fond carré.
  final alpha = List<int>.from(baseAlpha);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var strongest = baseAlpha[y * width + x];
      for (var dy = -outlineRadius; dy <= outlineRadius; dy++) {
        final sampleY = y + dy;
        if (sampleY < 0 || sampleY >= height) continue;
        for (var dx = -outlineRadius; dx <= outlineRadius; dx++) {
          final sampleX = x + dx;
          if (sampleX < 0 || sampleX >= width) continue;
          final candidate = baseAlpha[sampleY * width + sampleX];
          if (candidate > strongest) strongest = candidate;
        }
      }
      alpha[y * width + x] = strongest;
    }
  }

  final result = image.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final sourcePixel = source.getPixel(x, y);
      result.setPixelRgba(
        x,
        y,
        sourcePixel.r,
        sourcePixel.g,
        sourcePixel.b,
        alpha[y * width + x],
      );
    }
  }
  return result;
}

image.Image _resize(image.Image source, int size) => image.copyResize(
      source,
      width: size,
      height: size,
      interpolation: image.Interpolation.cubic,
    );

image.Image _withAndroidSafeZone(image.Image source) {
  final contentSize = (source.width * 0.78).round();
  final content = _resize(source, contentSize);
  final canvas = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  image.compositeImage(canvas, content, center: true);
  return canvas;
}

void _writePng(String path, image.Image asset) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(image.encodePng(asset, level: 9));
  stdout.writeln('generated $path (${asset.width}x${asset.height})');
}

void _writeSizes(image.Image source, Map<String, int> destinations) {
  for (final entry in destinations.entries) {
    _writePng(entry.key, _resize(source, entry.value));
  }
}

void _writeWindowsIcon(image.Image source) {
  const sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];
  final icon = _resize(source, sizes.first);
  for (final size in sizes.skip(1)) {
    icon.addFrame(_resize(source, size));
  }
  final file = File('windows/runner/resources/app_icon.ico')
    ..parent.createSync(recursive: true);
  file.writeAsBytesSync(image.encodeIco(icon));
  stdout.writeln('generated ${file.path} (${sizes.length} frames)');
}

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing $_sourcePath');
    exitCode = 2;
    return;
  }
  final source = image.decodePng(sourceFile.readAsBytesSync());
  if (source == null || source.width != 512 || source.height != 512) {
    stderr.writeln('The brand source must be a valid 512x512 PNG.');
    exitCode = 2;
    return;
  }

  final transparentLogo = _extractTransparentLogo(source);
  final androidSafeLogo = _withAndroidSafeZone(transparentLogo);

  // Flutter brand assets.
  _writePng('assets/logo.png', transparentLogo);
  _writePng('assets/launcher_icon.png', _resize(source, 1024));

  // Android legacy launcher icons.
  _writeSizes(source, const {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  });

  // Android adaptive foreground and native launch logo. The transparent
  // canvas already keeps the mark inside the adaptive icon safe zone.
  _writeSizes(androidSafeLogo, const {
    'android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png': 108,
    'android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png': 162,
    'android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png': 216,
    'android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png': 324,
    'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png': 432,
    'android/app/src/main/res/drawable-mdpi/launch_logo.png': 128,
    'android/app/src/main/res/drawable-hdpi/launch_logo.png': 192,
    'android/app/src/main/res/drawable-xhdpi/launch_logo.png': 256,
    'android/app/src/main/res/drawable-xxhdpi/launch_logo.png': 384,
    'android/app/src/main/res/drawable-xxxhdpi/launch_logo.png': 512,
  });

  // iOS launcher and launch-screen assets.
  _writeSizes(source, const {
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png': 50,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png': 100,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png': 57,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png': 114,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png': 72,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png': 144,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
        167,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
        1024,
  });
  // LaunchImage must be transparent, unlike AppIcon.
  _writeSizes(transparentLogo, const {
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png': 168,
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png': 336,
    'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png': 504,
  });

  // macOS, Windows and web icons.
  _writeSizes(source, const {
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png': 16,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png': 32,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png': 64,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png': 128,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png': 256,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png': 512,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png': 1024,
    'web/favicon.png': 32,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  });
  _writeWindowsIcon(source);
}
