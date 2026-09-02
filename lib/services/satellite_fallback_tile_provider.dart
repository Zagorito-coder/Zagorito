import 'dart:async';
import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image_lib;

/// Fournisseur satellite ArcGIS avec repli géographique 18 -> 17 -> 16.
///
/// ArcGIS renvoie parfois une image JPEG grise avec un statut HTTP 200 lorsque
/// la couverture détaillée n'existe pas. Un fournisseur réseau classique ne
/// peut donc pas distinguer cette réponse d'une vraie photographie. Ce
/// fournisseur reconnaît strictement cette image, récupère la tuile parente et
/// en extrait le quadrant correspondant afin de préserver l'alignement exact.
class SatelliteFallbackTileProvider extends TileProvider {
  SatelliteFallbackTileProvider({
    super.headers,
    http.Client? httpClient,
    MapCachingProvider? cachingProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _cachingProvider = cachingProvider ??
            BuiltInMapCachingProvider.getOrCreateInstance(
              maxCacheSize: 256 * 1024 * 1024,
            );

  static const int preferredNativeZoom = 18;
  static const int minimumFallbackZoom = 16;
  static const int _emergencyFallbackZoom = 15;

  // L'égalité exacte reste le chemin le moins coûteux. La détection visuelle
  // complémentaire protège aussi l'application si ArcGIS réencode le même
  // visuel d'indisponibilité avec une empreinte binaire différente.
  static const Set<String> _arcGisUnavailableTileSha256 = {
    '9eafd300d61393184a4abc1d458564cfd1cd9b6f9c4e9c74687045c0a0e5b858',
  };

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final MapCachingProvider _cachingProvider;
  final Set<String> _unavailableUrls = <String>{};

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    return _SatelliteFallbackImageProvider(
      provider: this,
      coordinates: coordinates,
      options: options,
      cancelLoading: cancelLoading,
    );
  }

  Future<Uint8List> loadBestAvailableTile(
    TileCoordinates requested,
    TileLayer options,
    Future<void> cancelLoading,
  ) async {
    // Z16 correspond au niveau natif choisi par flutter_map autour de 15,7x.
    // Si cette tuile précise échoue, Z15 fournit un dernier parent de secours
    // sans modifier les chemins normaux Z17/Z18 ni ajouter d'appel habituel.
    final lowestZoom = requested.z == minimumFallbackZoom
        ? _emergencyFallbackZoom
        : requested.z.clamp(0, minimumFallbackZoom);

    for (var candidateZoom = requested.z;
        candidateZoom >= lowestZoom;
        candidateZoom--) {
      final delta = requested.z - candidateZoom;
      final candidate = parentCoordinates(requested, candidateZoom);
      final url = getTileUrl(candidate, options);

      try {
        final bytes = await _loadTileBytes(url, cancelLoading);
        if (isArcGisUnavailableTile(bytes)) continue;
        if (delta == 0) return bytes;

        return cropParentTileForChild(
          bytes,
          requested: requested,
          parentZoom: candidateZoom,
        );
      } on http.RequestAbortedException {
        rethrow;
      } catch (_) {
        // Une erreur HTTP, un cache corrompu ou une image illisible suit le
        // même chemin sûr qu'une tuile indisponible : parent suivant.
      }
    }

    throw StateError(
      'Aucune tuile satellite exploitable entre Z${requested.z} '
      'et Z$lowestZoom',
    );
  }

  Future<Uint8List> _loadTileBytes(
    String url,
    Future<void> cancelLoading,
  ) async {
    if (_unavailableUrls.contains(url)) {
      throw StateError('Tuile ArcGIS déjà reconnue indisponible');
    }

    CachedMapTile? cached;
    if (_cachingProvider.isSupported) {
      try {
        cached = await _cachingProvider.getTile(url);
        if (cached != null && !cached.metadata.isStale) {
          if (isArcGisUnavailableTile(cached.bytes)) {
            _unavailableUrls.add(url);
            throw StateError('Placeholder ArcGIS présent dans le cache');
          }
          return cached.bytes;
        }
      } catch (_) {
        if (_unavailableUrls.contains(url)) rethrow;
        cached = null;
      }
    }

    try {
      final request = http.AbortableRequest(
        'GET',
        Uri.parse(url),
        abortTrigger: cancelLoading,
      )..headers.addAll(headers);
      final response = await _httpClient.send(request).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'HTTP ${response.statusCode}',
          Uri.parse(url),
        );
      }

      final bytes = await response.stream.toBytes();
      if (bytes.isEmpty) throw StateError('Réponse de tuile vide');

      // Ne jamais enregistrer l'image grise d'indisponibilité dans le cache.
      if (isArcGisUnavailableTile(bytes)) {
        _unavailableUrls.add(url);
        throw StateError('Placeholder ArcGIS reçu');
      }
      if (_cachingProvider.isSupported) {
        unawaited(
          _cachingProvider
              .putTile(
                url: url,
                bytes: bytes,
                metadata: CachedMapTileMetadata(
                  staleAt: DateTime.timestamp().add(const Duration(days: 7)),
                  lastModified: null,
                  etag: null,
                ),
              )
              .catchError((_) {}),
        );
      }
      return bytes;
    } catch (_) {
      // En cas de coupure, une vraie tuile périmée reste préférable à une
      // zone blanche. Une ancienne tuile grise reste toujours refusée.
      if (!_unavailableUrls.contains(url) &&
          cached != null &&
          !isArcGisUnavailableTile(cached.bytes)) {
        return cached.bytes;
      }
      rethrow;
    }
  }

  @visibleForTesting
  static bool isArcGisUnavailableTile(Uint8List bytes) {
    if (_arcGisUnavailableTileSha256.contains(
      sha256.convert(bytes).toString(),
    )) {
      return true;
    }

    // Le placeholder officiel est un carré gris 256x256 avec un petit texte
    // blanc centré et un minuscule repère rouge. Une vraie photo satellite,
    // même essentiellement marine, conserve nettement plus de variations.
    if (bytes.length > 8 * 1024) return false;
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null || decoded.width != 256 || decoded.height != 256) {
      return false;
    }

    var greyBackgroundSamples = 0;
    var sampled = 0;
    var brightCenterSamples = 0;
    for (var y = 8; y < 248; y += 16) {
      for (var x = 8; x < 248; x += 16) {
        final pixel = decoded.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        sampled++;
        if ((r - g).abs() <= 3 && (r - b).abs() <= 3 && r >= 180 && r <= 225) {
          greyBackgroundSamples++;
        }
        if (x >= 64 &&
            x <= 192 &&
            y >= 96 &&
            y <= 160 &&
            r > 225 &&
            g > 225 &&
            b > 225) {
          brightCenterSamples++;
        }
      }
    }
    return greyBackgroundSamples / sampled > 0.82 && brightCenterSamples >= 2;
  }

  @visibleForTesting
  static TileCoordinates parentCoordinates(
    TileCoordinates child,
    int parentZoom,
  ) {
    if (parentZoom < 0 || parentZoom > child.z) {
      throw ArgumentError.value(parentZoom, 'parentZoom');
    }
    final delta = child.z - parentZoom;
    return TileCoordinates(child.x >> delta, child.y >> delta, parentZoom);
  }

  @visibleForTesting
  static Uint8List cropParentTileForChild(
    Uint8List parentBytes, {
    required TileCoordinates requested,
    required int parentZoom,
  }) {
    final delta = requested.z - parentZoom;
    if (delta <= 0) return parentBytes;

    final parentImage = image_lib.decodeImage(parentBytes);
    if (parentImage == null || parentImage.width != parentImage.height) {
      throw StateError('Tuile satellite parente illisible');
    }

    final subdivisions = 1 << delta;
    final cropSize = parentImage.width ~/ subdivisions;
    if (cropSize < 1) throw StateError('Repli satellite trop profond');

    final childX = requested.x & (subdivisions - 1);
    final childY = requested.y & (subdivisions - 1);
    final cropped = image_lib.copyCrop(
      parentImage,
      x: childX * cropSize,
      y: childY * cropSize,
      width: cropSize,
      height: cropSize,
    );
    final resized = image_lib.copyResize(
      cropped,
      width: parentImage.width,
      height: parentImage.height,
      interpolation: image_lib.Interpolation.linear,
    );
    return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 90));
  }

  @override
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
    super.dispose();
  }
}

