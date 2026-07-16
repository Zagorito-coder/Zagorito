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
import 'package:flutter/services.dart' show rootBundle, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/spot_details_panel.dart';
import 'package:spots_app/spots_canvas_layer.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/l10n/app_localizations.dart';

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

        return MaterialApp(
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
      children: [
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
        if (controller.text.isNotEmpty && results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
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

  bool _isPremium = false;
  List<Spot> _spots = [];
  LatLngBounds? _lastBounds; // Added for visible spot calculation
  List<Spot> _visibleSpots = []; // Cache for visible spots
  String _searchQuery = '';
  Position? _currentPosition;
  Spot? _selectedSpot;
  double _currentZoom = 6.0;
  double get _maxZoom => _isPremium ? 16.0 : 8.0;

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
    _loadSpots();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(_updateVisibleSpots);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel(); // Annule le timer de debounce lors de la suppression du widget
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

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_selectedSpot != null) {
      setState(() {
        _selectedSpot = null;
      });
      // Dézoome de 10% pour voir les spots environnants
      _zoomTo(_currentZoom * 0.9);
    }
  }

  final MarkerCacheManager _markerCacheManager = MarkerCacheManager();

  Widget _buildPremiumBar() {
    final tc = ThemeColors.of(context);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isPremium
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : tc.glassBorder,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: tc.shadowColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isPremium
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : tc.surfaceLight.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    _isPremium ? Icons.workspace_premium : Icons.bolt,
                    color: _isPremium ? AppColors.gold : tc.textSecondary,
                    size: 11,
                  ),
                ),
                const SizedBox(width: 5),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: _isPremium ? AppColors.gold : tc.textSecondary,
                        fontSize: 6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _isPremium ? 'Activé' : 'Désactivé',
                      style: TextStyle(
                        color: tc.textMuted,
                        fontSize: 5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 22,
                  height: 12,
                  child: FittedBox(
                    child: Switch(
                      value: _isPremium,
                      activeThumbColor: AppColors.gold,
                      activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
                      inactiveThumbColor: tc.textSecondary,
                      inactiveTrackColor: tc.textMuted.withValues(alpha: 0.5),
                      onChanged: (val) {
                        setState(() {
                          _isPremium = val;
                          _markerCacheManager.clear();
                        });
                        if (!val && _currentZoom > 8.0) _zoomTo(8.0);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _debounceTimer?.cancel();

    final newBounds = camera.visibleBounds;
    final newZoom = camera.zoom;

    if (newZoom == _currentZoom && newBounds == _lastBounds) return;

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
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.spots_app',
              ),

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
            ],
          ),

          // ── TOP CENTER CONTROLS ──
          Positioned(
            top: 50,
            left: 40,
            right: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SearchBar(
                  controller: _searchController,
                  results: _searchResults,
                  onChanged: (query) => setState(() {
                    _searchQuery = query.trim().toLowerCase();
                    _selectedSpot = null;
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
                const SizedBox(height: 10),
                _buildPremiumBar(),
              ],
            ),
          ),

          // ── BOTTOM CENTER ZOOM ──
          Positioned(
            bottom: hasSelection ? 65 : 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZoomButton(
                  heroTag: 'zoom_out',
                  icon: Icons.remove,
                  onTap: () => _zoomTo(_currentZoom - 1),
                ),
                const SizedBox(width: 12),
                ZoomButton(
                  heroTag: 'zoom_in',
                  icon: Icons.add,
                  onTap: () => _zoomTo(_currentZoom + 1),
                ),
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
        ],
      ),
    );
  }
}