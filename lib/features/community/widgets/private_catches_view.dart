import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spots_app/features/community/models/community_catch.dart';
import 'package:spots_app/features/community/models/private_catch.dart';
import 'package:spots_app/features/community/services/community_repository.dart';
import 'package:spots_app/features/community/services/private_catch_repository.dart';
import 'package:spots_app/features/community/widgets/private_catch_form_sheet.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivateCatchesView extends StatefulWidget {
  const PrivateCatchesView({super.key});

  @override
  State<PrivateCatchesView> createState() => _PrivateCatchesViewState();
}

class _PrivateCatchesViewState extends State<PrivateCatchesView> {
  final _repository = PrivateCatchRepository.instance;
  final _community = CommunityRepository.instance;
  final _picker = ImagePicker();
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _lostDataChecked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() => _user = user);
      if (user == null) {
        _repository.lock();
      } else {
        unawaited(_initialize());
      }
    });
    if (_user != null) unawaited(_initialize());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _repository.initialize();
      if (_lostDataChecked) return;
      _lostDataChecked = true;
      final lost = await _picker.retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      final file = lost.files?.firstOrNull;
      if (file != null) await _openCreateForm(await file.readAsBytes());
    } catch (_) {
      if (mounted) _showMessage('community.privateStorageUnavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    if (_user == null) return _signedOutState(palette);
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) {
        final items = _repository.items;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('community.myPrivateCatches'),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: palette.success,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                context.tr('community.privateGalleryHelp'),
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: palette.divider),
                    ),
                    child: Text(
                      '${items.length}/${PrivateCatch.maximumItems}',
                      style: TextStyle(
                        color: palette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _repository.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? _emptyState(palette)
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 3, 14, 18),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.69,
                            crossAxisSpacing: 11,
                            mainAxisSpacing: 11,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _PrivateCatchCard(
                            item: items[index],
                            busy: _busy,
                            onEdit: () => _edit(items[index]),
                            onDelete: () => _delete(items[index]),
                            onPublish: () => _publish(items[index]),
                          ),
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _pickPhoto,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.tr('community.importCatch')),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _signedOutState(BoosterFishPagePalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_outlined,
                size: 38,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('community.signInRequired'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('community.privateAccountHelp'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BoosterFishPagePalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 36,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('community.noPrivateCatches'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('community.noPrivateCatchesHelp'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_repository.items.length >= PrivateCatch.maximumItems) {
      _showMessage('community.privateLimitReached');
      return;
    }
    try {
      final selected = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (selected == null || !mounted) return;
      await _openCreateForm(await selected.readAsBytes());
    } catch (_) {
      _showMessage('community.invalidPhoto');
    }
  }

  Future<void> _openCreateForm(Uint8List photoBytes) async {
    if (!mounted) return;
    final result = await showModalBottomSheet<PrivateCatchFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrivateCatchFormSheet(photoBytes: photoBytes),
    );
    if (result == null) return;
    await _run(() async {
      await _repository.create(
        PrivateCatchDraft(
          photoBytes: photoBytes,
          species: result.species,
          weightKg: result.weightKg,
          spotName: result.spotName,
          latitude: result.latitude,
          longitude: result.longitude,
          montage: result.montage,
          bait: result.bait,
          notes: result.notes,
          advice: result.advice,
          caughtAt: result.caughtAt,
        ),
      );
      _showMessage('community.privateCatchSaved');
    });
  }

  Future<void> _edit(PrivateCatch item) async {
    try {
      final bytes = await _repository.readPhoto(item);
      if (!mounted) return;
      final result = await showModalBottomSheet<PrivateCatchFormResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PrivateCatchFormSheet(
          photoBytes: bytes,
          existing: item,
        ),
      );
      if (result == null) return;
      await _run(() async {
        await _repository.update(
          item.copyWith(
            species: result.species,
            weightKg: result.weightKg,
            spotName: result.spotName,
            latitude: result.latitude,
            longitude: result.longitude,
            montage: result.montage,
            bait: result.bait,
            notes: result.notes,
            advice: result.advice,
            caughtAt: result.caughtAt,
          ),
        );
        _showMessage('community.privateCatchSaved');
      });
    } catch (_) {
      _showMessage('community.invalidPhoto');
    }
  }

  Future<void> _delete(PrivateCatch item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('community.deletePrivateCatch')),
        content: Text(context.tr('community.deletePrivateCatchConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('community.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _repository.delete(item));
  }

  Future<void> _publish(PrivateCatch item) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showMessage('community.signInRequired');
      return;
    }
    if (item.latitude == null || item.longitude == null) {
      _showMessage('community.locationRequiredToPublish');
      return;
    }
    if (!await _community.hasAcceptedTerms()) {
      if (!mounted || !await _showTermsDialog()) return;
      await _community.acceptTerms();
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('community.publishBestCatch')),
        content: Text(context.tr('community.publishPrivacyConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.public_rounded),
            label: Text(context.tr('community.publish')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _community.publish(item);
      _showMessage('community.catchPublished');
    });
  }

  Future<bool> _showTermsDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(context.tr('community.communityRules')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('community.communityRulesBody')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openCommunityTerms,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(context.tr('termsOfService')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('community.acceptAndContinue')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openCommunityTerms() async {
    final uri = Uri.parse(
      'https://zagorito-coder.github.io/boosterfish/terms-of-service/',
    );
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showMessage('settings.linkOpenError');
    } catch (_) {
      _showMessage('settings.linkOpenError');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PrivateCatchException catch (error) {
      _showMessage(
        error.failure == PrivateCatchFailure.limitReached
            ? 'community.privateLimitReached'
            : 'community.privateSaveFailed',
      );
    } on CommunityException catch (error) {
      _showMessage(_communityErrorKey(error));
    } catch (_) {
      _showMessage('community.privateSaveFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _communityErrorKey(CommunityException error) {
    return switch (error.failure) {
      CommunityFailure.authenticationRequired => 'community.signInRequired',
      CommunityFailure.termsRequired => 'community.communityRules',
      CommunityFailure.publicationCooldown => 'community.publicationCooldown',
      CommunityFailure.invalidData => 'community.invalidData',
      CommunityFailure.invalidPhoto => 'community.invalidPhoto',
      CommunityFailure.uploadFailed => 'community.uploadFailed',
      CommunityFailure.ownPostLike => 'community.ownPostLike',
      CommunityFailure.postUnavailable => 'community.postUnavailable',
      CommunityFailure.permissionDenied => 'community.permissionDenied',
      CommunityFailure.unavailable => 'community.unavailable',
    };
  }

  void _showMessage(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(key))),
    );
  }
}

class _PrivateCatchCard extends StatelessWidget {
  const _PrivateCatchCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
  });

  final PrivateCatch item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(item.photoPath),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: palette.surfaceElevated,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.navy.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_weight(item.weightKg)} kg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 5),
              child: Text(
                item.species,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 13, color: palette.accent),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      item.spotName.isEmpty
                          ? context.tr('community.privateZone')
                          : item.spotName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.tr('community.edit'),
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: context.tr('community.delete'),
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: context.tr('community.publish'),
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : onPublish,
                    icon: Icon(
                      item.isPublished
                          ? Icons.public_rounded
                          : Icons.upload_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weight(double value) {
    return value.toStringAsFixed(value < 10 ? 2 : 1).replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }
}
