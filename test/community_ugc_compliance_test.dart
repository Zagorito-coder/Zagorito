import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la publication impose les règles et donne accès aux CGU complètes', () {
    final source = File(
      'lib/features/community/widgets/private_catches_view.dart',
    ).readAsStringSync();

    expect(source, contains('barrierDismissible: false'));
    expect(source, contains('community.communityRulesBody'));
    expect(
      source,
      contains(
        'https://zagorito-coder.github.io/boosterfish/terms-of-service/',
      ),
    );
    expect(source, contains('community.acceptAndContinue'));
  });

  test('le détail propose séparément signalement et blocage', () {
    final source = File(
      'lib/features/community/widgets/community_map_view.dart',
    ).readAsStringSync();

    expect(source, contains("context.tr('community.reportPost')"));
    expect(
      source,
      isNot(contains("title: Text(context.tr('community.reportReason'))")),
    );
    expect(source, contains("context.tr('community.blockUser')"));
    expect(source, contains('repository.reportPost'));
    expect(source, contains('repository.blockUser'));
    expect(source, contains("'child_safety'"));
  });

  test('la gestion de l’équipage permet de débloquer un pêcheur', () {
    final repository = File(
      'lib/features/community/services/community_repository.dart',
    ).readAsStringSync();
    final settings = File('lib/pages/settings_page.dart').readAsStringSync();
    final map = File(
      'lib/features/community/widgets/community_map_view.dart',
    ).readAsStringSync();

    expect(repository, contains('watchBlockedUsers'));
    expect(repository, contains('unblockUser'));
    expect(settings, contains('_BlockedUsersSheet'));
    expect(settings, contains("context.tr('settings.unblock')"));
    expect(map, contains('_blockedUsersStream'));
  });

  test('Firestore exige le consentement avant toute publication', () {
    final rules = File('firestore.rules').readAsStringSync();
    final repository = File(
      'lib/features/community/services/community_repository.dart',
    ).readAsStringSync();
    final settings = File('lib/pages/settings_page.dart').readAsStringSync();
    final functions = File('firebase_functions/index.js').readAsStringSync();

    expect(rules, contains('communityProfileAccepted(request.auth.uid)'));
    expect(rules, contains('request.resource.data.termsAcceptedAt'));
    expect(rules, contains('match /community_reports/{reportId}'));
    expect(rules, contains("'child_safety'"));
    expect(
      rules,
      contains("request.resource.data.avatarUrl.matches(\n"
          "            '^https://lh3\\\\.googleusercontent"),
    );
    expect(
      RegExp(
        r'match /community_reports/\{reportId\}[\s\S]*?'
        r'allow delete: if false;',
      ).hasMatch(rules),
      isTrue,
    );
    expect(
      rules,
      contains('match /community_blocks/{userId}/users/{blockedUserId}'),
    );
    expect(rules, contains('match /community_public_profiles/{userId}'));
    expect(rules, contains("'publicDisplayName'"));
    expect(rules, contains("'publishAnonymously'"));
    expect(repository, contains('savePublicProfile'));
    expect(repository, contains('loadPublicProfile'));
    expect(repository, contains('hasSavedPreference: snapshot.exists'));
    expect(repository, contains('hasSavedPreference: true'));
    expect(repository, contains('Pêcheur anonyme'));
    expect(settings, contains('_PublicProfileSheet'));
    expect(settings, contains('_showUpdateHint = !profile.hasSavedPreference'));
    expect(settings, contains('_showUpdateHint = false'));
    expect(settings, contains('publicIdentityAnonymous'));
    expect(
        functions, contains("community_public_profiles').doc(uid).delete()"));
  });

  test('les CGU publient des standards explicites de sécurité des mineurs', () {
    final terms = File('docs/terms_of_service.html').readAsStringSync();

    expect(terms, contains('id="child-safety"'));
    expect(terms, contains('CSAE'));
    expect(terms, contains('CSAM'));
    expect(terms, contains('booster2fish@gmail.com'));
  });

  test('les requêtes globales de suppression ont leurs index Firestore', () {
    final indexes = jsonDecode(
      File('firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final overrides = indexes['fieldOverrides'] as List<dynamic>;

    bool hasCollectionGroupIndex(String collectionGroup, String fieldPath) {
      return overrides.cast<Map<String, dynamic>>().any((entry) {
        if (entry['collectionGroup'] != collectionGroup ||
            entry['fieldPath'] != fieldPath) {
          return false;
        }
        return (entry['indexes'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .any((index) => index['queryScope'] == 'COLLECTION_GROUP');
      });
    }

    expect(hasCollectionGroupIndex('likes', 'likerUid'), isTrue);
    expect(hasCollectionGroupIndex('users', 'blockedUid'), isTrue);
  });
}
