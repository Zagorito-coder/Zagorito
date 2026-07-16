// ============================================================
//  main.dart — Spots App OPTIMISÉE POUR 6200 SPOTS
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, SystemUiOverlayStyle;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/services/spot_service.dart';
import 'package:spots_app/models/fish_model.dart';
import 'package:spots_app/spot_details_panel.dart';
import 'package:spots_app/spots_canvas_layer.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/app_tile_layer.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/splash_bootstrap.dart';
import 'package:spots_app/widgets/fish_intelligence_modal.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/providers/fish_provider.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/widgets/trial_banner.dart';
import 'package:spots_app/widgets/auth_prompt_modal.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/widgets/wind_particle_layer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      animation: Listenable.merge([ThemeController.instance, LanguageController.instance]),
      builder: (context, child) {
        final isDark = ThemeController.instance.isDark;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: ThemeColors.of(context).background,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
            title: 'Spots App', debugShowCheckedModeBanner: false,
            theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
            locale: LanguageController.instance.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
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
    ..cubicTo(s.width * 0.05, s.height * 0.25, s.width * 0.05, s.height * 0.65, s.width * 0.5, s.height)
    ..cubicTo(s.width * 0.95, s.height * 0.65, s.width * 0.95, s.height * 0.25, s.width * 0.5, 0)
    ..close();
  @override bool shouldReclip(CustomClipper<ui.Path> o) => false;
}

class SpotMarker extends StatelessWidget {
  final Spot spot;
  final bool isSelected, isPremium;
  const SpotMarker({super.key, required this.spot, required this.isSelected, required this.isPremium});
  @override
  Widget build(BuildContext context) {
    final bc = spot.type.color;
    final mw = isSelected ? 42.0 : 32.0;
    final mh = isSelected ? 54.0 : 42.0;
    final hl = isPremium ? Colors.amberAccent : bc;
    return SizedBox(width: mw, height: mh + (isSelected ? 44 : 32),
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
        Positioned(bottom: 0, child: Container(width: mw * 1.4, height: mh * 0.6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: hl.withValues(alpha: isSelected ? 0.15 : 0.08)))),
        Positioned(bottom: 0, child: ClipPath(clipper: _DropClipper(), child: Container(width: mw, height: mh,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [bc.withValues(alpha: 0.95), bc.withValues(alpha: 0.65)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.4),
            boxShadow: [BoxShadow(color: bc.withValues(alpha: 0.45), blurRadius: isSelected ? 12 : 7, offset: const Offset(0, 3))]),
          child: Center(child: Icon(Icons.phishing, color: Colors.white.withValues(alpha: 0.95), size: mw * 0.42))))),
        Positioned(bottom: mh * 0.72, child: Container(width: mw * 0.35, height: mw * 0.18,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(mw * 0.09), color: Colors.white.withValues(alpha: 0.5)))),
        if (isSelected) Positioned(top: -40, child: SpotLabel(spot: spot, accent: hl)),
      ]));
  }
}

