import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/widgets/app_tile_layer.dart';

class _TransparentTileProvider extends TileProvider {
  static final Uint8List _tile = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0l'
    'EQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_tile);
  }
}

Widget _mapWithStyle(MapStyle style) {
  return MaterialApp(
    home: SizedBox.shrink(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(31, -8),
          initialZoom: 5,
        ),
        children: [
          AppTileLayer(
            style: style,
            networkTileProviderFactory: _TransparentTileProvider.new,
          ),
        ],
      ),
    ),
  );
}

void main() {
  test('les tuiles réseau conservent le cache HTTP requis par OSM', () {
    final source = File('lib/widgets/app_tile_layer.dart').readAsStringSync();

    expect(source, contains('BuiltInMapCachingProvider.getOrCreateInstance'));
    expect(source, isNot(contains('DisabledMapCachingProvider')));
    expect(source, contains('BoosterFish Android'));
    expect(source, contains('contact: booster2fish@gmail.com'));
  });

  testWidgets(
    'recree le fournisseur reseau apres le mode hors ligne',
    (tester) async {
      await tester.pumpWidget(_mapWithStyle(MapStyle.satellite));
      final initialProvider =
          tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;

      await tester.pumpWidget(_mapWithStyle(MapStyle.offline));
      expect(find.byType(TileLayer), findsNothing);

      await tester.pumpWidget(_mapWithStyle(MapStyle.standard));
      final restoredProvider =
          tester.widget<TileLayer>(find.byType(TileLayer)).tileProvider;

      expect(restoredProvider, isNot(same(initialProvider)));
    },
  );
}
