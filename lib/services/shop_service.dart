// ============================================================
//  shop_service.dart — Service de chargement et regroupement
//  des magasins de pêche synchronisés avec les spots
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../models/fishing_shop.dart';

class ShopService {
  ShopService._();

  static const _cacheFileName = 'shops_cache_v1.json';
  static const _distanceCalc = Distance();

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  /// Charge tous les magasins depuis le cache CSV ou le bundle
  static Future<List<FishingShop>> loadShops() async {
    try {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) return cached;
    } catch (e) {
      debugPrint('[ShopService] Erreur cache lecture: $e');
    }

    final fromCsv = await _loadFromCsv();
    try {
      await _saveToCache(fromCsv);
    } catch (e) {
      debugPrint('[ShopService] Erreur cache écriture: $e');
    }
    return fromCsv;
  }

  /// Regroupe les magasins par spot le plus proche (rayon 50 km)
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
    // Trie par nombre de magasins décroissant
    result.sort((a, b) => b.shops.length.compareTo(a.shops.length));
    return result;
  }

  /// Calcule la distance entre un spot et un magasin
  static double distanceBetween(Spot spot, FishingShop shop) {
    return _distanceCalc.as(
      LengthUnit.Kilometer,
      LatLng(spot.latitude, spot.longitude),
      LatLng(shop.latitude, shop.longitude),
    );
  }

  // ── Private helpers ──

  static Future<List<FishingShop>> _loadFromCache() async {
    final file = await _cacheFile;
    if (!file.existsSync()) return [];
    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => FishingShop.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveToCache(List<FishingShop> shops) async {
    final file = await _cacheFile;
    final data = jsonEncode(shops.map((s) => s.toJson()).toList());
    await file.writeAsString(data);
  }

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
