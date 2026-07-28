import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/models.dart';

class FavoriteSpotService {
  FavoriteSpotService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final FavoriteSpotService instance = FavoriteSpotService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _favorites(String uid) {
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  Stream<List<Spot>> watchFavorites(String uid) {
    return _favorites(uid).snapshots().map((snapshot) {
      final spots = snapshot.docs
          .map((document) => _fromDocument(document.data()))
          .whereType<Spot>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return spots;
    });
  }

  Stream<bool> watchIsFavorite(String uid, String spotId) {
    return _favorites(uid).doc(_documentId(spotId)).snapshots().map(
          (snapshot) => snapshot.exists,
        );
  }

  Future<void> add(Spot spot) async {
    final user = _auth.currentUser;
    if (user == null) throw const FavoriteSpotException();
    await _favorites(user.uid).doc(_documentId(spot.id)).set({
      'schemaVersion': 1,
      'ownerUid': user.uid,
      'spotId': spot.id,
      'name': spot.name,
      'latitude': spot.latitude,
      'longitude': spot.longitude,
      'type': spot.type.name,
      'fishTypes': spot.fishTypes.take(50).toList(),
      'notes': spot.notes.length <= 2000
          ? spot.notes
          : spot.notes.substring(0, 2000),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) throw const FavoriteSpotException();
    await _favorites(user.uid).doc(_documentId(spotId)).delete();
  }

  Future<void> deleteAllForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _favorites(user.uid).get();
    for (var offset = 0; offset < snapshot.docs.length; offset += 400) {
      final batch = _firestore.batch();
      final end = (offset + 400).clamp(0, snapshot.docs.length);
      for (final document in snapshot.docs.sublist(offset, end)) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  static String _documentId(String spotId) {
    return base64Url.encode(utf8.encode(spotId)).replaceAll('=', '');
  }

  static Spot? _fromDocument(Map<String, dynamic> data) {
    final id = data['spotId'];
    final name = data['name'];
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (id is! String ||
        name is! String ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    final typeName = data['type'];
    final type = SpotType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => SpotType.remoteSpot,
    );
    return Spot(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      location: LatLng(latitude, longitude),
      type: type,
      fishTypes:
          (data['fishTypes'] as List?)?.whereType<String>().take(50).toList() ??
              const [],
      notes: data['notes'] as String? ?? '',
    );
  }
}

class FavoriteSpotException implements Exception {
  const FavoriteSpotException();
}
