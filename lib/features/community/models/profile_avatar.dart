enum ProfileAvatarSource { google, preset, custom }

const List<String> profileAvatarIds = [
  'fisher_01',
  'fisher_02',
  'fisher_03',
  'fisher_04',
  'fisher_05',
  'fisher_06',
  'fisher_07',
  'fisher_08',
  'fisher_09',
  'fisher_10',
];

String? profileAvatarAssetPath(Object? value) {
  if (value is! String || !profileAvatarIds.contains(value)) return null;
  return 'assets/profile_avatars/$value.webp';
}

String profileAvatarSourceValue(ProfileAvatarSource source) => switch (source) {
      ProfileAvatarSource.google => 'google',
      ProfileAvatarSource.preset => 'preset',
      ProfileAvatarSource.custom => 'custom',
    };

ProfileAvatarSource profileAvatarSourceFromValue(Object? value) {
  return switch (value) {
    'preset' => ProfileAvatarSource.preset,
    'custom' => ProfileAvatarSource.custom,
    _ => ProfileAvatarSource.google,
  };
}

class ProfileAvatarChoice {
  const ProfileAvatarChoice._({
    required this.source,
    this.presetId = '',
    this.customUrl = '',
  });

  const ProfileAvatarChoice.google()
      : this._(source: ProfileAvatarSource.google);

  const ProfileAvatarChoice.pendingCustom()
      : this._(source: ProfileAvatarSource.custom);

  factory ProfileAvatarChoice.preset(String presetId) {
    return profileAvatarAssetPath(presetId) == null
        ? const ProfileAvatarChoice.google()
        : ProfileAvatarChoice._(
            source: ProfileAvatarSource.preset,
            presetId: presetId,
          );
  }

  factory ProfileAvatarChoice.custom(String customUrl) {
    final safeUrl = safeProfileAvatarUrl(customUrl);
    return safeUrl.isEmpty
        ? const ProfileAvatarChoice.google()
        : ProfileAvatarChoice._(
            source: ProfileAvatarSource.custom,
            customUrl: safeUrl,
          );
  }

  factory ProfileAvatarChoice.fromStored({
    required Object? source,
    required Object? presetId,
    required Object? customUrl,
  }) {
    return switch (profileAvatarSourceFromValue(source)) {
      ProfileAvatarSource.preset =>
        ProfileAvatarChoice.preset(presetId is String ? presetId : ''),
      ProfileAvatarSource.custom =>
        ProfileAvatarChoice.custom(customUrl is String ? customUrl : ''),
      ProfileAvatarSource.google => const ProfileAvatarChoice.google(),
    };
  }

  final ProfileAvatarSource source;
  final String presetId;
  final String customUrl;

  String get storedSource => profileAvatarSourceValue(source);
}

final RegExp _profileAvatarUidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
final RegExp _downloadTokenPattern = RegExp(r'^[A-Za-z0-9_-]{20,128}$');
final RegExp _profileAvatarVersionPattern = RegExp(r'^[0-9]{10,16}$');
final RegExp _googleProfileAvatarPattern = RegExp(
  r'^https://lh3\.googleusercontent\.com/[A-Za-z0-9_./%=-]+'
  r'(\?[A-Za-z0-9_&.=%-]+)?$',
);

String safeProfileAvatarUrl(Object? value) {
  if (value is! String) return '';
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 1024) return '';

  Uri url;
  try {
    url = Uri.parse(trimmed);
  } catch (_) {
    return '';
  }
  if (url.scheme != 'https' ||
      url.hasPort ||
      url.userInfo.isNotEmpty ||
      url.fragment.isNotEmpty) {
    return '';
  }

  if (url.host == 'lh3.googleusercontent.com') {
    return _googleProfileAvatarPattern.hasMatch(trimmed) ? trimmed : '';
  }
  if (url.host != 'firebasestorage.googleapis.com') return '';

  final segments = url.pathSegments;
  if (segments.length != 5 ||
      segments[0] != 'v0' ||
      segments[1] != 'b' ||
      segments[2] != 'zagorito-9a0c4.firebasestorage.app' ||
      segments[3] != 'o') {
    return '';
  }
  final objectSegments = segments[4].split('/');
  if (objectSegments.length != 3 ||
      objectSegments[0] != 'profile_avatars' ||
      !_profileAvatarUidPattern.hasMatch(objectSegments[1]) ||
      objectSegments[2] != 'avatar.jpg') {
    return '';
  }
  final versionValues = url.queryParametersAll['v'];
  if (url.queryParametersAll.keys
          .any((key) => key != 'alt' && key != 'token' && key != 'v') ||
      url.queryParametersAll['alt']?.length != 1 ||
      url.queryParameters['alt'] != 'media' ||
      url.queryParametersAll['token']?.length != 1 ||
      !_downloadTokenPattern.hasMatch(url.queryParameters['token'] ?? '') ||
      (versionValues != null &&
          (versionValues.length != 1 ||
              !_profileAvatarVersionPattern.hasMatch(versionValues.single)))) {
    return '';
  }
  return trimmed;
}
