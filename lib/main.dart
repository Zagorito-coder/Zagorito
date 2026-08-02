// ============================================================
//  main.dart — Spots App OPTIMISÉE POUR 6200 SPOTS
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show SystemChrome, SystemUiMode, SystemUiOverlayStyle;
import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/compass_readings.dart';
import 'package:spots_app/models/offline_map_region.dart';
import 'package:spots_app/models/spot_selection_request.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/models/user_spot_selection_request.dart';
import 'package:spots_app/services/spot_service.dart';
import 'package:spots_app/services/offline_map_service.dart';
import 'package:spots_app/services/user_spot_service.dart';
import 'package:spots_app/models/fish_model.dart';
import 'package:spots_app/spot_details_panel.dart';
import 'package:spots_app/spots_canvas_layer.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/utils/map_flight_plan.dart';
import 'package:spots_app/widgets/app_tile_layer.dart';
import 'package:spots_app/widgets/finite_map_controller.dart';
import 'package:spots_app/widgets/finite_marker_layer.dart';
import 'package:spots_app/widgets/fish_image_framing.dart';
import 'package:spots_app/widgets/offline_map_manager_sheet.dart';
import 'package:spots_app/widgets/personal_spots_map_layer.dart';
import 'package:spots_app/widgets/user_spot_form_sheet.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/splash_bootstrap.dart';
import 'package:spots_app/widgets/fish_intelligence_modal.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/services/crash_reporting_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/widgets/wind_particle_layer.dart';

const double _mapBottomControlHeight = 60;

void main() {
  runZonedGuarded(_bootstrap, (error, stackTrace) {
    // Expected when vector tiles discard stale work during pan or zoom.
    if (error is CancellationException) return;
    CrashReportingService.handleUncaught(error, stackTrace);
  });
}

void _bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 48 * 1024 * 1024;
  if (!kDebugMode) {
    // Securite : neutralise tous les logs en release pour eviter la fuite
    // d'uid, emails, tokens dans logcat. Conserve la signature exacte de
    // debugPrint pour compatibilite Flutter.
    // ignore: avoid_dynamic_calls
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const SpotsApp());
}

class SpotsApp extends StatelessWidget {
  const SpotsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [ThemeController.instance, LanguageController.instance]),
      builder: (context, child) {
        final isDark = ThemeController.instance.isDark;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: ThemeColors.of(context).background,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ));
        });
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider(create: (_) => FishProvider()),
            ChangeNotifierProvider(create: (_) => PremiumProvider()),
            ChangeNotifierProvider(create: (_) => WindAnimationProvider()),
          ],
          child: MaterialApp(
            title: 'Spots App',
            debugShowCheckedModeBanner: false,
            theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
            locale: LanguageController.instance.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashBootstrap(),
          ),
        );
      },
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────

class _DropClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size s) => ui.Path()
    ..moveTo(s.width * 0.5, 0)
    ..cubicTo(s.width * 0.05, s.height * 0.25, s.width * 0.05, s.height * 0.65,
        s.width * 0.5, s.height)
    ..cubicTo(s.width * 0.95, s.height * 0.65, s.width * 0.95, s.height * 0.25,
        s.width * 0.5, 0)
    ..close();
  @override
  bool shouldReclip(CustomClipper<ui.Path> o) => false;
}

class SpotMarker extends StatelessWidget {
  final Spot spot;
  final bool isSelected, isPremium;
  const SpotMarker(
      {super.key,
      required this.spot,
      required this.isSelected,
      required this.isPremium});
  @override
  Widget build(BuildContext context) {
    final bc = spot.type.color;
    final mw = isSelected ? 42.0 : 32.0;
    final mh = isSelected ? 54.0 : 42.0;
    final hl = isPremium ? Colors.amberAccent : bc;
    return SizedBox(
        width: mw,
        height: mh + (isSelected ? 44 : 32),
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                  bottom: 0,
                  child: Container(
                      width: mw * 1.4,
                      height: mh * 0.6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              hl.withValues(alpha: isSelected ? 0.15 : 0.08)))),
              Positioned(
                  bottom: 0,
                  child: ClipPath(
                      clipper: _DropClipper(),
                      child: Container(
                          width: mw,
                          height: mh,
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                bc.withValues(alpha: 0.95),
                                bc.withValues(alpha: 0.65)
                              ]),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.4),
                              boxShadow: [
                                BoxShadow(
                                    color: bc.withValues(alpha: 0.45),
                                    blurRadius: isSelected ? 12 : 7,
                                    offset: const Offset(0, 3))
                              ]),
                          child: Center(
                              child: Icon(Icons.phishing,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  size: mw * 0.42))))),
              Positioned(
                  bottom: mh * 0.72,
                  child: Container(
                      width: mw * 0.35,
                      height: mw * 0.18,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(mw * 0.09),
                          color: Colors.white.withValues(alpha: 0.5)))),
              if (isSelected)
                Positioned(top: -40, child: SpotLabel(spot: spot, accent: hl)),
            ]));
  }
}

class SpotLabel extends StatelessWidget {
  final Spot spot;
  final Color accent;
  const SpotLabel({super.key, required this.spot, required this.accent});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: accent.withValues(alpha: 0.95), width: 1.0),
            boxShadow: [
              BoxShadow(
                  color: tc.shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
          const SizedBox(width: 10),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name,
                        style: TextStyle(
                            color: tc.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                    const SizedBox(height: 2),
                    Text(spot.type.label,
                        style: TextStyle(
                            color: accent.withValues(alpha: 0.92),
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ])),
        ]));
  }
}

