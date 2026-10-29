import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:spots_app/features/community/models/profile_avatar.dart';
import 'package:spots_app/features/community/services/profile_avatar_processor.dart';

class ProfileAvatarStorageService {
  ProfileAvatarStorageService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static String objectPath(String uid) => 'profile_avatars/$uid/avatar.jpg';

  Future<String> upload(Uint8List bytes) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication required');
    if (bytes.isEmpty ||
        bytes.lengthInBytes > ProfileAvatarProcessor.maximumOutputBytes) {
      throw const FormatException('Invalid profile avatar');
    }

    final reference = _storage.ref(objectPath(user.uid));
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: ProcessedProfileAvatar.contentType,
        cacheControl: 'public,max-age=3600,must-revalidate',
      ),
    );
    final downloadUrl = safeProfileAvatarUrl(await reference.getDownloadURL());
    if (downloadUrl.isEmpty) {
      throw const FormatException('Unsafe profile avatar URL');
    }
    final uri = Uri.parse(downloadUrl);
    final versionedUrl = uri.replace(queryParameters: {
      'alt': 'media',
      'token': uri.queryParameters['token']!,
      'v': DateTime.now().millisecondsSinceEpoch.toString(),
    }).toString();
    final safeVersionedUrl = safeProfileAvatarUrl(versionedUrl);
    if (safeVersionedUrl.isEmpty) {
      throw const FormatException('Unsafe profile avatar URL');
    }
    return safeVersionedUrl;
  }

  Future<void> delete() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _storage.ref(objectPath(user.uid)).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
