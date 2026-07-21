import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fonds de carte supportés.
enum MapStyle { standard, satellite, dark }

/// Couche réseau sans téléchargement hors-ligne. Le cache persistant FMTC a
/// été retiré afin de respecter les politiques des fournisseurs de tuiles.
class AppTileLayer extends StatelessWidget {
  final MapStyle style;

  const AppTileLayer({
    super.key,
    this.style = MapStyle.standard,
  });

  static const _userAgentPackageName = 'com.zagorito.spots_app';

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case MapStyle.satellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: _userAgentPackageName,
        );
      case MapStyle.dark:
        return TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: _userAgentPackageName,
        );
      case MapStyle.standard:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: _userAgentPackageName,
        );
    }
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
    }

    return RichAttributionWidget(
      popupInitialDisplayDuration: const Duration(seconds: 4),
      showFlutterMapAttribution: false,
      attributions: attributions,
    );
  }
}
