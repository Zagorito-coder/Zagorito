// ============================================================
//  main.dart — Spots App OPTIMISÉE POUR 6200 SPOTS
//  Version ultra-fluide avec cache et rendu optimisé
// ============================================================

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, SystemChrome, SystemUiMode, SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/fish_model.dart';
import 'package:spots_app/spot_details_panel.dart';
import 'package:spots_app/spots_canvas_layer.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/widgets/fish_intelligence_modal.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  runApp(const SpotsApp());
}

// ─────────────────────────────────────────────────────────────
//  APP ROOT
// ─────────────────────────────────────────────────────────────

class SpotsApp extends StatelessWidget {
  const SpotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, child) {
        final isDark = ThemeController.instance.isDark;

        // Configuration de la barre de statut adaptative
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: ThemeColors.of(context).background,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => FishProvider()..loadFishData()),
            ChangeNotifierProvider(create: (_) => PremiumProvider()),
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
            home: AppShell(key: appShellKey),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SERVICE — CSV + JSON cache
// ─────────────────────────────────────────────────────────────

class SpotService {
  SpotService._();

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/spots_cache_v4.json');
  }

  /// Exécute [computation] via [compute] sur mobile/desktop,
  /// ou directement sur le thread principal pour le web (isolates non supportés).
  static Future<R> _computeOrRun<Q, R>(
    R Function(Q) computation,
    Q message,
  ) async {
    if (kIsWeb) {
      return computation(message);
    }
    return compute(computation, message);
  }

  static Future<List<Spot>> loadFromCache() async {
    try {
      final file = await _cacheFile;
      if (!file.existsSync()) return [];
      return await _computeOrRun(_parseJson, await file.readAsString());
    } catch (e) {
      debugPrint('[SpotService] Erreur cache lecture: $e');
      return [];
    }
  }

  static List<Spot> _parseJson(String contents) {
    final list = jsonDecode(contents) as List<dynamic>;
    return list.map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveToCache(List<Spot> spots) async {
    try {
      final file = await _cacheFile;
      final data = await _computeOrRun(_serializeJson, spots);
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('[SpotService] Erreur cache écriture: $e');
    }
  }

  static String _serializeJson(List<Spot> spots) {
    return jsonEncode(spots.map((s) => s.toJson()).toList());
  }

  static Future<List<Spot>> loadFromCsv() async {
    final raw = await rootBundle.loadString('assets/spots.csv');
    return await _computeOrRun(_parseCsv, raw);
  }

  static List<Spot> _parseCsv(String raw) {
    final lines = raw.split('\n');
    final spots = <Spot>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        spots.add(Spot.fromCsv(line, index: i));
      } catch (_) {
        debugPrint('[SpotService] Skipped malformed CSV line $i: $line');
      }
    }
    return spots;
  }
}

// ─────────────────────────────────────────────────────────────
//  WIDGETS — SpotMarker
// ─────────────────────────────────────────────────────────────

class _DropClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    final w = size.width;
    final h = size.height;
    // Goutte d'eau fluide : haut arrondi, pointe en bas
    path.moveTo(w * 0.5, 0);
    path.cubicTo(w * 0.05, h * 0.25, w * 0.05, h * 0.65, w * 0.5, h);
    path.cubicTo(w * 0.95, h * 0.65, w * 0.95, h * 0.25, w * 0.5, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) => false;
}

class SpotMarker extends StatelessWidget {
  final Spot spot;
  final bool isSelected;
  final bool isPremium;

