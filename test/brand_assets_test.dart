import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

image.Image _png(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Asset absent: $path');
  final decoded = image.decodePng(file.readAsBytesSync());
  expect(decoded, isNotNull, reason: 'PNG invalide: $path');
  return decoded!;
}

void _expectSize(String path, int size) {
  final asset = _png(path);
  expect(asset.width, size, reason: path);
  expect(asset.height, size, reason: path);
}

({double width, double height}) _visibleBoundsRatio(image.Image asset) {
  var minX = asset.width;
  var minY = asset.height;
  var maxX = -1;
  var maxY = -1;
  for (final pixel in asset) {
    if (pixel.a.toInt() <= 16) continue;
    if (pixel.x < minX) minX = pixel.x;
    if (pixel.y < minY) minY = pixel.y;
    if (pixel.x > maxX) maxX = pixel.x;
    if (pixel.y > maxY) maxY = pixel.y;
  }
  expect(maxX, greaterThanOrEqualTo(minX));
  expect(maxY, greaterThanOrEqualTo(minY));
  return (
    width: (maxX - minX + 1) / asset.width,
    height: (maxY - minY + 1) / asset.height,
  );
}

void main() {
  test('la source de marque validée reste inchangée', () {
    final source = File('assets/brand/boosterfish_icon_512.png');
    expect(source.existsSync(), isTrue);
    expect(
      sha256.convert(source.readAsBytesSync()).toString(),
      '609fff074b102336e875655b2d09ea5c42ed3837f3ec74550c8e8cbe68caa5db',
    );
    _expectSize(source.path, 512);
  });

  test('le logo Flutter est détouré et conserve un sujet visible', () {
    final logo = _png('assets/logo.png');
    expect(logo.width, 512);
    expect(logo.height, 512);
    expect(logo.numChannels, 4);
    expect(logo.getPixel(0, 0).a, 0);
    expect(logo.getPixel(511, 511).a, 0);

    var transparent = 0;
    var opaque = 0;
    for (final pixel in logo) {
      final alpha = pixel.a.toInt();
      if (alpha == 0) transparent++;
      if (alpha >= 250) opaque++;
    }
    final total = logo.width * logo.height;
    expect(transparent / total, greaterThan(0.70));
    expect(opaque / total, inInclusiveRange(0.10, 0.30));
  });

  test('les icônes launcher principales ont les dimensions attendues', () {
    _expectSize('assets/launcher_icon.png', 1024);
    _expectSize(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
      'Icon-App-1024x1024@1x.png',
      1024,
    );
    _expectSize(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
      1024,
    );
    _expectSize('web/icons/Icon-512.png', 512);

    final launcher = _png('assets/launcher_icon.png');
    expect(launcher.every((pixel) => pixel.a.toInt() == 255), isTrue);
  });

  test('les densités Android utilisent la nouvelle marque', () {
    const legacy = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    const adaptive = {
      'drawable-mdpi': 108,
      'drawable-hdpi': 162,
      'drawable-xhdpi': 216,
      'drawable-xxhdpi': 324,
      'drawable-xxxhdpi': 432,
    };
    for (final entry in legacy.entries) {
      _expectSize(
        'android/app/src/main/res/${entry.key}/ic_launcher.png',
        entry.value,
      );
    }
    for (final entry in adaptive.entries) {
      final path =
          'android/app/src/main/res/${entry.key}/ic_launcher_foreground.png';
      _expectSize(path, entry.value);
      final foreground = _png(path);
      expect(foreground.getPixel(0, 0).a, 0, reason: path);
      final bounds = _visibleBoundsRatio(foreground);
      expect(bounds.width, lessThanOrEqualTo(0.56), reason: path);
      expect(bounds.height, lessThanOrEqualTo(0.62), reason: path);
    }
  });

  test('les splash natifs affichent le logo transparent', () {
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final android12Style = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    expect(launchBackground, contains('@drawable/launch_logo'));
    expect(android12Style, contains('windowSplashScreenAnimatedIcon'));
    expect(android12Style, contains('@drawable/launch_logo'));

    final androidColors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    final splashSource = File('lib/splash_bootstrap.dart').readAsStringSync();
    expect(androidColors, contains('<color name="splash_background">#071529'));
    expect(splashSource, contains('backgroundColor: const Color(0xFF071529)'));
    expect(splashSource, contains('width: 132'));

    const launchSizes = {
      'drawable-mdpi': 128,
      'drawable-hdpi': 192,
      'drawable-xhdpi': 256,
      'drawable-xxhdpi': 384,
      'drawable-xxxhdpi': 512,
    };
    for (final entry in launchSizes.entries) {
      final path = 'android/app/src/main/res/${entry.key}/launch_logo.png';
      _expectSize(path, entry.value);
      expect(_png(path).getPixel(0, 0).a, 0, reason: path);
    }

    final iosLaunch = _png(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
    );
    expect(iosLaunch.width, 504);
    expect(iosLaunch.height, 504);
    expect(iosLaunch.getPixel(0, 0).a, 0);
  });
}
