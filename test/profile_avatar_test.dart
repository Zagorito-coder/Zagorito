import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:spots_app/features/community/models/profile_avatar.dart';
import 'package:spots_app/features/community/services/profile_avatar_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le catalogue contient exactement dix avatars WebP locaux', () {
    expect(profileAvatarIds, hasLength(10));
    expect(profileAvatarIds.toSet(), hasLength(10));
    for (final avatarId in profileAvatarIds) {
      final path = profileAvatarAssetPath(avatarId);
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue, reason: avatarId);
      expect(File(path).lengthSync(), lessThan(100 * 1024), reason: avatarId);
    }
    expect(profileAvatarAssetPath('fisher_11'), isNull);
    expect(profileAvatarAssetPath('../fisher_01'), isNull);
  });

  test('les choix stockés invalides reviennent à la photo Google', () {
    final preset = ProfileAvatarChoice.fromStored(
      source: 'preset',
      presetId: 'fisher_09',
      customUrl: '',
    );
    expect(preset.source, ProfileAvatarSource.preset);
    expect(preset.presetId, 'fisher_09');

    final invalid = ProfileAvatarChoice.fromStored(
      source: 'preset',
      presetId: '../../secret',
      customUrl: '',
    );
    expect(invalid.source, ProfileAvatarSource.google);
  });

  test('seuls Google et le chemin Firebase Storage du profil sont acceptés',
      () {
    const google =
        'https://lh3.googleusercontent.com/a/avatar_ABC-123=s96-c?sz=96';
    const custom = 'https://firebasestorage.googleapis.com/v0/b/'
        'zagorito-9a0c4.firebasestorage.app/o/'
        'profile_avatars%2Fowner-1%2Favatar.jpg'
        '?alt=media&token=abcdefghijklmnopqrst-1234567890&v=1788312345678';

    expect(safeProfileAvatarUrl(google), google);
    expect(safeProfileAvatarUrl(custom), custom);
    expect(
      safeProfileAvatarUrl(custom.replaceFirst('owner-1', '..%2Fother')),
      isEmpty,
    );
    expect(
      safeProfileAvatarUrl(custom.replaceFirst('avatar.jpg', 'other.jpg')),
      isEmpty,
    );
    expect(
      safeProfileAvatarUrl('$custom&redirect=https://tracker.example'),
      isEmpty,
    );
    expect(
      safeProfileAvatarUrl(custom.replaceFirst('v=1788312345678', 'v=abc')),
      isEmpty,
    );
    expect(
      safeProfileAvatarUrl('$google&redirect=https://tracker.example'),
      isEmpty,
    );
    expect(safeProfileAvatarUrl('https://tracker.example/avatar.jpg'), isEmpty);
  });

  test('une photo personnelle est recadrée, réduite et réencodée en JPEG',
      () async {
    final sourceImage = image.Image(width: 900, height: 600);
    for (var y = 0; y < sourceImage.height; y += 1) {
      for (var x = 0; x < sourceImage.width; x += 1) {
        sourceImage.setPixelRgba(
          x,
          y,
          x % 256,
          y % 256,
          (x + y) % 256,
          255,
        );
      }
    }
    final source = Uint8List.fromList(image.encodePng(sourceImage));
    final processed = await const ProfileAvatarProcessor().process(source);
    final decoded = image.decodeJpg(processed.bytes);

    expect(processed.bytes.take(3), [0xff, 0xd8, 0xff]);
    expect(
      processed.bytes.lengthInBytes,
      lessThanOrEqualTo(ProfileAvatarProcessor.maximumOutputBytes),
    );
    expect(decoded, isNotNull);
    expect(decoded!.width, ProcessedProfileAvatar.width);
    expect(decoded.height, ProcessedProfileAvatar.height);
  });

  test('les octets non image et les sources surdimensionnées sont refusés',
      () async {
    expect(
      () => const ProfileAvatarProcessor().process(
        Uint8List.fromList([1, 2, 3, 4]),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => const ProfileAvatarProcessor().process(
        Uint8List(ProfileAvatarProcessor.maximumSourceBytes + 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
