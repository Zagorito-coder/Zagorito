import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _sourceDirectory = 'assets/fish_images';
const _outputDirectory = 'assets/fish_selector_thumbnails';
const _catalogPath = 'assets/fish_data.json';
const _canvasWidth = 320;
const _canvasHeight = 220;
const _contentWidth = 292;
const _contentHeight = 184;

void main() {
  final sourceDirectory = Directory(_sourceDirectory);
  if (!sourceDirectory.existsSync()) {
    stderr.writeln('Dossier source introuvable: $_sourceDirectory');
    exitCode = 1;
    return;
  }

  final catalogFile = File(_catalogPath);
  if (!catalogFile.existsSync()) {
    stderr.writeln('Catalogue poissons introuvable: $_catalogPath');
    exitCode = 1;
    return;
  }
  final catalog = (jsonDecode(catalogFile.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final sourcePaths = catalog
      .map((entry) => entry['imageUrl'] as String)
      .where((path) => path.startsWith('$_sourceDirectory/'))
      .toSet()
      .toList()
    ..sort();

  final outputDirectory = Directory(_outputDirectory)
    ..createSync(recursive: true);
  for (final oldThumbnail in outputDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.png'))) {
    oldThumbnail.deleteSync();
  }

  var generated = 0;
  for (final sourcePath in sourcePaths) {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      stderr.writeln('Image catalogue introuvable: $sourcePath');
      exitCode = 1;
      return;
    }
    final decoded = img.decodePng(source.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('PNG invalide: ${source.path}');
      exitCode = 1;
      return;
    }

    final thumbnail = _buildThumbnail(decoded);
    final fileName = source.uri.pathSegments.last;
    File('${outputDirectory.path}/$fileName')
        .writeAsBytesSync(img.encodePng(thumbnail, level: 9));
    generated++;
  }

  stdout.writeln('$generated vignettes générées dans $_outputDirectory');
}

img.Image _buildThumbnail(img.Image source) {
  final rgba = source.convert(format: img.Format.uint8, numChannels: 4);
  final width = rgba.width;
  final height = rgba.height;
  final background = Uint8List(width * height);
  final queue = ListQueue<int>();

  void enqueueIfBackground(int x, int y) {
    final index = y * width + x;
    if (background[index] != 0 || !_isWhiteBackdrop(rgba.getPixel(x, y))) {
      return;
    }
    background[index] = 1;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    enqueueIfBackground(x, 0);
    enqueueIfBackground(x, height - 1);
  }
  for (var y = 1; y < height - 1; y++) {
    enqueueIfBackground(0, y);
    enqueueIfBackground(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final x = index % width;
    final y = index ~/ width;
    if (x > 0) enqueueIfBackground(x - 1, y);
    if (x + 1 < width) enqueueIfBackground(x + 1, y);
    if (y > 0) enqueueIfBackground(x, y - 1);
    if (y + 1 < height) enqueueIfBackground(x, y + 1);
  }

  for (var index = 0; index < background.length; index++) {
    if (background[index] == 0) continue;
    rgba.setPixelRgba(index % width, index ~/ width, 0, 0, 0, 0);
  }

  _softenMatte(rgba, background);
  final bounds = _opaqueBounds(rgba);
  if (bounds == null) {
    throw StateError('Aucun sujet détecté dans une image poisson.');
  }

  final cropped = img.copyCrop(
    rgba,
    x: bounds.$1,
    y: bounds.$2,
    width: bounds.$3 - bounds.$1 + 1,
    height: bounds.$4 - bounds.$2 + 1,
  );
  final scale = math.min(
    _contentWidth / cropped.width,
    _contentHeight / cropped.height,
  );
  final resized = img.copyResize(
    cropped,
    width: math.max(1, (cropped.width * scale).round()),
    height: math.max(1, (cropped.height * scale).round()),
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(
    width: _canvasWidth,
    height: _canvasHeight,
    format: img.Format.uint8,
    numChannels: 4,
  );
  return img.compositeImage(canvas, resized, center: true);
}

bool _isWhiteBackdrop(img.Pixel pixel) {
  final red = pixel.r.toInt();
  final green = pixel.g.toInt();
  final blue = pixel.b.toInt();
  final minimum = math.min(red, math.min(green, blue));
  final maximum = math.max(red, math.max(green, blue));
  return minimum >= 224 && maximum - minimum <= 42;
}

void _softenMatte(img.Image image, Uint8List background) {
  final width = image.width;
  final height = image.height;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final index = y * width + x;
      if (background[index] != 0) continue;
      final touchesBackground = background[index - 1] != 0 ||
          background[index + 1] != 0 ||
          background[index - width] != 0 ||
          background[index + width] != 0;
      if (!touchesBackground) continue;

      final pixel = image.getPixel(x, y);
      final minimum = math.min(
        pixel.r.toInt(),
        math.min(pixel.g.toInt(), pixel.b.toInt()),
      );
      final maximum = math.max(
        pixel.r.toInt(),
        math.max(pixel.g.toInt(), pixel.b.toInt()),
      );
      if (minimum < 185 || maximum - minimum > 58) continue;
      final alpha = (((224 - minimum) / 39) * 255).round().clamp(40, 230);
      image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, alpha);
    }
  }
}

(int, int, int, int)? _opaqueBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a.toInt() <= 12) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  return maxX < 0 ? null : (minX, minY, maxX, maxY);
}
