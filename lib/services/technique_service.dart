// ============================================================
//  technique_service.dart — Chargement des techniques depuis CSV
// ============================================================

import 'dart:convert' show utf8;
import 'package:flutter/services.dart' show rootBundle;
import 'package:spots_app/models/technique.dart';
import 'package:spots_app/l10n/app_localizations.dart';

class TechniqueService {
  static List<Technique>? _cache;
  static String? _cachedLang;

  /// Charge les techniques depuis le CSV correspondant à la langue active.
  /// Fallback sur la version française si la langue n'est pas supportée.
  static Future<List<Technique>> loadTechniques() async {
    final lang = LanguageController.instance.langCode;
    // Si on a déjà en cache pour cette langue, retourner directement
    if (_cache != null && _cachedLang == lang) return _cache!;

    // Déterminer le suffixe de langue pour le nom de fichier
    final String suffix;
    switch (lang) {
      case 'en':
        suffix = 'En';
        break;
      case 'ar':
        suffix = 'Ar';
        break;
      case 'fr':
      default:
        suffix = 'Fr';
        break;
    }

    // Charger en bytes pour gérer le BOM UTF-8
    final rawBytes = await rootBundle.load(
      'assets/peche_Montagestechnique_database$suffix.csv',
    );
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
      if (cols.length >= 10) {
        techniques.add(Technique.fromCsvRow(cols));
      }
    }

    _cache = techniques;
    _cachedLang = lang;
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

  static void clearCache() {
    _cache = null;
    _cachedLang = null;
  }
}
