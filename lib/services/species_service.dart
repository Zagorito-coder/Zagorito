// ============================================================
//  species_service.dart — Chargement des espèces depuis CSV
// ============================================================

import 'dart:convert' show utf8;
import 'package:flutter/services.dart' show rootBundle;
import 'package:spots_app/models/fish_species.dart';
import 'package:spots_app/l10n/app_localizations.dart';

class SpeciesService {
  static List<FishSpecies>? _cache;
  static String? _cachedLang;

  static String _fileForLang(String lang) {
    if (lang == 'ar') return 'assets/peche_cotiere_databaseAr.csv';
    if (lang == 'en') return 'assets/peche_cotiere_databaseEn.csv';
    if (lang == 'es') return 'assets/peche_cotiere_databaseEs.csv';
    return 'assets/peche_cotiere_databaseFr.csv';
  }

  static Future<List<FishSpecies>> loadSpecies() async {
    final lang = LanguageController.instance.langCode;
    if (_cache != null && _cachedLang == lang) return _cache!;

    final rawBytes = await rootBundle.load(_fileForLang(lang));
    // Strip le BOM UTF-8 (\xEF\xBB\xBF) s'il est présent
    var raw = utf8.decode(rawBytes.buffer.asUint8List());
    if (raw.startsWith('\uFEFF')) {
      raw = raw.substring(1);
    }
    final lines = raw.split('\n');
    if (lines.isEmpty) return [];

    // Sauter l'en-tête
    final species = <FishSpecies>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvLine(line);
      if (cols.length >= 16) {
        species.add(FishSpecies.fromCsvRow(cols));
      }
    }

    _cache = species;
    _cachedLang = lang;
    return species;
  }

  /// Parse une ligne CSV avec point-virgule comme séparateur,
  /// en gérant correctement les guillemets
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

  static void clearCache() {
    _cache = null;
    _cachedLang = null;
  }
}
