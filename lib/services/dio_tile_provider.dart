// ============================================================
//  dio_tile_provider.dart — TileProvider basé sur Dio
//  Permet de contrôler le User-Agent et d'éviter les 403 OSM.
// ============================================================

import 'dart:async' show StreamController;
import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// TileProvider utilisant Dio pour le téléchargement des tuiles.
///
/// Avantages par rapport au NetworkTileProvider par défaut :
/// - Contrôle total des headers (User-Agent explicite).
/// - Timeouts configurables.
class DioTileProvider extends TileProvider {
  final Dio _dio;

  DioTileProvider({
    Dio? dio,
    Map<String, String>? headers,
  }) : _dio = dio ?? Dio(BaseOptions(
           connectTimeout: const Duration(seconds: 5),
           receiveTimeout: const Duration(seconds: 5),
           headers: headers,
         ));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _DioImageProvider(
      dio: _dio,
      url: getTileUrl(coordinates, options),
      scale: 1.0,
    );
  }
}

class _DioImageProvider extends ImageProvider<_DioImageProvider> {
  final Dio dio;
  final String url;
  final double scale;

  const _DioImageProvider({
    required this.dio,
    required this.url,
    required this.scale,
  });

  @override
  Future<_DioImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DioImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DioImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode, chunkEvents),
      chunkEvents: chunkEvents.stream,
      scale: scale,
      debugLabel: url,
      informationCollector: () => [DiagnosticsProperty('URL', url)],
    );
  }

  Future<Codec> _loadAsync(
    _DioImageProvider key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    try {
      final response = await dio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Empty tile response: $url');
      }
      return decode(await ImmutableBuffer.fromUint8List(bytes));
    } catch (e, stackTrace) {
      debugPrint('[DioTileProvider] Erreur tuile $url: $e');
      throw Exception('Failed to load tile: $url\n$stackTrace');
    } finally {
      await chunkEvents.close();
    }
  }
}
