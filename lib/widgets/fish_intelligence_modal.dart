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
import 'package:spots_app/services/forecast_firestore_service.dart';
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
    final size = MediaQuery.of(context).size;
    final palette = _FishModalPalette.of(context);

    return Container(
      width: math.min(size.width * 0.90, 430),
      constraints: BoxConstraints(maxHeight: size.height * 0.68),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.72),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(fish: fish, onClose: onClose),
          Flexible(
            child: CustomScrollView(
              key: const ValueKey<String>('fish-intelligence-scroll'),
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: RepaintBoundary(child: _IdentityBlock(fish: fish)),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 11)),
                SliverToBoxAdapter(
                  child: RepaintBoundary(child: _TechniqueBlock(fish: fish)),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 11)),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _TideBlock(
                      fish: fish,
                      currentPosition: currentPosition,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 11)),
                SliverToBoxAdapter(
                  child: _SpotsSectionHeader(
                    isLoadingNearby: isLoadingNearby,
                    isEmpty: nearbySpots.isEmpty,
                  ),
                ),
                if (!isLoadingNearby && nearbySpots.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final spot = nearbySpots[index];
                          return _NearbySpotTile(
                            key: ValueKey<String>(
                              'fish-intelligence-spot-${spot.id}',
                            ),
                            spot: spot,
                            distanceText: distanceText,
                            onSpotSelected: onSpotSelected,
                          );
                        },
                        childCount: nearbySpots.length,
                        addAutomaticKeepAlives: false,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FishModalPalette {
  final bool isDark;

  const _FishModalPalette(this.isDark);

  factory _FishModalPalette.of(BuildContext context) =>
      _FishModalPalette(Theme.of(context).brightness == Brightness.dark);

  Color get background =>
      isDark ? const Color(0xFF071722) : const Color(0xFFF7FCFE);
  Color get header =>
      isDark ? const Color(0xFF0A2130) : const Color(0xFFE7F5FA);
  Color get panel => isDark ? const Color(0xFF0B202D) : const Color(0xFFEDF7FB);
  Color get cell =>
      isDark ? Colors.white.withValues(alpha: 0.035) : const Color(0xFFF9FDFF);
  Color get primaryText => isDark ? Colors.white : const Color(0xFF102B3A);
  Color get secondaryText => isDark ? Colors.white70 : const Color(0xFF425E6B);
  Color get mutedText => isDark ? Colors.white38 : const Color(0xFF6A818C);
  Color get border =>
      isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFC8DFE8);
  Color get accent =>
      isDark ? FishIntelligenceModal._cyan : const Color(0xFF087F9C);
  Color get progressBackground =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD5E8EF);
  Color get shadow => isDark
      ? Colors.black.withValues(alpha: 0.42)
      : const Color(0xFF164C66).withValues(alpha: 0.16);
}

class _Header extends StatelessWidget {
  final FishModel fish;
  final VoidCallback onClose;

  const _Header({required this.fish, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = _FishModalPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.header,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: palette.accent.withValues(alpha: 0.20),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      child: Row(
        children: [
          Icon(
            Icons.radar_rounded,
            size: 18,
            color: palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.translate('fishIntelligence.title').toUpperCase(),
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.15,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.close_rounded,
              color: palette.secondaryText,
              size: 20,
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
    final palette = _FishModalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          Container(
            height: 132,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: FishIntelligenceModal._cyan.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(context),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE6071722)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        fish.scientificName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _identityMetric(
                    context,
                    Icons.straighten_rounded,
                    '${fish.minSize.toStringAsFixed(0)} ${l10n.translate('fishIntelligence.sizeCm')}',
                  ),
                ),
                _metricDivider(context),
                Expanded(
                  child: _identityMetric(
                    context,
                    Icons.scale_outlined,
                    '${fish.averageWeight.toStringAsFixed(1)} ${l10n.translate('fishIntelligence.weightKg')}',
                  ),
                ),
                _metricDivider(context),
                Expanded(
                  child: _identityMetric(
                    context,
                    Icons.waves_rounded,
                    fish.habitat,
                  ),
                ),
                _metricDivider(context),
                Expanded(
                  child: _identityMetric(
                    context,
                    Icons.calendar_today_outlined,
                    fish.bestSeason,
                  ),
                ),
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

  Widget _identityMetric(BuildContext context, IconData icon, String value) {
    final palette = _FishModalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: palette.accent),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              height: 1.05,
              color: palette.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricDivider(BuildContext context) => Container(
        width: 0.7,
        height: 33,
        color: _FishModalPalette.of(context).border,
      );
}

class _TechniqueBlock extends StatelessWidget {
  final FishModel fish;
  const _TechniqueBlock({required this.fish});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = _FishModalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockTitle(l10n.translate('fishIntelligence.techniqueBlock')),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: fish.techniques
                .map((t) => _Chip(text: t, color: palette.accent))
                .toList(),
          ),
          const SizedBox(height: 8),
          _TextRow(l10n.translate('fishIntelligence.montage'), fish.montage),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: fish.baits
                .map(
                    (b) => _Chip(text: b, color: FishIntelligenceModal._orange))
                .toList(),
          ),
          const SizedBox(height: 8),
          _TextRow(l10n.translate('fishIntelligence.expertAdvice'),
              fish.fishingAdvice),
        ],
      ),
    );
  }
}

