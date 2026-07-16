// ============================================================
//  fish_species.dart — Modèle pour les espèces de poissons
// ============================================================

class FishingTechnique {
  final String name;
  final String description;
  final List<Bait> baits;

  const FishingTechnique({
    required this.name,
    required this.description,
    required this.baits,
  });
}

class Bait {
  final String name;
  final String description;

  const Bait({required this.name, required this.description});
}

class FishSpecies {
  final String id;
  final String name;
  final String scientificName;
  final String family;
  final String photoUrl;
  final String region;
  final String habitat;
  final int sizeMinCm;
  final int sizeMaxCm;
  final double weightMinKg;
  final double weightMaxKg;
  final String season;
  final List<FishingTechnique> techniques;
  final String description;
  final String tips;
  final String regulation;

  const FishSpecies({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.family,
    required this.photoUrl,
    required this.region,
    required this.habitat,
    required this.sizeMinCm,
    required this.sizeMaxCm,
    required this.weightMinKg,
    required this.weightMaxKg,
    required this.season,
    required this.techniques,
    required this.description,
    required this.tips,
    required this.regulation,
  });

  /// Parse la colonne "Techniques et appâts"
  /// Format: "Technique - Description. [Appât: Desc. | Appât2: Desc.] ;; Technique2 - Desc. [...]"
  static List<FishingTechnique> parseTechniques(String raw) {
    final techniques = <FishingTechnique>[];
    if (raw.isEmpty) return techniques;

    final techniqueBlocks = raw.split(' ;; ');
    for (final block in techniqueBlocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      // Extraction nom et description (avant les crochets)
      String name = '';
      String desc = '';
      String baitSection = '';

      final bracketIdx = trimmed.indexOf('[');
      if (bracketIdx != -1) {
        final beforeBrackets = trimmed.substring(0, bracketIdx).trim();
        final closeBracketIdx = trimmed.lastIndexOf(']');
        if (closeBracketIdx != -1) {
          baitSection = trimmed.substring(bracketIdx + 1, closeBracketIdx).trim();
        }

        // Parse nom et description
        final dashIdx = beforeBrackets.indexOf(' - ');
        if (dashIdx != -1) {
          name = beforeBrackets.substring(0, dashIdx).trim();
          desc = beforeBrackets.substring(dashIdx + 3).trim();
          // Enlever le point final s'il existe
          if (desc.endsWith('.')) desc = desc.substring(0, desc.length - 1);
        } else {
          name = beforeBrackets;
        }
      } else {
        // Pas de crochets
        final dashIdx = trimmed.indexOf(' - ');
        if (dashIdx != -1) {
          name = trimmed.substring(0, dashIdx).trim();
          desc = trimmed.substring(dashIdx + 3).trim();
        } else {
          name = trimmed;
        }
      }

      // Parse les appâts
      final baits = <Bait>[];
      if (baitSection.isNotEmpty) {
        final baitParts = baitSection.split(' | ');
        for (final part in baitParts) {
          final colonIdx = part.indexOf(':');
          if (colonIdx != -1) {
            final baitName = part.substring(0, colonIdx).trim();
            final baitDesc = part.substring(colonIdx + 1).trim();
            baits.add(Bait(name: baitName, description: baitDesc));
          } else {
            baits.add(Bait(name: part.trim(), description: ''));
          }
        }
      }

      techniques.add(FishingTechnique(
        name: name,
        description: desc,
        baits: baits,
      ));
    }

    return techniques;
  }

  static FishSpecies fromCsvRow(List<String> cols) {
    final id = cols[0].trim();
    final local = _localAssetForId(id);
    return FishSpecies(
      id: id,
      name: cols[1].trim(),
      scientificName: cols[2].trim(),
      family: cols[3].trim(),
      photoUrl: local ?? cols[4].trim(),
      region: cols[5].trim(),
      habitat: cols[6].trim(),
      sizeMinCm: int.tryParse(cols[7].trim()) ?? 0,
      sizeMaxCm: int.tryParse(cols[8].trim()) ?? 0,
      weightMinKg: double.tryParse(cols[9].trim().replaceFirst(',', '.')) ?? 0.0,
      weightMaxKg: double.tryParse(cols[10].trim().replaceFirst(',', '.')) ?? 0.0,
      season: cols[11].trim(),
      techniques: parseTechniques(cols[12].trim()),
      description: cols[13].trim(),
      tips: cols[14].trim(),
      regulation: cols[15].trim(),
    );
  }

  static String? _localAssetForId(String id) {
    // Seulement les espèces qui ont une vraie image dans assets/fish_images/
    const map = {
      'bar-europeen': 'bar',
      'dorade-royale': 'daurade',
      'mulet': 'mulet',
      'pageot-rose': 'pageot',
      'sole': 'sole',
      'thon-rouge': 'thon',
    };
    final file = map[id];
    return file != null ? 'assets/fish_images/$file.png' : null;
  }
}
