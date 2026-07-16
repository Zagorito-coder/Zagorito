import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum SpotType { sandyBeach, rockySpot, cliffTop, mixedSandRock, remoteSpot }

/// Extensions pour faciliter l'affichage et la colorisation des types de spots.
extension SpotTypeExtension on SpotType {
  Color get color {
    switch (this) {
      case SpotType.sandyBeach:
        return const Color(0xFFE74C3C); // 1 - Rouge : plages sableuses
      case SpotType.rockySpot:
        return const Color(0xFF9B59B6); // 2 - Violet : spots rocheux
      case SpotType.cliffTop:
        return const Color(0xFF0066CC); // 3 - Bleu marin : falaises
      case SpotType.mixedSandRock:
        return const Color(0xFFE67E22); // 4 - Orange : mixtes sable/rocher
      case SpotType.remoteSpot:
        return const Color(0xFF1ABC9C); // 5 - Cyan : loin des routes nationaux
    }
  }

  String get label {
    switch (this) {
      case SpotType.sandyBeach: return 'Plage de sable';
      case SpotType.rockySpot: return 'Spot rocheux';
      case SpotType.cliffTop: return 'Haut de falaise';
      case SpotType.mixedSandRock: return 'Mixte sable/rocher';
      case SpotType.remoteSpot: return 'Loin des routes';
    }
  }
}

class Spot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final LatLng location;
  final SpotType type;
  final List<String> fishTypes;
  final String notes;

  const Spot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.location,
    this.type = SpotType.remoteSpot,
    this.fishTypes = const [],
    this.notes = '',
  });

  factory Spot.fromCsv(String line, {required int index}) {
    final parts = line.split(',');
    if (parts.length < 3) {
      throw const FormatException('Ligne invalide: besoin d\'au moins 3 colonnes');
    }

    final name = parts[0].trim();
    final lat = double.tryParse(parts[1]);
    final lng = double.tryParse(parts[2]);

    if (lat == null || lng == null) {
      throw const FormatException('Coordonnées invalides');
    }

    final List<String> fishTypes = parts.length > 3
        ? parts[3].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final String notes = parts.length > 4 ? parts[4].trim() : '';

    return Spot(
      id: 'spot_$index',
      name: name,
      latitude: lat,
      longitude: lng,
      location: LatLng(lat, lng),
      type: _inferSpotType(name),
      fishTypes: fishTypes,
      notes: notes,
    );
  }

  factory Spot.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num).toDouble();
    final lng = (json['longitude'] as num).toDouble();

    return Spot(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: lat,
      longitude: lng,
      location: LatLng(lat, lng),
      type: SpotType.values.firstWhere(
        (t) => t.toString() == (json['type'] as String),
        orElse: () => SpotType.remoteSpot,
      ),
      fishTypes: List<String>.from(json['fishTypes'] as List? ?? []),
      notes: json['notes'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'type': type.toString(),
    'fishTypes': fishTypes,
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Spot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Déduit le type de spot en fonction de mots-clés dans son nom.
  static SpotType _inferSpotType(String name) {
    final lower = name.toLowerCase();

    final hasSand = lower.contains('plage') ||
        lower.contains('sable') ||
        lower.contains('aftas') ||
        lower.contains('افتاس');
    final hasRock = lower.contains('roch') ||
        lower.contains('حرش') ||
        lower.contains('roche') ||
        lower.contains('pointe') ||
        lower.contains('cap') ||
        lower.contains('isk') ||
        lower.contains('إيسك');

    // 4 - Mixte sable/rocher
    if (hasSand && hasRock) return SpotType.mixedSandRock;

    // 1 - Plage de sable
    if (hasSand) return SpotType.sandyBeach;

    // 2 - Spot rocheux
    if (hasRock) return SpotType.rockySpot;

    // 3 - Falaise
    if (lower.contains('falaise')) return SpotType.cliffTop;

    // 5 - Loin des routes / non catégorisé
    return SpotType.remoteSpot;
  }
}