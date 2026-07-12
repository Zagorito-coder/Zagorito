// ============================================================
//  app_tile_layer.dart — Couche de tuiles réutilisable
//  OSM standard / ArcGIS satellite / CartoDB sombre.
//  Avec FMTC : cache automatique online + fallback offline.
//  User-Agent explicite pour éviter les 403 OSM.
// ============================================================

import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/io_client.dart';

/// Fonds de carte supportés.
enum MapStyle { standard, satellite, dark }

/// AppTileLayer — Couche de fond avec cache FMTC automatique.
/// Usage : AppTileLayer(style: MapStyle.standard)
class AppTileLayer extends StatelessWidget {
  final MapStyle style;

  const AppTileLayer({
    super.key,
    this.style = MapStyle.standard,
  });

  static const _userAgentPackageName = 'com.zagorito.spots_app';
  static const _userAgent =
      'SpotsApp/1.0 (+https://github.com/Zagorito-coder/Zagorito; noreply@github.com)';

  /// Client HTTP réutilisé pour toutes les instances.
  /// `userAgent = null` permet à FMTC d'utiliser le header User-Agent explicite.
  static final _httpClient = IOClient(HttpClient()..userAgent = null);

  /// Cache des tile providers par style pour éviter de les recréer à chaque build.
  static final Map<MapStyle, FMTCTileProvider> _tileProviders = {};

  FMTCStore get _store {
    switch (style) {
      case MapStyle.standard:
        return const FMTCStore('osm');
      case MapStyle.satellite:
        return const FMTCStore('satellite');
      case MapStyle.dark:
        return const FMTCStore('dark');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tileProvider = _tileProviders[style] ??= FMTCTileProvider(
      stores: Map.from({
        _store.storeName: BrowseStoreStrategy.readUpdateCreate,
      }),
      loadingStrategy: BrowseLoadingStrategy.onlineFirst,
      cachedValidDuration: const Duration(days: 7),
      httpClient: _httpClient,
      headers: Map.from({'User-Agent': _userAgent}),
    );

    switch (style) {
      case MapStyle.satellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: _userAgentPackageName,
          tileProvider: tileProvider,
        );
      case MapStyle.dark:
        return TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: _userAgentPackageName,
          tileProvider: tileProvider,
        );
      case MapStyle.standard:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: _userAgentPackageName,
          tileProvider: tileProvider,
        );
    }
  }
}
