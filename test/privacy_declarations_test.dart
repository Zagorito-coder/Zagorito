import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la politique décrit les identifiants réellement embarqués', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final privacy = File('docs/privacy_policy.html').readAsStringSync();
    final checklist =
        File('docs/GOOGLE_PLAY_RELEASE_CHECKLIST.md').readAsStringSync();

    expect(pubspec, isNot(contains('firebase_messaging:')));
    expect(privacy, isNot(contains('jeton FCM')));
    expect(checklist, isNot(contains('jeton FCM')));
    expect(privacy, contains("identifiant d'installation Firebase"));
    expect(checklist, contains("identifiant d'installation Firebase"));
  });
}
