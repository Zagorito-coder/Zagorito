enum OfflineMapContinent {
  africa,
  asia,
  northAmerica,
  southAmerica,
  oceania,
  europe;

  static OfflineMapContinent fromJson(String value) {
    return OfflineMapContinent.values.firstWhere(
      (continent) => continent.name == value,
      orElse: () => throw const FormatException('Unknown continent'),
    );
  }
}

abstract final class OfflineMapInstallPolicy {
  static const maximumInstalledRegions = 1;

  static bool canInstall({
    required Set<String> installedRegionIds,
    required String requestedRegionId,
  }) {
    return installedRegionIds.contains(requestedRegionId) ||
        installedRegionIds.length < maximumInstalledRegions;
  }
}

class OfflineMapRegion {
  const OfflineMapRegion({
    required this.id,
    required this.countryCode,
    required this.continent,
    required this.names,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256Digest,
    required this.minZoom,
    required this.maxZoom,
    required this.spotCount,
    required this.bounds,
  });

  static const minimumSpotCount = 30;
  static const supportedArabCountryCodes = {
    'AE',
    'BH',
    'DJ',
    'DZ',
    'EG',
    'IQ',
    'JO',
    'KM',
    'KW',
    'LB',
    'LY',
    'MA',
    'MR',
    'OM',
    'PS',
    'QA',
    'SA',
    'SD',
    'SO',
    'SY',
    'TN',
    'YE',
  };

  final String id;
  final String countryCode;
  final OfflineMapContinent continent;
  final Map<String, String> names;
  final String fileName;
  final int sizeBytes;
  final String sha256Digest;
  final int minZoom;
  final int maxZoom;
  final int spotCount;
  final OfflineMapBounds bounds;

  bool get isAllowed =>
      continent != OfflineMapContinent.europe &&
      supportedArabCountryCodes.contains(countryCode) &&
      spotCount >= minimumSpotCount;

  String localizedName(String languageCode) {
    return names[languageCode] ?? names['fr'] ?? names['en'] ?? countryCode;
  }

  Uri downloadUri(Uri baseUri) => baseUri.resolve(fileName);

  factory OfflineMapRegion.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final countryCode = json['countryCode'];
    final fileName = json['file'];
    final sizeBytes = json['sizeBytes'];
    final digest = json['sha256'];
    final minZoom = json['minZoom'];
    final maxZoom = json['maxZoom'];
    final spotCount = json['spotCount'];
    final rawBounds = json['bounds'];
    final rawNames = json['names'];
    final continentValue = json['continent'];

    if (id is! String || !RegExp(r'^[a-z0-9][a-z0-9_-]{1,31}$').hasMatch(id)) {
      throw const FormatException('Invalid region id');
    }
    if (countryCode is! String ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw const FormatException('Invalid country code');
    }
    if (fileName is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{1,63}\.pmtiles$').hasMatch(fileName)) {
      throw const FormatException('Invalid PMTiles file name');
    }
    if (sizeBytes is! int || sizeBytes <= 0) {
      throw const FormatException('Invalid file size');
    }
    if (digest is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid SHA-256 digest');
    }
    if (minZoom is! int ||
        maxZoom is! int ||
        minZoom < 0 ||
        maxZoom > 18 ||
        minZoom > maxZoom) {
      throw const FormatException('Invalid zoom range');
    }
    if (spotCount is! int || spotCount < 0) {
      throw const FormatException('Invalid spot count');
    }
    if (rawBounds is! List<dynamic>) {
      throw const FormatException('Missing map bounds');
    }
    if (rawNames is! Map<String, dynamic> || rawNames.isEmpty) {
      throw const FormatException('Missing localized names');
    }
    if (continentValue is! String) {
      throw const FormatException('Missing continent');
    }

    final names = <String, String>{};
    for (final entry in rawNames.entries) {
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid localized name');
      }
      names[entry.key] = value.trim();
    }

    return OfflineMapRegion(
      id: id,
      countryCode: countryCode,
      continent: OfflineMapContinent.fromJson(continentValue),
      names: Map.unmodifiable(names),
      fileName: fileName,
      sizeBytes: sizeBytes,
      sha256Digest: digest,
      minZoom: minZoom,
      maxZoom: maxZoom,
      spotCount: spotCount,
      bounds: OfflineMapBounds.fromJson(rawBounds),
    );
  }
}

class OfflineMapBounds {
  const OfflineMapBounds({
    required this.minLongitude,
    required this.minLatitude,
    required this.maxLongitude,
    required this.maxLatitude,
  });

  final double minLongitude;
  final double minLatitude;
  final double maxLongitude;
  final double maxLatitude;

  double get centerLatitude => (minLatitude + maxLatitude) / 2;
  double get centerLongitude => (minLongitude + maxLongitude) / 2;

  factory OfflineMapBounds.fromJson(List<dynamic> values) {
    if (values.length != 4 || values.any((value) => value is! num)) {
      throw const FormatException('Invalid map bounds');
    }
    final minLongitude = (values[0] as num).toDouble();
    final minLatitude = (values[1] as num).toDouble();
    final maxLongitude = (values[2] as num).toDouble();
    final maxLatitude = (values[3] as num).toDouble();
    if (minLongitude < -180 ||
        maxLongitude > 180 ||
        minLatitude < -85 ||
        maxLatitude > 85 ||
        minLongitude >= maxLongitude ||
        minLatitude >= maxLatitude) {
      throw const FormatException('Invalid map bounds');
    }
    return OfflineMapBounds(
      minLongitude: minLongitude,
      minLatitude: minLatitude,
      maxLongitude: maxLongitude,
      maxLatitude: maxLatitude,
    );
  }
}

class OfflineMapCatalog {
  const OfflineMapCatalog({
    required this.schemaVersion,
    required this.regions,
  });

  final int schemaVersion;
  final List<OfflineMapRegion> regions;

  factory OfflineMapCatalog.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final rawRegions = json['regions'];
    if (schemaVersion != 1 || rawRegions is! List<dynamic>) {
      throw const FormatException('Unsupported offline map catalog');
    }

    final ids = <String>{};
    final regions = <OfflineMapRegion>[];
    for (final rawRegion in rawRegions) {
      if (rawRegion is! Map<String, dynamic>) {
        throw const FormatException('Invalid region entry');
      }
      final region = OfflineMapRegion.fromJson(rawRegion);
      if (!ids.add(region.id)) {
        throw const FormatException('Duplicate region id');
      }
      if (region.isAllowed) regions.add(region);
    }

    regions.sort((a, b) => a.countryCode.compareTo(b.countryCode));
    return OfflineMapCatalog(
      schemaVersion: schemaVersion as int,
      regions: List.unmodifiable(regions),
    );
  }
}
