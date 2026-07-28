enum SpotModerationStatus {
  pending,
  approved,
  rejected;

  static SpotModerationStatus fromValue(Object? value) {
    return switch (value) {
      'approved' => SpotModerationStatus.approved,
      'rejected' => SpotModerationStatus.rejected,
      _ => SpotModerationStatus.pending,
    };
  }
}

class UserSpot {
  const UserSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.notes,
    required this.dangerNotes,
    required this.status,
    this.photoUrl,
    this.photoObjectKey,
    this.moderationNote,
    this.createdAt,
    this.updatedAt,
  });

  static const maximumNameLength = 80;
  static const maximumNotesLength = 1000;
  static const maximumDangerNotesLength = 500;
  static const maximumPhotoBytes = 2 * 1024 * 1024;
  static const duplicateRadiusMeters = 100.0;

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String notes;
  final String dangerNotes;
  final String? photoUrl;
  final String? photoObjectKey;
  final SpotModerationStatus status;
  final String? moderationNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasDanger => dangerNotes.trim().isNotEmpty;
  bool get hasPhoto => photoUrl?.trim().isNotEmpty ?? false;

  UserSpot copyWith({
    String? name,
    String? notes,
    String? dangerNotes,
    String? photoUrl,
    String? photoObjectKey,
    SpotModerationStatus? status,
    String? moderationNote,
    DateTime? updatedAt,
  }) {
    return UserSpot(
      id: id,
      name: name ?? this.name,
      latitude: latitude,
      longitude: longitude,
      notes: notes ?? this.notes,
      dangerNotes: dangerNotes ?? this.dangerNotes,
      photoUrl: photoUrl ?? this.photoUrl,
      photoObjectKey: photoObjectKey ?? this.photoObjectKey,
      status: status ?? this.status,
      moderationNote: moderationNote ?? this.moderationNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserSpotDraft {
  const UserSpotDraft({
    required this.name,
    required this.notes,
    required this.dangerNotes,
    this.photoBytes,
    this.photoContentType,
    this.removeExistingPhoto = false,
  });

  final String name;
  final String notes;
  final String dangerNotes;
  final List<int>? photoBytes;
  final String? photoContentType;
  final bool removeExistingPhoto;
}