class _TideBlock extends StatefulWidget {
  final FishModel fish;
  final Position? currentPosition;
  static final Map<String, TideData> _cachedTides = <String, TideData>{};

  const _TideBlock({required this.fish, this.currentPosition});

  @override
  State<_TideBlock> createState() => _TideBlockState();
}

class _TideBlockState extends State<_TideBlock> {
  TideData? _tide;
  GfsWeatherTimeline? _gfsWeather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final lat = widget.currentPosition?.latitude ?? 33.57;
    final lon = widget.currentPosition?.longitude ?? -7.59;
    final gfsFuture = ForecastFirestoreService.fetchNearestGfsWeather(
      latitude: lat,
      longitude: lon,
    ).catchError((_) => null);
    final cacheKey = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    final cached = _TideBlock._cachedTides[cacheKey];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _tide = cached;
        _loading = false;
      });
    } else {
      try {
        final d = await TideService.fetchTides(latitude: lat, longitude: lon);
        if (d.hourlyPoints.isNotEmpty) {
          _TideBlock._cachedTides[cacheKey] = d;
        }
        if (!mounted) return;
        setState(() {
          _tide = d;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _tide = TideData.fallback();
          _loading = false;
        });
      }
    }

    final gfsWeather = await gfsFuture;
    if (!mounted || gfsWeather == null) return;
    setState(() => _gfsWeather = gfsWeather);
  }

  double _getTideActivity(TideData t) {
    if (t.hourlyPoints.isEmpty) return 0.0;
    final now = DateTime.now();
    double cur = t.low;
    for (final p in t.hourlyPoints) {
      if (p.time.isAfter(now)) {
        cur = p.height;
        break;
      }
    }
    final range = t.high - t.low;
    if (range <= 0) return 0.0;
    return ((cur - t.low) / range).clamp(0.0, 1.0);
  }

  TidePoint? _currentPoint(TideData t) {
    if (t.hourlyPoints.isEmpty) return null;
    final now = DateTime.now();
    return t.hourlyPoints.firstWhere(
      (point) => point.time.isAfter(now),
      orElse: () => t.hourlyPoints.last,
    );
  }

  String _getTideLabel(BuildContext context, double activity) {
    final l10n = AppLocalizations.of(context);
    if (activity > 0.75) {
      return l10n.translate('fishIntelligence.tideRisingStrong');
    }
    if (activity > 0.5) return l10n.translate('fishIntelligence.tideRising');
    if (activity > 0.25) return l10n.translate('fishIntelligence.tideFalling');
    return l10n.translate('fishIntelligence.tideSlack');
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = _FishModalPalette.of(context);
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

    if (t == null || t.hourlyPoints.isEmpty) {
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
              Text(
                l10n.translate('fishIntelligence.unavailable'),
                style: TextStyle(color: tc.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.translate('fishIntelligence.simulatedNote'),
                style: TextStyle(
                  fontSize: 10,
                  color: tc.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activity = _getTideActivity(t);
    final isGood = activity > 0.5;
    final point = _currentPoint(t);
    final gfsPoint = _gfsWeather?.nearestTo(point?.time ?? DateTime.now());
    final wind = point?.windSpeedKmh;
    final temp = point?.temperatureC;
    final pressure = point?.pressureHpa ?? gfsPoint?.pressureHpa;
    final rain = point?.precipitationProbabilityPct ??
        gfsPoint?.precipitationProbabilityPct;
    final humidity =
        point?.relativeHumidityPct ?? gfsPoint?.relativeHumidityPct;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BlockTitle(l10n.translate('fishIntelligence.tideBlock')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.translate('fishIntelligence.fishActivity'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: palette.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(activity * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isGood
                        ? FishIntelligenceModal._green
                        : FishIntelligenceModal._orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: activity,
                minHeight: 5,
                backgroundColor: palette.progressBackground,
                valueColor: AlwaysStoppedAnimation(
                  isGood
                      ? FishIntelligenceModal._green
                      : FishIntelligenceModal._orange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 3;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ConditionMetric(
                      width: tileWidth,
                      icon: Icons.waves_rounded,
                      label: l10n.translate('fishIntelligence.tide'),
                      value: _getTideLabel(context, activity),
                    ),
                    _ConditionMetric(
                      width: tileWidth,
                      icon: Icons.air_rounded,
                      label: l10n.translate('fishIntelligence.wind'),
                      value: wind == null ? '--' : '${wind.round()} km/h',
                    ),
                    _ConditionMetric(
                      width: tileWidth,
                      icon: Icons.thermostat_rounded,
                      label: l10n.translate('fishIntelligence.waterTemp'),
                      value:
                          temp == null ? '--' : '${temp.toStringAsFixed(1)}°',
                    ),
                    _ConditionMetric(
                      width: tileWidth,
                      icon: Icons.speed_rounded,
                      label: l10n.translate('fishIntelligence.pressure'),
                      value:
                          pressure == null ? '--' : '${pressure.round()} hPa',
                    ),
                    _ConditionMetric(
                      width: tileWidth,
                      icon: Icons.umbrella_rounded,
                      label: l10n.translate('fishIntelligence.rain'),
                      value: rain == null ? '--' : '${rain.round()}%',
                    ),
                    _ConditionMetric(
                      width: tileWidth,
                      icon: Icons.water_drop_outlined,
                      label: l10n.translate('fishIntelligence.humidity'),
                      value: humidity == null ? '--' : '${humidity.round()}%',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  Icons.height_rounded,
                  size: 12,
                  color: palette.mutedText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    child: Text(
                      '${t.next.toStringAsFixed(2)} m  ·  ${t.low.toStringAsFixed(1)}–${t.high.toStringAsFixed(1)} m',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.translate('fishIntelligence.simulatedNote'),
              style: TextStyle(
                fontSize: 8,
                color: palette.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionMetric extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;

  const _ConditionMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _FishModalPalette.of(context);
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: palette.cell,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: palette.accent),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 6.8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotsSectionHeader extends StatelessWidget {
  final bool isLoadingNearby;
  final bool isEmpty;

  const _SpotsSectionHeader({
    required this.isLoadingNearby,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = _FishModalPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockTitle(l10n.translate('fishIntelligence.nearbySpots')),
          const SizedBox(height: 7),
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
                  style: TextStyle(color: palette.secondaryText, fontSize: 11),
                ),
              ],
            )
          else if (isEmpty)
            Text(
              l10n.translate('fishIntelligence.noNearbySpots'),
              style: TextStyle(color: palette.secondaryText, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _NearbySpotTile extends StatelessWidget {
  final Spot spot;
  final String Function(Spot) distanceText;
  final void Function(Spot) onSpotSelected;

  const _NearbySpotTile({
    super.key,
    required this.spot,
    required this.distanceText,
    required this.onSpotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = _FishModalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: palette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
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
              color: palette.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            distanceText(spot),
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 10,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.translate('fishIntelligence.navigate'),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: palette.accent,
              ),
            ],
          ),
          onTap: () => onSpotSelected(spot),
        ),
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = _FishModalPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: palette.accent,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600),
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
    final palette = _FishModalPalette.of(context);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 10.5,
          color: palette.secondaryText,
          height: 1.35,
        ),
        children: [
          TextSpan(
            text: '$label : ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: palette.primaryText,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