class SpotLabel extends StatelessWidget {
  final Spot spot; final Color accent;
  const SpotLabel({super.key, required this.spot, required this.accent});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.95), width: 1.0),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
        const SizedBox(width: 10),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(spot.name, style: TextStyle(color: tc.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 2),
          Text(spot.type.label, style: TextStyle(color: accent.withValues(alpha: 0.92), fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1),
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
  final VoidCallback? onTap;
  const _SearchBar({required this.controller, required this.results, required this.onChanged,
    required this.onClear, required this.onSelect, required this.distanceText, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.glassBorder, width: 1.2),
          boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 12, offset: const Offset(0, 4))]),
        child: TextField(controller: controller, style: TextStyle(color: tc.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          onTap: onTap,
          decoration: InputDecoration(filled: true, fillColor: tc.surfaceLight.withValues(alpha: 0.8),
            hintText: l10n.translate('map.searchHint'), hintStyle: TextStyle(color: tc.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: tc.textSecondary, size: 22),
            suffixIcon: controller.text.isEmpty ? null : IconButton(
              icon: Icon(Icons.close, color: tc.textMuted, size: 18), onPressed: onClear),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tc.oceanMedium, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          textInputAction: TextInputAction.search, onChanged: onChanged,
          onSubmitted: (_) { if (results.isNotEmpty) onSelect(results.first); })),
      if (controller.text.isNotEmpty && results.isNotEmpty)
        Container(margin: const EdgeInsets.only(bottom: 8), constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tc.glassBorder, width: 1.2),
            boxShadow: [BoxShadow(color: tc.shadowColor.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: ListView.builder(shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8), itemCount: results.length,
            itemBuilder: (context, index) {
              final spot = results[index];
              return Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: tc.surfaceLight.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(10)),
                child: ListTile(dense: true,
                  leading: Container(width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: spot.type.color,
                      boxShadow: [BoxShadow(color: spot.type.color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)])),
                  title: Text(spot.name, style: TextStyle(color: tc.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(distanceText(spot), style: TextStyle(color: tc.textMuted, fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, color: tc.textMuted, size: 16), onTap: () => onSelect(spot)));
            }))),
    ]);
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
    return GestureDetector(onTap: onTap, child: Container(width: 48, height: 48,
      decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.glassBorder, width: 1.2),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 12, offset: const Offset(0, 4))]),
      child: Center(child: Icon(icon, color: tc.textPrimary, size: 24))));
  }
}

class MarkerCacheManager {
  final Map<String, SpotMarker> _cache = {};
  SpotMarker getOrCreateMarker(Spot s, bool sel, bool prem) {
    final k = '${s.id}_${sel}_$prem';
    if (_cache.containsKey(k)) return _cache[k]!;
    return _cache[k] = SpotMarker(key: ValueKey(k), spot: s, isSelected: sel, isPremium: prem);
  }
  void clear() => _cache.clear();
}

// ── FishMenu ──────────────────────────────────────────────────

class _FishVerticalMenu extends StatelessWidget {
  final List<FishModel> fishes;
  final FishModel? selectedFish;
  final void Function(FishModel) onFishSelected;
  final VoidCallback onFishDeselected;
  const _FishVerticalMenu({required this.fishes, required this.selectedFish,
    required this.onFishSelected, required this.onFishDeselected});
  static const double _cs = 53, _rs = 72;
  @override
  Widget build(BuildContext context) {
    if (fishes.isEmpty) return const SizedBox.shrink();
    return SizedBox(width: _cs + 120, height: 6 * _rs + 20,
      child: ListView.builder(reverse: true, padding: EdgeInsets.zero, itemCount: fishes.length,
        itemBuilder: (ctx, i) {
          final f = fishes[i];
          final sel = selectedFish?.id == f.id;
          return _FishRow(fish: f, isSelected: sel,
            onTap: () {
              if (sel) { onFishDeselected(); } else { onFishSelected(f); }
            },
            circleSize: _cs);
        }));
  }
}

class _FishRow extends StatelessWidget {
  final FishModel fish;
  final bool isSelected;
  final VoidCallback onTap;
  final double circleSize;
  const _FishRow({required this.fish, required this.isSelected, required this.onTap, required this.circleSize});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
          width: circleSize, height: circleSize,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: isSelected ? const Color(0xFF48CAE4) : tc.surfaceLight,
            border: Border.all(color: isSelected ? const Color(0xFF48CAE4) : tc.glassBorder, width: 2),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF48CAE4).withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)] : null),
          child: ClipOval(child: _buildImage(context))),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fish.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tc.textPrimary, fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            Text(fish.scientificName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tc.textMuted, fontSize: 9, fontStyle: FontStyle.italic)),
          ])),
      ])));
  }
  Widget _buildImage(BuildContext context) {
    if (fish.imageUrl.startsWith('assets/')) { return Image.asset(fish.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph()); }
    return CachedNetworkImage(imageUrl: fish.imageUrl, fit: BoxFit.cover, placeholder: (_, __) => _ph(), errorWidget: (_, __, ___) => _ph());
  }
  Widget _ph() => Container(color: const Color(0xFF1E6091), child: const Center(child: Text('🐟', style: TextStyle(fontSize: 20))));
}

