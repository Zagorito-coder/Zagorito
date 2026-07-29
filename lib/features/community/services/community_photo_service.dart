import 'dart:typed_data';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:spots_app/features/community/models/community_catch.dart';
import 'package:spots_app/features/community/models/private_catch.dart';

class UploadedCommunityPhoto {
  const UploadedCommunityPhoto({
    required this.url,
    required this.objectKey,
  });

  final String url;
  final String objectKey;
}

class CommunityPhotoService {
  CommunityPhotoService({
    FirebaseAuth? auth,
    FirebaseAppCheck? appCheck,
    http.Client? httpClient,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _appCheck = appCheck ?? FirebaseAppCheck.instance,
        _httpClient = httpClient ?? http.Client();

  static const _productionBaseUrl =
      'https://boosterfish-offline-maps.boosterfish-maps.workers.dev/';
  static const _baseUrl = String.fromEnvironment(
    'COMMUNITY_PHOTO_BASE_URL',
    defaultValue: _productionBaseUrl,
  );

  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;
  final http.Client _httpClient;

  Future<UploadedCommunityPhoto> upload({
    required String postId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > PrivateCatch.maximumPhotoBytes) {
      throw const CommunityException(CommunityFailure.invalidPhoto);
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityException(
        CommunityFailure.authenticationRequired,
      );
    }
    final objectKey = '${user.uid}_$postId';
    final response = await _httpClient.put(
      Uri.parse(_baseUrl).resolve('community-photos/$objectKey'),
      headers: await _authorizationHeaders(contentType: 'image/jpeg'),
      body: bytes,
    );
    if (response.statusCode != 201) {
      throw CommunityException(
        response.statusCode == 401 || response.statusCode == 403
            ? CommunityFailure.permissionDenied
            : CommunityFailure.uploadFailed,
      );
    }
    return UploadedCommunityPhoto(
      url:
          Uri.parse(_baseUrl).resolve('community-photos/$objectKey').toString(),
      objectKey: objectKey,
    );
  }

  Future<bool> delete(String objectKey) async {
    if (objectKey.isEmpty) return true;
    try {
      final response = await _httpClient.delete(
        Uri.parse(_baseUrl).resolve('community-photos/$objectKey'),
        headers: await _authorizationHeaders(),
      );
      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _authorizationHeaders({
    String? contentType,
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const CommunityException(
        CommunityFailure.authenticationRequired,
      );
    }
    String? appCheckToken;
    try {
      appCheckToken = await _appCheck.getToken(false);
    } catch (_) {
      throw const CommunityException(CommunityFailure.permissionDenied);
    }
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw const CommunityException(CommunityFailure.permissionDenied);
    }
    return {
      'Authorization': 'Bearer $token',
      'X-Firebase-AppCheck': appCheckToken,
      if (contentType != null) 'Content-Type': contentType,
    };
  }
}
