// ============================================================
//  splash_map_page.dart — Splash animé : zoom satellite Terre → Maroc
//  Utilise FlutterMap + AnimatedMapController pour un zoom cinématique.
//  Après l'animation, navigation vers AppShell (onglet Carte actif).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/services/spot_service.dart';
import 'package:spots_app/widgets/app_tile_layer.dart';

/// Départ : vue Terre entière approximative.
const LatLng _earthCenter = LatLng(25.0, -5.0);
const double _earthZoom = 2.4;

/// Arrivée : centre du Maroc, vue nationale.
const LatLng _marocCenter = LatLng(31.7917, -7.0926);
const double _marocZoom = 6.2;

class SplashMapPage extends StatefulWidget {
  const SplashMapPage({super.key});

  @override
  State<SplashMapPage> createState() => _SplashMapPageState();
}

class _SplashMapPageState extends State<SplashMapPage>
    with TickerProviderStateMixin {
  late final AnimatedMapController _mapController;
  late final AnimationController _logoController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  bool _spotsReady = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();

    _mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      curve: Curves.easeInOutCubic,
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _preload();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _preload() async {
    await SpotService.loadFromCsv();
    if (!mounted) return;
    setState(() => _spotsReady = true);

    // Petit délai pour laisser le premier frame s'afficher.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    _startZoomAnimation();
  }

  Future<void> _startZoomAnimation() async {
    // Zoom animé Terre → Maroc.
    await _mapController.animateTo(
      dest: _marocCenter,
      zoom: _marocZoom,
      rotation: 0,
    );

    if (!mounted) return;

    // Pause sur le Maroc, puis disparition du logo et transition.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    await _logoController.forward();
    if (!mounted) return;

    _navigateToApp();
  }

  void _navigateToApp() {
    if (_exiting) return;
    _exiting = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AppShell(key: appShellKey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.28;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── CARTE SATELLITE ANIMÉE ──
          FlutterMap(
            mapController: _mapController.mapController,
            options: const MapOptions(
              initialCenter: _earthCenter,
              initialZoom: _earthZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.none, // blocage gestes pendant le splash
              ),
            ),
            children: const [
              AppTileLayer(style: MapStyle.satellite),
            ],
          ),

          // ── VIGNETTE SOMBRE POUR LE LOGO ──
          AnimatedBuilder(
            animation: _logoFade,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.35 * (1 - _logoFade.value),
                  ),
                ),
              );
            },
          ),

          // ── LOGO ANIMÉ ──
          Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/logo.png',
                        width: logoSize,
                        height: logoSize,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── INDICATEUR DE CHARGEMENT DISCRET ──
          if (!_spotsReady)
            const Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // ── BOUTON PASSER (debug) ──
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    tooltip: 'Passer le splash',
                    onPressed: _navigateToApp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