@immutable
class _SatelliteFallbackImageProvider
    extends ImageProvider<_SatelliteFallbackImageProvider> {
  const _SatelliteFallbackImageProvider({
    required this.provider,
    required this.coordinates,
    required this.options,
    required this.cancelLoading,
  });

  final SatelliteFallbackTileProvider provider;
  final TileCoordinates coordinates;
  final TileLayer options;
  final Future<void> cancelLoading;

  @override
  Future<_SatelliteFallbackImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SatelliteFallbackImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunks = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(decode)..whenComplete(() => unawaited(chunks.close())),
      chunkEvents: chunks.stream,
      scale: 1,
      debugLabel: 'ArcGIS ${coordinates.z}/${coordinates.x}/${coordinates.y}',
    );
  }

  Future<Codec> _loadCodec(ImageDecoderCallback decode) async {
    void evictFailedImage() => scheduleMicrotask(
          () => PaintingBinding.instance.imageCache.evict(this),
        );

    try {
      final bytes = await provider.loadBestAvailableTile(
        coordinates,
        options,
        cancelLoading,
      );
      return decode(await ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Une annulation est une situation normale pendant un mouvement de
      // caméra. La tuile transparente reste silencieuse, mais ne doit jamais
      // être mémorisée comme une vraie image pour ces coordonnées : la
      // prochaine apparition doit pouvoir relancer le chargement réseau.
      evictFailedImage();
      return decode(
        await ImmutableBuffer.fromUint8List(TileProvider.transparentImage),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SatelliteFallbackImageProvider &&
          identical(provider, other.provider) &&
          coordinates == other.coordinates;

  @override
  int get hashCode => Object.hash(provider, coordinates);
}
