// ============================================================
//  services/spot_service.dart — Chargement et cache des spots
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models.dart';

class SpotService {
  SpotService._();

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/spots_cache_v4.json');
  }

  /// Exécute [computation] via [compute] sur mobile/desktop,
  /// ou directement sur le thread principal pour le web (isolates non supportés).
  static Future<R> _computeOrRun<Q, R>(
    R Function(Q) computation,
    Q message,
  ) async {
    if (kIsWeb) {
      return computation(message);
    }
    return compute(computation, message);
  }

  static Future<List<Spot>> loadFromCache() async {
    try {
      final file = await _cacheFile;
      if (!file.existsSync()) return [];
      return await _computeOrRun(_parseJson, await file.readAsString());
    } catch (e) {
      debugPrint('[SpotService] Erreur cache lecture: $e');
      return [];
    }
  }

  static List<Spot> _parseJson(String contents) {
    final list = jsonDecode(contents) as List<dynamic>;
    return list.map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveToCache(List<Spot> spots) async {
    try {
      final file = await _cacheFile;
      final data = await _computeOrRun(_serializeJson, spots);
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('[SpotService] Erreur cache écriture: $e');
    }
  }

  static String _serializeJson(List<Spot> spots) {
    return jsonEncode(spots.map((s) => s.toJson()).toList());
  }

  static Future<List<Spot>> loadFromCsv() async {
    final raw = await rootBundle.loadString('assets/spots.csv');
    return await _computeOrRun(_parseCsv, raw);
  }

  static List<Spot> _parseCsv(String raw) {
    final lines = raw.split('\n');
    final spots = <Spot>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        spots.add(Spot.fromCsv(line, index: i));
      } catch (_) {
        debugPrint('[SpotService] Skipped malformed CSV line $i: $line');
      }
    }
    return spots;
  }
}