// ── SearchBar ─────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final List<Spot> results;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final void Function(Spot) onSelect;
  final String Function(Spot) distanceText;
  final String? measurementText;
  final VoidCallback onStopMeasurement;
  final VoidCallback? onTap;
  const _SearchBar(
      {required this.controller,
      required this.results,
      required this.onChanged,
      required this.onClear,
      required this.onSelect,
      required this.distanceText,
      required this.onStopMeasurement,
      this.measurementText,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Stack(clipBehavior: Clip.none, children: [
        Padding(
            padding: EdgeInsets.only(top: measurementText == null ? 0 : 64),
            child: Container(
                key: const ValueKey<String>('map-search-bar-surface'),
                height: _mapBottomControlHeight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: tc.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tc.glassBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: tc.shadowColor,
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: TextField(
                    controller: controller,
                    style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    onTap: onTap,
                    decoration: InputDecoration(
                        filled: true,
                        fillColor: tc.surfaceLight.withValues(alpha: 0.8),
                        hintText: l10n.translate('map.searchHint'),
                        hintStyle: TextStyle(color: tc.textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: tc.textSecondary, size: 22),
                        suffixIcon: controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close,
                                    color: tc.textMuted, size: 18),
                                onPressed: onClear),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: tc.oceanMedium, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14)),
                    textInputAction: TextInputAction.search,
                    onChanged: onChanged,
                    onSubmitted: (_) {
                      if (results.isNotEmpty) onSelect(results.first);
                    }))),
        if (measurementText != null)
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                  child: Stack(clipBehavior: Clip.none, children: [
                Semantics(
                    liveRegion: true,
                    label:
                        '${l10n.translate('map.measureDistance')} : $measurementText',
                    child: Container(
                        key: const ValueKey<String>(
                            'map-measurement-search-indicator'),
                        width: 154,
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                            color: tc.surface.withValues(alpha: 0.97),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: tc.gold.withValues(alpha: 0.75),
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                  color: tc.shadowColor,
                                  blurRadius: 12,
                                  offset: const Offset(0, 3))
                            ]),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.straighten_rounded,
                                  color: tc.gold, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                  child: Text(measurementText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: TextStyle(
                                          color: tc.gold,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ])))
                            ]))),
                Positioned(
                    top: 6,
                    right: -18,
                    child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Material(
                            color: tc.surface.withValues(alpha: 0.97),
                            elevation: 4,
                            shadowColor: tc.shadowColor,
                            shape: CircleBorder(
                                side: BorderSide(
                                    color: tc.gold.withValues(alpha: 0.75),
                                    width: 1.2)),
                            child: IconButton(
                                key: const ValueKey<String>(
                                    'map-measurement-close'),
                                tooltip: l10n.translate('map.stopMeasure'),
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.close_rounded,
                                    color: tc.textPrimary, size: 24),
                                onPressed: onStopMeasurement))))
              ]))),
      ]),
      if (controller.text.isNotEmpty && results.isNotEmpty)
        Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tc.glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: tc.shadowColor.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final spot = results[index];
                      return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: tc.surfaceLight.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                              dense: true,
                              leading: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: spot.type.color,
                                      boxShadow: [
                                        BoxShadow(
                                            color: spot.type.color
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 1)
                                      ])),
                              title: Text(spot.name,
                                  style: TextStyle(
                                      color: tc.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(distanceText(spot),
                                  style: TextStyle(
                                      color: tc.textMuted, fontSize: 11)),
                              trailing: Icon(Icons.chevron_right,
                                  color: tc.textMuted, size: 16),
                              onTap: () => onSelect(spot)));
                    }))),
    ]);
  }
}

class ZoomButton extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final VoidCallback onTap;
  const ZoomButton(
      {super.key,
      required this.heroTag,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tc.glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: tc.shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Center(child: Icon(icon, color: tc.textPrimary, size: 24))));
  }
}

class MarkerCacheManager {
  final Map<String, SpotMarker> _cache = {};
  static const int _maxEntries = 200;

  SpotMarker getOrCreateMarker(Spot s, bool sel, bool prem) {
    final k = '${s.id}_${sel}_$prem';
    if (_cache.containsKey(k)) return _cache[k]!;
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return _cache[k] =
        SpotMarker(key: ValueKey(k), spot: s, isSelected: sel, isPremium: prem);
  }

  void clear() => _cache.clear();
}

// ── FishMenu ──────────────────────────────────────────────────

class _FishVerticalMenu extends StatelessWidget {
  final List<FishModel> fishes;
  final FishModel? selectedFish;
  final void Function(FishModel) onFishSelected;
  final VoidCallback onFishDeselected;
  const _FishVerticalMenu(
      {required this.fishes,
      required this.selectedFish,
      required this.onFishSelected,
      required this.onFishDeselected});
  static const double _menuWidth = 188;
  static const double _rowExtent = 66;

