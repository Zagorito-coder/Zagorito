import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les avatars locaux sont déclarés sans appel réseau', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final catalog = File(
      'lib/features/community/models/profile_avatar.dart',
    ).readAsStringSync();
    final resolverStart = catalog.indexOf('String? profileAvatarAssetPath');
    final resolverEnd = catalog.indexOf('\n}\n', resolverStart) + 3;
    final localResolver = catalog.substring(resolverStart, resolverEnd);

    expect(pubspec, contains('- assets/profile_avatars/'));
    expect(localResolver, contains("'assets/profile_avatars/\$value.webp'"));
    expect(localResolver, isNot(contains('http://')));
    expect(localResolver, isNot(contains('https://')));
  });

  test('la photo personnelle est isolée et limitée dans Firebase Storage', () {
    final rules = File('storage.rules').readAsStringSync();
    final firebase = File('firebase.json').readAsStringSync();
    final service = File(
      'lib/features/community/services/profile_avatar_storage_service.dart',
    ).readAsStringSync();

    expect(firebase, contains('"rules": "storage.rules"'));
    expect(rules, contains('match /profile_avatars/{userId}/avatar.jpg'));
    expect(rules, contains('request.auth.uid == userId'));
    expect(rules, contains("request.resource.contentType == 'image/jpeg'"));
    expect(rules, contains('request.resource.size <= 358400'));
    expect(service, contains("'profile_avatars/\$uid/avatar.jpg'"));
  });

  test('l’anonymat retire le nom et les deux formes de photo publique', () {
    final repository = File(
      'lib/features/community/services/community_repository.dart',
    ).readAsStringSync();

    expect(
      repository,
      contains("if (profile?.publishAnonymously == true) return '';"),
    );
    expect(
      repository,
      contains("if (profile == null || profile.publishAnonymously) return '';"),
    );
    expect(repository, contains("'avatarUrl': avatarUrl"));
    expect(repository, contains("'avatarId': avatarId"));
  });

  test('le profil propose Google, galerie, caméra et dix avatars', () {
    final settings = File('lib/pages/settings_page.dart').readAsStringSync();

    expect(settings, contains('ProfileAvatarChoice.google()'));
    expect(settings, contains('ImageSource.gallery'));
    expect(settings, contains('ImageSource.camera'));
    expect(
      settings,
      contains(
        'for (var index = 0; index < profileAvatarIds.length; index++)',
      ),
    );
    expect(settings, contains('ProfileAvatarProcessor'));
  });
}
