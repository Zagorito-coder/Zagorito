import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la suppression est visible, confirmée et protégée contre les doublons',
      () {
    final settings = File('lib/pages/settings_page.dart').readAsStringSync();
    final auth = File('lib/services/auth_service.dart').readAsStringSync();

    expect(settings, contains("context.tr('settings.deleteAccount')"));
    expect(settings, contains("context.tr('settings.deleteAccountConfirm')"));
    expect(settings, contains('onTap: auth.isLoading'));
    expect(auth, contains('if (_isLoading) return false;'));
    expect(auth, contains('await _reauthenticateForDeletion(user);'));
    expect(auth, contains('await gsi.GoogleSignIn.instance.signOut();'));
  });

  test('les données sont nettoyées avant la suppression Firebase Auth', () {
    final auth = File('lib/services/auth_service.dart').readAsStringSync();
    final userSpots = auth.indexOf(
      'UserSpotService.instance.deleteAllForCurrentUser()',
    );
    final favorites = auth.indexOf(
      'FavoriteSpotService.instance.deleteAllForCurrentUser()',
    );
    final community = auth.indexOf(
      'CommunityRepository.instance.deleteAllForCurrentUser()',
    );
    final privateGallery = auth.indexOf(
      'PrivateCatchRepository.instance.deleteAllForAccount()',
    );
    final firebaseAccount = auth.indexOf('await user.delete();');

    expect(userSpots, greaterThan(0));
    expect(favorites, greaterThan(userSpots));
    expect(community, greaterThan(favorites));
    expect(privateGallery, greaterThan(community));
    expect(firebaseAccount, greaterThan(privateGallery));
    expect(auth, contains("prefs.remove('anonymous_user_id')"));
    expect(
      auth,
      contains("prefs.remove('unread_personal_spot_badge_count')"),
    );
  });

  test('la politique publique documente les deux chemins de suppression', () {
    final policy = File('docs/privacy_policy.html').readAsStringSync();

    expect(policy, contains('id="account-deletion"'));
    expect(policy, contains('Supprimer mon compte'));
    expect(policy, contains('mailto:booster2fish@gmail.com'));
  });
}
