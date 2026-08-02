import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/services/user_spot_photo_processor.dart';

enum UserSpotFailure {
  authenticationRequired,
  duplicateSpot,
  limitReached,
  invalidPhoto,
  photoUploadFailed,
  appCheckUnavailable,
  permissionDenied,
  unavailable,
}

class UserSpotException implements Exception {
  const UserSpotException(this.failure);

  final UserSpotFailure failure;
}

class _UploadedPhoto {
  const _UploadedPhoto({required this.url, required this.objectKey});

  final String url;
  final String objectKey;
}

class UserSpotService {
  UserSpotService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseAppCheck? appCheck,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _appCheck = appCheck ?? FirebaseAppCheck.instance,
        _httpClient = httpClient ?? http.Client();

  static final UserSpotService instance = UserSpotService();

  static const _productionPhotoBaseUrl =
      'https://boosterfish-offline-maps.boosterfish-maps.workers.dev/';
  static const _photoBaseUrl = String.fromEnvironment(
    'SPOT_PHOTO_BASE_URL',
    defaultValue: _productionPhotoBaseUrl,
  );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;
  final http.Client _httpClient;
  final Distance _distance = const Distance();

  CollectionReference<Map<String, dynamic>> _privateSpots(String uid) {
    return _firestore.collection('users').doc(uid).collection('spots');
  }

  CollectionReference<Map<String, dynamic>> get _submissions {
    return _firestore.collection('spot_submissions');
  }

