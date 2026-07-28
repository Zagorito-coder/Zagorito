import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/offline_map_region.dart';

Map<String, dynamic> _region({
  required String id,
  required String countryCode,
  required String continent,
  int spotCount = 100,
}) {
  return {
    'id': id,
    'countryCode': countryCode,
    'continent': continent,
    'names': {'fr': id, 'en': id},
    'file': '$id.pmtiles',
    'sizeBytes': 1024,
    'sha256': List.filled(64, 'a').join(),
    'minZoom': 0,
    'maxZoom': 14,
    'spotCount': spotCount,
    'bounds': [-10.0, 20.0, -1.0, 36.0],
  };
}

void main() {
  group('limite des cartes hors ligne', () {
    test('autorise la premiere carte', () {
      expect(
        OfflineMapInstallPolicy.canInstall(
          installedRegionIds: const {},
          requestedRegionId: 'ma',
        ),
        isTrue,
      );
    });

    test('refuse une autre carte tant que la premiere est installee', () {
      expect(
        OfflineMapInstallPolicy.canInstall(
          installedRegionIds: const {'ma'},
          requestedRegionId: 'tn',
        ),
        isFalse,
      );
    });

    test('autorise la carte deja installee', () {
      expect(
        OfflineMapInstallPolicy.canInstall(
          installedRegionIds: const {'ma'},
          requestedRegionId: 'ma',
        ),
        isTrue,
      );
    });
  });

  test('le catalogue exclut toujours les packs europeens', () {
    final catalog = OfflineMapCatalog.fromJson({
      'schemaVersion': 1,
      'regions': [
        _region(id: 'ma', countryCode: 'MA', continent: 'africa'),
        _region(id: 'fr', countryCode: 'FR', continent: 'europe'),
      ],
    });

    expect(catalog.regions.map((region) => region.id), ['ma']);
  });

  test('un nom de fichier traversant un dossier est refuse', () {
    final raw = _region(
      id: 'ma',
      countryCode: 'MA',
      continent: 'africa',
    )..['file'] = '../ma.pmtiles';

    expect(
      () => OfflineMapRegion.fromJson(raw),
      throwsA(isA<FormatException>()),
    );
  });

  test('le manifeste exige une empreinte SHA-256 complete', () {
    final raw = _region(
      id: 'ma',
      countryCode: 'MA',
      continent: 'africa',
    )..['sha256'] = 'invalide';

    expect(
      () => OfflineMapRegion.fromJson(raw),
      throwsA(isA<FormatException>()),
    );
  });

  test('le catalogue conserve uniquement les pays arabes avec 30 spots', () {
    final catalog = OfflineMapCatalog.fromJson({
      'schemaVersion': 1,
      'regions': [
        _region(
          id: 'ae',
          countryCode: 'AE',
          continent: 'asia',
          spotCount: 30,
        ),
        _region(
          id: 'ps',
          countryCode: 'PS',
          continent: 'asia',
          spotCount: 29,
        ),
        _region(
          id: 'za',
          countryCode: 'ZA',
          continent: 'africa',
          spotCount: 100,
        ),
      ],
    });

    expect(catalog.regions.map((region) => region.id), ['ae']);
  });

  test('une emprise geographique invalide est refusee', () {
    final raw = _region(
      id: 'ma',
      countryCode: 'MA',
      continent: 'africa',
    )..['bounds'] = [-10.0, 36.0, -1.0, 20.0];

    expect(
      () => OfflineMapRegion.fromJson(raw),
      throwsA(isA<FormatException>()),
    );
  });

  test('le manifeste de production contient exactement les 11 pays retenus',
      () {
    final source = File('tool/offline_maps/manifest.json').readAsStringSync();
    final catalog = OfflineMapCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );

    expect(
      catalog.regions.map((region) => region.countryCode),
      ['AE', 'BH', 'DZ', 'EG', 'LY', 'MA', 'OM', 'SA', 'SY', 'TN', 'YE'],
    );
    expect(
      catalog.regions.fold<int>(
        0,
        (total, region) => total + region.spotCount,
      ),
      5992,
    );
    expect(
      catalog.regions.every(
        (region) =>
            region.isAllowed &&
            region.spotCount >= OfflineMapRegion.minimumSpotCount,
      ),
      isTrue,
    );
  });
}
