import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:spots_app/features/community/models/community_catch.dart';
import 'package:spots_app/features/community/models/private_catch.dart';
import 'package:spots_app/features/community/services/community_photo_service.dart';
import 'package:spots_app/features/community/services/community_privacy.dart';
import 'package:spots_app/features/community/services/private_catch_repository.dart';

/// Identité affichée dans la galerie publique, indépendante du nom du compte
/// Google. Les valeurs par défaut conservent le comportement historique.
class CommunityPublicProfile {
  const CommunityPublicProfile({
    required this.publicDisplayName,
    required this.publishAnonymously,
    required this.hasSavedPreference,
  });

  final String publicDisplayName;
  final bool publishAnonymously;
  final bool hasSavedPreference;
}

/// Entrée privée visible uniquement par le pêcheur qui a effectué le blocage.
class CommunityBlockedUser {
  const CommunityBlockedUser({
    required this.uid,
    required this.displayName,
    required this.blockedAt,
  });

  final String uid;
  final String displayName;
  final DateTime? blockedAt;

  static CommunityBlockedUser fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawName = data['blockedDisplayName'];
    final rawDate = data['createdAt'];
    return CommunityBlockedUser(
      uid: document.id,
      displayName: rawName is String ? rawName.trim() : '',
      blockedAt: rawDate is Timestamp ? rawDate.toDate() : null,
    );
  }
}

class CommunityRepository {
  CommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    CommunityPhotoService? photoService,
    PrivateCatchRepository? privateRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
        _photoService = photoService ?? CommunityPhotoService(),
        _privateRepository =
            privateRepository ?? PrivateCatchRepository.instance;

  static final instance = CommunityRepository();
  static const termsVersion = 1;
  static const publicProfileCollection = 'community_public_profiles';
  static const anonymousDisplayName = 'Pêcheur anonyme';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final CommunityPhotoService _photoService;
  final PrivateCatchRepository _privateRepository;
  CommunityPublicProfile? _publicProfileCache;
  String? _publicProfileCacheUid;

  CollectionReference<Map<String, dynamic>> get _catches =>
      _firestore.collection('community_catches');

