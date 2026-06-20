import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tuile satellite ESRI optimisée par défaut, avec fallback OSM standard.
/// Usage : AppTileLayer(satellite: true) ou AppTileLayer(satellite: false)
class AppTileLayer extends StatelessWidget {
  final bool satellite;

  const AppTileLayer({
    super.key,
    this.satellite = true,
  });

  @override
  Widget build(BuildContext context) {
    if (satellite) {
      return TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        subdomains: const [],
        minZoom: 2,
        maxZoom: 18,
        maxNativeZoom: 18,
        tileSize: 256,
        retinaMode: true,
        keepBuffer: 3,
        tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 120)),
        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
        userAgentPackageName: 'com.example.spots_app',
      );
    }

    return TileLayer(
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      minZoom: 2,
      maxZoom: 18,
      maxNativeZoom: 19,
      tileSize: 256,
      retinaMode: true,
      keepBuffer: 3,
      tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 120)),
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      userAgentPackageName: 'com.example.spots_app',
    );
  }
}
