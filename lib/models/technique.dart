// ============================================================
//  technique.dart — Modèle pour les techniques/montages
//  Même schéma CSV que fish_species + Rigs + Knots dérivés
// ============================================================

import 'package:spots_app/models/fish_species.dart' show FishSpecies, FishingTechnique;

/// ── MONTAGE ──
class FishingRig {
  final String name;
  final String description;
  final List<String> components;

  const FishingRig({
    required this.name,
    required this.description,
    required this.components,
  });
}

/// ── NŒUD ──
class FishingKnot {
  final String name;
  final String description;
  final String usage;

  const FishingKnot({
    required this.name,
    required this.description,
    required this.usage,
  });
}

/// ── TECHNIQUE (fiche montage/technique) ──
class Technique {
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
  final List<FishingRig> rigs;
  final List<FishingKnot> knots;
  final String description;
  final String tips;
  final String regulation;

  const Technique({
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
    required this.rigs,
    required this.knots,
    required this.description,
    required this.tips,
    required this.regulation,
  });

  static List<FishingRig> _deriveRigs(List<FishingTechnique> techniques) {
    final rigs = <FishingRig>[];
    for (final t in techniques) {
      final components = t.baits.map((b) => b.name).toList();
      rigs.add(FishingRig(
        name: 'Montage ${t.name}',
        description: t.description.isNotEmpty
            ? t.description
            : 'Configuration optimale pour ${t.name.toLowerCase()}.',
        components: components.isNotEmpty
            ? components
            : const ['Hameçon adapté', 'Fluorocarbone', 'Plomb'],
      ));
    }
    return rigs;
  }

  static List<FishingKnot> _deriveKnots(List<FishingTechnique> techniques) {
    final knots = <FishingKnot>[
      const FishingKnot(
        name: 'Nœud de pêcheur (Clinch)',
        description: 'Nœud universel pour fixer l\'hameçon ou le leurre. Faire 5-6 tours autour du fil avant de repasser dans la boucle.',
        usage: 'Toutes techniques',
      ),
      const FishingKnot(
        name: 'Nœud Palomar',
        description: 'Nœud très résistant, double le fil. Passer dans l\'anneau, faire une boucle, nouer, puis passer l\'hameçon dans la boucle.',
        usage: 'Surfcasting, pêche au gros',
      ),
    ];

    final names = techniques.map((t) => t.name.toLowerCase()).join(' ');

    if (names.contains('spinning') || names.contains('leurre')) {
      knots.add(const FishingKnot(
        name: 'Nœud Rapala',
        description: 'Idéal pour les leurres articulés. Ne comprime pas l\'anneau et laisse un mouvement naturel.',
        usage: 'Spinning, leurre',
      ));
      knots.add(const FishingKnot(
        name: 'Nœud Uni (Grinner)',
        description: 'Excellent pour les têtes plombées et les montages en drop-shot. Très fiable.',
        usage: 'Spinning, leurre souple',
      ));
    }

    if (names.contains('surfcasting')) {
      knots.add(const FishingKnot(
        name: 'Nœud Blood Knot',
        description: 'Parfait pour raccorder deux fils de même diamètre. Indispensable pour les bas de ligne.',
        usage: 'Surfcasting, montages',
      ));
    }

    if (names.contains('pater') || names.contains('coulissant')) {
      knots.add(const FishingKnot(
        name: 'Nœud Dropper',
        description: 'Permet de créer une patte sur le fil principal pour le montage pater-noster.',
        usage: 'Pater-noster, montage coulissant',
      ));
    }

    return knots;
  }

  static Technique fromCsvRow(List<String> cols) {
    final techniques = FishSpecies.parseTechniques(cols[12].trim());
    return Technique(
      id: cols[0].trim(),
      name: cols[1].trim(),
      scientificName: cols[2].trim(),
      family: cols[3].trim(),
      photoUrl: cols[4].trim(),
      region: cols[5].trim(),
      habitat: cols[6].trim(),
      sizeMinCm: int.tryParse(cols[7].trim()) ?? 0,
      sizeMaxCm: int.tryParse(cols[8].trim()) ?? 0,
      weightMinKg: double.tryParse(cols[9].trim().replaceFirst(',', '.')) ?? 0.0,
      weightMaxKg: double.tryParse(cols[10].trim().replaceFirst(',', '.')) ?? 0.0,
      season: cols[11].trim(),
      techniques: techniques,
      rigs: _deriveRigs(techniques),
      knots: _deriveKnots(techniques),
      description: cols[13].trim(),
      tips: cols[14].trim(),
      regulation: cols[15].trim(),
    );
  }
}
