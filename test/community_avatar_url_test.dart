import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/features/community/models/community_catch.dart';

void main() {
  test('les avatars communautaires utilisent uniquement l’hôte approuvé', () {
    const allowed =
        'https://lh3.googleusercontent.com/a/avatar_ABC-123=s96-c?sz=96';
    expect(safeCommunityAvatarUrl(allowed), allowed);
    expect(safeCommunityAvatarUrl(''), isEmpty);
    expect(
      safeCommunityAvatarUrl('https://tracker.example/avatar.png'),
      isEmpty,
    );
    expect(
      safeCommunityAvatarUrl(
        'https://lh3.googleusercontent.com.tracker.example/avatar.png',
      ),
      isEmpty,
    );
    expect(
      safeCommunityAvatarUrl(
        'https://tracker.example@lh3.googleusercontent.com/avatar.png',
      ),
      isEmpty,
    );
    expect(
      safeCommunityAvatarUrl(
        'https://lh3.googleusercontent.com:444/avatar.png',
      ),
      isEmpty,
    );
  });
}
