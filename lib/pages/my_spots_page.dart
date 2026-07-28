import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/services/favorite_spot_service.dart';
import 'package:spots_app/services/user_spot_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/authenticated_spot_photo.dart';
import 'package:spots_app/widgets/user_spot_form_sheet.dart';

class MySpotsPage extends StatelessWidget {
  const MySpotsPage({
    super.key,
    required this.onAddSpot,
    required this.onOpenFavorite,
  });

  final VoidCallback onAddSpot;
  final ValueChanged<Spot> onOpenFavorite;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Scaffold(
          backgroundColor: tc.background,
          appBar: AppBar(
            backgroundColor: tc.background,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 18,
            title: Text(
              context.tr('mySpots.title'),
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                tooltip: context.tr('mySpots.addFromMap'),
                onPressed: onAddSpot,
                icon: const Icon(Icons.add_location_alt_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Consumer<AuthService>(
            builder: (context, auth, _) {
              final uid = auth.uid;
              if (uid == null) return _SignInView(auth: auth);
              return StreamBuilder<List<Spot>>(
                stream: FavoriteSpotService.instance.watchFavorites(uid),
                builder: (context, favoriteSnapshot) {
                  return StreamBuilder<List<UserSpot>>(
                    stream: UserSpotService.instance.watchUserSpots(uid),
                    builder: (context, personalSnapshot) {
                      if (favoriteSnapshot.hasError ||
                          personalSnapshot.hasError) {
                        return const _ErrorView();
                      }
                      if (!favoriteSnapshot.hasData ||
                          !personalSnapshot.hasData) {
                        return Center(
                          child:
                              CircularProgressIndicator(color: tc.oceanMedium),
                        );
                      }
                      final favorites = favoriteSnapshot.data!;
                      final personal = personalSnapshot.data!;
                      return _SpotsList(
                        favorites: favorites,
                        personal: personal,
                        onAddSpot: onAddSpot,
                        onOpenFavorite: onOpenFavorite,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SpotsList extends StatelessWidget {
  const _SpotsList({
    required this.favorites,
    required this.personal,
    required this.onAddSpot,
    required this.onOpenFavorite,
  });

  final List<Spot> favorites;
  final List<UserSpot> personal;
  final VoidCallback onAddSpot;
  final ValueChanged<Spot> onOpenFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        _SectionTitle(
          icon: Icons.favorite_rounded,
          title: context.tr('mySpots.favoritesTitle'),
          count: favorites.length,
        ),
        const SizedBox(height: 8),
        if (favorites.isEmpty)
          const _EmptyFavoritesNotice()
        else
          for (final spot in favorites) ...[
            _FavoriteSpotCard(
              spot: spot,
              onOpen: () => onOpenFavorite(spot),
            ),
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 12),
        _SectionTitle(
          icon: Icons.lock_person_rounded,
          title: context.tr('mySpots.personalTitle'),
          count: personal.length,
          trailing: IconButton(
            tooltip: context.tr('mySpots.addFromMap'),
            onPressed: onAddSpot,
            icon: const Icon(Icons.add_location_alt_rounded),
          ),
        ),
        const SizedBox(height: 6),
        _PrivateNotice(count: personal.length),
        const SizedBox(height: 9),
        if (personal.isEmpty)
          _EmptyPersonalNotice(onAddSpot: onAddSpot)
        else
          for (final spot in personal) ...[
            _UserSpotCard(spot: spot),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 20, color: tc.oceanMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tc.oceanMedium.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: tc.oceanMedium,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _FavoriteSpotCard extends StatelessWidget {
  const _FavoriteSpotCard({required this.spot, required this.onOpen});

  final Spot spot;
  final VoidCallback onOpen;

  Future<void> _remove(BuildContext context) async {
    try {
      await FavoriteSpotService.instance.remove(spot.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.favoriteRemoved'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.favoriteError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            border: Border.all(color: tc.glassBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: spot.type.color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.place_rounded,
                  color: spot.type.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('mySpots.openOnMap'),
                      style: TextStyle(color: tc.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('mySpots.removeFavorite'),
                onPressed: () => _remove(context),
                icon: Icon(Icons.favorite_rounded, color: tc.error),
              ),
              Icon(Icons.chevron_right_rounded, color: tc.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFavoritesNotice extends StatelessWidget {
  const _EmptyFavoritesNotice();

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tc.glassBorder),
      ),
      child: Text(
        context.tr('mySpots.noFavorites'),
        style: TextStyle(color: tc.textSecondary, fontSize: 12.5),
      ),
    );
  }
}

class _EmptyPersonalNotice extends StatelessWidget {
  const _EmptyPersonalNotice({required this.onAddSpot});

  final VoidCallback onAddSpot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onAddSpot,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(context.tr('mySpots.chooseOnMap')),
      ),
    );
  }
}

class _PrivateNotice extends StatelessWidget {
  const _PrivateNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tc.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lock_person_rounded, color: tc.success, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.trArgs(
                    count == 1 ? 'mySpots.countOne' : 'mySpots.count',
                    args: {'count': '$count'},
                  ),
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.tr('mySpots.privateNotice'),
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSpotCard extends StatelessWidget {
  const _UserSpotCard({required this.spot});

  final UserSpot spot;

  Future<void> _edit(BuildContext context) async {
    final updated = await showUserSpotFormSheet(
      context: context,
      latitude: spot.latitude,
      longitude: spot.longitude,
      existingSpot: spot,
      onSubmit: (draft) => UserSpotService.instance.updateSpot(spot, draft),
    );
    if (updated && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('mySpots.updated'))),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final approved = spot.status == SpotModerationStatus.approved;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('mySpots.deleteTitle')),
            content: Text(
              context.tr(
                approved
                    ? 'mySpots.deleteApprovedConfirm'
                    : 'mySpots.deleteConfirm',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.tr('common.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.tr('common.delete')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await UserSpotService.instance.deleteSpot(spot);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.deleted'))),
        );
      }
    } on UserSpotException catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.deleteError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final statusColor = switch (spot.status) {
      SpotModerationStatus.pending => tc.warning,
      SpotModerationStatus.approved => tc.success,
      SpotModerationStatus.rejected => tc.error,
    };
    final statusIcon = switch (spot.status) {
      SpotModerationStatus.pending => Icons.schedule_rounded,
      SpotModerationStatus.approved => Icons.verified_rounded,
      SpotModerationStatus.rejected => Icons.report_gmailerrorred_rounded,
    };
    final statusKey = 'mySpots.status.${spot.status.name}';

    return Material(
      color: tc.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _edit(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tc.glassBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (spot.hasPhoto)
                AspectRatio(
                  aspectRatio: 16 / 6.5,
                  child: AuthenticatedSpotPhoto(
                    url: spot.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: ColoredBox(
                      color: tc.surfaceLight,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tc.textMuted,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spot.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tc.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: context.tr('mySpots.actions'),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _edit(context);
                            } else if (value == 'delete') {
                              _delete(context);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.edit_rounded),
                                title: Text(context.tr('common.edit')),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline_rounded,
                                  color: tc.error,
                                ),
                                title: Text(context.tr('common.delete')),
                              ),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.38),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                context.tr(statusKey),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.lock_outline_rounded,
                            color: tc.textMuted, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.tr('mySpots.coordinatesProtected'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tc.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (spot.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailLine(
                        icon: Icons.notes_rounded,
                        text: spot.notes,
                        color: tc.textSecondary,
                      ),
                    ],
                    if (spot.hasDanger) ...[
                      const SizedBox(height: 8),
                      _DetailLine(
                        icon: Icons.warning_amber_rounded,
                        text: spot.dangerNotes,
                        color: tc.error,
                      ),
                    ],
                    if (spot.status == SpotModerationStatus.rejected &&
                        (spot.moderationNote?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      _DetailLine(
                        icon: Icons.fact_check_outlined,
                        text: spot.moderationNote!,
                        color: tc.warning,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView({required this.auth});

  final AuthService auth;

  Future<void> _signIn(BuildContext context) async {
    final success = await auth.signInWithGoogle();
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('mySpots.signInError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_person_outlined, color: tc.oceanMedium, size: 54),
            const SizedBox(height: 14),
            Text(
              context.tr('mySpots.signInTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('mySpots.signInSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed:
                  kIsWeb || auth.isLoading ? null : () => _signIn(context),
              icon: auth.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(context.tr('settings.signInGoogle')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: tc.error, size: 48),
            const SizedBox(height: 12),
            Text(
              context.tr('mySpots.loadError'),
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