  Stream<List<UserSpot>> watchUserSpots(String uid) {
    late StreamController<List<UserSpot>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        privateSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        moderationSubscription;
    var privateSpots = <UserSpot>[];
    var moderation = <String, Map<String, dynamic>>{};

    void emit() {
      final merged = privateSpots.map((spot) {
        final review = moderation[spot.id];
        if (review == null) return spot;
        return spot.copyWith(
          status: SpotModerationStatus.fromValue(review['status']),
          moderationNote: _optionalString(review['moderationNote']),
        );
      }).toList()
        ..sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt;
          final bDate = b.updatedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return a.name.compareTo(b.name);
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
      if (!controller.isClosed) controller.add(merged);
    }

    controller = StreamController<List<UserSpot>>(
      onListen: () {
        privateSubscription = _privateSpots(uid).snapshots().listen(
          (snapshot) {
            privateSpots = snapshot.docs
                .map((doc) => _fromDocument(doc.id, doc.data()))
                .whereType<UserSpot>()
                .toList();
            emit();
          },
          onError: controller.addError,
        );
        moderationSubscription =
            _submissions.where('ownerUid', isEqualTo: uid).snapshots().listen(
          (snapshot) {
            moderation = {
              for (final doc in snapshot.docs) doc.id: doc.data(),
            };
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await privateSubscription?.cancel();
        await moderationSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<String> createSpot({
    required double latitude,
    required double longitude,
    required UserSpotDraft draft,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UserSpotException(UserSpotFailure.authenticationRequired);
    }
    _validateDraft(draft);
    final privateSnapshot = await _privateSpots(user.uid)
        .limit(UserSpot.maximumPersonalSpots + 1)
        .get();
    if (privateSnapshot.docs.length >= UserSpot.maximumPersonalSpots) {
      throw const UserSpotException(UserSpotFailure.limitReached);
    }
    if (_hasNearbySpot(
      documents: privateSnapshot.docs,
      latitude: latitude,
      longitude: longitude,
    )) {
      throw const UserSpotException(UserSpotFailure.duplicateSpot);
    }

    final privateDocument = _privateSpots(user.uid).doc();
    final submissionDocument = _submissions.doc(privateDocument.id);
    _UploadedPhoto? photo;

    try {
      final bytes = draft.photoBytes;
      if (bytes != null) {
        photo = await _uploadPhoto(
          spotId: privateDocument.id,
          bytes: bytes,
          contentType: draft.photoContentType,
        );
      }

      final now = FieldValue.serverTimestamp();
      final data = <String, dynamic>{
        'schemaVersion': 1,
        'ownerUid': user.uid,
        'name': draft.name.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'locationKey': locationKey(latitude, longitude),
        'notes': draft.notes.trim(),
        'dangerNotes': draft.dangerNotes.trim(),
        'photoUrl': photo?.url ?? '',
        'photoObjectKey': photo?.objectKey ?? '',
        'status': SpotModerationStatus.pending.name,
        'createdAt': now,
        'updatedAt': now,
      };
      final batch = _firestore.batch()
        ..set(privateDocument, data)
        ..set(submissionDocument, data);
      await batch.commit();
      return privateDocument.id;
    } on FirebaseException catch (error, stackTrace) {
      if (photo != null) await _deletePhoto(photo.objectKey);
      debugPrint(
        '[UserSpotService] Firestore create failed: ${error.code}\n$stackTrace',
      );
      throw UserSpotException(_mapFirebaseFailure(error));
    } on UserSpotException {
      if (photo != null) await _deletePhoto(photo.objectKey);
      rethrow;
    } catch (error, stackTrace) {
      if (photo != null) await _deletePhoto(photo.objectKey);
      debugPrint('[UserSpotService] Create failed: $error\n$stackTrace');
      throw const UserSpotException(UserSpotFailure.unavailable);
    }
  }

  Future<void> updateSpot(UserSpot spot, UserSpotDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UserSpotException(UserSpotFailure.authenticationRequired);
    }
    _validateDraft(draft);

    _UploadedPhoto? uploadedPhoto;
    try {
      final bytes = draft.photoBytes;
      if (bytes != null) {
        uploadedPhoto = await _uploadPhoto(
          spotId: spot.id,
          bytes: bytes,
          contentType: draft.photoContentType,
        );
      }

      final nextPhotoUrl = uploadedPhoto?.url ??
          (draft.removeExistingPhoto ? '' : spot.photoUrl ?? '');
      final nextObjectKey = uploadedPhoto?.objectKey ??
          (draft.removeExistingPhoto ? '' : spot.photoObjectKey ?? '');
      final returnsToReview = spot.status != SpotModerationStatus.approved;
      final changes = <String, dynamic>{
        'name': draft.name.trim(),
        'notes': draft.notes.trim(),
        'dangerNotes': draft.dangerNotes.trim(),
        'photoUrl': nextPhotoUrl,
        'photoObjectKey': nextObjectKey,
        'updatedAt': FieldValue.serverTimestamp(),
        if (returnsToReview) 'status': SpotModerationStatus.pending.name,
      };

      final batch = _firestore.batch()
        ..update(_privateSpots(user.uid).doc(spot.id), changes);
      if (returnsToReview) {
        batch.update(_submissions.doc(spot.id), changes);
      }
      await batch.commit();

      final oldObjectKey = spot.photoObjectKey;
      final replacedOrRemoved =
          uploadedPhoto != null || draft.removeExistingPhoto;
      if (replacedOrRemoved &&
          oldObjectKey != null &&
          oldObjectKey.isNotEmpty &&
          spot.status != SpotModerationStatus.approved) {
        await _deletePhoto(oldObjectKey);
      }
    } on FirebaseException catch (error, stackTrace) {
      if (uploadedPhoto != null) {
        await _deletePhoto(uploadedPhoto.objectKey);
      }
      debugPrint(
        '[UserSpotService] Firestore update failed: ${error.code}\n$stackTrace',
      );
      throw UserSpotException(_mapFirebaseFailure(error));
    } on UserSpotException {
      rethrow;
    } catch (error, stackTrace) {
      if (uploadedPhoto != null) {
        await _deletePhoto(uploadedPhoto.objectKey);
      }
      debugPrint('[UserSpotService] Update failed: $error\n$stackTrace');
      throw const UserSpotException(UserSpotFailure.unavailable);
    }
  }

  Future<void> deleteSpot(UserSpot spot) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UserSpotException(UserSpotFailure.authenticationRequired);
    }

    try {
      String? photoToDelete;
      if (spot.status == SpotModerationStatus.approved) {
        final submission = await _submissions.doc(spot.id).get();
        final officialPhotoKey = submission.exists
            ? _optionalString(submission.data()?['photoObjectKey'])
            : null;
        if (spot.photoObjectKey != officialPhotoKey) {
          photoToDelete = spot.photoObjectKey;
        }
      } else {
        photoToDelete = spot.photoObjectKey;
      }

      final batch = _firestore.batch()
        ..delete(_privateSpots(user.uid).doc(spot.id));
      if (spot.status != SpotModerationStatus.approved) {
        batch.delete(_submissions.doc(spot.id));
      }
      await batch.commit();
      if (photoToDelete != null && photoToDelete.isNotEmpty) {
        await _deletePhoto(photoToDelete);
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[UserSpotService] Firestore delete failed: ${error.code}\n$stackTrace',
      );
      throw UserSpotException(_mapFirebaseFailure(error));
    }
  }

  Future<void> deleteAllForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final privateSnapshot = await _privateSpots(user.uid).get();
    final submissionSnapshot =
        await _submissions.where('ownerUid', isEqualTo: user.uid).get();
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...privateSnapshot.docs.map((document) => document.reference),
      ...submissionSnapshot.docs.map((document) => document.reference),
    ];
    final photoKeys = <String>{};
    for (final document in [
      ...privateSnapshot.docs,
      ...submissionSnapshot.docs,
    ]) {
      final key = _optionalString(document.data()['photoObjectKey']);
      if (key != null) photoKeys.add(key);
    }

    for (final key in photoKeys) {
      final deleted = await _deletePhoto(key);
      if (!deleted) {
        throw const UserSpotException(UserSpotFailure.unavailable);
      }
    }
    for (var offset = 0; offset < references.length; offset += 400) {
      final batch = _firestore.batch();
      final end = (offset + 400).clamp(0, references.length);
      for (final reference in references.sublist(offset, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  Future<bool> hasNearbyPrivateSpot({
    required String uid,
    required double latitude,
    required double longitude,
    String? excludingSpotId,
  }) async {
    final snapshot = await _privateSpots(uid).get();
    return _hasNearbySpot(
      documents: snapshot.docs,
      latitude: latitude,
      longitude: longitude,
      excludingSpotId: excludingSpotId,
    );
  }

  bool _hasNearbySpot({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    required double latitude,
    required double longitude,
    String? excludingSpotId,
  }) {
    final point = LatLng(latitude, longitude);
    for (final document in documents) {
      if (document.id == excludingSpotId) continue;
      final data = document.data();
      final otherLatitude = (data['latitude'] as num?)?.toDouble();
      final otherLongitude = (data['longitude'] as num?)?.toDouble();
      if (otherLatitude == null || otherLongitude == null) continue;
      final meters = _distance.as(
        LengthUnit.Meter,
        point,
        LatLng(otherLatitude, otherLongitude),
      );
      if (meters <= UserSpot.duplicateRadiusMeters) return true;
    }
    return false;
  }

  static String locationKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}';
  }

  void _validateDraft(UserSpotDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty || name.length > UserSpot.maximumNameLength) {
      throw const UserSpotException(UserSpotFailure.unavailable);
    }
    if (draft.notes.trim().length > UserSpot.maximumNotesLength ||
        draft.dangerNotes.trim().length > UserSpot.maximumDangerNotesLength) {
      throw const UserSpotException(UserSpotFailure.unavailable);
    }
    final bytes = draft.photoBytes;
    if (bytes != null &&
        (bytes.isEmpty || bytes.length > UserSpot.maximumPhotoBytes)) {
      throw const UserSpotException(UserSpotFailure.invalidPhoto);
    }
  }

  Future<_UploadedPhoto> _uploadPhoto({
    required String spotId,
    required List<int> bytes,
    required String? contentType,
  }) async {
    if (bytes.isEmpty || bytes.length > UserSpot.maximumPhotoBytes) {
      throw const UserSpotException(UserSpotFailure.invalidPhoto);
    }
    final detectedContentType = detectUserSpotPhotoContentType(bytes);
    if (detectedContentType == null) {
      throw const UserSpotException(UserSpotFailure.invalidPhoto);
    }
    final normalizedContentType = detectedContentType;
    final revision = DateTime.now().microsecondsSinceEpoch;
    final objectKey = '$spotId-$revision';
    final baseUri = Uri.tryParse(_photoBaseUrl);
    if (baseUri == null || baseUri.scheme != 'https') {
      throw const UserSpotException(UserSpotFailure.photoUploadFailed);
    }
    final response = await _httpClient
        .put(
          baseUri.resolve('spot-photos/$objectKey'),
          headers: await _authorizationHeaders(
            contentType: normalizedContentType,
          ),
          body: Uint8List.fromList(bytes),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 201) {
      throw UserSpotException(
        switch (response.statusCode) {
          401 => UserSpotFailure.authenticationRequired,
          403 => UserSpotFailure.permissionDenied,
          413 || 415 => UserSpotFailure.invalidPhoto,
          _ => UserSpotFailure.photoUploadFailed,
        },
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['photoUrl'] is! String ||
        (payload['photoUrl'] as String).isEmpty) {
      throw const UserSpotException(UserSpotFailure.photoUploadFailed);
    }
    return _UploadedPhoto(
      url: payload['photoUrl'] as String,
      objectKey: objectKey,
    );
  }

  Future<bool> _deletePhoto(String objectKey) async {
    try {
      final baseUri = Uri.tryParse(_photoBaseUrl);
      if (baseUri == null || baseUri.scheme != 'https') return false;
      final response = await _httpClient
          .delete(
            baseUri.resolve('spot-photos/$objectKey'),
            headers: await _authorizationHeaders(),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 204 || response.statusCode == 404;
    } catch (error) {
      debugPrint('[UserSpotService] Photo cleanup deferred: $error');
      return false;
    }
  }

  Future<Map<String, String>> _authorizationHeaders({
    String? contentType,
  }) {
    return buildUserSpotPhotoAuthorizationHeaders(
      authTokenProvider: () async => _auth.currentUser?.getIdToken(),
      appCheckTokenProvider: () => _appCheck.getToken(false),
      contentType: contentType,
    );
  }

  static UserSpot? _fromDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    final name = data['name'];
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (name is! String || latitude == null || longitude == null) return null;
    return UserSpot(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      notes: data['notes'] as String? ?? '',
      dangerNotes: data['dangerNotes'] as String? ?? '',
      photoUrl: _optionalString(data['photoUrl']),
      photoObjectKey: _optionalString(data['photoObjectKey']),
      status: SpotModerationStatus.fromValue(data['status']),
      moderationNote: _optionalString(data['moderationNote']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    return value is Timestamp ? value.toDate() : null;
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static UserSpotFailure _mapFirebaseFailure(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => UserSpotFailure.permissionDenied,
      'unauthenticated' => UserSpotFailure.authenticationRequired,
      _ => UserSpotFailure.unavailable,
    };
  }
}

@visibleForTesting
Future<Map<String, String>> buildUserSpotPhotoAuthorizationHeaders({
  required Future<String?> Function() authTokenProvider,
  required Future<String?> Function() appCheckTokenProvider,
  String? contentType,
}) async {
  final authToken = await authTokenProvider();
  if (authToken == null || authToken.trim().isEmpty) {
    throw const UserSpotException(UserSpotFailure.authenticationRequired);
  }

  String? appCheckToken;
  try {
    appCheckToken = await appCheckTokenProvider();
  } catch (_) {
    throw const UserSpotException(UserSpotFailure.appCheckUnavailable);
  }
  if (appCheckToken == null || appCheckToken.trim().isEmpty) {
    throw const UserSpotException(UserSpotFailure.appCheckUnavailable);
  }

  return {
    'Authorization': 'Bearer ${authToken.trim()}',
    'X-Firebase-AppCheck': appCheckToken.trim(),
    if (contentType != null) 'Content-Type': contentType,
  };
}