  const SpotMarker({
    super.key,
    required this.spot,
    required this.isSelected,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = spot.type.color;
    final markerW = isSelected ? 42.0 : 32.0;
    final markerH = isSelected ? 54.0 : 42.0;
    final highlightColor = isPremium ? Colors.amberAccent : baseColor;

    return SizedBox(
      width: markerW,
      height: markerH + (isSelected ? 44 : 32),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Halo lumineux sous la goutte
          Positioned(
            bottom: 0,
            child: Container(
              width: markerW * 1.4,
              height: markerH * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlightColor.withValues(alpha: isSelected ? 0.15 : 0.08),
              ),
            ),
          ),
          // Marqueur goutte d'eau glassmorphique
          Positioned(
            bottom: 0,
            child: ClipPath(
              clipper: _DropClipper(),
              child: Container(
                width: markerW,
                height: markerH,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseColor.withValues(alpha: 0.95),
                      baseColor.withValues(alpha: 0.65),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.45),
                      blurRadius: isSelected ? 12 : 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.phishing,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: markerW * 0.42,
                  ),
                ),
              ),
            ),
          ),
          // Reflet highlight en haut de la goutte
          Positioned(
            bottom: markerH * 0.72,
            child: Container(
              width: markerW * 0.35,
              height: markerW * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(markerW * 0.09),
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: -40,
              child: SpotLabel(spot: spot, accent: highlightColor),
            ),
        ],
      ),
    );
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
        border: Border.all(color: accent.withValues(alpha: 0.95), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: tc.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.name,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  spot.type.label,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.92),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final List<Spot> results;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final void Function(Spot) onSelect;
  final String Function(Spot) distanceText;

  const _SearchBar({
    required this.controller,
    required this.results,
    required this.onChanged,
    required this.onClear,
    required this.onSelect,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Liste deroulante AU-DESSUS de la barre
        if (controller.text.isNotEmpty && results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tc.glassBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tc.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final spot = results[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tc.surfaceLight.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                              color: spot.type.color.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
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
                        style: TextStyle(
                          color: tc.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: tc.textMuted,
                        size: 16,
                      ),
                      onTap: () => onSelect(spot),
                    ),
                  );
                },
              ),
            ),
          ),
        // Barre de recherche en bas
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tc.glassBorder,
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
              child: TextField(
                controller: controller,
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: tc.surfaceLight.withValues(alpha: 0.8),
                  hintText: 'Rechercher un spot...',
                  hintStyle: TextStyle(
                    color: tc.textMuted,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: tc.textSecondary,
                    size: 22,
                  ),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            color: tc.textMuted,
                            size: 18,
                          ),
                          onPressed: onClear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: tc.oceanMedium,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: (_) {
                  if (results.isNotEmpty) onSelect(results.first);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ZoomButton extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final VoidCallback onTap;
  const ZoomButton({super.key, required this.heroTag, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tc.glassBorder,
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
                icon,
                color: tc.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UTILITIES — MarkerCacheManager
// ─────────────────────────────────────────────────────────────

/// Manages and caches SpotMarker widgets to optimize performance.
///
/// This helps prevent unnecessary rebuilds of markers when their properties
/// (like `isSelected` or `isPremium`) haven't changed, or when they are
/// simply moving on the map.
class MarkerCacheManager {
  final Map<String, SpotMarker> _cache = {};

  /// Retrieves a cached marker or creates a new one if not found or if properties change.
  SpotMarker getOrCreateMarker(Spot spot, bool isSelected, bool isPremium) {
    final key = '${spot.id}_${isSelected}_$isPremium';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final marker = SpotMarker(
      key: ValueKey(key), // Use ValueKey for efficient widget comparison
      spot: spot,
      isSelected: isSelected,
      isPremium: isPremium,
    );
    _cache[key] = marker;
    return marker;
  }

  /// Clears the cache. Useful when the underlying data changes significantly.
  void clear() {
    _cache.clear();
  }

  /// Removes a specific marker from the cache.
  void remove(String spotId, bool isSelected, bool isPremium) {
    final key = '${spotId}_${isSelected}_$isPremium';
    _cache.remove(key);
  }
}

// ─────────────────────────────────────────────────────────────
//  FISH VERTICAL MENU — colonne verticale alignée style Snapchat
//  Cercles empilés vers le haut sur le même axe X, texte à droite
// ─────────────────────────────────────────────────────────────

class _FishVerticalMenu extends StatelessWidget {
  final List<FishModel> fishes;
  final FishModel? selectedFish;
  final void Function(FishModel) onFishSelected;
  final VoidCallback onFishDeselected;

  const _FishVerticalMenu({
    required this.fishes,
    required this.selectedFish,
    required this.onFishSelected,
    required this.onFishDeselected,
  });

  static const double _circleSize = 53;
  static const double _rowSpacing = 72;

  @override
  Widget build(BuildContext context) {
    if (fishes.isEmpty) return const SizedBox.shrink();

    final all = fishes;

    return SizedBox(
      width: _circleSize + 120,
      height: 6 * _rowSpacing + 20, // fixé à 6 poissons visibles
      child: ListView.builder(
        reverse: true, // scroll vers le haut style Snapchat
        padding: EdgeInsets.zero,
        itemCount: all.length,
        itemBuilder: (context, index) {
          final fish = all[index];
          final isSelected = selectedFish?.id == fish.id;
          return _FishRow(
            fish: fish,
            isSelected: isSelected,
            onTap: () {
              if (isSelected) { onFishDeselected(); }
              else { onFishSelected(fish); }
            },
            circleSize: _circleSize,
          );
        },
      ),
    );
  }
}

class _FishRow extends StatelessWidget {
  final FishModel fish;
  final bool isSelected;
  final VoidCallback onTap;
  final double circleSize;

  const _FishRow({
    required this.fish,
    required this.isSelected,
    required this.onTap,
    required this.circleSize,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF48CAE4) : tc.surfaceLight,
                border: Border.all(
                  color: isSelected ? const Color(0xFF48CAE4) : tc.glassBorder,
                  width: 2,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFF48CAE4).withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
              child: ClipOval(child: _buildFishImage(context)),
            ),
            const SizedBox(width: 8),
            // Texte à droite avec fond semi-transparent
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fish.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tc.textPrimary, fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  Text(fish.scientificName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tc.textMuted, fontSize: 9, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFishImage(BuildContext context) {
    if (fish.imageUrl.startsWith('assets/')) {
      return Image.asset(fish.imageUrl, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder());
    }
    return CachedNetworkImage(imageUrl: fish.imageUrl, fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Container(color: const Color(0xFF1E6091),
    child: const Center(child: Text('🐟', style: TextStyle(fontSize: 20))));
}

// ─────────────────────────────────────────────────────────────
//  SCREEN — MapScreen (VERSION CORRIGÉE)
// ─────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Distance _distance = const Distance();
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 100);

  List<Spot> _spots = [];
  LatLngBounds? _lastBounds; // Added for visible spot calculation
  List<Spot> _visibleSpots = []; // Cache for visible spots
  String _searchQuery = '';
  Position? _currentPosition;
  Spot? _selectedSpot;
  double _currentZoom = 6.0;
  bool _isFishBarVisible = false;
  bool _showToolsPanel = false;
  bool _isMeasuring = false;
  final List<LatLng> _measurePoints = [];
  double _measuredDistanceKm = 0.0;
  String _mapStyle = 'osm';
  final bool _isPremium = false;
  double get _maxZoom => _isPremium ? 16.0 : 8.0;

  // Compass / heading
  double _heading = 0.0;
  double _courseOverGround = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  List<Spot> get _searchResults {
    final lower = _searchQuery.trim().toLowerCase();
    if (lower.isEmpty) return [];
    return _spots
        .where((s) => s.name.toLowerCase().contains(lower))
        .toList();
  }

  String _distanceText(Spot spot) {
    if (_currentPosition == null) return 'Distance inconnue';
    final km = _distance.as(
      LengthUnit.Kilometer,
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(spot.latitude, spot.longitude),
    );
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSpots();
    _initLocation();
    _initCompass();
    _initPositionStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(_updateVisibleSpots);
      }
    });
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      final h = event.heading;
      if (h != null) {
        setState(() => _heading = h);
      }
    });
  }

  void _initPositionStream() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!mounted) return;
      final cog = position.heading;
      if (!cog.isNaN && cog >= 0) {
        setState(() => _courseOverGround = cog);
      } else if (_lastPosition != null && position.speed > 0.5) {
        final bearing = Geolocator.bearingBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        setState(() => _courseOverGround = bearing);
      }
      _lastPosition = position;
      setState(() => _currentPosition = position);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _mapController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _updateVisibleSpots() {
    if (_spots.isEmpty) return;
    try {
      final bounds = _mapController.camera.visibleBounds;
      _applyBoundsFilter(bounds);
    } catch (_) {}
  }

  void _applyBoundsFilter(LatLngBounds bounds) {
    final s = bounds.south;
    final n = bounds.north;
    final w = bounds.west;
    final e = bounds.east;

    _visibleSpots = _spots.where((spot) =>
      spot.latitude >= s &&
      spot.latitude <= n &&
      spot.longitude >= w &&
      spot.longitude <= e).toList();
    // Met à jour _lastBounds pour refléter les limites pour lesquelles _visibleSpots a été filtré.
    _lastBounds = bounds; 
  }

  Future<void> _loadSpots() async {
    final cached = await SpotService.loadFromCache();
    if (cached.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _spots = cached;
        _visibleSpots = cached;
        _markerCacheManager.clear(); // Clear cache if data changes
      });
      return;
    }

    final fromCsv = await SpotService.loadFromCsv();
    if (!mounted) return;
    setState(() {
      _spots = fromCsv;
      _visibleSpots = fromCsv;
      _markerCacheManager.clear(); // Clear cache if data changes
    });
    
    await SpotService.saveToCache(fromCsv);
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _currentPosition = position);
  }

  void _zoomTo(double zoom) {
    final clamped = zoom.clamp(3.0, _maxZoom);
    _mapController.move(_mapController.camera.center, clamped);
    setState(() => _currentZoom = clamped);
  }

  Future<void> _animateToSpot(Spot spot) async {
    final target = LatLng(spot.latitude, spot.longitude);
    final targetZoom = (_currentZoom < _maxZoom ? _maxZoom : _currentZoom).clamp(3.0, _maxZoom);
    final startZoom = _currentZoom;
    const steps = 6;

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final zoom = (startZoom + (targetZoom - startZoom) * t).clamp(3.0, _maxZoom);
      _mapController.move(target, zoom);
      if (i < steps) await Future.delayed(const Duration(milliseconds: 40));
    }
    if (!mounted) return;
    setState(() => _currentZoom = targetZoom);
  }

  Future<void> _selectSpot(Spot spot) async {
    setState(() {
      _selectedSpot = spot;
      _searchQuery = '';
    });
    _searchController.clear();
    FocusScope.of(context).unfocus();
    await _animateToSpot(spot);
  }

  void _clearSelection() {
    if (_selectedSpot != null) {
      final center = LatLng(_selectedSpot!.latitude, _selectedSpot!.longitude);
      final targetZoom = _zoomForDistanceKm(20.0, center.latitude);
      setState(() {
        _selectedSpot = null;
      });
      _zoomTo(targetZoom);
    }
  }

  /// Calcule le niveau de zoom pour afficher [distanceKm] kilomètres
  /// à l'écran, centré sur [latitude].
  double _zoomForDistanceKm(double distanceKm, double latitude) {
    const earthCircumference = 40075016.686; // mètres à l'équateur
    const tileSize = 256.0; // pixels par tuile OSM
    final distanceM = distanceKm * 1000.0;
    final latRad = latitude * 3.141592653589793 / 180.0;
    final metersPerPixel = distanceM / tileSize;
    final zoom = math.log( earthCircumference * math.cos(latRad) / (tileSize * metersPerPixel) ) / math.ln2;
    return zoom.clamp(3.0, _maxZoom);
  }

  Widget _buildTileLayer() {
    switch (_mapStyle) {
      case 'satellite':
        return TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.spots_app',
        );
      case 'dark':
        return TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.spots_app',
        );
      case 'osm':
      default:
        return TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.spots_app',
        );
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // 1) Si une fenêtre/panneau est ouvert, un tap sur la carte la ferme sans autre action.
    bool hasOverlay = _selectedSpot != null ||
        _isFishBarVisible ||
        _showToolsPanel ||
        _searchQuery.isNotEmpty;

    final fishProvider = FishProvider.instance;
    if (fishProvider.isFishModalVisible) {
      fishProvider.closeFishModal();
      hasOverlay = true;
    }
    if (fishProvider.isFishBarVisible) {
      fishProvider.closeFishBar();
      hasOverlay = true;
    }

    if (hasOverlay) {
      setState(() {
        _selectedSpot = null;
        _isFishBarVisible = false;
        _showToolsPanel = false;
        _searchQuery = '';
      });
      _searchController.clear();
      FocusScope.of(context).unfocus();
      return;
    }

    // 2) Sinon comportement normal.
    if (_isMeasuring) {
      setState(() {
        _measurePoints.add(point);
        _recalcMeasure();
      });
      return;
    }
  }

  void _recalcMeasure() {
    if (_measurePoints.length < 2) {
      _measuredDistanceKm = 0.0;
      return;
    }
    double total = 0.0;
    for (int i = 1; i < _measurePoints.length; i++) {
      total += _distance.as(LengthUnit.Kilometer, _measurePoints[i - 1], _measurePoints[i]);
    }
    _measuredDistanceKm = total;
  }

  final MarkerCacheManager _markerCacheManager = MarkerCacheManager();

  void _showPremiumDialog() {
    if (!mounted) return;
    final tc = ThemeColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: tc.gold),
            const SizedBox(width: 8),
            Text('Fonctionnalité Premium', style: TextStyle(fontSize: 16, color: tc.textPrimary)),
          ],
        ),
        content: Text(
          'Passez Premium pour accéder à tous les détails : types de poissons, notes, zoom avancé, et plus encore.',
          style: TextStyle(color: tc.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Plus tard', style: TextStyle(color: tc.textSecondary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.star_rounded, size: 16, color: Colors.black),
            label: const Text("S'abonner"),
            style: ElevatedButton.styleFrom(
              backgroundColor: tc.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Abonnement Premium à venir...', style: TextStyle(color: tc.textPrimary))),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    _debounceTimer?.cancel();

    final newBounds = position.bounds;
    final newZoom = position.zoom ?? _currentZoom;

    if (newZoom == _currentZoom && newBounds == _lastBounds) return;
    if (newBounds == null) return;

    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() {
        _currentZoom = newZoom;
        _applyBoundsFilter(newBounds);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hasSelection = _selectedSpot != null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(30.5, -9.7),
              initialZoom: 6,
              maxZoom: _maxZoom,
              minZoom: 3.0,
              onPositionChanged: (camera, hasGesture) => _onPositionChanged(camera, hasGesture),
              onTap: _onMapTap,
            ),
            children: [
              _buildTileLayer(),

              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 20,
                      height: 20,
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withValues(alpha: 0.9),
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.45),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // High performance rendering for 6000+ points via Canvas
              SpotsCanvasLayer(
                visibleSpots: _visibleSpots,
                mapController: _mapController,
                selectedSpot: _selectedSpot,
                onSpotTap: _selectSpot,
                onMapTap: (latLng) => _onMapTap(const TapPosition(Offset.zero, Offset.zero), latLng),
              ),

              // Fancy marker only for the selected spot to maintain quality without sacrificing speed
              if (_selectedSpot != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 52,
                      height: 56,
                      point: LatLng(_selectedSpot!.latitude, _selectedSpot!.longitude),
                      child: _markerCacheManager.getOrCreateMarker(_selectedSpot!, true, _isPremium),
                    ),
                  ],
                ),

              // Outil de mesure : polyline + points
              if (_isMeasuring && _measurePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _measurePoints,
                      color: Colors.redAccent,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              if (_isMeasuring && _measurePoints.isNotEmpty)
                MarkerLayer(
                  markers: _measurePoints
                      .map((p) => Marker(
                            width: 14,
                            height: 14,
                            point: p,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.redAccent, width: 2),
                              ),
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),


          if (_showToolsPanel)
            _buildToolsPanel(),

          // ── FISH VERTICAL MENU : au-dessus du bouton poisson ──
          Positioned(
            bottom: 96 + 16 + 8, // 96 = taille poisson, 16 = marge bas, 8 = gap
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Consumer<FishProvider>(
                builder: (context, fishProvider, _) {
                  final displayFishes = fishProvider.allFish;
                  if (displayFishes.isEmpty) return const SizedBox.shrink();
                  return AnimatedSlide(
                    offset: _isFishBarVisible ? Offset.zero : const Offset(0, 2),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _isFishBarVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: _FishVerticalMenu(
                        fishes: displayFishes,
                        selectedFish: fishProvider.selectedFish,
                        onFishSelected: (fish) => fishProvider.selectFish(fish, _spots, _currentPosition),
                        onFishDeselected: fishProvider.deselectFish,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── FISH BUTTON fixe en bas à gauche (forcé LTR même en arabe) ──
          Positioned(
            bottom: 8,
            left: 8,
            width: 96,
            height: 96,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: _buildFishFilterButton(),
            ),
          ),

          // ── SEARCHBAR centrée en bas ──
          if (!hasSelection)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: _SearchBar(
                    controller: _searchController,
                    results: _searchResults,
                  onChanged: (query) => setState(() {
                    _searchQuery = query.trim().toLowerCase();
                    _selectedSpot = null;
                    _isFishBarVisible = false;
                  }),
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedSpot = null;
                      });
                      FocusScope.of(context).unfocus();
                    },
                    onSelect: _selectSpot,
                    distanceText: _distanceText,
                  ),
                ),
              ),
            ),

          // ── TOP COMPASS RIBBON ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _CompassRibbon(
                heading: _heading,
                courseOverGround: _courseOverGround,
              ),
            ),
          ),

          // ── RIGHT SIDE CONTROLS COLUMN ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            bottom: hasSelection ? MediaQuery.of(context).size.height * 0.34 + 20 : 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                ZoomButton(
                  heroTag: 'zoom_in',
                  icon: Icons.add,
                  onTap: () => _zoomTo(_currentZoom + 1),
                ),
                const SizedBox(height: 12),
                ZoomButton(
                  heroTag: 'zoom_out',
                  icon: Icons.remove,
                  onTap: () => _zoomTo(_currentZoom - 1),
                ),
                const SizedBox(height: 12),
                _buildMyLocationButton(),
                const SizedBox(height: 12),
                _buildToolsPanelToggleButton(),
              ],
            ),
          ),

          if (hasSelection)
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.92,
                height: MediaQuery.of(context).size.height * 0.33,
                child: SpotDetailsPanel(
                  spot: _selectedSpot!,
                  distanceText: _distanceText(_selectedSpot!),
                      isPremium: _isPremium,
                  onClose: _clearSelection,
                  onPremiumTap: _showPremiumDialog,
                  currentPosition: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : null,
                  allSpots: _spots,
                  onSpotSelected: _selectSpot,
                ),
              ),
            ),

          // ── FISH INTELLIGENCE MODAL ──
          Consumer<FishProvider>(
            builder: (context, fishProvider, _) {
              if (!fishProvider.isFishModalVisible || fishProvider.selectedFish == null) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: GestureDetector(
                  onTap: fishProvider.closeFishModal,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.8 + 0.2 * value,
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: () {},
                            child: FishIntelligenceModal(
                              fish: fishProvider.selectedFish!,
                              nearbySpots: fishProvider.nearbySpots,
                              isLoadingNearby: fishProvider.isLoadingNearby,
                              distanceText: _distanceText,
                            onSpotSelected: (spot) {
                              fishProvider.closeFishModal();
                              _selectSpot(spot);
                            },
                            onClose: fishProvider.closeFishModal,
                            currentPosition: _currentPosition,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolsPanelToggleButton() {
    return ZoomButton(
      heroTag: 'tools_panel_toggle',
      icon: _showToolsPanel ? Icons.close : Icons.layers,
      onTap: () => setState(() => _showToolsPanel = !_showToolsPanel),
    );
  }

  Widget _buildToolsPanel() {
    final tc = ThemeColors.of(context);
    return Positioned(
      bottom: 170,
      right: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(color: tc.shadowColor, blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outils carto',
                  style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Divider(height: 16),
                _toolItem(
                  icon: _isMeasuring ? Icons.stop : Icons.straighten,
                  label: _isMeasuring ? 'Arrêter mesure' : 'Mesurer distance',
                  color: _isMeasuring ? AppColors.gold : tc.textPrimary,
                  onTap: () {
                    setState(() {
                      _isMeasuring = !_isMeasuring;
                      if (!_isMeasuring) {
                        _measurePoints.clear();
                        _measuredDistanceKm = 0.0;
                      }
                    });
                  },
                ),
                if (_isMeasuring && _measurePoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_measuredDistanceKm.toStringAsFixed(2)} km',
                      style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Fond de carte',
                  style: TextStyle(color: tc.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _toolItem(
                  icon: Icons.map,
                  label: 'Standard',
                  color: _mapStyle == 'osm' ? tc.oceanMedium : tc.textPrimary,
                  onTap: () => setState(() => _mapStyle = 'osm'),
                ),
                const SizedBox(height: 6),
                _toolItem(
                  icon: Icons.satellite,
                  label: 'Satellite',
                  color: _mapStyle == 'satellite' ? tc.oceanMedium : tc.textPrimary,
                  onTap: () => setState(() => _mapStyle = 'satellite'),
                ),
                const SizedBox(height: 6),
                _toolItem(
                  icon: Icons.dark_mode,
                  label: 'Sombre',
                  color: _mapStyle == 'dark' ? tc.oceanMedium : tc.textPrimary,
                  onTap: () => setState(() => _mapStyle = 'dark'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildFishFilterButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _isFishBarVisible = !_isFishBarVisible;
        _searchQuery = '';
      }),
      child: SizedBox(
        width: 96,
        height: 96,
        child: ClipOval(
          child: Image.asset(
            'assets/images/blue_fish_button.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(child: Text('🐟', style: TextStyle(fontSize: 48))),
          ),
        ),
      ),
    );
  }


  Widget _buildMyLocationButton() {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: () async {
        if (_currentPosition == null) {
          await _initLocation();
          return;
        }
        final zoom = (_currentZoom + 2).clamp(3.0, _maxZoom);
        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom,
        );
        if (mounted) setState(() => _currentZoom = zoom);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.my_location,
                color: tc.oceanMedium,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _CompassRibbon extends StatelessWidget {
  final double heading;
  final double courseOverGround;

  const _CompassRibbon({
    required this.heading,
    required this.courseOverGround,
  });

  @override
  Widget build(BuildContext context) {
    final cog = courseOverGround.isNaN || courseOverGround == 0 ? 0.0 : courseOverGround;
    final head = heading.isNaN ? 0.0 : heading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // === ROSE DES VENTS ROTATIVE ===
                  SizedBox(
                    height: 38,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        const step = 45;
                        final children = <Widget>[];
                        for (int deg = 0; deg < 360; deg += step) {
                          var delta = (deg - head) % 360;
                          if (delta > 180) delta -= 360;
                          if (delta.abs() > 90) continue;
                          final x = width / 2 + (delta / 90.0) * (width / 2);
                          children.add(
                            Positioned(
                              left: x - 10,
                              child: SizedBox(
                                width: 20,
                                child: Text(
                                  _roseLabel(deg),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: deg % 90 == 0 ? Colors.black : Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Indicateur central
                            const Positioned(
                              top: 0,
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFFFF2D55),
                                size: 16,
                              ),
                            ),
                            ...children,
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // === LIGNE + GRADUATIONS + FLÈCHE ROUGE (Heading) ===
                  SizedBox(
                    height: 14,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        const step = 45;
                        final marks = <Widget>[];
                        for (int deg = 0; deg < 360; deg += step) {
                          var delta = (deg - head) % 360;
                          if (delta > 180) delta -= 360;
                          if (delta.abs() > 90) continue;
                          final x = width / 2 + (delta / 90.0) * (width / 2);
                          final isCardinal = deg % 90 == 0;
                          marks.add(
                            Positioned(
                              left: x - 1,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Container(
                                  width: isCardinal ? 3.5 : 2.5,
                                  height: isCardinal ? 22.0 : 14.0,
                                  decoration: BoxDecoration(
                                    color: isCardinal
                                        ? Colors.black.withValues(alpha: 0.65)
                                        : Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 2,
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            ...marks,
                            Transform.rotate(
                              angle: head * (math.pi / 180),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: const Color(0xFFFF2D55),
                                size: 34,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // === TEXTES EN BAS ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Heading
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Heading',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            head == 0 ? '--' : '${head.toInt()}° ${_getDirection(head)}',
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),

                      // Course Over Ground
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Course over ground',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            cog == 0 ? '--' : '${cog.toInt()}° ${_getDirection(cog)}',
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }

  String _getDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final d = degrees % 360;
    final index = (((d < 0 ? d + 360 : d) + 22.5) % 360) ~/ 45;
    return directions[index.clamp(0, 7)];
  }

  String _roseLabel(int degrees) {
    switch (degrees % 360) {
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
}


