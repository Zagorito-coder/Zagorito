import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spots_app/features/community/models/profile_avatar.dart';

class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView({
    super.key,
    required this.choice,
    required this.googlePhotoUrl,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    this.memoryBytes,
    this.anonymous = false,
  });

  final ProfileAvatarChoice choice;
  final String? googlePhotoUrl;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final Uint8List? memoryBytes;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Icon(
          anonymous ? Icons.visibility_off_rounded : Icons.person_rounded,
          color: iconColor,
          size: size * 0.54,
        ),
      ),
    );

    Widget image = fallback;
    if (!anonymous) {
      final pendingBytes = memoryBytes;
      final assetPath = choice.source == ProfileAvatarSource.preset
          ? profileAvatarAssetPath(choice.presetId)
          : null;
      final networkUrl = switch (choice.source) {
        ProfileAvatarSource.google => safeProfileAvatarUrl(googlePhotoUrl),
        ProfileAvatarSource.custom => choice.customUrl,
        ProfileAvatarSource.preset => '',
      };
      if (pendingBytes != null && pendingBytes.isNotEmpty) {
        image = Image.memory(
          pendingBytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else if (assetPath != null) {
        image = Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else if (networkUrl.isNotEmpty) {
        image = CachedNetworkImage(
          imageUrl: networkUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        );
      }
    }

    return ClipOval(
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}
