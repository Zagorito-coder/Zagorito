import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:spots_app/services/offline_map_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

/// Fonds de carte supportes.
enum MapStyle { standard, satellite, dark, offline }

/// Couche reseau sans telechargement hors-ligne.
class AppTileLayer extends StatefulWidget {
  final MapStyle style;
  final TileProvider Function()? networkTileProviderFactory;

  const AppTileLayer({
    super.key,
    this.style = MapStyle.standard,
    this.networkTileProviderFactory,
  });

  @override
  State<AppTileLayer> createState() => _AppTileLayerState();
}

class _AppTileLayerState extends State<AppTileLayer> {
  static const _userAgentPackageName = 'com.zagorito.spots_app';
  TileProvider? _networkTileProvider;

  TileProvider get _tileProvider {
    return _networkTileProvider ??= widget.networkTileProviderFactory?.call() ??
        NetworkTileProvider(
          headers: {
            'User-Agent': 'BoosterFish Android '
                '(+https://zagorito-coder.github.io/boosterfish/; '
                'contact: booster2fish@gmail.com)',
          },
          // Respecte les en-têtes HTTP des fournisseurs (obligatoire pour
          // tile.openstreetmap.org), évite les téléchargements répétés et
          // borne l'empreinte disque du cache partagé entre les fonds.
          cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
            maxCacheSize: 256 * 1024 * 1024,
          ),
        );
  }

  @override
  void didUpdateWidget(covariant AppTileLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != MapStyle.offline &&
        widget.style == MapStyle.offline) {
      // TileLayer disposes its provider when the raster layer is removed.
      // Drop our reference so returning online creates a fresh HTTP client.
      _networkTileProvider = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case MapStyle.satellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: _userAgentPackageName,
          tileProvider: _tileProvider,
          keepBuffer: 1,
          panBuffer: 0,
        );
      case MapStyle.dark:
        return TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: _userAgentPackageName,
          tileProvider: _tileProvider,
          keepBuffer: 1,
          panBuffer: 0,
        );
      case MapStyle.standard:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: _userAgentPackageName,
          tileProvider: _tileProvider,
          keepBuffer: 1,
          panBuffer: 0,
        );
      case MapStyle.offline:
        return const _OfflinePmTilesLayer();
    }
  }
}

class _OfflinePmTilesLayer extends StatelessWidget {
  const _OfflinePmTilesLayer();

  static final _theme = ProtomapsThemes.lightV4();

  @override
  Widget build(BuildContext context) {
    final service = OfflineMapService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final provider = service.activeProvider;
        if (provider == null) {
          return const ColoredBox(color: Color(0xFFE8EEF1));
        }
        return FutureBuilder<PmTilesVectorTileProvider>(
          future: provider,
          builder: (context, snapshot) {
            final tileProvider = snapshot.data;
            if (tileProvider == null) {
              return const ColoredBox(color: Color(0xFFE8EEF1));
            }
            return VectorTileLayer(
              key: ValueKey(service.activeRegionId),
              theme: _theme,
              tileProviders: TileProviders({'protomaps': tileProvider}),
              fileCacheTtl: Duration.zero,
              fileCacheMaximumSizeInBytes: 0,
              memoryTileCacheMaxSize: 6 * 1024 * 1024,
              memoryTileDataCacheMaxSize: 12,
              textCacheMaxSize: 80,
              concurrency: 2,
              maximumTileSubstitutionDifference: 0,
            );
          },
        );
      },
    );
  }
}

/// Attribution visible et interactive, requise par les fournisseurs de cartes.
class AppMapAttribution extends StatelessWidget {
  final MapStyle style;

  const AppMapAttribution({
    super.key,
    this.style = MapStyle.standard,
  });

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attributions = <SourceAttribution>[];
    switch (style) {
      case MapStyle.satellite:
        attributions.add(
          TextSourceAttribution(
            'Esri, Maxar, Earthstar Geographics and the GIS User Community',
            onTap: () => _open(
              'https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9',
            ),
          ),
        );
        break;
      case MapStyle.dark:
        attributions.add(
          TextSourceAttribution(
            'OpenStreetMap contributors',
            onTap: () => _open('https://www.openstreetmap.org/copyright'),
          ),
        );
        attributions.add(
          TextSourceAttribution(
            'CARTO',
            onTap: () => _open('https://carto.com/attributions'),
          ),
        );
        break;
      case MapStyle.standard:
        attributions.add(
          TextSourceAttribution(
            'OpenStreetMap contributors',
            onTap: () => _open('https://www.openstreetmap.org/copyright'),
          ),
        );
        break;
      case MapStyle.offline:
        attributions.add(
          TextSourceAttribution(
            'OpenStreetMap contributors',
            onTap: () => _open('https://www.openstreetmap.org/copyright'),
          ),
        );
        attributions.add(
          TextSourceAttribution(
            'Protomaps',
            onTap: () => _open('https://protomaps.com'),
          ),
        );
        break;
    }

    return RichAttributionWidget(
      popupInitialDisplayDuration: const Duration(seconds: 4),
      showFlutterMapAttribution: false,
      attributions: attributions,
    );
  }
}
