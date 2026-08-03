import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/services/user_spot_photo_processor.dart';
import 'package:spots_app/services/user_spot_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/widgets/authenticated_spot_photo.dart';

Future<bool> showUserSpotFormSheet({
  required BuildContext context,
  required double latitude,
  required double longitude,
  required Future<void> Function(UserSpotDraft draft) onSubmit,
  UserSpot? existingSpot,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UserSpotFormSheet(
          latitude: latitude,
          longitude: longitude,
          existingSpot: existingSpot,
          onSubmit: onSubmit,
        ),
      ) ??
      false;
}

class _UserSpotFormSheet extends StatefulWidget {
  const _UserSpotFormSheet({
    required this.latitude,
    required this.longitude,
    required this.onSubmit,
    this.existingSpot,
  });

  final double latitude;
  final double longitude;
  final UserSpot? existingSpot;
  final Future<void> Function(UserSpotDraft draft) onSubmit;

  @override
  State<_UserSpotFormSheet> createState() => _UserSpotFormSheetState();
}

class _UserSpotFormSheetState extends State<_UserSpotFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _photoProcessor = const UserSpotPhotoProcessor();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late final TextEditingController _dangerController;
  Uint8List? _photoBytes;
  String? _photoContentType;
  bool _removeExistingPhoto = false;
  bool _isPickingPhoto = false;
  bool _isSaving = false;
  String? _errorKey;

  bool get _hasExistingPhoto =>
      !_removeExistingPhoto && (widget.existingSpot?.hasPhoto ?? false);

  @override
  void initState() {
    super.initState();
    final spot = widget.existingSpot;
    _nameController = TextEditingController(text: spot?.name ?? '');
    _notesController = TextEditingController(text: spot?.notes ?? '');
    _dangerController = TextEditingController(text: spot?.dangerNotes ?? '');
    _recoverLostImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _dangerController.dispose();
    super.dispose();
  }

  Future<void> _recoverLostImage() async {
    try {
      final response = await _picker.retrieveLostData();
      final file = response.files?.firstOrNull;
      if (file != null) await _useImage(file);
    } catch (_) {
      // The form remains usable when Android has no interrupted picker data.
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingPhoto || _isSaving) return;
    setState(() {
      _isPickingPhoto = true;
      _errorKey = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (file != null) await _useImage(file);
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'mySpots.photoReadError');
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _useImage(XFile file) async {
    try {
      final source = await file.readAsBytes();
      final processed = await _photoProcessor.process(source);
      if (!mounted) return;
      setState(() {
        _photoBytes = processed.bytes;
        _photoContentType = processed.contentType;
        _removeExistingPhoto = false;
        _errorKey = null;
      });
    } on UserSpotPhotoException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorKey = error.failure == UserSpotPhotoFailure.tooLarge
            ? 'mySpots.photoTooLarge'
            : 'mySpots.photoReadError';
      });
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'mySpots.photoReadError');
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoContentType = null;
      _removeExistingPhoto = true;
      _errorKey = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorKey = null;
    });
    try {
      await widget.onSubmit(
        UserSpotDraft(
          name: _nameController.text,
          notes: _notesController.text,
          dangerNotes: _dangerController.text,
          photoBytes: _photoBytes,
          photoContentType: _photoContentType,
          removeExistingPhoto: _removeExistingPhoto,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on UserSpotException catch (error) {
      if (mounted) setState(() => _errorKey = _failureKey(error.failure));
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'mySpots.saveError');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _failureKey(UserSpotFailure failure) {
    return switch (failure) {
      UserSpotFailure.authenticationRequired => 'mySpots.signInRequired',
      UserSpotFailure.duplicateSpot => 'mySpots.duplicatePrivate',
      UserSpotFailure.limitReached => 'mySpots.personalLimitReached',
      UserSpotFailure.invalidPhoto => 'mySpots.photoTooLarge',
      UserSpotFailure.photoUploadFailed => 'mySpots.photoUploadError',
      UserSpotFailure.appCheckUnavailable => 'mySpots.appCheckError',
      UserSpotFailure.permissionDenied => 'mySpots.permissionError',
      UserSpotFailure.unavailable => 'mySpots.saveError',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.91,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 9),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: tc.textMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tc.oceanMedium.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: tc.oceanMedium,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        context.tr(
                          widget.existingSpot == null
                              ? 'mySpots.addTitle'
                              : 'mySpots.editTitle',
                        ),
                        style: TextStyle(
                          color: tc.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('common.close'),
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tc.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPhoto(tc),
                        const SizedBox(height: 16),
                        _field(
                          controller: _nameController,
                          label: context.tr('mySpots.name'),
                          icon: Icons.place_rounded,
                          maxLength: UserSpot.maximumNameLength,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? context.tr('mySpots.nameRequired')
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _notesController,
                          label: context.tr('mySpots.notes'),
                          icon: Icons.notes_rounded,
                          maxLength: UserSpot.maximumNotesLength,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _dangerController,
                          label: context.tr('mySpots.danger'),
                          hint: context.tr('mySpots.dangerHint'),
                          icon: Icons.warning_amber_rounded,
                          maxLength: UserSpot.maximumDangerNotesLength,
                          maxLines: 2,
                        ),
                        if (_errorKey != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: tc.error, size: 19),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  context.tr(_errorKey!),
                                  style: TextStyle(
                                    color: tc.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _submit,
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            context.tr(
                              _isSaving ? 'mySpots.saving' : 'common.save',
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: tc.oceanMedium,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(ThemeColors tc) {
    final hasSelectedPhoto = _photoBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_back_rounded,
                size: 18, color: tc.oceanMedium),
            const SizedBox(width: 7),
            Text(
              context.tr('mySpots.photo'),
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              context.tr('mySpots.photoLimit'),
              style: TextStyle(color: tc.textMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tc.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tc.glassBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasSelectedPhoto)
                    Image.memory(_photoBytes!, fit: BoxFit.cover)
                  else if (_hasExistingPhoto)
                    AuthenticatedSpotPhoto(
                      url: widget.existingSpot!.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: _photoPlaceholder(tc),
                    )
                  else
                    _photoPlaceholder(tc),
                  if (hasSelectedPhoto || _hasExistingPhoto)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: IconButton.filled(
                        tooltip: context.tr('mySpots.removePhoto'),
                        onPressed: _isSaving ? null : _removePhoto,
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 19),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.68),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPickingPhoto || _isSaving
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: Text(context.tr('mySpots.gallery')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPickingPhoto || _isSaving
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 19),
                label: Text(context.tr('mySpots.camera')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _photoPlaceholder(ThemeColors tc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, color: tc.textMuted, size: 34),
        const SizedBox(height: 5),
        Text(
          context.tr('mySpots.onePhoto'),
          style: TextStyle(color: tc.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int maxLength,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final tc = ThemeColors.of(context);
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      enabled: !_isSaving,
      style: TextStyle(color: tc.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 42 : 0),
          child: Icon(icon, color: tc.oceanMedium, size: 20),
        ),
        filled: true,
        fillColor: tc.surfaceLight.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tc.glassBorder),
        ),
      ),
    );
  }
}
