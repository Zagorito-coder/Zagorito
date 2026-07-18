// ============================================================
//  fish_intelligence_modal.dart — Modal fiche intelligence poisson
// ============================================================

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/fish_model.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/services/tide_service.dart';
import 'package:spots_app/theme.dart';

class FishIntelligenceModal extends StatelessWidget {
  final FishModel fish;
  final List<Spot> nearbySpots;
  final bool isLoadingNearby;
  final String Function(Spot) distanceText;
  final void Function(Spot) onSpotSelected;
  final VoidCallback onClose;
  final Position? currentPosition;

  const FishIntelligenceModal({
    super.key,
    required this.fish,
    required this.nearbySpots,
    this.isLoadingNearby = false,
    required this.distanceText,
    required this.onSpotSelected,
    required this.onClose,
    this.currentPosition,
  });

  static const Color _cyan = Color(0xFF48CAE4);
  static const Color _green = Color(0xFF52B788);
  static const Color _orange = Color(0xFFF4A261);

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width * 0.65,
      constraints: BoxConstraints(maxHeight: size.height * 0.75),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tc.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CloseButton(onClose: onClose),
          _Header(fish: fish, onClose: onClose),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IdentityBlock(fish: fish),
                  const SizedBox(height: 16),
                  _TechniqueBlock(fish: fish),
                  const SizedBox(height: 16),
                  _TideBlock(fish: fish, currentPosition: currentPosition),
                  const SizedBox(height: 16),
                  _SpotsBlock(
                    fish: fish,
                    nearbySpots: nearbySpots,
                    isLoadingNearby: isLoadingNearby,
                    distanceText: distanceText,
                    onSpotSelected: onSpotSelected,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;
  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          margin: const EdgeInsets.only(left: 8, top: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FishModel fish;
  final VoidCallback onClose;

  const _Header({required this.fish, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1E6091)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          const Text('🐟', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.translate('fishIntelligence.title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  final FishModel fish;
  const _IdentityBlock({required this.fish});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: FishIntelligenceModal._cyan, width: 2.5),
            ),
            child: ClipOval(child: _buildImage(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fish.name,
                  style: AppTextStyles.headlineSmall(context),
                ),
                const SizedBox(height: 2),
                Text(
                  fish.scientificName,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                _infoRow(Icons.straighten,
                    '${fish.minSize.toStringAsFixed(0)} ${l10n.translate('fishIntelligence.sizeCm')}'),
                _infoRow(Icons.scale,
                    '${fish.averageWeight.toStringAsFixed(1)} ${l10n.translate('fishIntelligence.weightKg')}'),
                _infoRow(Icons.place, fish.habitat),
                _infoRow(Icons.calendar_today, fish.bestSeason),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (fish.imageUrl.startsWith('assets/')) {
      return Image.asset(
        fish.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return CachedNetworkImage(
      imageUrl: fish.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(context),
      errorWidget: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: const Color(0xFF1E6091),
      child: const Center(child: Text('🐟', style: TextStyle(fontSize: 36))),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: FishIntelligenceModal._cyan),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechniqueBlock extends StatelessWidget {
  final FishModel fish;
  const _TechniqueBlock({required this.fish});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockTitle(l10n.translate('fishIntelligence.techniqueBlock')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fish.techniques
                .map((t) => _Chip(text: t, color: FishIntelligenceModal._cyan))
                .toList(),
          ),
          const SizedBox(height: 12),
          _TextRow(l10n.translate('fishIntelligence.montage'), fish.montage),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fish.baits
                .map((b) => _Chip(text: b, color: FishIntelligenceModal._orange))
                .toList(),
          ),
          const SizedBox(height: 12),
          _TextRow(l10n.translate('fishIntelligence.expertAdvice'), fish.fishingAdvice),
        ],
      ),
    );
  }
}

class _TideBlock extends StatefulWidget {
  final FishModel fish;
  final Position? currentPosition;
  static TideData? _cachedTide;

  const _TideBlock({required this.fish, this.currentPosition});

  @override
  State<_TideBlock> createState() => _TideBlockState();
}

class _TideBlockState extends State<_TideBlock> {
  TideData? _tide;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_TideBlock._cachedTide != null) {
      if (!mounted) return;
      setState(() { _tide = _TideBlock._cachedTide; _loading = false; });
      return;
    }
    try {
      final lat = widget.currentPosition?.latitude ?? 33.57;
      final lon = widget.currentPosition?.longitude ?? -7.59;
      final d = await TideService.fetchTides(latitude: lat, longitude: lon);
      _TideBlock._cachedTide = d;
      if (!mounted) return;
      setState(() { _tide = d; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _tide = TideData.fallback(); _loading = false; });
    }
  }

  double _getTideActivity(TideData t) {
    if (t.hourlyPoints.isEmpty) {
      final now = DateTime.now();
      final hour = now.hour + now.minute / 60;
      return 0.5 + 0.5 * math.sin(hour * math.pi / 6);
    }
    final now = DateTime.now();
    double cur = t.low;
    for (final p in t.hourlyPoints) {
      if (p.time.isAfter(now)) { cur = p.height; break; }
    }
    final range = t.high - t.low;
    if (range <= 0) return 0.5;
    return ((cur - t.low) / range).clamp(0.0, 1.0);
  }

  double _estimateWind(TideData t) => (t.waveHeight * 15).clamp(5.0, 60.0);
  double _estimateWaterTemp(TideData t) => (16.0 + t.waveHeight * 5).clamp(14.0, 26.0);

  String _getTideLabel(BuildContext context, double activity) {
    final l10n = AppLocalizations.of(context);
    if (activity > 0.75) return l10n.translate('fishIntelligence.tideRisingStrong');
    if (activity > 0.5) return l10n.translate('fishIntelligence.tideRising');
    if (activity > 0.25) return l10n.translate('fishIntelligence.tideFalling');
    return l10n.translate('fishIntelligence.tideSlack');
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final t = _tide;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tc.glassBorder),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final activity = _getTideActivity(t!);
    final isGood = activity > 0.5;
    final wind = _estimateWind(t);
    final temp = _estimateWaterTemp(t);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BlockTitle(l10n.translate('fishIntelligence.tideBlock')),
            const SizedBox(height: 10),
            _TextRow(l10n.translate('fishIntelligence.tide'), _getTideLabel(context, activity)),
            const SizedBox(height: 6),
            _TextRow('Hauteur', '${t.next.toStringAsFixed(2)}m (basse: ${t.low.toStringAsFixed(1)}m, haute: ${t.high.toStringAsFixed(1)}m)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  l10n.translate('fishIntelligence.fishActivity'),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: activity,
                      minHeight: 8,
                      backgroundColor: tc.glassBorder,
                      valueColor: AlwaysStoppedAnimation(
                        isGood ? FishIntelligenceModal._green : FishIntelligenceModal._orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TextRow(l10n.translate('fishIntelligence.wind'), '${wind.toStringAsFixed(0)} km/h'),
            _TextRow(l10n.translate('fishIntelligence.waterTemp'), '${temp.toStringAsFixed(1)}°C'),
            const SizedBox(height: 6),
            Text(
              l10n.translate('fishIntelligence.simulatedNote'),
              style: TextStyle(fontSize: 10, color: tc.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotsBlock extends StatelessWidget {
  final FishModel fish;
  final List<Spot> nearbySpots;
  final bool isLoadingNearby;
  final String Function(Spot) distanceText;
  final void Function(Spot) onSpotSelected;

  const _SpotsBlock({
    required this.fish,
    required this.nearbySpots,
    required this.isLoadingNearby,
    required this.distanceText,
    required this.onSpotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockTitle(l10n.translate('fishIntelligence.nearbySpots')),
          const SizedBox(height: 10),
          if (isLoadingNearby)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FishIntelligenceModal._cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.translate('fishIntelligence.loadingNearbySpots'),
                  style: AppTextStyles.bodyMedium(context),
                ),
              ],
            )
          else if (nearbySpots.isEmpty)
            Text(
              l10n.translate('fishIntelligence.noNearbySpots'),
              style: AppTextStyles.bodyMedium(context),
            )
          else
            Column(
              children: nearbySpots.map((spot) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: tc.surfaceLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tc.glassBorder),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: spot.type.color,
                      ),
                    ),
                    title: Text(
                      spot.name,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      distanceText(spot),
                      style: TextStyle(color: tc.textMuted, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.translate('fishIntelligence.navigate'),
                          style: const TextStyle(
                            color: FishIntelligenceModal._cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: FishIntelligenceModal._cyan),
                      ],
                    ),
                    onTap: () => onSpotSelected(spot),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.titleLarge(context).copyWith(
        color: FishIntelligenceModal._cyan,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  final String label;
  final String value;
  const _TextRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12, color: ThemeColors.of(context).textSecondary, height: 1.4),
        children: [
          TextSpan(
            text: '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
