// ============================================================
//  fishing_shop.dart — Modèle Magasin de Pêche
// ============================================================

import 'package:latlong2/latlong.dart';

class FishingShop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String phone;
  final String address;
  final String imageUrl;
  final String openTime;
  final String closeTime;
  final List<String> tags; // ex: ['Appâts', 'Cannes', 'Matériel', 'Bateau']
  final bool isOpen;
  final double? rating;

  const FishingShop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.address,
    required this.imageUrl,
    required this.openTime,
    required this.closeTime,
    this.tags = const [],
    this.isOpen = true,
    this.rating,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory FishingShop.fromCsv(String line, {required int index}) {
    final parts = line.split(',');
    if (parts.length < 8) {
      throw const FormatException('Ligne invalide: besoin d\'au moins 8 colonnes');
    }

    final name = parts[0].trim();
    final lat = double.tryParse(parts[1]);
    final lng = double.tryParse(parts[2]);
    final phone = parts[3].trim();
    final address = parts[4].trim();
    final imageUrl = parts[5].trim();
    final openTime = parts[6].trim();
    final closeTime = parts[7].trim();

    if (lat == null || lng == null) {
      throw const FormatException('Coordonnées invalides');
    }

    final tags = parts.length > 8
        ? parts[8].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final rating = parts.length > 9 ? double.tryParse(parts[9]) : null;

    return FishingShop(
      id: 'shop_$index',
      name: name,
      latitude: lat,
      longitude: lng,
      phone: phone,
      address: address,
      imageUrl: imageUrl,
      openTime: openTime,
      closeTime: closeTime,
      tags: tags,
      rating: rating,
    );
  }

  factory FishingShop.fromJson(Map<String, dynamic> json) {
    return FishingShop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      phone: json['phone'] as String,
      address: json['address'] as String,
      imageUrl: json['imageUrl'] as String,
      openTime: json['openTime'] as String,
      closeTime: json['closeTime'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      isOpen: json['isOpen'] as bool? ?? true,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'address': address,
    'imageUrl': imageUrl,
    'openTime': openTime,
    'closeTime': closeTime,
    'tags': tags,
    'isOpen': isOpen,
    'rating': rating,
  };
}

/// Groupe de magasins associés à un spot
class ShopSpotGroup {
  final String spotId;
  final String spotName;
  final double spotLat;
  final double spotLng;
  final List<FishingShop> shops;

  const ShopSpotGroup({
    required this.spotId,
    required this.spotName,
    required this.spotLat,
    required this.spotLng,
    required this.shops,
  });
}
