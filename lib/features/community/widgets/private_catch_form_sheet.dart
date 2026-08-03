import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:spots_app/features/community/models/private_catch.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';
import 'package:spots_app/widgets/location_access_feedback.dart';

class PrivateCatchFormResult {
  const PrivateCatchFormResult({
    required this.species,
    required this.weightKg,
    required this.spotName,
    required this.latitude,
    required this.longitude,
    required this.montage,
    required this.bait,
    required this.notes,
    required this.advice,
    required this.caughtAt,
  });

  final String species;
  final double weightKg;
  final String spotName;
  final double? latitude;
  final double? longitude;
  final String montage;
  final String bait;
  final String notes;
  final String advice;
  final DateTime caughtAt;
}

class PrivateCatchFormSheet extends StatefulWidget {
  const PrivateCatchFormSheet({
    super.key,
    required this.photoBytes,
    this.existing,
  });

  final Uint8List photoBytes;
  final PrivateCatch? existing;

  @override
  State<PrivateCatchFormSheet> createState() => _PrivateCatchFormSheetState();
}

class _PrivateCatchFormSheetState extends State<PrivateCatchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _species;
  late final TextEditingController _weight;
  late final TextEditingController _spotName;
  late final TextEditingController _montage;
  late final TextEditingController _bait;
  late final TextEditingController _notes;
  late final TextEditingController _advice;
  late DateTime _caughtAt;
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _species = TextEditingController(text: item?.species ?? '');
    _weight = TextEditingController(
      text: item == null ? '' : _formatWeight(item.weightKg),
    );
    _spotName = TextEditingController(text: item?.spotName ?? '');
    _montage = TextEditingController(text: item?.montage ?? '');
    _bait = TextEditingController(text: item?.bait ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _advice = TextEditingController(text: item?.advice ?? '');
    _caughtAt = item?.caughtAt ?? DateTime.now();
    _latitude = item?.latitude;
    _longitude = item?.longitude;
  }

  @override
  void dispose() {
    _species.dispose();
    _weight.dispose();
    _spotName.dispose();
    _montage.dispose();
    _bait.dispose();
    _notes.dispose();
    _advice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.91,
          minChildSize: 0.65,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.textMuted.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(
                              widget.existing == null
                                  ? 'community.addPrivateCatch'
                                  : 'community.editPrivateCatch',
                            ),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.memory(
                          widget.photoBytes,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _species,
                      label: context.tr('community.species'),
                      icon: Icons.set_meal_rounded,
                      maximumLength: PrivateCatch.maximumSpeciesLength,
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        context,
                        label: context.tr('community.weightKg'),
                        icon: Icons.monitor_weight_outlined,
                        suffix: 'kg',
                      ),
                      validator: (value) {
                        final weight = _parseWeight(value);
                        if (weight == null ||
                            weight < PrivateCatch.minimumWeightKg ||
                            weight > PrivateCatch.maximumWeightKg) {
                          return context.tr('community.invalidWeight');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _spotName,
                      label: context.tr('community.zoneName'),
                      icon: Icons.place_outlined,
                      maximumLength: PrivateCatch.maximumSpotNameLength,
                    ),
                    const SizedBox(height: 9),
                    OutlinedButton.icon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _latitude == null
                                  ? Icons.my_location_rounded
                                  : Icons.verified_user_rounded,
                            ),
                      label: Text(
                        context.tr(
                          _latitude == null
                              ? 'community.usePrivateLocation'
                              : 'community.privateLocationSaved',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        context.tr('community.locationPrivacyHelp'),
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _montage,
                      label: context.tr('community.rig'),
                      icon: Icons.device_hub_rounded,
                      maximumLength: PrivateCatch.maximumMontageLength,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _bait,
                      label: context.tr('community.bait'),
                      icon: Icons.grass_rounded,
                      maximumLength: PrivateCatch.maximumBaitLength,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _notes,
                      label: context.tr('community.notes'),
                      icon: Icons.notes_rounded,
                      maximumLength: PrivateCatch.maximumNotesLength,
                      maximumLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _advice,
                      label: context.tr('community.advice'),
                      icon: Icons.lightbulb_outline_rounded,
                      maximumLength: PrivateCatch.maximumAdviceLength,
                      maximumLines: 3,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        Icons.calendar_today_rounded,
                        color: palette.accent,
                      ),
                      title: Text(context.tr('community.catchDate')),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(_caughtAt),
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.lock_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(context.tr('community.savePrivately')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int maximumLength,
    bool required = false,
    int maximumLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maximumLength,
      maxLines: maximumLines,
      textInputAction:
          maximumLines == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: _decoration(context, label: label, icon: icon),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? context.tr('community.requiredField')
              : null
          : null,
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? suffix,
  }) {
    final palette = BoosterFishPagePalette.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: palette.accent),
      suffixText: suffix,
      filled: true,
      fillColor: palette.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: palette.divider),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await ensureLocationAccess(context)) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      _showLocationError();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('community.locationUnavailable'))),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _caughtAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) setState(() => _caughtAt = selected);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final weight = _parseWeight(_weight.text);
    if (weight == null) return;
    Navigator.pop(
      context,
      PrivateCatchFormResult(
        species: _species.text.trim(),
        weightKg: weight,
        spotName: _spotName.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        montage: _montage.text.trim(),
        bait: _bait.text.trim(),
        notes: _notes.text.trim(),
        advice: _advice.text.trim(),
        caughtAt: _caughtAt,
      ),
    );
  }

  static double? _parseWeight(String? raw) {
    return double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  }

  static String _formatWeight(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
