// ============================================================
//  technique_service.dart — Chargement des techniques depuis CSV
// ============================================================

import 'dart:convert' show utf8;
import 'package:flutter/services.dart' show rootBundle;
import 'package:spots_app/models/technique.dart';

class TechniqueService {
  static List<Technique>? _cache;

  static Future<List<Technique>> loadTechniques() async {
    if (_cache != null) return _cache!;

    // Charger en bytes pour gérer le BOM UTF-8
    final rawBytes = await rootBundle.load('assets/peche_Montagestechnique_database.csv');
    var raw = utf8.decode(rawBytes.buffer.asUint8List());
    if (raw.startsWith('\uFEFF')) {
      raw = raw.substring(1);
    }
    final lines = raw.split('\n');
    if (lines.isEmpty) return [];

    final techniques = <Technique>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvLine(line);
      if (cols.length >= 16) {
        techniques.add(Technique.fromCsvRow(cols));
      }
    }

    _cache = techniques;
    return techniques;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ';' && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  static void clearCache() => _cache = null;
}
