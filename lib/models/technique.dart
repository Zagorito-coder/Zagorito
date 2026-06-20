// ============================================================
//  technique.dart — Modèle pour les nœuds de pêche
//  Schéma CSV 10 colonnes: ID;Nom;Categorie;Description;
//  Image URL;Poissons cibles;Technique;Difficulte;
//  Materiel necessaire;Conseils
// ============================================================

/// ── NŒUD DE PÊCHE ──
class Technique {
  final String id;
  final String name;
  final String category;
  final String description;
  final String photoUrl;
  final String targetFish;
  final String techniqueType;
  final String difficulty;
  final String requiredMaterial;
  final String tips;

  // Champs legacy conservés avec valeurs par défaut
  // pour éviter de casser tout le reste de la page détail
  final String scientificName;
  final String family;
  final String region;
  final String habitat;
  final int sizeMinCm;
  final int sizeMaxCm;
  final double weightMinKg;
  final double weightMaxKg;
  final String season;
  final String regulation;
  final List<FishingTechniqueStub> techniques;
  final List<FishingRigStub> rigs;
  final List<FishingKnotStub> knots;

  const Technique({
    required this.id,
    required this.name,
    this.category = '',
    this.description = '',
    this.photoUrl = '',
    this.targetFish = '',
    this.techniqueType = '',
    this.difficulty = '',
    this.requiredMaterial = '',
    this.tips = '',
    this.scientificName = '',
    this.family = '',
    this.region = '',
    this.habitat = '',
    this.sizeMinCm = 0,
    this.sizeMaxCm = 0,
    this.weightMinKg = 0.0,
    this.weightMaxKg = 0.0,
    this.season = '',
    this.regulation = '',
    this.techniques = const [],
    this.rigs = const [],
    this.knots = const [],
  });

  factory Technique.fromCsvRow(List<String> cols) {
    return Technique(
      id: cols[0].trim(),
      name: cols[1].trim(),
      category: cols[2].trim(),
      description: cols[3].trim(),
      photoUrl: cols[4].trim(),
      targetFish: cols[5].trim(),
      techniqueType: cols[6].trim(),
      difficulty: cols[7].trim(),
      requiredMaterial: cols[8].trim(),
      tips: cols[9].trim(),
    );
  }
}

// Stubs pour compatibilité avec l'ancien code de la page détail
class FishingTechniqueStub {
  final String name;
  final String description;
  final List<BaitStub> baits;
  const FishingTechniqueStub({
    required this.name,
    this.description = '',
    this.baits = const [],
  });
}

class BaitStub {
  final String name;
  final String description;
  const BaitStub({required this.name, this.description = ''});
}

class FishingRigStub {
  final String name;
  final String description;
  final List<String> components;
  const FishingRigStub({
    required this.name,
    this.description = '',
    this.components = const [],
  });
}

class FishingKnotStub {
  final String name;
  final String description;
  final String usage;
  const FishingKnotStub({
    required this.name,
    this.description = '',
    this.usage = '',
  });
}
