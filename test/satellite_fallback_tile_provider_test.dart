import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spots_app/services/satellite_fallback_tile_provider.dart';

void main() {
  test('calcule les parents exacts Z18 vers Z17 puis Z16', () {
    const david = TileCoordinates(125807, 104894, 18);

    expect(
      SatelliteFallbackTileProvider.parentCoordinates(david, 17),
      const TileCoordinates(62903, 52447, 17),
    );
    expect(
      SatelliteFallbackTileProvider.parentCoordinates(david, 16),
      const TileCoordinates(31451, 26223, 16),
    );
  });

  test('extrait le quadrant géographique exact de la tuile parente', () {
    final parent = image_lib.Image(width: 4, height: 4);
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        final isRight = x >= 2;
        final isBottom = y >= 2;
        parent.setPixelRgba(
          x,
          y,
          isRight ? 240 : 10,
          isBottom ? 220 : 20,
          30,
          255,
        );
      }
    }

    final result = SatelliteFallbackTileProvider.cropParentTileForChild(
      Uint8List.fromList(image_lib.encodePng(parent)),
      requested: const TileCoordinates(3, 3, 2),
      parentZoom: 1,
    );
    final decoded = image_lib.decodeJpg(result)!;

    // (3,3) est le quadrant inférieur droit de sa tuile parente Z1.
    expect(decoded.getPixel(2, 2).r, greaterThan(220));
    expect(decoded.getPixel(2, 2).g, greaterThan(200));
  });

  test('reconnait le placeholder ArcGIS sans classer une vraie image', () {
    final placeholder = File(
      'test/fixtures/arcgis_unavailable_tile.jpg',
    ).readAsBytesSync();
    expect(
      SatelliteFallbackTileProvider.isArcGisUnavailableTile(placeholder),
      isTrue,
    );

    final realTile = image_lib.Image(width: 256, height: 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        realTile.setPixelRgba(x, y, x, y, (x + y) ~/ 2, 255);
      }
    }
    expect(
      SatelliteFallbackTileProvider.isArcGisUnavailableTile(
        Uint8List.fromList(image_lib.encodeJpg(realTile)),
      ),
      isFalse,
    );
  });

  test('essaie Z18 puis extrait Z17 quand Z18 est indisponible', () async {
    final placeholder = File(
      'test/fixtures/arcgis_unavailable_tile.jpg',
    ).readAsBytesSync();
    final parent = image_lib.Image(width: 256, height: 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        parent.setPixelRgba(x, y, x, y, 50, 255);
      }
    }
    final requestedUrls = <String>[];
    final provider = SatelliteFallbackTileProvider(
      httpClient: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response.bytes(
          request.url.path.contains('/18/')
              ? placeholder
              : image_lib.encodePng(parent),
          200,
        );
      }),
      cachingProvider: const DisabledMapCachingProvider(),
    );

    final bytes = await provider.loadBestAvailableTile(
      const TileCoordinates(125807, 104894, 18),
      TileLayer(
        urlTemplate: 'https://tiles.test/tile/{z}/{y}/{x}',
      ),
      Completer<void>().future,
    );
    final decoded = image_lib.decodeJpg(bytes)!;

    expect(requestedUrls, [
      'https://tiles.test/tile/18/104894/125807',
      'https://tiles.test/tile/17/52447/62903',
    ]);
    expect(decoded.width, 256);
    expect(decoded.height, 256);
    // David se trouve dans le quadrant supérieur droit de cette tuile Z17.
    expect(decoded.getPixel(128, 128).r, greaterThan(128));
    expect(decoded.getPixel(128, 128).g, lessThan(128));
  });
}
