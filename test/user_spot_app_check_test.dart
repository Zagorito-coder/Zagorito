import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/services/user_spot_service.dart';

void main() {
  group('protection App Check des photos de spots personnels', () {
    test('utilise la route v2 protégée sans modifier la clé R2', () {
      final uri = buildUserSpotPhotoUri(
        Uri.parse('https://maps.example/base'),
        'spot-key-123',
      );

      expect(
        uri,
        Uri.parse('https://maps.example/spot-photos-v2/spot-key-123'),
      );
    });

    test('envoie Auth et App Check avec le type MIME', () async {
      final headers = await buildUserSpotPhotoAuthorizationHeaders(
        authTokenProvider: () async => ' auth-token ',
        appCheckTokenProvider: () async => ' app-check-token ',
        contentType: 'image/jpeg',
      );

      expect(headers, {
        'Authorization': 'Bearer auth-token',
        'X-Firebase-AppCheck': 'app-check-token',
        'Content-Type': 'image/jpeg',
      });
    });

    test('refuse un jeton Auth absent', () async {
      expect(
        () => buildUserSpotPhotoAuthorizationHeaders(
          authTokenProvider: () async => null,
          appCheckTokenProvider: () async => 'app-check-token',
        ),
        throwsA(
          isA<UserSpotException>().having(
            (error) => error.failure,
            'failure',
            UserSpotFailure.authenticationRequired,
          ),
        ),
      );
    });

    test('refuse un jeton App Check absent ou indisponible', () async {
      for (final provider in <Future<String?> Function()>[
        () async => '',
        () async => throw StateError('indisponible'),
      ]) {
        expect(
          () => buildUserSpotPhotoAuthorizationHeaders(
            authTokenProvider: () async => 'auth-token',
            appCheckTokenProvider: provider,
          ),
          throwsA(
            isA<UserSpotException>().having(
              (error) => error.failure,
              'failure',
              UserSpotFailure.appCheckUnavailable,
            ),
          ),
        );
      }
    });
  });
}