  Future<CommunityPublicProfile> loadPublicProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const CommunityPublicProfile(
        publicDisplayName: '',
        publishAnonymously: true,
        hasSavedPreference: false,
      );
    }
    if (_publicProfileCacheUid == user.uid && _publicProfileCache != null) {
      return _publicProfileCache!;
    }

    final fallback = CommunityPublicProfile(
      publicDisplayName: _fallbackPublicName(user),
      publishAnonymously: false,
      hasSavedPreference: false,
    );
    final snapshot = await _firestore
        .collection(publicProfileCollection)
        .doc(user.uid)
        .get();
    final data = snapshot.data();
    final savedName = data?['publicDisplayName'];
    final profile = CommunityPublicProfile(
      publicDisplayName: savedName is String && savedName.trim().isNotEmpty
          ? savedName.trim()
          : fallback.publicDisplayName,
      publishAnonymously: data?['publishAnonymously'] == true,
      hasSavedPreference: snapshot.exists,
    );
    _publicProfileCacheUid = user.uid;
    _publicProfileCache = profile;
    return profile;
  }

  Future<void> savePublicProfile({
    required bool publishAnonymously,
    required String publicDisplayName,
  }) async {
    final user = _requireUser();
    final cleanName = publicDisplayName.trim();
    if (!publishAnonymously &&
        (cleanName.length < 2 || cleanName.length > 40)) {
      throw const FormatException(
        'Le surnom public doit contenir entre 2 et 40 caractères.',
      );
    }
    final profile = CommunityPublicProfile(
      publicDisplayName: publishAnonymously ? '' : cleanName,
      publishAnonymously: publishAnonymously,
      hasSavedPreference: true,
    );
    await _firestore.collection(publicProfileCollection).doc(user.uid).set({
      'schemaVersion': 1,
      'ownerUid': user.uid,
      'publicDisplayName': profile.publicDisplayName,
      'publishAnonymously': profile.publishAnonymously,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _publicProfileCacheUid = user.uid;
    _publicProfileCache = profile;
  }

  Stream<List<CommunityCatch>> watchActiveCatches() {
    final now = Timestamp.now();
    return _catches
        .where('status', isEqualTo: 'published')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .limit(CommunityCatch.maximumPublicItems)
        .snapshots()
        .map((snapshot) {
      final current = DateTime.now();
      final items = snapshot.docs
          .map(CommunityCatch.fromDocument)
          .whereType<CommunityCatch>()
          .where((item) => item.isActiveAt(current))
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Stream<WeeklyCommunityWinner?> watchWeeklyWinner() {
    return _firestore
        .collection('community_state')
        .doc('weekly_winner')
        .snapshots()
        .map(WeeklyCommunityWinner.fromDocument);
  }

  Stream<Set<String>> watchMyLikes() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <String>{});
    return _firestore
        .collectionGroup('likes')
        .where('likerUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => document.reference.parent.parent?.id)
              .whereType<String>()
              .toSet(),
        );
  }

  Future<bool> hasAcceptedTerms() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final profile =
        await _firestore.collection('community_profiles').doc(uid).get();
    final data = profile.data();
    return data?['termsVersion'] == termsVersion &&
        data?['termsAcceptedAt'] is Timestamp;
  }

  Future<void> acceptTerms() async {
    final user = _requireUser();
    await _firestore.collection('community_profiles').doc(user.uid).set(
      {
        'schemaVersion': 1,
        'ownerUid': user.uid,
        'termsVersion': termsVersion,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<DateTime?> nextPublicationAt() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final state =
        await _firestore.collection('community_publish_state').doc(uid).get();
    final lastPublishedAt = state.data()?['lastPublishedAt'];
    if (lastPublishedAt is! Timestamp) return null;
    return lastPublishedAt.toDate().add(CommunityCatch.publicationCooldown);
  }

  Future<String> publish(PrivateCatch privateCatch) async {
    final user = _requireUser();
    if (!await hasAcceptedTerms()) {
      throw const CommunityException(CommunityFailure.termsRequired);
    }
    final retryAt = await nextPublicationAt();
    if (retryAt != null && retryAt.isAfter(DateTime.now())) {
      throw CommunityException(
        CommunityFailure.publicationCooldown,
        retryAt: retryAt,
      );
    }
    final approximate = _publicLocation(privateCatch);
    final document = _catches.doc();
    final photoBytes = await _privateRepository.readPhoto(privateCatch);
    UploadedCommunityPhoto? uploaded;
    try {
      uploaded = await _photoService.upload(
        postId: document.id,
        bytes: photoBytes,
      );
      final state =
          _firestore.collection('community_publish_state').doc(user.uid);
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(CommunityCatch.publicationLifetime),
      );
      final publicName = await _publicName(user);
      await _firestore.runTransaction((transaction) async {
        final stateSnapshot = await transaction.get(state);
        final lastPublishedAt = stateSnapshot.data()?['lastPublishedAt'];
        if (lastPublishedAt is Timestamp) {
          final serverCooldown =
              lastPublishedAt.toDate().add(CommunityCatch.publicationCooldown);
          if (serverCooldown.isAfter(DateTime.now())) {
            throw CommunityException(
              CommunityFailure.publicationCooldown,
              retryAt: serverCooldown,
            );
          }
        }
        transaction.set(document, {
          'schemaVersion': 1,
          'ownerUid': user.uid,
          'anglerName': publicName,
          'avatarUrl': _safeAvatarUrl(user.photoURL),
          'photoUrl': uploaded!.url,
          'photoObjectKey': uploaded.objectKey,
          'species': privateCatch.species.trim(),
          'weightKg': privateCatch.weightKg,
          'zoneName': _zoneName(privateCatch),
          'publicLatitude': approximate.latitude,
          'publicLongitude': approximate.longitude,
          'montage': privateCatch.montage.trim(),
          'bait': privateCatch.bait.trim(),
          'notes': privateCatch.notes.trim(),
          'advice': privateCatch.advice.trim(),
          'status': 'published',
          'likeCount': 0,
          'reportCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt,
        });
        transaction.set(state, {
          'schemaVersion': 1,
          'ownerUid': user.uid,
          'lastPostId': document.id,
          'lastPublishedAt': FieldValue.serverTimestamp(),
        });
      });
      try {
        await _privateRepository.markPublished(
          privateCatchId: privateCatch.id,
          postId: document.id,
          publishedAt: DateTime.now(),
        );
      } on PrivateCatchException catch (error, stackTrace) {
        // The remote transaction is already committed at this point. Never
        // remove its photo and leave a broken public post only because the
        // optional local publication badge could not be updated.
        debugPrint(
          '[CommunityRepository] Local publication badge failed: '
          '${error.failure}\n$stackTrace',
        );
      }
      return document.id;
    } on CommunityException {
      if (uploaded != null) await _photoService.delete(uploaded.objectKey);
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      if (uploaded != null) await _photoService.delete(uploaded.objectKey);
      debugPrint(
        '[CommunityRepository] Publication failed: ${error.code}\n$stackTrace',
      );
      throw CommunityException(_mapFirebaseFailure(error));
    } catch (error, stackTrace) {
      if (uploaded != null) await _photoService.delete(uploaded.objectKey);
      debugPrint(
          '[CommunityRepository] Publication failed: $error\n$stackTrace');
      throw const CommunityException(CommunityFailure.unavailable);
    }
  }

  Future<void> toggleLike(CommunityCatch item) async {
    final user = _requireUser();
    if (user.uid == item.ownerUid) {
      throw const CommunityException(CommunityFailure.ownPostLike);
    }
    final post = _catches.doc(item.id);
    final like = post.collection('likes').doc(user.uid);
    try {
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(post);
        if (!postSnapshot.exists ||
            postSnapshot.data()?['status'] != 'published') {
          throw const CommunityException(CommunityFailure.postUnavailable);
        }
        final expiresAt = postSnapshot.data()?['expiresAt'];
        if (expiresAt is! Timestamp ||
            !expiresAt.toDate().isAfter(DateTime.now())) {
          throw const CommunityException(CommunityFailure.postUnavailable);
        }
        final likeSnapshot = await transaction.get(like);
        final currentCount = postSnapshot.data()?['likeCount'];
        final safeCount =
            currentCount is int && currentCount >= 0 ? currentCount : 0;
        if (likeSnapshot.exists) {
          transaction.delete(like);
          transaction
              .update(post, {'likeCount': safeCount > 0 ? safeCount - 1 : 0});
        } else {
          transaction.set(like, {
            'schemaVersion': 1,
            'likerUid': user.uid,
            'postOwnerUid': item.ownerUid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(post, {'likeCount': safeCount + 1});
        }
      });
    } on CommunityException {
      rethrow;
    } on FirebaseException catch (error) {
      throw CommunityException(_mapFirebaseFailure(error));
    }
  }

  Future<void> removeOwnPublication(CommunityCatch item) async {
    final user = _requireUser();
    if (item.ownerUid != user.uid) {
      throw const CommunityException(CommunityFailure.permissionDenied);
    }
    try {
      await _catches.doc(item.id).delete();
      await _privateRepository.clearPublicationForPost(item.id);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[CommunityRepository] Publication removal failed: '
        '${error.code}\n$stackTrace',
      );
      throw CommunityException(_mapFirebaseFailure(error));
    } on PrivateCatchException catch (error, stackTrace) {
      debugPrint(
        '[CommunityRepository] Local publication state cleanup failed: '
        '${error.failure}\n$stackTrace',
      );
      // The public post is already removed. Keep that safe outcome even if
      // clearing the local publication badge must wait for a later repair.
    }
  }

  Future<void> reportPost({
    required CommunityCatch item,
    required String reason,
  }) async {
    final user = _requireUser();
    final reportId = '${user.uid}_${item.id}';
    await _firestore.collection('community_reports').doc(reportId).set({
      'schemaVersion': 1,
      'reporterUid': user.uid,
      'postId': item.id,
      'postOwnerUid': item.ownerUid,
      'reason': reason.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityBlockedUser>> watchBlockedUsers() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <CommunityBlockedUser>[]);
    return _firestore
        .collection('community_blocks')
        .doc(uid)
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CommunityBlockedUser.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> blockUser({
    required String blockedUid,
    required String blockedDisplayName,
  }) async {
    final user = _requireUser();
    if (blockedUid == user.uid) return;
    final cleanName = blockedDisplayName.trim();
    await _firestore
        .collection('community_blocks')
        .doc(user.uid)
        .collection('users')
        .doc(blockedUid)
        .set({
      'schemaVersion': 1,
      'ownerUid': user.uid,
      'blockedUid': blockedUid,
      'blockedDisplayName': cleanName.length <= 80 ? cleanName : '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String blockedUid) async {
    final user = _requireUser();
    if (blockedUid == user.uid) return;
    await _firestore
        .collection('community_blocks')
        .doc(user.uid)
        .collection('users')
        .doc(blockedUid)
        .delete();
  }

  Future<void> deleteAllForCurrentUser() async {
    if (_auth.currentUser == null) return;
    try {
      await _functions.httpsCallable('deleteCommunityAccountData').call<void>();
      await _privateRepository.clearAll();
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[CommunityRepository] Account cleanup failed: '
        '${error.code}\n$stackTrace',
      );
      throw CommunityException(
        error.code == 'unauthenticated'
            ? CommunityFailure.authenticationRequired
            : CommunityFailure.unavailable,
      );
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityException(
        CommunityFailure.authenticationRequired,
      );
    }
    return user;
  }

  ApproximateCommunityLocation _publicLocation(PrivateCatch item) {
    final latitude = item.latitude;
    final longitude = item.longitude;
    if (latitude == null || longitude == null) {
      throw const CommunityException(CommunityFailure.invalidData);
    }
    try {
      return approximateCommunityLocation(
        latitude: latitude,
        longitude: longitude,
      );
    } on FormatException {
      throw const CommunityException(CommunityFailure.invalidData);
    }
  }

  Future<String> _publicName(User user) async {
    try {
      final profile = await loadPublicProfile();
      if (profile.publishAnonymously) return anonymousDisplayName;
      if (profile.publicDisplayName.isNotEmpty) {
        return profile.publicDisplayName;
      }
    } catch (error, stackTrace) {
      // L’identité publique est optionnelle : une panne de son document ne
      // doit jamais empêcher une publication déjà valide.
      debugPrint(
        '[CommunityRepository] Public profile unavailable: $error\n$stackTrace',
      );
    }
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isEmpty) return 'Pêcheur BoosterFish';
    return displayName.length <= 80
        ? displayName
        : displayName.substring(0, 80);
  }

  static String _fallbackPublicName(User user) {
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isEmpty) return 'Pêcheur BoosterFish';
    return displayName.length <= 80
        ? displayName
        : displayName.substring(0, 80);
  }

  static String _safeAvatarUrl(String? value) {
    return safeCommunityAvatarUrl(value);
  }

  static String _zoneName(PrivateCatch item) {
    final value = item.spotName.trim();
    return value.isEmpty ? 'Zone approximative' : value;
  }

  static CommunityFailure _mapFirebaseFailure(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => CommunityFailure.permissionDenied,
      'unauthenticated' => CommunityFailure.authenticationRequired,
      _ => CommunityFailure.unavailable,
    };
  }
}
