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
    expect(pubspec, contains('firebase_analytics: 12.4.5'));
    expect(privacy, contains('Google Analytics for Firebase'));
    expect(checklist, contains('Google Analytics'));
    expect(privacy, isNot(contains("Google Analytics n'est pas intégré")));
  });

  test('chaque page légale conserve sa date réelle de mise à jour', () {
    final privacy = File('docs/privacy_policy.html').readAsStringSync();
    final terms = File('docs/terms_of_service.html').readAsStringSync();

    expect(privacy, contains('Dernière mise à jour : 4 septembre 2026'));
    expect(terms, contains('Dernière mise à jour : 4 septembre 2026'));
  });
}
