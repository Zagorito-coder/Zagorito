// ============================================================
//  home_page.dart — Page d'accueil BoosterFish
//  Avec données de marées en temps réel + infos astronomiques
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as lat2;
import 'package:provider/provider.dart';
import '../models.dart';
import '../models/tide_data.dart';
import '../pages/settings_page.dart';
import '../providers/premium_provider.dart';
import '../services/spot_service.dart';
import '../services/tide_service.dart';
import '../theme.dart';
import '../theme_controller.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';
import '../widgets/app_tile_layer.dart';

class HomePage extends StatefulWidget {
  final List<Spot>? initialSpots;
  final VoidCallback? onNavigateToSpots;
  final VoidCallback? onNavigateToSpecies;
  final VoidCallback? onNavigateToTechniques;
  final VoidCallback? onNavigateToCommunity;
  final VoidCallback? onNavigateToShops;
  final VoidCallback? onNavigateToPremium;
  final VoidCallback? onNavigateToTides;
  final VoidCallback? onNavigateToTidesV2;

  const HomePage({
    super.key,
    this.initialSpots,
    this.onNavigateToSpots,
    this.onNavigateToSpecies,
    this.onNavigateToTechniques,
    this.onNavigateToCommunity,
    this.onNavigateToShops,
    this.onNavigateToPremium,
    this.onNavigateToTides,
    this.onNavigateToTidesV2,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TideData _tideData = TideData.fallback();
  bool _isLoading = true;
  late List<Spot> _spots;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _spots = widget.initialSpots ?? [];
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // Ne pas await pour ne pas bloquer le premier frame.
    _loadTides();
    _loadSpots();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSpots() async {
    if (_spots.isNotEmpty) return; // Déjà fournis par SplashBootstrap.
    final spots = await SpotService.loadFromCache();
    if (mounted) {
      setState(() => _spots = spots);
    }
  }

  Future<void> _loadTides() async {
    final data = await TideService.fetchTides();
    if (mounted) {
      setState(() {
        _tideData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadTides();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: tc.background,
          drawer: _buildDrawer(context, tc),
          body: _buildHomeBody(context, tc),
        );
      },
    );
  }

  Widget _buildHomeBody(BuildContext context, ThemeColors tc) {
    return RefreshIndicator(
      color: tc.oceanLight,
      backgroundColor: tc.surface,
      onRefresh: _refresh,
      child: Stack(
        children: [
          // ═══════════════════════════════════════════
          //  FOND MARIN avec gradient + vagues
          // ═══════════════════════════════════════════
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: ThemeController.instance.isDark
                    ? const [Color(0xFF0D3B3B), Color(0xFF06181E), Color(0xFF0A0F1A)]
                    : const [Color(0xFF81D4FA), Color(0xFFB3E5FC), Color(0xFFE3F2FD)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: const CustomPaint(
                size: Size(double.infinity, 360),
                painter: _WavePainter(),
              ),
            ),
          ),

          // ═══════════════════════════════════════════
          //  CONTENU SCROLLABLE
          // ═══════════════════════════════════════════
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),

                // ── Aperçu de la carte des spots ──
                SliverToBoxAdapter(
                  child: _buildMapPreviewCard(),
                ),

                // ── Titre Expedition Sections ──
                SliverToBoxAdapter(
                  child: _buildSectionTitle(),
                ),

                // ── Grid 2x2 ──
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _ExpeditionCard(
                        title: context.tr('home.fishSpecies'),
                        subtitle: context.tr('home.fishSpeciesSubtitle'),
                        icon: Icons.set_meal_rounded,
                        iconColor: const Color(0xFF7BAAF7),
                        onTap: widget.onNavigateToSpecies,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.fishingTechniques'),
                        subtitle: context.tr('home.fishingTechniquesSubtitle'),
                        icon: Icons.school_rounded,
                        iconColor: const Color(0xFFFFB74D),
                        onTap: widget.onNavigateToTechniques,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.community'),
                        subtitle: context.tr('home.communitySubtitle'),
                        icon: Icons.groups_rounded,
                        iconColor: const Color(0xFF4CAF50),
                        onTap: widget.onNavigateToCommunity,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.tackleShops'),
                        subtitle: context.tr('home.tackleShopsSubtitle'),
                        icon: Icons.store_rounded,
                        iconColor: const Color(0xFFFF7043),
                        onTap: widget.onNavigateToShops,
                      ),
                    ],
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  //  DRAWER — Menu latéral
  // ─────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, ThemeColors tc) {
    return Drawer(
      backgroundColor: tc.background,
      child: SizedBox(
        width: 300,
        child: SafeArea(
          child: Column(
            children: [
              // Header du drawer
              Container(
                padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tc.oceanDeep, tc.oceanMedium],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/logo.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.anchor,
                              color: Colors.white,
                              size: 32,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BoosterFish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('app.tagline'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: tc.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('home.member'),
                          style: TextStyle(
                            color: tc.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Switch Dark / Light
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: ListenableBuilder(
                listenable: ThemeController.instance,
                builder: (context, child) {
                  final isDark = ThemeController.instance.isDark;
                  return GestureDetector(
                    onTap: () => ThemeController.instance.toggle(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A2332)
                            : const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              key: ValueKey<bool>(isDark),
                              color: isDark ? const Color(0xFF00B4D8) : const Color(0xFFFFB300),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isDark ? context.tr('theme.dark') : context.tr('theme.light'),
                              style: TextStyle(
                                color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1A2332),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 46,
                            height: 26,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: isDark ? const Color(0xFF00B4D8) : const Color(0xFFB0BEC5),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Sélecteur de langue mignon (flags only)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CuteLanguageSelector(),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: context.tr('drawer.home'),
                    isActive: true,
                    onTap: null,
                  ),
                  _DrawerItem(
                    icon: Icons.waves,
                    label: context.tr('drawer.tides'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTides?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.waves,
                    label: context.tr('drawer.tidesPro'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTidesV2?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.location_on,
                    label: context.tr('drawer.spots'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToSpots?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.set_meal,
                    label: context.tr('drawer.fish'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToSpecies?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.school,
                    label: context.tr('drawer.techniques'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTechniques?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.storefront,
                    label: context.tr('drawer.shops'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToShops?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people,
                    label: context.tr('drawer.community'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToCommunity?.call();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium,
                    label: context.tr('drawer.premium'),
                    trailing: Consumer<PremiumProvider>(
                      builder: (context, premiumProvider, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: premiumProvider.isPremium
                                ? tc.gold.withValues(alpha: 0.25)
                                : tc.textMuted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            premiumProvider.isPremium ? 'PRO' : 'FREE',
                            style: TextStyle(
                              color: premiumProvider.isPremium ? tc.gold : tc.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToPremium?.call();
                    },
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: context.tr('drawer.settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: context.tr('drawer.help'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.tr('drawer.help')),
                          content: Text(
                              context.tr('drawer.helpContent')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(context.tr('common.ok')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Footer du drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, color: tc.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('drawer.logout'),
                    style: TextStyle(
                      color: tc.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  // ─────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tc.glassBorder),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: tc.textPrimary,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo BoosterFish
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/logo.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.anchor,
                          color: Colors.white,
                          size: 32,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'BoosterFish',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      shadows: [
                        Shadow(
                          color: tc.oceanLight.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  APERÇU CARTE DES SPOTS — Pleine fenêtre, spots animés
  // ─────────────────────────────────────────────
  Widget _buildMapPreviewCard() {
    final tc = ThemeColors.of(context);
    final size = MediaQuery.of(context).size;
    final displaySpots = _spots.take(500).toList();
    final bounds = displaySpots.isEmpty
        ? null
        : fm.LatLngBounds.fromPoints(
            displaySpots.map((s) => lat2.LatLng(s.latitude, s.longitude)).toList(),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onNavigateToSpots,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        height: size.height * 0.52,
        constraints: const BoxConstraints(minHeight: 360, maxHeight: 520),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: tc.oceanLight.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: tc.shadowColor.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Mini-carte non interactive (tap redirige vers la carte complète)
            AbsorbPointer(
              child: fm.FlutterMap(
                options: fm.MapOptions(
                  initialCenter: const lat2.LatLng(31.7917, -7.0926),
                  initialZoom: 4.5,
                  interactionOptions: const fm.InteractionOptions(
                    flags: fm.InteractiveFlag.none,
                  ),
                  initialCameraFit: bounds == null
                      ? null
                      : fm.CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(24),
                        ),
                ),
                children: [
                  const AppTileLayer(style: MapStyle.satellite),
                  if (displaySpots.isNotEmpty)
                    fm.MarkerLayer(
                      markers: displaySpots
                          .map(
                            (spot) => fm.Marker(
                              width: 36,
                              height: 36,
                              point: lat2.LatLng(spot.latitude, spot.longitude),
                              child: _PulsingSpotMarker(
                                color: spot.type.color,
                                animation: _pulseController,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),

            // Gradient overlay pour la lisibilité
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),

            // Texte + icône d'appel à l'action
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('drawer.spots'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LanguageController.instance.langCode == 'en'
                              ? 'Tap to open the full map'
                              : LanguageController.instance.langCode == 'ar'
                                  ? 'اضغط لفتح الخريطة الكاملة'
                                  : 'Appuyez pour ouvrir la carte complète',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 24,
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

  // ─────────────────────────────────────────────
  //  CARTE MARÉES COMPLÈTE — Toutes les infos pêcheur
  // ─────────────────────────────────────────────
  // ignore: unused_element
  Widget _buildTidesCard() {
    final tc = ThemeColors.of(context);
    final astro = _tideData.astro;
    final lowStr = '${_tideData.low.toStringAsFixed(1)}m';
    final highStr = '${_tideData.high.toStringAsFixed(1)}m';
    final nextStr = '${_tideData.next.toStringAsFixed(1)}m';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: tc.oceanLight.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tc.shadowColor.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne titre + localisation + loading ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('home.tidesTitle'),
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    _tideData.location,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: tc.oceanLight,
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Graphique courbe temps réel ──
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _RealTimeTidePainter(
                points: _tideData.hourlyPoints,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Heures ──
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeLabel('06:00'),
              _TimeLabel('09:00'),
              _TimeLabel('12:00'),
              _TimeLabel('15:00'),
              _TimeLabel('18:00'),
              _TimeLabel('21:00'),
              _TimeLabel('00:00'),
            ],
          ),

          const SizedBox(height: 14),
          _thinDivider(),
          const SizedBox(height: 14),

          // ── Stats LOW / HIGH / NEXT ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TideStat(
                label: context.tr('home.low'),
                value: lowStr,
                color: const Color(0xFF22C55E),
                icon: Icons.arrow_downward,
              ),
              _TideStat(
                label: context.tr('home.high'),
                value: highStr,
                color: const Color(0xFFD946EF),
                icon: Icons.arrow_upward,
              ),
              _TideStat(
                label: context.tr('home.next'),
                value: nextStr,
                color: Colors.white,
                icon: Icons.access_time,
              ),
            ],
          ),

          const SizedBox(height: 14),
          _thinDivider(),
          const SizedBox(height: 14),

          // ── LIGNE 1 : Phase Lune | Coef | Activité ──
          Row(
            children: [
              // Phase lunaire
              Expanded(
                child: _InfoPill(
                  icon: _moonIcon(astro.moonPhase),
                  iconColor: const Color(0xFFFFD700),
                  label: astro.moonPhaseName,
                  value: 'Coef ${astro.coefficient.round()}',
                ),
              ),
              const SizedBox(width: 10),
              // Activité de poisson
              Expanded(
                child: _InfoPill(
                  icon: Icons.speed,
                  iconColor: _activityColor(astro.fishActivity),
                  label: context.tr('home.activity'),
                  value: astro.activityLabel,
                  valueColor: _activityColor(astro.fishActivity),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _thinDivider(),
          const SizedBox(height: 14),

          // ── LIGNE 2 : Lever / Coucher Soleil ──
          Row(
            children: [
              Expanded(
                child: _SunMoonRow(
                  icon: Icons.wb_sunny,
                  iconColor: const Color(0xFFFFB300),
                  label: context.tr('home.sun'),
                  rise: astro.sunRise,
                  set_: astro.sunSet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SunMoonRow(
                  icon: Icons.nightlight_round,
                  iconColor: const Color(0xFF90A4AE),
                  label: context.tr('home.moon'),
                  rise: astro.moonRise,
                  set_: astro.moonSet,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _thinDivider(),
          const SizedBox(height: 14),

          // ── LIGNE 3 : Transit Solunaire ──
          Row(
            children: [
              Expanded(
                child: _TransitPill(
                  label: context.tr('home.major'),
                  time: astro.lunarTransit,
                  color: const Color(0xFF00B4D8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TransitPill(
                  label: context.tr('home.minor'),
                  time: astro.lunarUnder,
                  color: const Color(0xFFAB47BC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thinDivider() {
    final tc = ThemeColors.of(context);
    return Divider(
      color: tc.divider,
      height: 1,
    );
  }

  // ─────────────────────────────────────────────
  //  TITRE SECTION
  // ─────────────────────────────────────────────
  Widget _buildSectionTitle() {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Center(
        child: Text(
          context.tr('home.expeditionTitle'),
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      ),
    );
  }

  // ── Icône lune selon la phase ──
  IconData _moonIcon(double phase) {
    if (phase < 0.03 || phase > 0.97) return Icons.brightness_3;
    if (phase < 0.22) return Icons.brightness_2;
    if (phase < 0.28) return Icons.brightness_2_outlined;
    if (phase < 0.47) return Icons.brightness_2;
    if (phase < 0.53) return Icons.brightness_5;
    if (phase < 0.72) return Icons.brightness_3;
    if (phase < 0.78) return Icons.brightness_3_outlined;
    return Icons.brightness_3;
  }

  // ── Couleur activité ──
  Color _activityColor(double score) {
    if (score >= 0.75) return const Color(0xFF00E676);
    if (score >= 0.55) return const Color(0xFFFFD700);
    if (score >= 0.35) return const Color(0xFFFF8C69);
    return const Color(0xFFEF5350);
  }
}

// ═══════════════════════════════════════════════════════════
//  MARQUEUR PULSANT — petit point animé sur la mini-carte
// ═══════════════════════════════════════════════════════════

class _PulsingSpotMarker extends AnimatedWidget {
  final Color color;

  const _PulsingSpotMarker({
    required this.color,
    required Animation<double> animation,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final t = animation.value;
    final outerScale = 0.7 + t * 0.6;
    final midScale = 0.5 + t * 0.5;
    final outerAlpha = 0.15 + t * 0.25;
    final midAlpha = 0.25 + t * 0.25;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo extérieur pulsant
          Transform.scale(
            scale: outerScale,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: outerAlpha),
              ),
            ),
          ),
          // Halo intermédiaire
          Transform.scale(
            scale: midScale,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: midAlpha),
              ),
            ),
          ),
          // Cœur lumineux avec icône
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.circle,
                color: Colors.white,
                size: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WIDGETS INTERNES
// ═══════════════════════════════════════════════════════════

class _TimeLabel extends StatelessWidget {
  final String text;
  const _TimeLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Text(
      text,
      style: TextStyle(
        color: tc.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _TideStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _TideStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: tc.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Icon(icon, color: color, size: 16),
      ],
    );
  }
}

// ── InfoPill : petit bloc d'info (Lune / Coef / Activité) ──
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tc.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tc.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? tc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── SunMoonRow : Lever / Coucher ──
class _SunMoonRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String rise;
  final String set_;

  const _SunMoonRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.rise,
    required this.set_,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tc.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tc.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$rise → $set_',
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── TransitPill : Major / Minor ──
class _TransitPill extends StatelessWidget {
  final String label;
  final String time;
  final Color color;

  const _TransitPill({
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('home.transit')} $label',
                  style: TextStyle(
                    color: tc.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

// ═══════════════════════════════════════════════════════════
//  PAINTER — Courbe de marée avec données temps réel
// ═══════════════════════════════════════════════════════════

class _RealTimeTidePainter extends CustomPainter {
  final List<TidePoint> points;

  _RealTimeTidePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (points.length < 3) {
      _drawDefaultCurve(canvas, size);
      return;
    }

    final now = DateTime.now();
    final todayPoints = points.where((p) {
      final diff = p.time.difference(now).inHours;
      return diff >= -6 && diff <= 18;
    }).toList();

    if (todayPoints.length < 3) {
      _drawDefaultCurve(canvas, size);
      return;
    }

    double minH = double.infinity;
    double maxH = -double.infinity;
    for (final p in todayPoints) {
      if (p.height < minH) minH = p.height;
      if (p.height > maxH) maxH = p.height;
    }
    final range = (maxH - minH).clamp(0.1, 100.0);

    final firstTime = todayPoints.first.time;
    final lastTime = todayPoints.last.time;
    final timeRange = lastTime.difference(firstTime).inMinutes.toDouble()
        .clamp(1.0, double.infinity);

    final linePaint = Paint()
      ..color = const Color(0xFF00B4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00B4D8).withValues(alpha: 0.30),
          const Color(0xFF00B4D8).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = Path();

    double mapX(DateTime t) {
      final dx = t.difference(firstTime).inMinutes.toDouble();
      return (dx / timeRange) * w;
    }

    double mapY(double height) {
      final normalized = (height - minH) / range;
      return h - (normalized * h * 0.85 + h * 0.075);
    }

    path.moveTo(mapX(todayPoints[0].time), mapY(todayPoints[0].height));
    for (int i = 0; i < todayPoints.length - 1; i++) {
      final p0 = todayPoints[i];
      final p1 = todayPoints[i + 1];
      final x0 = mapX(p0.time);
      final y0 = mapY(p0.height);
      final x1 = mapX(p1.time);
      final y1 = mapY(p1.height);
      final cpx = (x0 + x1) / 2;
      path.cubicTo(cpx, y0, cpx, y1, x1, y1);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    TidePoint? peakPoint;
    double maxPeak = -double.infinity;
    for (final p in todayPoints) {
      if (p.height > maxPeak) {
        maxPeak = p.height;
        peakPoint = p;
      }
    }
    if (peakPoint != null) {
      final px = mapX(peakPoint.time);
      final py = mapY(peakPoint.height);
      final center = Offset(px, py);
      canvas.drawCircle(center, 10,
          Paint()..color = const Color(0xFF00B4D8).withValues(alpha: 0.35));
      canvas.drawCircle(
          center, 5, Paint()..color = Colors.white..style = PaintingStyle.fill);
    }
  }

  void _drawDefaultCurve(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = const Color(0xFF00B4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00B4D8).withValues(alpha: 0.30),
          const Color(0xFF00B4D8).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = Path();
    path.moveTo(0, h * 0.72);
    path.cubicTo(w * 0.18, h * 0.72, w * 0.32, h * 0.08, w * 0.50, h * 0.08);
    path.cubicTo(w * 0.68, h * 0.08, w * 0.82, h * 0.62, w, h * 0.62);

    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    final dotCenter = Offset(w * 0.50, h * 0.08);
    canvas.drawCircle(dotCenter, 5,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(dotCenter, 10,
        Paint()..color = const Color(0xFF00B4D8).withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════
//  PAINTER — Vagues en haut du fond
// ═══════════════════════════════════════════════════════════

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final wave1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, h * 0.15);
    path1.cubicTo(w * 0.25, h * 0.05, w * 0.5, h * 0.25, w * 0.75, h * 0.10);
    path1.cubicTo(w * 0.9, h * 0.05, w, h * 0.15, w, h * 0.15);
    path1.lineTo(w, 0);
    path1.lineTo(0, 0);
    path1.close();
    canvas.drawPath(path1, wave1);

    final wave2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, h * 0.25);
    path2.cubicTo(w * 0.3, h * 0.15, w * 0.6, h * 0.35, w, h * 0.20);
    path2.lineTo(w, 0);
    path2.lineTo(0, 0);
    path2.close();
    canvas.drawPath(path2, wave2);

    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.15, h * 0.08), 3, bubblePaint);
    canvas.drawCircle(Offset(w * 0.75, h * 0.06), 2, bubblePaint);
    canvas.drawCircle(Offset(w * 0.88, h * 0.12), 4, bubblePaint);
    canvas.drawCircle(Offset(w * 0.40, h * 0.05), 2.5, bubblePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════
//  CARTE EXPEDITION
// ═══════════════════════════════════════════════════════════

class _ExpeditionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ExpeditionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surfaceElevated.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tc.glassBorder,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: CustomPaint(
                size: const Size(60, 60),
                painter: _DiamondPatternPainter(iconColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: tc.textMuted,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final tile = ListTile(
      leading: Icon(
        icon,
        color: isActive ? tc.oceanLight : tc.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? tc.oceanLight : tc.textPrimary,
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: trailing ?? (isActive
          ? Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: tc.oceanLight,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : null),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );

    return tile;
  }
}

class _DiamondPatternPainter extends CustomPainter {
  final Color baseColor;
  const _DiamondPatternPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = baseColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void drawDiamond(double cx, double cy, double radius) {
      final path = Path();
      path.moveTo(cx, cy - radius);
      path.lineTo(cx + radius, cy);
      path.lineTo(cx, cy + radius);
      path.lineTo(cx - radius, cy);
      path.close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);
    }

    drawDiamond(20, 15, 12);
    drawDiamond(40, 30, 10);
    drawDiamond(15, 40, 8);
    drawDiamond(45, 10, 9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
