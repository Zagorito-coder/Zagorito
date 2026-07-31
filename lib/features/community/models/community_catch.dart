import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityCatch {
  const CommunityCatch({
    required this.id,
    required this.ownerUid,
    required this.anglerName,
    required this.avatarUrl,
    required this.photoUrl,
    required this.photoObjectKey,
    required this.species,
    required this.weightKg,
    required this.zoneName,
    required this.latitude,
    required this.longitude,
    required this.montage,
    required this.bait,
    required this.notes,
    required this.advice,
    required this.likeCount,
    required this.createdAt,
    required this.expiresAt,
  });

  static const maximumPublicItems = 100;
  static const publicationLifetime = Duration(days: 7);
  static const publicationCooldown = Duration(hours: 24);

  final String id;
  final String ownerUid;
  final String anglerName;
  final String avatarUrl;
  final String photoUrl;
  final String photoObjectKey;
  final String species;
  final double weightKg;
  final String zoneName;
  final double latitude;
  final double longitude;
  final String montage;
  final String bait;
  final String notes;
  final String advice;
  final int likeCount;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime time) => expiresAt.isAfter(time);

  static CommunityCatch? fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null || data['status'] != 'published') return null;
    final createdAt = data['createdAt'];
    final expiresAt = data['expiresAt'];
    if (createdAt is! Timestamp || expiresAt is! Timestamp) return null;

    final ownerUid = _requiredString(data['ownerUid'], 128);
    final anglerName = _requiredString(data['anglerName'], 80);
    final photoUrl = _requiredString(data['photoUrl'], 1024);
    final photoObjectKey = _requiredString(data['photoObjectKey'], 225);
    final species = _requiredString(data['species'], 80);
    final zoneName = _requiredString(data['zoneName'], 100);
    final latitude = _number(data['publicLatitude']);
    final longitude = _number(data['publicLongitude']);
    final weightKg = _number(data['weightKg']);
    final likeCount = data['likeCount'];
    if (ownerUid == null ||
        anglerName == null ||
        photoUrl == null ||
        photoObjectKey == null ||
        species == null ||
        zoneName == null ||
        latitude == null ||
        longitude == null ||
        weightKg == null ||
        likeCount is! int ||
        likeCount < 0 ||
        latitude < -85 ||
        latitude > 85 ||
        longitude < -180 ||
        longitude > 180 ||
        weightKg <= 0 ||
        weightKg > 1000) {
      return null;
    }
    return CommunityCatch(
      id: document.id,
      ownerUid: ownerUid,
      anglerName: anglerName,
      avatarUrl: _optionalString(data['avatarUrl'], 1024),
      photoUrl: photoUrl,
      photoObjectKey: photoObjectKey,
      species: species,
      weightKg: weightKg,
      zoneName: zoneName,
      latitude: latitude,
      longitude: longitude,
      montage: _optionalString(data['montage'], 160),
      bait: _optionalString(data['bait'], 120),
      notes: _optionalString(data['notes'], 600),
      advice: _optionalString(data['advice'], 400),
      likeCount: likeCount,
      createdAt: createdAt.toDate(),
      expiresAt: expiresAt.toDate(),
    );
  }

  static String? _requiredString(Object? value, int maximumLength) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maximumLength) return null;
    return trimmed;
  }

  static String _optionalString(Object? value, int maximumLength) {
    if (value is! String) return '';
    final trimmed = value.trim();
    if (trimmed.length > maximumLength) return '';
    return trimmed;
  }

  static double? _number(Object? value) {
    if (value is! num) return null;
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }
}

class WeeklyCommunityWinner {
  const WeeklyCommunityWinner({
    required this.catchId,
    required this.anglerName,
    required this.avatarUrl,
    required this.photoUrl,
    required this.species,
    required this.weightKg,
    required this.zoneName,
    required this.likeCount,
    required this.weekId,
  });

  final String catchId;
  final String anglerName;
  final String avatarUrl;
  final String photoUrl;
  final String species;
  final double weightKg;
  final String zoneName;
  final int likeCount;
  final String weekId;

  static WeeklyCommunityWinner? fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) return null;
    final catchId = data['catchId'];
    final anglerName = data['anglerName'];
    final photoUrl = data['photoUrl'];
    final species = data['species'];
    final weightKg = data['weightKg'];
    final zoneName = data['zoneName'];
    final likeCount = data['likeCount'];
    final weekId = data['weekId'];
    if (catchId is! String ||
        catchId.isEmpty ||
        anglerName is! String ||
        anglerName.isEmpty ||
        photoUrl is! String ||
        photoUrl.isEmpty ||
        species is! String ||
        species.isEmpty ||
        weightKg is! num ||
        zoneName is! String ||
        zoneName.isEmpty ||
        likeCount is! int ||
        likeCount < 0 ||
        weekId is! String ||
        weekId.isEmpty) {
      return null;
    }
    return WeeklyCommunityWinner(
      catchId: catchId,
      anglerName: anglerName,
      avatarUrl: data['avatarUrl'] is String ? data['avatarUrl'] as String : '',
      photoUrl: photoUrl,
      species: species,
      weightKg: weightKg.toDouble(),
      zoneName: zoneName,
      likeCount: likeCount,
      weekId: weekId,
    );
  }
}

enum CommunityFailure {
  authenticationRequired,
  termsRequired,
  publicationCooldown,
  invalidData,
  invalidPhoto,
  uploadFailed,
  ownPostLike,
  postUnavailable,
  permissionDenied,
  appCheckUnavailable,
  unavailable,
}

class CommunityException implements Exception {
  const CommunityException(this.failure, {this.retryAt});

  final CommunityFailure failure;
  final DateTime? retryAt;
}
