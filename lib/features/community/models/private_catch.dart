import 'dart:typed_data';

class PrivateCatch {
  const PrivateCatch({
    required this.id,
    required this.ownerUid,
    required this.photoPath,
    required this.species,
    required this.weightKg,
    required this.spotName,
    required this.montage,
    required this.bait,
    required this.notes,
    required this.advice,
    required this.caughtAt,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.publishedPostId,
    this.publishedAt,
  });

  static const maximumItems = 20;
  static const maximumPhotoBytes = 2 * 1024 * 1024;
  static const maximumSpeciesLength = 80;
  static const maximumSpotNameLength = 100;
  static const maximumMontageLength = 160;
  static const maximumBaitLength = 120;
  static const maximumNotesLength = 600;
  static const maximumAdviceLength = 400;
  static const minimumWeightKg = 0.01;
  static const maximumWeightKg = 1000.0;

  final String id;
  final String ownerUid;
  final String photoPath;
  final String species;
  final double weightKg;
  final String spotName;
  final double? latitude;
  final double? longitude;
  final String montage;
  final String bait;
  final String notes;
  final String advice;
  final DateTime caughtAt;
  final DateTime createdAt;
  final String? publishedPostId;
  final DateTime? publishedAt;

  bool get isPublished => publishedPostId?.isNotEmpty ?? false;

  PrivateCatch copyWith({
    String? species,
    double? weightKg,
    String? spotName,
    double? latitude,
    double? longitude,
    String? montage,
    String? bait,
    String? notes,
    String? advice,
    DateTime? caughtAt,
    String? publishedPostId,
    DateTime? publishedAt,
    bool clearPublication = false,
  }) {
    return PrivateCatch(
      id: id,
      ownerUid: ownerUid,
      photoPath: photoPath,
      species: species ?? this.species,
      weightKg: weightKg ?? this.weightKg,
      spotName: spotName ?? this.spotName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      montage: montage ?? this.montage,
      bait: bait ?? this.bait,
      notes: notes ?? this.notes,
      advice: advice ?? this.advice,
      caughtAt: caughtAt ?? this.caughtAt,
      createdAt: createdAt,
      publishedPostId:
          clearPublication ? null : publishedPostId ?? this.publishedPostId,
      publishedAt: clearPublication ? null : publishedAt ?? this.publishedAt,
    );
  }

  Map<String, Object?> toDatabase() => {
        'id': id,
        'owner_uid': ownerUid,
        'photo_path': photoPath,
        'species': species,
        'weight_kg': weightKg,
        'spot_name': spotName,
        'latitude': latitude,
        'longitude': longitude,
        'montage': montage,
        'bait': bait,
        'notes': notes,
        'advice': advice,
        'caught_at': caughtAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'published_post_id': publishedPostId,
        'published_at': publishedAt?.millisecondsSinceEpoch,
      };

  factory PrivateCatch.fromDatabase(Map<String, Object?> data) {
    return PrivateCatch(
      id: data['id']! as String,
      ownerUid: data['owner_uid']! as String,
      photoPath: data['photo_path']! as String,
      species: data['species']! as String,
      weightKg: (data['weight_kg']! as num).toDouble(),
      spotName: data['spot_name']! as String,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      montage: data['montage']! as String,
      bait: data['bait']! as String,
      notes: data['notes']! as String,
      advice: data['advice']! as String,
      caughtAt: DateTime.fromMillisecondsSinceEpoch(
        data['caught_at']! as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['created_at']! as int,
      ),
      publishedPostId: data['published_post_id'] as String?,
      publishedAt: data['published_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(data['published_at']! as int),
    );
  }
}

class PrivateCatchDraft {
  const PrivateCatchDraft({
    required this.photoBytes,
    required this.species,
    required this.weightKg,
    required this.spotName,
    required this.montage,
    required this.bait,
    required this.notes,
    required this.advice,
    required this.caughtAt,
    this.latitude,
    this.longitude,
  });

  final Uint8List photoBytes;
  final String species;
  final double weightKg;
  final String spotName;
  final double? latitude;
  final double? longitude;
  final String montage;
  final String bait;
  final String notes;
  final String advice;
  final DateTime caughtAt;
}

enum PrivateCatchFailure {
  authenticationRequired,
  limitReached,
  invalidPhoto,
  invalidData,
  unavailable,
}

class PrivateCatchException implements Exception {
  const PrivateCatchException(this.failure);

  final PrivateCatchFailure failure;
}
