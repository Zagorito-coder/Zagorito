// ============================================================
//  shop_service.dart — Service de chargement et regroupement
//  des magasins de pêche synchronisés avec les spots
//  ✅ Source de données : Overpass API (OpenStreetMap), gratuit, sans clé
// ============================================================

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

  static const _cacheFileName = 'shops_cache_v2.json';
  static const _distanceCalc = Distance();

  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
  ];

  static const int _radiusMeters = 20000;
  static const int _batchSize = 8;

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  static Future<List<FishingShop>> loadShops({bool forceRefresh = false}) async {
    // 1. Cache Overpass prioritaire
    if (!forceRefresh) {
      try {
        final cached = await _loadFromCache();
        if (cached.isNotEmpty) {
          debugPrint('[ShopService] ${cached.length} magasins chargés depuis le cache Overpass');
          // Rafraîchir Overpass en arrière-plan sans bloquer
          _refreshOverpassInBackground();
          return cached;
        }
      } catch (e) {
        debugPrint('[ShopService] Erreur cache lecture: $e');
      }
    }

    // 2. Fallback immédiat sur le CSV local (ne laisse jamais l'UI vide)
    List<FishingShop> shops = [];
    try {
      shops = await _loadFromCsv();
      debugPrint('[ShopService] ${shops.length} magasins chargés depuis le CSV fallback');
    } catch (e) {
      debugPrint('[ShopService] Erreur CSV fallback: $e');
    }

    // 3. Lancer Overpass en arrière-plan pour les prochains lancements
    _refreshOverpassInBackground();

    return shops;
  }

  /// Lance une requête Overpass en arrière-plan et met à jour le cache.
  static void _refreshOverpassInBackground() {
    Future.microtask(() async {
      try {
        final fromOverpass = await _loadFromOverpass();
        if (fromOverpass.isNotEmpty) {
          await _saveToCache(fromOverpass);
          debugPrint('[ShopService] Cache Overpass mis à jour: ${fromOverpass.length} magasins');
        }
      } catch (e) {
        debugPrint('[ShopService] Échec rafraîchissement Overpass: $e');
      }
    });
  }

  static Future<List<FishingShop>> refreshShops() => loadShops(forceRefresh: true);

  static Future<void> clearCache() async {
    final file = await _cacheFile;
    if (await file.exists()) await file.delete();
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

  static Future<List<FishingShop>> _loadFromCache() async {
    final file = await _cacheFile;
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => FishingShop.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveToCache(List<FishingShop> shops) async {
    final file = await _cacheFile;
    final data = jsonEncode(shops.map((s) => s.toJson()).toList());
    await file.writeAsString(data);
  }

  // ── Overpass API ──

  static Future<List<FishingShop>> _loadFromOverpass() async {
    final results = <FishingShop>[];
    final seenIds = <String>{};

    for (var i = 0; i < coastalCities.length; i += _batchSize) {
      final batch = coastalCities.sublist(
        i,
        (i + _batchSize).clamp(0, coastalCities.length),
      );

      final batchShops = await _fetchBatch(batch);
      for (final shop in batchShops) {
        if (seenIds.add(shop.id)) {
          results.add(shop);
        }
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    debugPrint('[ShopService] ${results.length} magasins récupérés depuis Overpass/OSM');
    return results;
  }

  static Future<List<FishingShop>> _fetchBatch(List<CoastalCity> batch) async {
    final query = _buildOverpassQuery(batch);

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 200) {
          return _parseOverpassResponse(response.body, batch);
        }
        debugPrint('[ShopService] $endpoint a répondu ${response.statusCode}, essai miroir suivant');
      } catch (e) {
        debugPrint('[ShopService] Miroir $endpoint indisponible: $e');
        continue;
      }
    }
    return [];
  }

  static String _buildOverpassQuery(List<CoastalCity> cities) {
    final buffer = StringBuffer();
    buffer.writeln('[out:json][timeout:90];');
    buffer.writeln('(');
    for (final c in cities) {
      buffer.writeln('  node["shop"="fishing"](around:$_radiusMeters,${c.lat},${c.lon});');
      buffer.writeln('  way["shop"="fishing"](around:$_radiusMeters,${c.lat},${c.lon});');
    }
    buffer.writeln(');');
    buffer.writeln('out center tags;');
    return buffer.toString();
  }

  static List<FishingShop> _parseOverpassResponse(String body, List<CoastalCity> batch) {
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
      final phone = (tags['phone'] as String?) ?? (tags['contact:phone'] as String?) ?? '';
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

  static CoastalCity _nearestCity(double lat, double lon, List<CoastalCity> batch) {
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
    final match = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(raw);
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