  @override
  Widget build(BuildContext context) {
    if (fishes.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      key: const ValueKey<String>('map-fish-selector'),
      child: SizedBox(
        width: _menuWidth,
        height: 6 * _rowExtent + 20,
        child: ListView.builder(
          reverse: true,
          padding: EdgeInsets.zero,
          itemCount: fishes.length,
          itemBuilder: (ctx, i) {
            final f = fishes[i];
            final sel = selectedFish?.id == f.id;
            return _FishRow(
              fish: f,
              isSelected: sel,
              onTap: () {
                if (sel) {
                  onFishDeselected();
                } else {
                  onFishSelected(f);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _FishRow extends StatelessWidget {
  final FishModel fish;
  final bool isSelected;
  final VoidCallback onTap;
  const _FishRow(
      {required this.fish, required this.isSelected, required this.onTap});

  static const double _collapsedWidth = 62;
  static const double _selectedWidth = 184;
  static const double _tileHeight = 58;

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    const accent = Color(0xFF48CAE4);
    return Semantics(
      button: true,
      selected: isSelected,
      label: fish.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: _FishVerticalMenu._rowExtent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              key: ValueKey<String>('map-fish-tile-${fish.id}'),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isSelected ? _selectedWidth : _collapsedWidth,
              height: _tileHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tc.surface.withValues(alpha: 0.97),
                    tc.surfaceLight.withValues(alpha: 0.94),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? accent : tc.glassBorder,
                  width: isSelected ? 1.4 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: _collapsedWidth - 2,
                    height: _tileHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: _buildImage(context),
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    Container(
                      width: 3,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tc.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (fish.imageUrl.startsWith('assets/')) {
      final imageScale = FishImageFraming.thumbnailScale(fish.id);
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      return Transform.scale(
          scale: imageScale,
          child: Image.asset(fish.imageUrl,
              fit: BoxFit.cover,
              cacheWidth: (_tileHeight * imageScale * pixelRatio).ceil(),
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _ph()));
    }
    return CachedNetworkImage(
        imageUrl: fish.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _ph(),
        errorWidget: (_, __, ___) => _ph());
  }

  Widget _ph() => Container(
      color: const Color(0xFF1E6091),
      child: const Center(child: Text('🐟', style: TextStyle(fontSize: 20))));
}

// ═══════════════════════════════════════════════════════════════
//  MAP SCREEN
// ═══════════════════════════════════════════════════════════════

class MapScreen extends StatefulWidget {
  final List<Spot>? initialSpots;
  final ValueListenable<bool>? isActive;
  final ValueListenable<int>? addSpotRequests;
  final ValueListenable<SpotSelectionRequest?>? spotSelectionRequests;
  final ValueListenable<UserSpotSelectionRequest?>? userSpotSelectionRequests;
  final VoidCallback? onOpenMySpots;
  final VoidCallback? onPersonalSpotCreated;

  const MapScreen({
    super.key,
    this.initialSpots,
    this.isActive,
    this.addSpotRequests,
    this.spotSelectionRequests,
    this.userSpotSelectionRequests,
    this.onOpenMySpots,
    this.onPersonalSpotCreated,
  });
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = FiniteMapController();
  final TextEditingController _searchController = TextEditingController();
  final Distance _distance = const Distance();
  Timer? _debounceTimer;
  LatLngBounds? _pendingBounds;
  double? _pendingZoom;

  List<Spot> _spots = [];
  LatLngBounds? _lastBounds;
  List<Spot> _visibleSpots = [];
  String _searchQuery = '';
  Position? _currentPosition;
  Spot? _selectedSpot;
  UserSpot? _selectedUserSpot;
  double _currentZoom = 6.0;
  bool _isLoadingSpots = true;
  bool _isFishBarVisible = false, _showToolsPanel = false, _isMeasuring = false;
  bool _isAddingSpot = false;
  LatLng? _pendingPersonalSpot;
  bool _ignoreNextCanvasTap = false;
  int _lastAddSpotRequest = 0;
  int _lastSpotSelectionRequest = 0;
  int _lastUserSpotSelectionRequest = 0;
  int _cameraFlightSerial = 0;
  late final AnimationController _cameraFlightController;
  MapFlightPlan? _cameraFlightPlan;
  Duration _lastCameraFlightFrame = Duration.zero;
  final List<LatLng> _measurePoints = [];
  double _measuredDistanceKm = 0.0;
  MapStyle _mapStyle = MapStyle.satellite;
  // Toutes les fonctions sont gratuites dans la version financée par AdMob.
  static const bool _isPremium = true;
  static const double _maxZoom = 16.0;

  // Compass — désactivé par défaut
  bool _isCompassEnabled = false;
  double? _magneticHeading, _gpsCourseOverGround;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  bool _positionStreamStartedForCompass = false;
  Position? _lastPosition;

  List<Spot> get _searchResults {
    final q = _searchQuery.trim().toLowerCase();
    return q.isEmpty
        ? []
        : _spots.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  String _distanceText(Spot spot) {
    if (_currentPosition == null) return 'Distance inconnue';
    final km = _distance.as(
        LengthUnit.Kilometer,
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(spot.latitude, spot.longitude));
    return '${km.toStringAsFixed(1)} km';
  }

  String get _formattedMeasuredDistance =>
      '${_measuredDistanceKm.toStringAsFixed(2)} km';

  @override
  void initState() {
    super.initState();
    _cameraFlightController = AnimationController(vsync: this)
      ..addListener(_applyCameraFlightFrame);
    widget.isActive?.addListener(_handleMapActivityChanged);
    _lastAddSpotRequest = widget.addSpotRequests?.value ?? 0;
    widget.addSpotRequests?.addListener(_handleAddSpotRequest);
    _lastSpotSelectionRequest =
        widget.spotSelectionRequests?.value?.serial ?? 0;
    widget.spotSelectionRequests?.addListener(_handleSpotSelectionRequest);
    _lastUserSpotSelectionRequest =
        widget.userSpotSelectionRequests?.value?.serial ?? 0;
    widget.userSpotSelectionRequests
        ?.addListener(_handleUserSpotSelectionRequest);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadSpots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateVisibleSpots();
      unawaited(_initLocation());
    });
    // Compass & position stream démarrés uniquement à la demande.
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      oldWidget.isActive?.removeListener(_handleMapActivityChanged);
      widget.isActive?.addListener(_handleMapActivityChanged);
      _handleMapActivityChanged();
    }
    if (oldWidget.addSpotRequests != widget.addSpotRequests) {
      oldWidget.addSpotRequests?.removeListener(_handleAddSpotRequest);
      _lastAddSpotRequest = widget.addSpotRequests?.value ?? 0;
      widget.addSpotRequests?.addListener(_handleAddSpotRequest);
    }
    if (oldWidget.spotSelectionRequests != widget.spotSelectionRequests) {
      oldWidget.spotSelectionRequests
          ?.removeListener(_handleSpotSelectionRequest);
      _lastSpotSelectionRequest =
          widget.spotSelectionRequests?.value?.serial ?? 0;
      widget.spotSelectionRequests?.addListener(_handleSpotSelectionRequest);
    }
    if (oldWidget.userSpotSelectionRequests !=
        widget.userSpotSelectionRequests) {
      oldWidget.userSpotSelectionRequests
          ?.removeListener(_handleUserSpotSelectionRequest);
      _lastUserSpotSelectionRequest =
          widget.userSpotSelectionRequests?.value?.serial ?? 0;
      widget.userSpotSelectionRequests
          ?.addListener(_handleUserSpotSelectionRequest);
    }
  }

  void _handleAddSpotRequest() {
    final request = widget.addSpotRequests?.value ?? 0;
    if (request == _lastAddSpotRequest) return;
    _lastAddSpotRequest = request;
    _startAddingSpot();
  }

  void _handleMapActivityChanged() {
    if (widget.isActive?.value ?? true) return;

    final fishProvider = FishProvider.instance;
    if (fishProvider.isFishModalVisible) {
      fishProvider.closeFishModal();
    }
    if (!mounted || !_isFishBarVisible) return;
    setState(() => _isFishBarVisible = false);
  }

  void _handleSpotSelectionRequest() {
    final request = widget.spotSelectionRequests?.value;
    if (request == null || request.serial == _lastSpotSelectionRequest) return;
    _lastSpotSelectionRequest = request.serial;
    unawaited(_selectSpot(request.spot));
  }

  void _handleUserSpotSelectionRequest() {
    final request = widget.userSpotSelectionRequests?.value;
    if (request == null || request.serial == _lastUserSpotSelectionRequest) {
      return;
    }
    _lastUserSpotSelectionRequest = request.serial;
    unawaited(_selectUserSpot(request.spot));
  }

  void _toggleCompass() {
    if (_isCompassEnabled) {
      _compassSubscription?.cancel();
      _compassSubscription = null;
      _magneticHeading = null;
      _gpsCourseOverGround = null;
      setState(() => _isCompassEnabled = false);
      _stopCompassOwnedPositionStream();
    } else {
      _compassSubscription = FlutterCompass.events?.listen((e) {
        final magneticHeading = e.heading;
        if (mounted && magneticHeading != null && magneticHeading.isFinite) {
          setState(() => _magneticHeading = magneticHeading);
        }
      });
      setState(() => _isCompassEnabled = true);
      unawaited(_ensureCompassCourseTracking());
    }
  }

  Future<void> _ensureCompassCourseTracking() async {
    if (_positionSubscription != null) return;
    await _initLocation();
    if (!mounted || !_isCompassEnabled || _positionSubscription != null) return;
    _initPositionStream(startedForCompass: true);
  }

  void _stopCompassOwnedPositionStream() {
    if (!_positionStreamStartedForCompass) return;
    final subscription = _positionSubscription;
    _positionStreamStartedForCompass = false;
    _positionSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  double? _courseOverGroundFor(Position position) {
    final rawCourse = position.heading;
    final speed = position.speed;
    if (speed.isFinite && speed >= 0 && speed < 0.5) return null;
    if (speed.isFinite &&
        speed >= 0.5 &&
        rawCourse.isFinite &&
        rawCourse >= 0) {
      return rawCourse;
    }

    final previous = _lastPosition;
    if (previous == null) return null;
    final movedMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    final accuracyGuard = math.max(
      5.0,
      math.min(30.0, math.max(previous.accuracy, position.accuracy)),
    );
    if (!movedMeters.isFinite || movedMeters < accuracyGuard) return null;
    return Geolocator.bearingBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
  }

  void _initPositionStream({bool startedForCompass = false}) {
    if (_positionSubscription != null) {
      if (!startedForCompass) _positionStreamStartedForCompass = false;
      return;
    }
    _positionStreamStartedForCompass = startedForCompass;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 10),
    ).listen(
      (pos) {
        if (!mounted) return;
        final gpsCourseOverGround = _courseOverGroundFor(pos);
        _lastPosition = pos;
        _currentPosition = pos;
        setState(() {
          _gpsCourseOverGround = _isCompassEnabled ? gpsCourseOverGround : null;
        });
      },
      onError: (Object error) {
        debugPrint('[MapScreen] Position stream unavailable: $error');
        _positionSubscription = null;
        _positionStreamStartedForCompass = false;
        if (!mounted) return;
        setState(() {
          _currentPosition = null;
          _lastPosition = null;
          _gpsCourseOverGround = null;
        });
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cancelCameraFlight();
    _cameraFlightController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    widget.isActive?.removeListener(_handleMapActivityChanged);
    widget.addSpotRequests?.removeListener(_handleAddSpotRequest);
    widget.spotSelectionRequests?.removeListener(_handleSpotSelectionRequest);
    widget.userSpotSelectionRequests
        ?.removeListener(_handleUserSpotSelectionRequest);
    super.dispose();
  }

  void _updateVisibleSpots() {
    if (_spots.isEmpty) return;
    try {
      _applyBoundsFilter(_mapController.camera.visibleBounds);
    } catch (_) {}
  }

  void _applyBoundsFilter(LatLngBounds b) {
    if (b.north.isNaN || b.south.isNaN || b.east.isNaN || b.west.isNaN) return;
    _visibleSpots = _spots
        .where((s) =>
            s.latitude >= b.south &&
            s.latitude <= b.north &&
            s.longitude >= b.west &&
            s.longitude <= b.east)
        .toList();
    _lastBounds = b;
  }

  Future<void> _loadSpots() async {
    try {
      if (widget.initialSpots != null && widget.initialSpots!.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _spots = widget.initialSpots!;
          _isLoadingSpots = false;
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _updateVisibleSpots());
        return;
      }
      final spots = await SpotService.loadSpots();
      if (!mounted) return;
      setState(() {
        _spots = spots;
        _isLoadingSpots = false;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updateVisibleSpots());
    } catch (e, st) {
      debugPrint('[MapScreen] ERREUR chargement spots: $e\n$st');
      if (mounted) setState(() => _isLoadingSpots = false);
    }
  }

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = pos);
    } catch (e) {
      debugPrint('[main] Erreur initLocation: $e');
    }
  }

  void _zoomTo(double zoom) {
    _cancelCameraFlight();
    if (!zoom.isFinite) return;
    final center = _mapController.camera.center;
    if (!center.latitude.isFinite || !center.longitude.isFinite) return;
    if (zoom > _maxZoom) {
      zoom = _maxZoom;
    }
    final z = zoom.clamp(3.0, _maxZoom);
    _mapController.move(center, z);
    setState(() => _currentZoom = z);
  }

  Future<void> _animateToSpot(Spot spot) async {
    await _animateToPoint(LatLng(spot.latitude, spot.longitude));
  }

  Future<void> _animateToPoint(LatLng target) async {
    if (!_isValidMapPoint(target)) return;
    final flightSerial = ++_cameraFlightSerial;
    _cameraFlightController.stop();
    _cameraFlightPlan = null;

    late final MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      return;
    }
    final start = camera.center;
    final startZoom = camera.zoom;
    if (!_isValidMapPoint(start) || !startZoom.isFinite) return;

    final targetZoom = (startZoom < _maxZoom ? _maxZoom : startZoom)
        .clamp(3.0, _maxZoom)
        .toDouble();
    final distanceKm = _distance.as(LengthUnit.Kilometer, start, target);
    final plan = MapFlightPlan.adaptive(
      start: start,
      target: target,
      startZoom: startZoom,
      targetZoom: targetZoom,
      distanceKm: distanceKm,
    );
    _cameraFlightPlan = plan;
    _lastCameraFlightFrame = Duration.zero;
    _cameraFlightController.duration = plan.duration;

    try {
      await _cameraFlightController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }

    if (mounted && flightSerial == _cameraFlightSerial) {
      setState(() => _currentZoom = targetZoom);
      _cameraFlightPlan = null;
    }
  }

  void _applyCameraFlightFrame() {
    final plan = _cameraFlightPlan;
    if (plan == null || !mounted) return;

    final elapsed =
        _cameraFlightController.lastElapsedDuration ?? Duration.zero;
    final isFinalFrame = _cameraFlightController.value >= 1;
    if (!isFinalFrame &&
        elapsed - _lastCameraFlightFrame < MapFlightPlan.frameInterval) {
      return;
    }
    _lastCameraFlightFrame = elapsed;

    try {
      _mapController.move(
        plan.centerAt(_cameraFlightController.value),
        plan.zoomAt(_cameraFlightController.value),
      );
    } catch (_) {
      _cancelCameraFlight();
    }
  }

  void _cancelCameraFlight() {
    _cameraFlightSerial++;
    _cameraFlightController.stop();
    _cameraFlightPlan = null;
  }

  Future<void> _selectSpot(Spot spot) async {
    setState(() {
      _selectedSpot = spot;
      _selectedUserSpot = null;
      _pendingPersonalSpot = null;
      _searchQuery = '';
      _isFishBarVisible = false;
      _showToolsPanel = false;
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
    // Active le vent pour le spot selectionne
    context.read<WindAnimationProvider>().enableNearest(
          spot.latitude,
          spot.longitude,
        );
    await _animateToSpot(spot);
  }

  Future<void> _selectUserSpot(UserSpot spot) async {
    if (!spot.latitude.isFinite || !spot.longitude.isFinite) return;
    context.read<WindAnimationProvider>().disable();
    setState(() {
      _selectedUserSpot = spot;
      _selectedSpot = null;
      _pendingPersonalSpot = null;
      _searchQuery = '';
      _isFishBarVisible = false;
      _showToolsPanel = false;
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
    await _animateToPoint(LatLng(spot.latitude, spot.longitude));
  }

  void _clearSelection() {
    final selectedSpot = _selectedSpot;
    if (selectedSpot == null) return;

    // La fermeture d'un spot désactive toujours son vent, même si ses
    // coordonnées ne permettent exceptionnellement pas de recalculer le zoom.
    context.read<WindAnimationProvider>().disable();
    setState(() => _selectedSpot = null);

    final center = LatLng(selectedSpot.latitude, selectedSpot.longitude);
    if (!center.latitude.isFinite || !center.longitude.isFinite) return;

    final zoom = (math.log(40075016.686 *
                math.cos(center.latitude * math.pi / 180) /
                (256 * (20000 / 256))) /
            math.ln2)
        .clamp(3.0, _maxZoom);
    if (!zoom.isFinite) return;

    _zoomTo(zoom);
  }

  void _startAddingSpot() {
    if (!mounted) return;
    if (_selectedSpot != null) {
      context.read<WindAnimationProvider>().disable();
    }
    setState(() {
      _isAddingSpot = true;
      _pendingPersonalSpot = null;
      _showToolsPanel = false;
      _isFishBarVisible = false;
      _selectedSpot = null;
      _selectedUserSpot = null;
      _isMeasuring = false;
      _measurePoints.clear();
      _measuredDistanceKm = 0;
      _searchQuery = '';
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  void _onMapLongPress(TapPosition _, LatLng point) {
    if (!mounted || _isMeasuring || !_isValidMapPoint(point)) return;
    if (_selectedSpot != null) {
      context.read<WindAnimationProvider>().disable();
    }
    _ignoreNextCanvasTap = true;
    setState(() {
      _pendingPersonalSpot = point;
      _isAddingSpot = false;
      _selectedSpot = null;
      _selectedUserSpot = null;
      _showToolsPanel = false;
      _isFishBarVisible = false;
      _searchQuery = '';
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  void _onCanvasSpotTap(Spot spot) {
    if (_ignoreNextCanvasTap) {
      _ignoreNextCanvasTap = false;
      return;
    }
    if (_pendingPersonalSpot != null) {
      setState(() => _pendingPersonalSpot = null);
      return;
    }
    if (_selectedUserSpot != null) {
      setState(() => _selectedUserSpot = null);
      return;
    }
    unawaited(_selectSpot(spot));
  }

  Future<void> _confirmNewSpotLocation(LatLng point) async {
    if (!mounted || _pendingPersonalSpot != point) return;
    setState(() => _pendingPersonalSpot = null);

    final auth = context.read<AuthService>();
    if (auth.uid == null) {
      final shouldSignIn = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.tr('mySpots.signInTitle')),
              content: Text(context.tr('mySpots.signInSubtitle')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.tr('common.cancel')),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(context.tr('settings.signInGoogle')),
                ),
              ],
            ),
          ) ??
          false;
      if (!shouldSignIn || !mounted) return;
      final signedIn = await auth.signInWithGoogle();
      if (!mounted) return;
      if (!signedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.signInError'))),
        );
        return;
      }
    }

    for (final spot in _spots) {
      final meters = _distance.as(
        LengthUnit.Meter,
        point,
        LatLng(spot.latitude, spot.longitude),
      );
      if (meters <= UserSpot.duplicateRadiusMeters) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.duplicateOfficial'))),
        );
        return;
      }
    }

    final created = await showUserSpotFormSheet(
      context: context,
      latitude: point.latitude,
      longitude: point.longitude,
      onSubmit: (draft) async {
        await UserSpotService.instance.createSpot(
          latitude: point.latitude,
          longitude: point.longitude,
          draft: draft,
        );
      },
    );
    if (!created || !mounted) return;
    widget.onPersonalSpotCreated?.call();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.tr('mySpots.created')),
        duration: const Duration(seconds: 3),
        persist: false,
        action: widget.onOpenMySpots == null
            ? null
            : SnackBarAction(
                label: context.tr('mySpots.openMine'),
                onPressed: widget.onOpenMySpots!,
              ),
      ),
    );
  }

  void _onMapTap(TapPosition tp, LatLng point) {
    if (!_isValidMapPoint(point)) return;
    if (_ignoreNextCanvasTap) {
      _ignoreNextCanvasTap = false;
      return;
    }
    if (_pendingPersonalSpot != null) {
      setState(() => _pendingPersonalSpot = null);
      return;
    }
    if (_isAddingSpot) {
      return;
    }
    final fp = FishProvider.instance;
    if (fp.isFishModalVisible) {
      fp.closeFishModal();
    }
    // Si overlays ouverts (hors recherche seule), les fermer
    if (_selectedSpot != null ||
        _selectedUserSpot != null ||
        _isFishBarVisible ||
        _showToolsPanel) {
      // Desactive le vent quand on ferme le spot
      if (_selectedSpot != null) {
        context.read<WindAnimationProvider>().disable();
      }
      setState(() {
        _selectedSpot = null;
        _selectedUserSpot = null;
        _isFishBarVisible = false;
        _showToolsPanel = false;
        _searchQuery = '';
      });
      _searchController.clear();
      FocusScope.of(context).unfocus();
      return;
    }
    // Si recherche active mais pas d'autre overlay → juste cacher le clavier, garder le texte
    if (_searchQuery.isNotEmpty) {
      FocusScope.of(context).unfocus();
      return;
    }
    if (_isMeasuring) {
      setState(() {
        _measurePoints.add(point);
        _recalcMeasure();
      });
    }
  }

  void _recalcMeasure() {
    if (_measurePoints.length < 2) {
      _measuredDistanceKm = 0.0;
      return;
    }
    double total = 0.0;
    for (int i = 1; i < _measurePoints.length; i++) {
      total += _distance.as(
          LengthUnit.Kilometer, _measurePoints[i - 1], _measurePoints[i]);
    }
    _measuredDistanceKm = total;
  }

  void _stopMeasuring() {
    if (!mounted || !_isMeasuring) return;
    setState(() {
      _isMeasuring = false;
      _measurePoints.clear();
      _measuredDistanceKm = 0.0;
    });
  }

  final MarkerCacheManager _markerCacheManager = MarkerCacheManager();

  bool _isValidMapPoint(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;

  void _onPositionChanged(MapCamera camera, bool gesture) {
    if (gesture) _cancelCameraFlight();
    final nb = camera.visibleBounds;
    var nz = camera.zoom;
    if (!nz.isFinite) return;
    if (nb.north.isNaN ||
        nb.south.isNaN ||
        nb.east.isNaN ||
        nb.west.isNaN ||
        !nb.north.isFinite ||
        !nb.south.isFinite ||
        !nb.east.isFinite ||
        !nb.west.isFinite) {
      return;
    }
    if (nz > _maxZoom) {
      nz = _maxZoom;
      _mapController.move(camera.center, nz);
    }

    _pendingBounds = nb;
    _pendingZoom = nz;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 80), () {
      final pendingBounds = _pendingBounds;
      final pendingZoom = _pendingZoom;
      _pendingBounds = null;
      _pendingZoom = null;

      if (!mounted || pendingBounds == null || pendingZoom == null) return;
      if (pendingZoom == _currentZoom && pendingBounds == _lastBounds) return;

      setState(() {
        _currentZoom = pendingZoom;
        _applyBoundsFilter(pendingBounds);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        final hasSel = _selectedSpot != null;

        return Scaffold(
            body: Stack(children: [
          if (_isLoadingSpots)
            Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: tc.oceanLight),
              const SizedBox(height: 12),
              Text('Chargement des spots...',
                  style: TextStyle(color: tc.textSecondary)),
            ])),
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(30.5, -9.7),
              initialZoom: 6,
              maxZoom: _maxZoom,
              minZoom: 3.0,
              interactionOptions: const InteractionOptions(
                // Pinch zoom is essential. Pinch-move and rotation remain
                // disabled so two fingers only change the finite, clamped zoom.
                flags: InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.doubleTapDragZoom,
              ),
              onPositionChanged: _onPositionChanged,
              onLongPress: _onMapLongPress,
              onMapReady: () {
                final region = OfflineMapService.instance.activeRegion;
                if (_mapStyle == MapStyle.offline && region != null) {
                  _showOfflineRegion(region);
                }
              },
            ),
            children: [
              AppTileLayer(style: _mapStyle),
              AppMapAttribution(style: _mapStyle),
              if (_currentPosition != null)
                FiniteMarkerLayer(markers: [
                  Marker(
                      width: 20,
                      height: 20,
                      point: LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                      child: Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withValues(alpha: 0.9),
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.45),
                                blurRadius: 10)
                          ])))
                ]),
              SpotsCanvasLayer(
                visibleSpots: _visibleSpots,
                mapController: _mapController,
                selectedSpot: _selectedSpot,
                onSpotTap: _onCanvasSpotTap,
                onMapTap: (ll) =>
                    _onMapTap(const TapPosition(Offset.zero, Offset.zero), ll),
              ),
              PersonalSpotsMapLayer(
                selectedSpotId: _selectedUserSpot?.id,
                onSpotTap: (spot) => unawaited(_selectUserSpot(spot)),
              ),
              if (_selectedUserSpot != null)
                FiniteMarkerLayer(
                  markers: [
                    Marker(
                      width: 172,
                      height: 86,
                      point: LatLng(
                        _selectedUserSpot!.latitude,
                        _selectedUserSpot!.longitude,
                      ),
                      alignment: Alignment.topCenter,
                      child: PersonalSpotMapMarker(
                        spot: _selectedUserSpot!,
                        selected: true,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              // 🌬️ Couche de particules de vent animees (30fps)
              // IgnorePointer pour ne pas bloquer les taps sur la carte
              ListenableBuilder(
                listenable: FishProvider.instance,
                child: IgnorePointer(
                  child: Consumer<WindAnimationProvider>(
                    builder: (ctx, wind, _) => WindParticleLayer(
                      provider: wind,
                      mapController: _mapController,
                    ),
                  ),
                ),
                builder: (context, child) => TickerMode(
                  enabled: !FishProvider.instance.isFishModalVisible,
                  child: child!,
                ),
              ),
              if (_selectedSpot != null)
                FiniteMarkerLayer(markers: [
                  Marker(
                      width: 52,
                      height: 56,
                      point: LatLng(
                          _selectedSpot!.latitude, _selectedSpot!.longitude),
                      child: _markerCacheManager.getOrCreateMarker(
                          _selectedSpot!, true, _isPremium))
                ]),
              if (_pendingPersonalSpot != null)
                FiniteMarkerLayer(
                  markers: [
                    Marker(
                      width: 210,
                      height: 96,
                      point: _pendingPersonalSpot!,
                      // In flutter_map, topCenter places the whole marker
                      // above its geographic point. The pin tip at the bottom
                      // therefore lands exactly on the long-pressed location.
                      alignment: Alignment.topCenter,
                      child: _buildPendingPersonalSpotMarker(
                        _pendingPersonalSpot!,
                      ),
                    ),
                  ],
                ),
              if (_isMeasuring && _measurePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                      points: _measurePoints,
                      color: Colors.redAccent,
                      strokeWidth: 4.0)
                ]),
              if (_isMeasuring && _measurePoints.isNotEmpty)
                FiniteMarkerLayer(
                    markers: _measurePoints
                        .map((p) => Marker(
                            width: 14,
                            height: 14,
                            point: p,
                            child: Container(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                        color: Colors.redAccent, width: 2)))))
                        .toList()),
            ],
          ),
          if (_showToolsPanel) _buildToolsPanel(),
          if (_isAddingSpot) _buildAddSpotModeBanner(),
          if (_isLoadingSpots) const SizedBox.shrink(),
          Positioned(
              bottom: 96 + 16 + 8,
              left: 0,
              right: 0,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Consumer<FishProvider>(builder: (ctx, fp, _) {
                    if (fp.isFishModalVisible) {
                      return const SizedBox.shrink();
                    }
                    if (!_isFishBarVisible) {
                      return const SizedBox.shrink();
                    }
                    final df = fp.allFish;
                    if (df.isEmpty) return const SizedBox.shrink();
                    return _FishVerticalMenu(
                        fishes: df,
                        selectedFish: fp.selectedFish,
                        onFishSelected: (f) {
                          if (_isFishBarVisible) {
                            setState(() => _isFishBarVisible = false);
                          }
                          unawaited(fp.selectFish(
                            f,
                            _spots,
                            _currentPosition,
                          ));
                        },
                        onFishDeselected: fp.deselectFish);
                  }))),
          Positioned(
              bottom: 16,
              left: 16,
              width: _mapBottomControlHeight,
              height: _mapBottomControlHeight,
              child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: _buildFishFilterButton())),
          if (!hasSel && _selectedUserSpot == null)
            ListenableBuilder(
                listenable: LanguageController.instance,
                builder: (ctx, _) {
                  return Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Center(
                          child: SizedBox(
                              width: MediaQuery.of(ctx).size.width * 0.45,
                              child: _SearchBar(
                                  controller: _searchController,
                                  results: _searchResults,
                                  onTap: () {
                                    if (_isFishBarVisible) {
                                      setState(() => _isFishBarVisible = false);
                                    }
                                  },
                                  onChanged: (q) => setState(() {
                                        _searchQuery = q.trim().toLowerCase();
                                        _selectedSpot = null;
                                        _selectedUserSpot = null;
                                        _isFishBarVisible = false;
                                      }),
                                  onClear: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedSpot = null;
                                      _selectedUserSpot = null;
                                    });
                                    FocusScope.of(context).unfocus();
                                  },
                                  onSelect: _selectSpot,
                                  distanceText: _distanceText,
                                  measurementText: _isMeasuring
                                      ? _formattedMeasuredDistance
                                      : null,
                                  onStopMeasurement: _stopMeasuring))));
                }),
          if (_isCompassEnabled)
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _CompassRibbon(
                    magneticHeading: _magneticHeading,
                    gpsCourseOverGround: _gpsCourseOverGround)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            bottom: 100,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildZoomIn(),
                  const SizedBox(height: 8),
                  _buildZoomOut(),
                  const SizedBox(height: 8),
                  _buildMyLocationButton(),
                  const SizedBox(height: 8),
                  ZoomButton(
                    heroTag: 'compass_toggle',
                    icon: _isCompassEnabled ? Icons.explore : Icons.explore_off,
                    onTap: _toggleCompass,
                  ),
                  const SizedBox(height: 8),
                  _buildToolsPanelToggleButton(),
                  const SizedBox(height: 8),
                  _buildWindToggleButton(),
                ],
              ),
            ),
          ),
          if (hasSel)
            ListenableBuilder(
                listenable: LanguageController.instance,
                builder: (ctx, _) {
                  final media = MediaQuery.of(ctx);
                  final isPortrait = media.orientation == Orientation.portrait;
                  final panelHeight =
                      (media.size.height * (isPortrait ? 0.28 : 0.49))
                          .clamp(
                            isPortrait ? 210.0 : 190.0,
                            isPortrait ? 240.0 : 220.0,
                          )
                          .toDouble();
                  return Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                          width: MediaQuery.of(ctx).size.width * 0.92,
                          height: panelHeight,
                          child: SpotDetailsPanel(
                              spot: _selectedSpot!,
                              distanceText: _distanceText(_selectedSpot!),
                              isPremium: _isPremium,
                              onClose: _clearSelection,
                              onPremiumTap: () {},
                              currentPosition: _currentPosition != null
                                  ? LatLng(_currentPosition!.latitude,
                                      _currentPosition!.longitude)
                                  : null,
                              allSpots: _spots,
                              onSpotSelected: _selectSpot)));
                }),
          ListenableBuilder(
              listenable: LanguageController.instance,
              builder: (ctx, _) {
                return Consumer<FishProvider>(builder: (ctx, fp, __) {
                  if (!fp.isFishModalVisible || fp.selectedFish == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                      child: GestureDetector(
                          onTap: fp.closeFishModal,
                          child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                  child: TweenAnimationBuilder<double>(
                                      duration:
                                          const Duration(milliseconds: 350),
                                      curve: Curves.easeOutBack,
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (ctx, v, c) => Opacity(
                                          opacity: v.clamp(0.0, 1.0),
                                          child: Transform.scale(
                                              scale: 0.8 + 0.2 * v, child: c)),
                                      child: GestureDetector(
                                          onTap: () {},
                                          child: RepaintBoundary(
                                              child: FishIntelligenceModal(
                                                  fish: fp.selectedFish!,
                                                  nearbySpots: fp.nearbySpots,
                                                  isLoadingNearby:
                                                      fp.isLoadingNearby,
                                                  distanceText: _distanceText,
                                                  onSpotSelected: (s) {
                                                    fp.closeFishModal();
                                                    _selectSpot(s);
                                                  },
                                                  onClose: fp.closeFishModal,
                                                  currentPosition:
                                                      _currentPosition))))))));
                });
              }),
        ]));
      },
    );
  }

  Widget _buildToolsPanel() {
    final tc = ThemeColors.of(context);
    return Positioned(
        bottom: 170,
        right: 80,
        child: Container(
            width: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tc.glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: tc.shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('map.tools'),
                      style: TextStyle(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Divider(height: 16),
                  _toolItem(
                    icon: Icons.add_location_alt_rounded,
                    label: context.tr('mySpots.addTitle'),
                    color: tc.oceanMedium,
                    onTap: _startAddingSpot,
                  ),
                  const SizedBox(height: 10),
                  _toolItem(
                      key: const ValueKey<String>('map-measurement-toggle'),
                      icon: _isMeasuring ? Icons.stop : Icons.straighten,
                      label: _isMeasuring
                          ? context.tr('map.stopMeasure')
                          : context.tr('map.measureDistance'),
                      color: _isMeasuring ? AppColors.gold : tc.textPrimary,
                      onTap: () {
                        if (_isMeasuring) {
                          _stopMeasuring();
                        } else {
                          setState(() {
                            _isMeasuring = true;
                            _showToolsPanel = false;
                          });
                        }
                      }),
                  if (_isMeasuring && _measurePoints.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_formattedMeasuredDistance,
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Text('Fond de carte',
                      style: TextStyle(
                          color: tc.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _toolItem(
                      icon: Icons.map,
                      label: 'Standard',
                      color: _mapStyle == MapStyle.standard
                          ? tc.oceanMedium
                          : tc.textPrimary,
                      onTap: () =>
                          setState(() => _mapStyle = MapStyle.standard)),
                  const SizedBox(height: 6),
                  _toolItem(
                      icon: Icons.satellite,
                      label: 'Satellite',
                      color: _mapStyle == MapStyle.satellite
                          ? tc.oceanMedium
                          : tc.textPrimary,
                      onTap: () =>
                          setState(() => _mapStyle = MapStyle.satellite)),
                  const SizedBox(height: 6),
                  _toolItem(
                      icon: Icons.dark_mode,
                      label: 'Sombre',
                      color: _mapStyle == MapStyle.dark
                          ? tc.oceanMedium
                          : tc.textPrimary,
                      onTap: () => setState(() => _mapStyle = MapStyle.dark)),
                  const SizedBox(height: 6),
                  _toolItem(
                      icon: Icons.map_outlined,
                      label: context.tr('offlineMaps.offlineStyle'),
                      color: _mapStyle == MapStyle.offline
                          ? tc.oceanMedium
                          : tc.textPrimary,
                      onTap: () {
                        final service = OfflineMapService.instance;
                        if (service.hasActiveMap) {
                          final region = service.activeRegion;
                          if (region == null) {
                            setState(() => _mapStyle = MapStyle.offline);
                          } else {
                            _showOfflineRegion(region);
                          }
                        } else {
                          unawaited(_openOfflineMaps());
                        }
                      }),
                  const SizedBox(height: 6),
                  _toolItem(
                      icon: Icons.download_for_offline,
                      label: context.tr('offlineMaps.manage'),
                      color: tc.textPrimary,
                      onTap: () => unawaited(_openOfflineMaps())),
                ])));
  }

  Widget _buildAddSpotModeBanner() {
    final tc = ThemeColors.of(context);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + (_isCompassEnabled ? 92 : 12),
      left: 14,
      right: 76,
      child: Material(
        color: tc.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        elevation: 7,
        shadowColor: tc.shadowColor,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: tc.oceanMedium.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tc.oceanMedium.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  color: tc.oceanMedium,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr('mySpots.tapLocation'),
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('common.cancel'),
                onPressed: () => setState(() => _isAddingSpot = false),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPersonalSpotMarker(LatLng point) {
    final tc = ThemeColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          color: tc.surface.withValues(alpha: 0.98),
          elevation: 8,
          shadowColor: tc.shadowColor,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            key: const ValueKey<String>('confirm-personal-spot'),
            borderRadius: BorderRadius.circular(9),
            onTap: () => unawaited(_confirmNewSpotLocation(point)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: tc.oceanMedium.withValues(alpha: 0.65),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_location_alt_rounded,
                    color: tc.oceanMedium,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      context.tr('mySpots.addToMine'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Icon(
          Icons.location_on_rounded,
          color: tc.oceanMedium,
          size: 34,
          shadows: [
            Shadow(
              color: tc.shadowColor.withValues(alpha: 0.45),
              blurRadius: 5,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openOfflineMaps() async {
    await showOfflineMapManager(
      context,
      onActivated: _showOfflineRegion,
    );
    if (!mounted) return;
    if (_mapStyle == MapStyle.offline &&
        !OfflineMapService.instance.hasActiveMap) {
      setState(() => _mapStyle = MapStyle.satellite);
    }
  }

  void _showOfflineRegion(OfflineMapRegion region) {
    if (!mounted) return;
    setState(() => _mapStyle = MapStyle.offline);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bounds = region.bounds;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(bounds.minLatitude, bounds.minLongitude),
            LatLng(bounds.maxLatitude, bounds.maxLongitude),
          ),
          padding: const EdgeInsets.fromLTRB(28, 120, 28, 180),
          maxZoom: 10,
        ),
      );
    });
  }

  Widget _toolItem(
      {Key? key,
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
        key: key,
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w500)))
        ]));
  }

  Widget _buildFishFilterButton() {
    return GestureDetector(
        key: const ValueKey<String>('map-fish-filter-button'),
        onTap: () => setState(() {
              _isFishBarVisible = !_isFishBarVisible;
              _searchQuery = '';
            }),
        child: SizedBox(
            width: _mapBottomControlHeight,
            height: _mapBottomControlHeight,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/fish_route_button.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                        child: Text('🐟', style: TextStyle(fontSize: 48)))))));
  }

  Widget _buildMyLocationButton() {
    final tc = ThemeColors.of(context);
    return GestureDetector(
        onTap: () async {
          if (_currentPosition == null) {
            await _initLocation();
            if (_currentPosition != null && _positionSubscription == null) {
              _initPositionStream();
            }
            return;
          }
          if (_positionSubscription == null) _initPositionStream();
          final pos =
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
          if (!pos.latitude.isFinite || !pos.longitude.isFinite) return;
          final z = (_currentZoom + 2).clamp(3.0, _maxZoom);
          if (!z.isFinite) return;
          _cancelCameraFlight();
          _mapController.move(pos, z);
          if (mounted) setState(() {});
        },
        child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tc.glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: tc.shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: Center(
                child:
                    Icon(Icons.my_location, color: tc.oceanMedium, size: 24))));
  }

  Widget _buildToolsPanelToggleButton() {
    return ZoomButton(
        key: const ValueKey<String>('map-tools-toggle'),
        heroTag: 'tpt',
        icon: _showToolsPanel ? Icons.close : Icons.layers,
        onTap: () {
          final shouldOpen = !_showToolsPanel;
          if (shouldOpen) {
            _clearSelection();
          }
          if (!mounted) return;
          setState(() {
            _showToolsPanel = shouldOpen;
            if (shouldOpen) {
              _selectedUserSpot = null;
              _isFishBarVisible = false;
            }
          });
        });
  }

  Widget _buildZoomIn() {
    return ZoomButton(
        heroTag: 'zi', icon: Icons.add, onTap: () => _zoomTo(_currentZoom + 1));
  }

  Widget _buildZoomOut() {
    return ZoomButton(
        heroTag: 'zo',
        icon: Icons.remove,
        onTap: () => _zoomTo(_currentZoom - 1));
  }

  Widget _buildWindToggleButton() {
    final tc = ThemeColors.of(context);
    final wind = context.watch<WindAnimationProvider>();
    final isOn = wind.isEnabled;
    return GestureDetector(
      onTap: () {
        // Utiliser la position GPS si dispo, sinon le centre de la carte
        final lat =
            _currentPosition?.latitude ?? _mapController.camera.center.latitude;
        final lon = _currentPosition?.longitude ??
            _mapController.camera.center.longitude;
        wind.toggleNearest(lat, lon);
        if (mounted) setState(() {});
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isOn
              ? tc.oceanMedium.withValues(alpha: 0.9)
              : tc.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOn ? tc.oceanMedium : tc.glassBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: tc.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.air,
            color: isOn ? Colors.white : tc.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  COMPASS RIBBON
// ═══════════════════════════════════════════════════════════════

class _CompassRibbon extends StatelessWidget {
  final double? magneticHeading, gpsCourseOverGround;
  const _CompassRibbon({
    required this.magneticHeading,
    required this.gpsCourseOverGround,
  });

  @override
  Widget build(BuildContext context) {
    final readings = CompassReadings(
      magneticHeadingDegrees: magneticHeading,
      gpsCourseOverGroundDegrees: gpsCourseOverGround,
    );
    final head = readings.magneticHeadingDegrees ?? 0;
    final topInset = MediaQuery.paddingOf(context).top;
    const radius = BorderRadius.only(
      bottomLeft: Radius.circular(20),
      bottomRight: Radius.circular(20),
    );

    return Semantics(
      container: true,
      label:
          'Boussole, cap ${_valueText(readings.magneticHeadingDegrees)}, route suivie ${_valueText(readings.gpsCourseOverGroundDegrees)}',
      child: RepaintBoundary(
        child: Container(
          key: const ValueKey<String>('map-active-compass-ribbon'),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.fromLTRB(16, topInset + 5, 16, 8),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xB821252B),
                      Color(0xD10A0C0F),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white24,
                    width: 0.75,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 39,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _CompassScalePainter(heading: head),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final metric in readings.displayValues)
                          Expanded(
                            child: _CompassValue(
                              key: ValueKey<String>(
                                'map-compass-${metric.kind.name}',
                              ),
                              label: metric.label,
                              value: _valueText(metric.degrees),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _valueText(double? value) =>
      value == null ? '--' : '${value.round()}° ${_gd(value)}';

  String _gd(double d) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((((d < 0 ? d + 360 : d) + 22.5) % 360) ~/ 45).clamp(0, 7)];
  }
}

class _CompassValue extends StatelessWidget {
  const _CompassValue({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFCDD3D8),
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF7F8F9),
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompassScalePainter extends CustomPainter {
  const _CompassScalePainter({required this.heading});

  final double heading;

  static const _labelStyle = TextStyle(
    color: Color(0xFFF1F3F5),
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w600,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final pixelsPerDegree = size.width / 270;
    final visibleDegrees = size.width / pixelsPerDegree / 2;
    final normalizedHeading = ((heading % 360) + 360) % 360;
    final firstTick = ((normalizedHeading - visibleDegrees) / 5).floor() * 5;
    final lastTick = normalizedHeading + visibleDegrees;
    final tickPaint = Paint()
      ..color = const Color(0xFFD9DEE3)
      ..strokeCap = StrokeCap.square;

    for (var degree = firstTick; degree <= lastTick; degree += 5) {
      final x = size.width / 2 + (degree - normalizedHeading) * pixelsPerDegree;
      final normalizedDegree = ((degree % 360) + 360) % 360;
      final isDirection = normalizedDegree % 45 == 0;
      final isMedium = normalizedDegree % 15 == 0;

      tickPaint.strokeWidth = isDirection ? 1.35 : 1;
      final tickTop = isDirection
          ? 24.0
          : isMedium
              ? 27.0
              : 29.0;
      canvas.drawLine(
        Offset(x, tickTop),
        Offset(x, 34),
        tickPaint,
      );

      if (isDirection) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: _directionLabel(normalizedDegree),
            style: _labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(x - labelPainter.width / 2, 2),
        );
      }
    }

    final markerPaint = Paint()..color = const Color(0xFFFF4D47);
    final marker = ui.Path()
      ..moveTo(size.width / 2, 24)
      ..lineTo(size.width / 2 - 4.5, 34)
      ..lineTo(size.width / 2 + 4.5, 34)
      ..close();
    canvas.drawPath(marker, markerPaint);
  }

  static String _directionLabel(int degree) {
    switch (degree) {
      case 0:
        return 'N';
      case 45:
        return 'NE';
      case 90:
        return 'E';
      case 135:
        return 'SE';
      case 180:
        return 'S';
      case 225:
        return 'SW';
      case 270:
        return 'W';
      case 315:
        return 'NW';
      default:
        return '';
    }
  }

  @override
  bool shouldRepaint(covariant _CompassScalePainter oldDelegate) =>
      oldDelegate.heading != heading;
}