// ═══════════════════════════════════════════════════════════════
//  MAP SCREEN
// ═══════════════════════════════════════════════════════════════

class MapScreen extends StatefulWidget {
  final List<Spot>? initialSpots;
  const MapScreen({super.key, this.initialSpots});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Distance _distance = const Distance();
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 100);

  List<Spot> _spots = [];
  LatLngBounds? _lastBounds;
  List<Spot> _visibleSpots = [];
  String _searchQuery = '';
  Position? _currentPosition;
  Spot? _selectedSpot;
  double _currentZoom = 6.0;
  bool _isLoadingSpots = true;
  bool _isFishBarVisible = false, _showToolsPanel = false, _isMeasuring = false;
  final List<LatLng> _measurePoints = [];
  double _measuredDistanceKm = 0.0;
  MapStyle _mapStyle = MapStyle.standard;
  bool _isPremium = false;
  double _maxZoom = 8.0;
  bool _isLoggedIn = false;
  VoidCallback? _premiumListener;
  VoidCallback? _authListener;

  // Compass — désactivé par défaut
  bool _isCompassEnabled = false;
  double _heading = 0.0, _courseOverGround = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  List<Spot> get _searchResults {
    final q = _searchQuery.trim().toLowerCase();
    return q.isEmpty ? [] : _spots.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  String _distanceText(Spot spot) {
    if (_currentPosition == null) return 'Distance inconnue';
    final km = _distance.as(LengthUnit.Kilometer,
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(spot.latitude, spot.longitude));
    return '${km.toStringAsFixed(1)} km';
  }

  @override void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadSpots();
    _initLocation();
    // Compass & position stream démarrés uniquement à la demande
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final p = context.read<PremiumProvider>();
      _authListener = () {
        if (!mounted) return;
        final logged = auth.isLoggedIn;
        final newPremium = logged && p.isPremium;
        final newMaxZoom = logged ? p.maxZoom : 8.0;
        if (_isLoggedIn != logged || _isPremium != newPremium || _maxZoom != newMaxZoom) {
          setState(() {
            _isLoggedIn = logged;
            _isPremium = newPremium;
            _maxZoom = newMaxZoom;
          });
        }
      };
      auth.addListener(_authListener!);
      _premiumListener = () {
        if (!mounted) return;
        final logged = auth.isLoggedIn;
        final newPremium = logged && p.isPremium;
        final newMaxZoom = logged ? p.maxZoom : 8.0;
        if (_isPremium != newPremium || _maxZoom != newMaxZoom || _isLoggedIn != logged) {
          setState(() {
            _isLoggedIn = logged;
            _isPremium = newPremium;
            _maxZoom = newMaxZoom;
          });
        }
      };
      p.addListener(_premiumListener!);
      _isLoggedIn = auth.isLoggedIn;
      _isPremium = _isLoggedIn && p.isPremium;
      _maxZoom = _isLoggedIn ? p.maxZoom : 8.0;
      if (mounted) setState(() {});
      _updateVisibleSpots();
    });
  }

  void _toggleCompass() {
    if (_isCompassEnabled) {
      _compassSubscription?.cancel();
      _compassSubscription = null;
      _heading = 0.0;
      _courseOverGround = 0.0;
      setState(() => _isCompassEnabled = false);
    } else {
      _compassSubscription = FlutterCompass.events?.listen((e) {
        if (mounted && e.heading != null) {
          setState(() => _heading = e.heading!);
        }
      });
      setState(() => _isCompassEnabled = true);
    }
  }

  void _initPositionStream() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10),
    ).listen((pos) {
      if (!mounted) return;
      final cog = pos.heading;
      if (!cog.isNaN && cog >= 0) {
        _courseOverGround = cog;
      } else if (_lastPosition != null) {
        _courseOverGround = Geolocator.bearingBetween(
          _lastPosition!.latitude, _lastPosition!.longitude, pos.latitude, pos.longitude);
      }
      _lastPosition = pos;
      _currentPosition = pos;
      setState(() {});
    });
  }

  @override void dispose() {
    if (_authListener != null) {
      context.read<AuthService>().removeListener(_authListener!);
    }
    if (_premiumListener != null) {
      context.read<PremiumProvider>().removeListener(_premiumListener!);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _mapController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _updateVisibleSpots() { if (_spots.isEmpty) return; try { _applyBoundsFilter(_mapController.camera.visibleBounds); } catch (_) {} }

  void _applyBoundsFilter(LatLngBounds b) {
    if (b.north.isNaN || b.south.isNaN || b.east.isNaN || b.west.isNaN) return;
    _visibleSpots = _spots.where((s) =>
      s.latitude >= b.south && s.latitude <= b.north && s.longitude >= b.west && s.longitude <= b.east).toList();
    _lastBounds = b;
  }

  Future<void> _loadSpots() async {
    try {
      if (widget.initialSpots != null && widget.initialSpots!.isNotEmpty) {
        if (!mounted) return;
        setState(() { _spots = widget.initialSpots!; _isLoadingSpots = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibleSpots());
        return;
      }
      final c = await SpotService.loadFromCache();
      if (c.isNotEmpty) {
        if (!mounted) return;
        setState(() { _spots = c; _isLoadingSpots = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibleSpots());
        return;
      }
      final csv = await SpotService.loadFromCsv();
      if (!mounted) return;
      setState(() { _spots = csv; _isLoadingSpots = false; });
      SpotService.saveToCache(csv);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibleSpots());
    } catch (e, st) {
      debugPrint('[MapScreen] ERREUR chargement spots: $e\n$st');
      if (mounted) setState(() => _isLoadingSpots = false);
    }
  }

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = pos);
    } catch (e) { debugPrint('[main] Erreur initLocation: $e'); }
  }

  void _zoomTo(double zoom) {
    if (!zoom.isFinite) return;
    final center = _mapController.camera.center;
    if (!center.latitude.isFinite || !center.longitude.isFinite) return;
    if (zoom > _maxZoom) {
      if (!_isPremium) {
        _showPremiumDialog();
      }
      zoom = _maxZoom;
    }
    final z = zoom.clamp(3.0, _maxZoom);
    _mapController.move(center, z);
    setState(() => _currentZoom = z);
  }

  Future<void> _animateToSpot(Spot spot) async {
    if (!spot.latitude.isFinite || !spot.longitude.isFinite) return;
    final target = LatLng(spot.latitude, spot.longitude);
    final tz = (_currentZoom < _maxZoom ? _maxZoom : _currentZoom).clamp(3.0, _maxZoom);
    if (!tz.isFinite) return;
    for (var i = 1; i <= 6; i++) {
      final stepZ = (_currentZoom + (tz - _currentZoom) * (i / 6)).clamp(3.0, _maxZoom);
      if (!stepZ.isFinite) continue;
      _mapController.move(target, stepZ);
      if (i < 6) await Future.delayed(const Duration(milliseconds: 25));
    }
    if (mounted) setState(() => _currentZoom = tz);
  }

  Future<void> _selectSpot(Spot spot) async {
    setState(() { _selectedSpot = spot; _searchQuery = ''; });
    _searchController.clear(); FocusScope.of(context).unfocus();
    await _animateToSpot(spot);
  }

  void _clearSelection() {
    if (_selectedSpot == null) return;
    final center = LatLng(_selectedSpot!.latitude, _selectedSpot!.longitude);
    if (!center.latitude.isFinite || !center.longitude.isFinite) {
      setState(() => _selectedSpot = null);
      return;
    }
    final zoom = (math.log(40075016.686 * math.cos(center.latitude * math.pi / 180) / (256 * (20000 / 256))) / math.ln2).clamp(3.0, _maxZoom);
    if (!zoom.isFinite) {
      setState(() => _selectedSpot = null);
      return;
    }
    _zoomTo(zoom);
    setState(() => _selectedSpot = null);
  }

  void _onMapTap(TapPosition tp, LatLng point) {
    final fp = FishProvider.instance;
    if (fp.isFishModalVisible) { fp.closeFishModal(); }
    // Si overlays ouverts (hors recherche seule), les fermer
    if (_selectedSpot != null || _isFishBarVisible || _showToolsPanel) {
      setState(() { _selectedSpot = null; _isFishBarVisible = false; _showToolsPanel = false; _searchQuery = ''; });
      _searchController.clear();
      FocusScope.of(context).unfocus();
      return;
    }
    // Si recherche active mais pas d'autre overlay → juste cacher le clavier, garder le texte
    if (_searchQuery.isNotEmpty) { FocusScope.of(context).unfocus(); return; }
    if (_isMeasuring) { setState(() { _measurePoints.add(point); _recalcMeasure(); }); }
  }

  void _recalcMeasure() {
    if (_measurePoints.length < 2) { _measuredDistanceKm = 0.0; return; }
    double total = 0.0;
    for (int i = 1; i < _measurePoints.length; i++) { total += _distance.as(LengthUnit.Kilometer, _measurePoints[i - 1], _measurePoints[i]); }
    _measuredDistanceKm = total;
  }

  final MarkerCacheManager _markerCacheManager = MarkerCacheManager();

  void _showPremiumDialog() {
    if (!mounted) return;
    final provider = context.read<PremiumProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubscriptionModal(
        currentPlan: provider.planType,
        onAnnualTap: () {
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Abonnement annuel en cours de configuration...')),
          );
        },
        onLifetimeTap: () {
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accès à vie en cours de configuration...')),
          );
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _onPositionChanged(MapCamera camera, bool gesture) {
    _debounceTimer?.cancel();
    final nb = camera.visibleBounds;
    var nz = camera.zoom;
    if (!nz.isFinite) return;
    if (nb.north.isNaN || nb.south.isNaN || nb.east.isNaN || nb.west.isNaN) return;
    if (nz > _maxZoom) {
      nz = _maxZoom;
      _mapController.move(camera.center, nz);
    }
    if (nz == _currentZoom && nb == _lastBounds) return;
    _debounceTimer = Timer(_debounceDuration, () { if (mounted) setState(() { _currentZoom = nz; _applyBoundsFilter(nb); }); });
  }

  @override Widget build(BuildContext context) {
    super.build(context);
    final tc = ThemeColors.of(context);
    final hasSel = _selectedSpot != null;

    return Scaffold(body: Stack(children: [
      if (_isLoadingSpots)
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: tc.oceanLight),
          const SizedBox(height: 12),
          Text('Chargement des spots...', style: TextStyle(color: tc.textSecondary)),
        ])),
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(30.5, -9.7),
          initialZoom: 6,
          maxZoom: _maxZoom,
          minZoom: 3.0,
          onPositionChanged: _onPositionChanged,
          onTap: _onMapTap,
          onMapReady: () {},
        ),
        children: [
              AppTileLayer(style: _mapStyle),
              if (_currentPosition != null)
                MarkerLayer(markers: [Marker(width: 20, height: 20,
                  point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withValues(alpha: 0.9),
                    border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.45), blurRadius: 10)])))]),
              SpotsCanvasLayer(
                visibleSpots: _visibleSpots,
                mapController: _mapController,
                selectedSpot: _selectedSpot,
                onSpotTap: _selectSpot,
                onMapTap: (ll) => _onMapTap(const TapPosition(Offset.zero, Offset.zero), ll),
              ),
              // 🌬️ Couche de particules de vent animees (30fps)
              // IgnorePointer pour ne pas bloquer les taps sur la carte
              IgnorePointer(
                child: Consumer<WindAnimationProvider>(
                  builder: (ctx, wind, _) => WindParticleLayer(
                    provider: wind,
                    mapController: _mapController,
                  ),
                ),
              ),
              if (_selectedSpot != null)
                MarkerLayer(markers: [Marker(width: 52, height: 56, point: LatLng(_selectedSpot!.latitude, _selectedSpot!.longitude),
                  child: _markerCacheManager.getOrCreateMarker(_selectedSpot!, true, _isPremium))]),
              if (_isMeasuring && _measurePoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: _measurePoints, color: Colors.redAccent, strokeWidth: 4.0)]),
              if (_isMeasuring && _measurePoints.isNotEmpty)
                MarkerLayer(markers: _measurePoints.map((p) => Marker(width: 14, height: 14, point: p,
                  child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                    border: Border.all(color: Colors.redAccent, width: 2))))).toList()),
            ],
          ),
      if (_showToolsPanel) _buildToolsPanel(),
      if (_isLoadingSpots) const SizedBox.shrink(),
      Positioned(top: MediaQuery.of(context).padding.top + 4, left: 0, right: 0,
        child: TrialBanner(onSubscribeTap: _showPremiumDialog)),
      Positioned(bottom: 96+16+8, left: 0, right: 0, child: Align(alignment: Alignment.centerLeft,
        child: Consumer<FishProvider>(builder: (ctx, fp, _) {
          final df = fp.allFish;
          if (df.isEmpty) return const SizedBox.shrink();
          return AnimatedSlide(offset: _isFishBarVisible ? Offset.zero : const Offset(0, 2),
            duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
            child: AnimatedOpacity(opacity: _isFishBarVisible ? 1.0 : 0.0, duration: const Duration(milliseconds: 200),
              child: _FishVerticalMenu(fishes: df, selectedFish: fp.selectedFish,
                onFishSelected: (f) => fp.selectFish(f, _spots, _currentPosition), onFishDeselected: fp.deselectFish)));
        }))),
      Positioned(bottom: 8, left: 8, width: 96, height: 96,
        child: Directionality(textDirection: TextDirection.ltr, child: _buildFishFilterButton())),
      if (!hasSel)
        ListenableBuilder(listenable: LanguageController.instance, builder: (ctx, _) {
          return Positioned(bottom: 16, left: 16, right: 16, child: Center(
            child: SizedBox(width: MediaQuery.of(ctx).size.width * 0.45,
            child: _SearchBar(controller: _searchController, results: _searchResults,
              onTap: () { if (_isFishBarVisible) setState(() => _isFishBarVisible = false); },
              onChanged: (q) => setState(() { _searchQuery = q.trim().toLowerCase(); _selectedSpot = null; _isFishBarVisible = false; }),
              onClear: () { _searchController.clear(); setState(() { _searchQuery = ''; _selectedSpot = null; }); FocusScope.of(context).unfocus(); },
              onSelect: _selectSpot, distanceText: _distanceText))));
        }),
      if (_isCompassEnabled)
        Positioned(top: 0, left: 0, right: 0,
          child: MediaQuery.removePadding(context: context, removeTop: true,
            child: _CompassRibbon(heading: _heading, courseOverGround: _courseOverGround))),
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
        ListenableBuilder(listenable: LanguageController.instance, builder: (ctx, _) {
          return Align(alignment: Alignment.bottomCenter, child: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.92, height: MediaQuery.of(ctx).size.height * 0.33,
            child: SpotDetailsPanel(spot: _selectedSpot!, distanceText: _distanceText(_selectedSpot!), isPremium: _isPremium,
              onClose: _clearSelection, onPremiumTap: _showPremiumDialog,
              currentPosition: _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : null,
              allSpots: _spots, onSpotSelected: _selectSpot)));
        }),
      ListenableBuilder(listenable: LanguageController.instance, builder: (ctx, _) {
        return Consumer<FishProvider>(builder: (ctx, fp, __) {
          if (!fp.isFishModalVisible || fp.selectedFish == null) return const SizedBox.shrink();
          return Positioned.fill(child: GestureDetector(onTap: fp.closeFishModal, child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (ctx, v, c) => Opacity(opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.8 + 0.2 * v, child: c)),
              child: GestureDetector(onTap: () {}, child: FishIntelligenceModal(
                fish: fp.selectedFish!, nearbySpots: fp.nearbySpots, isLoadingNearby: fp.isLoadingNearby,
                distanceText: _distanceText,
                onSpotSelected: (s) { fp.closeFishModal(); _selectSpot(s); },
                onClose: fp.closeFishModal, currentPosition: _currentPosition)))))));
        });
      }),
      if (!_isLoggedIn)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => AuthPromptModal.show(context),
            child: Container(color: Colors.transparent),
          ),
        ),
    ]));
  }

  Widget _buildToolsPanel() {
    final tc = ThemeColors.of(context);
    return Positioned(bottom: 170, right: 80, child: Container(width: 180, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.glassBorder, width: 1.2),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Outils carto', style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        const Divider(height: 16),
        _toolItem(icon: _isMeasuring ? Icons.stop : Icons.straighten, label: _isMeasuring ? 'Arrêter mesure' : 'Mesurer distance',
          color: _isMeasuring ? AppColors.gold : tc.textPrimary, onTap: () { setState(() { _isMeasuring = !_isMeasuring; if (!_isMeasuring) { _measurePoints.clear(); _measuredDistanceKm = 0.0; } }); }),
        if (_isMeasuring && _measurePoints.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_measuredDistanceKm.toStringAsFixed(2)} km', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        Text('Fond de carte', style: TextStyle(color: tc.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _toolItem(icon: Icons.map, label: 'Standard', color: _mapStyle == MapStyle.standard ? tc.oceanMedium : tc.textPrimary, onTap: () => setState(() => _mapStyle = MapStyle.standard)),
        const SizedBox(height: 6),
        _toolItem(icon: Icons.satellite, label: 'Satellite', color: _mapStyle == MapStyle.satellite ? tc.oceanMedium : tc.textPrimary, onTap: () => setState(() => _mapStyle = MapStyle.satellite)),
        const SizedBox(height: 6),
        _toolItem(icon: Icons.dark_mode, label: 'Sombre', color: _mapStyle == MapStyle.dark ? tc.oceanMedium : tc.textPrimary, onTap: () => setState(() => _mapStyle = MapStyle.dark)),
      ])));
  }

  Widget _toolItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))]));
  }

  Widget _buildFishFilterButton() {
    return GestureDetector(onTap: () => setState(() { _isFishBarVisible = !_isFishBarVisible; _searchQuery = ''; }),
      child: SizedBox(width: 96, height: 96, child: ClipOval(child: Image.asset('assets/images/blue_fish_button.png', fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('🐟', style: TextStyle(fontSize: 48)))))));
  }

  Widget _buildMyLocationButton() {
    final tc = ThemeColors.of(context);
    return GestureDetector(onTap: () async {
      if (_currentPosition == null) {
        await _initLocation();
        if (_currentPosition != null && _positionSubscription == null) _initPositionStream();
        return;
      }
      if (_positionSubscription == null) _initPositionStream();
      final pos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      if (!pos.latitude.isFinite || !pos.longitude.isFinite) return;
      final z = (_currentZoom + 2).clamp(3.0, _maxZoom);
      if (!z.isFinite) return;
      _mapController.move(pos, z);
      if (mounted) setState(() {});
    }, child: Container(width: 48, height: 48,
      decoration: BoxDecoration(color: tc.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.glassBorder, width: 1.2),
        boxShadow: [BoxShadow(color: tc.shadowColor, blurRadius: 12, offset: const Offset(0, 4))]),
      child: Center(child: Icon(Icons.my_location, color: tc.oceanMedium, size: 24))));
  }

  Widget _buildToolsPanelToggleButton() {
    return ZoomButton(heroTag: 'tpt', icon: _showToolsPanel ? Icons.close : Icons.layers, onTap: () => setState(() => _showToolsPanel = !_showToolsPanel));
  }

  Widget _buildZoomIn() {
    return ZoomButton(heroTag: 'zi', icon: Icons.add, onTap: () => _zoomTo(_currentZoom + 1));
  }
  Widget _buildZoomOut() {
    return ZoomButton(heroTag: 'zo', icon: Icons.remove, onTap: () => _zoomTo(_currentZoom - 1));
  }

  Widget _buildWindToggleButton() {
    final tc = ThemeColors.of(context);
    final wind = context.watch<WindAnimationProvider>();
    final isOn = wind.isEnabled;
    return GestureDetector(
      onTap: () {
        // Utiliser la position GPS si dispo, sinon le centre de la carte
        final lat = _currentPosition?.latitude ?? _mapController.camera.center.latitude;
        final lon = _currentPosition?.longitude ?? _mapController.camera.center.longitude;
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
  final double heading, courseOverGround;
  const _CompassRibbon({required this.heading, required this.courseOverGround});

  @override
  Widget build(BuildContext context) {
    final cog = courseOverGround.isNaN || courseOverGround == 0 ? 0.0 : courseOverGround;
    final head = heading.isNaN ? 0.0 : heading;
    return Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 6), child: ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      child: Container(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 3))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 38, child: LayoutBuilder(builder: (ctx, cons) {
            final w = cons.maxWidth; final cs = <Widget>[];
            for (int d = 0; d < 360; d += 45) {
              var del = (d - head) % 360; if (del > 180) del -= 360; if (del.abs() > 90) continue;
              final x = w / 2 + (del / 90.0) * (w / 2);
              cs.add(Positioned(left: x - 10, child: SizedBox(width: 20, child: Text(_rl(d), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: d % 90 == 0 ? Colors.black : Colors.black54))))); }
            return Stack(alignment: Alignment.center, children: [const Positioned(top: 0, child: Icon(Icons.arrow_drop_down, color: Color(0xFFFF2D55), size: 16)), ...cs]);
          })),
          const SizedBox(height: 8),
          SizedBox(height: 14, child: LayoutBuilder(builder: (ctx, cons) {
            final w = cons.maxWidth; final ms = <Widget>[];
            for (int d = 0; d < 360; d += 45) {
              var del = (d - head) % 360; if (del > 180) del -= 360; if (del.abs() > 90) continue;
              final x = w / 2 + (del / 90.0) * (w / 2); final isC = d % 90 == 0;
              ms.add(Positioned(left: x - 1, top: 0, bottom: 0, child: Center(child: Container(
                width: isC ? 3.5 : 2.5, height: isC ? 22.0 : 14.0,
                decoration: BoxDecoration(color: isC ? Colors.black.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(1)))))); }
            return Stack(alignment: Alignment.center, children: [
              Container(height: 2, color: Colors.black.withValues(alpha: 0.3)), ...ms,
              Transform.rotate(angle: head * (math.pi / 180), child: Icon(Icons.arrow_upward_rounded, color: const Color(0xFFFF2D55), size: 34,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]))]);
          })),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Heading', style: TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(head == 0 ? '--' : '${head.toInt()}° ${_gd(head)}', style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Course over ground', style: TextStyle(fontSize: 12.5, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(cog == 0 ? '--' : '${cog.toInt()}° ${_gd(cog)}', style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            ]),
          ]),
        ]))));
  }

  String _gd(double d) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((((d < 0 ? d + 360 : d) + 22.5) % 360) ~/ 45).clamp(0, 7)];
  }
  String _rl(int d) { switch (d % 360) { case 0: return 'N'; case 45: return 'NE'; case 90: return 'E'; case 135: return 'SE'; case 180: return 'S'; case 225: return 'SW'; case 270: return 'W'; case 315: return 'NW'; default: return ''; } }
}
