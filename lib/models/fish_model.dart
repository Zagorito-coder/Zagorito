// ============================================================
//  fish_model.dart — Modèle de données pour les poissons
// ============================================================

import 'package:flutter/foundation.dart';

@immutable
class FishModel {
  final String id;
  final String name;
  final String scientificName;
  final String imageUrl;
  final String description;
  final List<String> techniques;
  final String montage;
  final List<String> baits;
  final String bestSeason;
  final String habitat;
  final double minSize;
  final double averageWeight;
  final String fishingAdvice;
  final List<String> compatibleSpotTypes;

  const FishModel({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.imageUrl,
    required this.description,
    required this.techniques,
    required this.montage,
    required this.baits,
    required this.bestSeason,
    required this.habitat,
    required this.minSize,
    required this.averageWeight,
    required this.fishingAdvice,
    required this.compatibleSpotTypes,
  });

  factory FishModel.fromJson(Map<String, dynamic> json) {
    return FishModel(
      id: json['id'] as String,
      name: json['name'] as String,
      scientificName: json['scientificName'] as String,
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String,
      techniques: List<String>.from(json['techniques'] as List? ?? []),
      montage: json['montage'] as String,
      baits: List<String>.from(json['baits'] as List? ?? []),
      bestSeason: json['bestSeason'] as String,
      habitat: json['habitat'] as String,
      minSize: (json['minSize'] as num).toDouble(),
      averageWeight: (json['averageWeight'] as num).toDouble(),
      fishingAdvice: json['fishingAdvice'] as String,
      compatibleSpotTypes: List<String>.from(json['compatibleSpotTypes'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scientificName': scientificName,
    'imageUrl': imageUrl,
    'description': description,
    'techniques': techniques,
    'montage': montage,
    'baits': baits,
    'bestSeason': bestSeason,
    'habitat': habitat,
    'minSize': minSize,
    'averageWeight': averageWeight,
    'fishingAdvice': fishingAdvice,
    'compatibleSpotTypes': compatibleSpotTypes,
  };

  FishModel copyWith({
    String? id,
    String? name,
    String? scientificName,
    String? imageUrl,
    String? description,
    List<String>? techniques,
    String? montage,
    List<String>? baits,
    String? bestSeason,
    String? habitat,
    double? minSize,
    double? averageWeight,
    String? fishingAdvice,
    List<String>? compatibleSpotTypes,
  }) {
    return FishModel(
      id: id ?? this.id,
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      techniques: techniques ?? this.techniques,
      montage: montage ?? this.montage,
      baits: baits ?? this.baits,
      bestSeason: bestSeason ?? this.bestSeason,
      habitat: habitat ?? this.habitat,
      minSize: minSize ?? this.minSize,
      averageWeight: averageWeight ?? this.averageWeight,
      fishingAdvice: fishingAdvice ?? this.fishingAdvice,
      compatibleSpotTypes: compatibleSpotTypes ?? this.compatibleSpotTypes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FishModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
