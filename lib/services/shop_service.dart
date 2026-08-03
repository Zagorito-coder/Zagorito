// ============================================================
//  shop_service.dart — Service de chargement et regroupement
//  des magasins de pêche synchronisés avec les spots
//  ✅ Source de données : Overpass API (OpenStreetMap), gratuit, sans clé
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../models/fishing_shop.dart';
import '../data/coastal_cities.dart';

class ShopService {
  ShopService._();

  static const _cacheFileName = 'shops_cache_v3.json';
  static const _distanceCalc = Distance();
  static const _cacheTtl = Duration(days: 14);
  static const _refreshBudget = Duration(seconds: 75);
  static Future<List<FishingShop>>? _refreshInFlight;

  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
  ];

  static const int _radiusMeters = 20000;
  static const int _batchSize = 16;

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  static Future<List<FishingShop>> loadShops(
      {bool forceRefresh = false}) async {
    if (forceRefresh) return refreshShops();

    _ShopCacheSnapshot? staleCache;
    try {
      final cached = await _loadFromCache();
      if (cached.shops.isNotEmpty && cached.isFresh) {
        debugPrint(
          '[ShopService] ${cached.shops.length} magasins chargés depuis le cache local frais',
        );
        return cached.shops;
      }
      if (cached.shops.isNotEmpty) staleCache = cached;
    } catch (e) {
      debugPrint('[ShopService] Erreur cache lecture: $e');
    }

    // Le chargement normal reste 100 % local. Overpass n'est contacté que par
    // une actualisation explicite afin d'éviter des dizaines de requêtes à
    // chaque ouverture d'écran, en particulier sur réseau mobile.
    List<FishingShop> shops = [];
    try {
      shops = await _loadFromCsv();
      debugPrint(
          '[ShopService] ${shops.length} magasins chargés depuis le CSV fallback');
    } catch (e) {
      debugPrint('[ShopService] Erreur CSV fallback: $e');
    }

    if (shops.isNotEmpty) return shops;
    return staleCache?.shops ?? const [];
  }

  static Future<List<FishingShop>> refreshShops() async {
    final refreshed = await _refreshOverpassOnce();
    if (refreshed.isNotEmpty) return refreshed;
    return loadShops();
  }

  static Future<void> clearCache() async {
    final file = await _cacheFile;
    if (await file.exists()) await file.delete();
  }

  @visibleForTesting
  static bool isCacheTimestampFresh(
    DateTime refreshedAt, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toUtc();
    final age = reference.difference(refreshedAt.toUtc());
    return !age.isNegative && age <= _cacheTtl;
  }

  static List<ShopSpotGroup> groupShopsBySpot(
    List<FishingShop> shops,
    List<Spot> spots, {
    double maxDistanceKm = 50.0,
  }) {
    final groups = <String, ShopSpotGroup>{};

    for (final shop in shops) {
      Spot? nearest;
      double minDist = double.infinity;

      for (final spot in spots) {
        final dist = _distanceCalc.as(
          LengthUnit.Kilometer,
          LatLng(spot.latitude, spot.longitude),
          LatLng(shop.latitude, shop.longitude),
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = spot;
        }
      }

      if (nearest != null && minDist <= maxDistanceKm) {
        final key = nearest.id;
        if (!groups.containsKey(key)) {
          groups[key] = ShopSpotGroup(
            spotId: nearest.id,
            spotName: nearest.name,
            spotLat: nearest.latitude,
            spotLng: nearest.longitude,
            shops: [],
          );
        }
        groups[key] = ShopSpotGroup(
          spotId: groups[key]!.spotId,
          spotName: groups[key]!.spotName,
          spotLat: groups[key]!.spotLat,
          spotLng: groups[key]!.spotLng,
          shops: [...groups[key]!.shops, shop],
        );
      }
    }

    final result = groups.values.toList();
    result.sort((a, b) => b.shops.length.compareTo(a.shops.length));
    return result;
  }

  static double distanceBetween(Spot spot, FishingShop shop) {
    return _distanceCalc.as(
      LengthUnit.Kilometer,
      LatLng(spot.latitude, spot.longitude),
      LatLng(shop.latitude, shop.longitude),
    );
  }

  // ── Cache local ──

  static Future<_ShopCacheSnapshot> _loadFromCache() async {
    final file = await _cacheFile;
    if (!await file.exists()) return const _ShopCacheSnapshot.empty();
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const _ShopCacheSnapshot.empty();
    }
    final refreshedAt =
        DateTime.tryParse(decoded['refreshedAt'] as String? ?? '');
    final rawShops = decoded['shops'];
    if (refreshedAt == null || rawShops is! List<dynamic>) {
      return const _ShopCacheSnapshot.empty();
    }
    return _ShopCacheSnapshot(
      refreshedAt: refreshedAt.toUtc(),
      shops: rawShops
          .map((entry) => FishingShop.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  static Future<void> _saveToCache(List<FishingShop> shops) async {
    final file = await _cacheFile;
    final data = jsonEncode({
      'schemaVersion': 3,
      'refreshedAt': DateTime.now().toUtc().toIso8601String(),
      'shops': shops.map((shop) => shop.toJson()).toList(growable: false),
    });
    await file.writeAsString(data, flush: true);
  }

  // ── Overpass API ──

  static Future<List<FishingShop>> _refreshOverpassOnce() {
    final running = _refreshInFlight;
    if (running != null) return running;

    late final Future<List<FishingShop>> operation;
    operation = _performOverpassRefresh().whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
    _refreshInFlight = operation;
    return operation;
  }

  static Future<List<FishingShop>> _performOverpassRefresh() async {
    try {
      final fromOverpass = await _loadFromOverpass();
      if (fromOverpass.isEmpty) return const [];
      await _saveToCache(fromOverpass);
      debugPrint(
        '[ShopService] Cache Overpass mis à jour: ${fromOverpass.length} magasins',
      );
      return fromOverpass;
    } catch (error) {
      debugPrint('[ShopService] Actualisation Overpass abandonnée: $error');
      return const [];
    }
  }

  static Future<List<FishingShop>> _loadFromOverpass() async {
    final results = <FishingShop>[];
    final seenIds = <String>{};
    final deadline = DateTime.now().add(_refreshBudget);

    for (var i = 0; i < coastalCities.length; i += _batchSize) {
      if (!DateTime.now().isBefore(deadline)) {
        throw TimeoutException('Budget global Overpass dépassé');
      }
      final batch = coastalCities.sublist(
        i,
        (i + _batchSize).clamp(0, coastalCities.length),
      );

      final batchResult = await _fetchBatch(batch, deadline: deadline);
      if (!batchResult.succeeded) {
        throw StateError('Lot Overpass incomplet; cache précédent conservé');
      }
      for (final shop in batchResult.shops) {
        if (seenIds.add(shop.id)) {
          results.add(shop);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    debugPrint(
        '[ShopService] ${results.length} magasins récupérés depuis Overpass/OSM');
    return results;
  }

  static Future<_OverpassBatchResult> _fetchBatch(
    List<CoastalCity> batch, {
    required DateTime deadline,
  }) async {
    final query = _buildOverpassQuery(batch);

    for (final endpoint in _overpassEndpoints) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      final requestTimeout = remaining < const Duration(seconds: 12)
          ? remaining
          : const Duration(seconds: 12);
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
            'User-Agent':
                'BoosterFish/1.0 (+https://zagorito-coder.github.io/boosterfish/privacy-policy/)',
          },
          body: {'data': query},
        ).timeout(requestTimeout);

        if (response.statusCode == 200) {
          return _OverpassBatchResult.success(
            _parseOverpassResponse(response.body, batch),
          );
        }
        debugPrint(
            '[ShopService] $endpoint a répondu ${response.statusCode}, essai miroir suivant');
      } catch (e) {
        debugPrint('[ShopService] Miroir $endpoint indisponible: $e');
        continue;
      }
    }
    return const _OverpassBatchResult.failure();
  }

  static String _buildOverpassQuery(List<CoastalCity> cities) {
    final buffer = StringBuffer();
    buffer.writeln('[out:json][timeout:25];');
    buffer.writeln('(');
    for (final c in cities) {
      buffer.writeln(
          '  node["shop"="fishing"](around:$_radiusMeters,${c.lat},${c.lon});');
      buffer.writeln(
          '  way["shop"="fishing"](around:$_radiusMeters,${c.lat},${c.lon});');
    }
    buffer.writeln(');');
    buffer.writeln('out center tags;');
    return buffer.toString();
  }

  static List<FishingShop> _parseOverpassResponse(
      String body, List<CoastalCity> batch) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final elements = (json['elements'] as List?) ?? [];

    final shops = <FishingShop>[];
    for (final raw in elements) {
      final element = raw as Map<String, dynamic>;
      final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? {};

      final lat = (element['lat'] ?? element['center']?['lat'])?.toDouble();
      final lon = (element['lon'] ?? element['center']?['lon'])?.toDouble();
      if (lat == null || lon == null) continue;

      final nearest = _nearestCity(lat, lon, batch);

      final name = (tags['name'] as String?)?.trim();
      final phone = (tags['phone'] as String?) ??
          (tags['contact:phone'] as String?) ??
          '';
      final imageUrl = (tags['image'] as String?) ?? '';

      final addressParts = <String>[];
      final street = tags['addr:street'] as String?;
      if (street != null && street.isNotEmpty) {
        final num = tags['addr:housenumber'] as String?;
        addressParts.add(num != null ? '$street $num' : street);
      }
      addressParts.add((tags['addr:city'] as String?) ?? nearest.name);
      addressParts.add(nearest.country);

      final hours = _parseOpeningHours(tags['opening_hours'] as String?);

      shops.add(FishingShop(
        id: 'osm_${element['type']}_${element['id']}',
        name: (name != null && name.isNotEmpty) ? name : 'Magasin de pêche',
        latitude: lat,
        longitude: lon,
        phone: phone,
        address: addressParts.join(', '),
        imageUrl: imageUrl,
        openTime: hours.$1,
        closeTime: hours.$2,
        tags: const ['Matériel de pêche'],
        rating: null,
      ));
    }
    return shops;
  }

  static CoastalCity _nearestCity(
      double lat, double lon, List<CoastalCity> batch) {
    var nearest = batch.first;
    var best = double.infinity;
    for (final c in batch) {
      final d = (lat - c.lat) * (lat - c.lat) + (lon - c.lon) * (lon - c.lon);
      if (d < best) {
        best = d;
        nearest = c;
      }
    }
    return nearest;
  }

  static (String, String) _parseOpeningHours(String? raw) {
    if (raw == null || raw.isEmpty) return ('09:00', '18:00');
    final match =
        RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(raw);
    if (match != null) {
      return (match.group(1)!, match.group(2)!);
    }
    return ('09:00', '18:00');
  }

  // ── Fallback CSV local ──

  static Future<List<FishingShop>> _loadFromCsv() async {
    final raw = await rootBundle.loadString('assets/shops.csv');
    final lines = raw.split('\n');
    final shops = <FishingShop>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        shops.add(FishingShop.fromCsv(line, index: i));
      } catch (e) {
        debugPrint('[ShopService] Skipped line $i: $e');
      }
    }
    return shops;
  }
}

class _ShopCacheSnapshot {
  const _ShopCacheSnapshot({
    required this.refreshedAt,
    required this.shops,
  });

  const _ShopCacheSnapshot.empty()
      : refreshedAt = null,
        shops = const [];

  final DateTime? refreshedAt;
  final List<FishingShop> shops;

  bool get isFresh {
    final timestamp = refreshedAt;
    if (timestamp == null) return false;
    return ShopService.isCacheTimestampFresh(timestamp);
  }
}

class _OverpassBatchResult {
  const _OverpassBatchResult.success(this.shops) : succeeded = true;
  const _OverpassBatchResult.failure()
      : shops = const [],
        succeeded = false;

  final List<FishingShop> shops;
  final bool succeeded;
}
