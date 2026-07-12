// ============================================================================
// wind_particle_layer.dart
//
// Widget Flutter qui s'integre dans FlutterMap.children[].
// - Ticker a 30fps (pas d'AnimationController a 60fps)
// - RepaintBoundary isole les tuiles map
// - Tous les calculs de particules sont faits DANS le ticker (ZERO math
//   dans le CustomPainter, qui ne fait que drawCircle/drawLine)
// - LOD dynamique: nombre de particules base sur devicePixelRatio
// - Desactive automatiquement quand la carte bouge (economie GPU)
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/widgets/wind_particle_painter.dart';

class WindParticleLayer extends StatefulWidget {
  final WindAnimationProvider provider;
  final MapController mapController;

  const WindParticleLayer({
    super.key,
    required this.provider,
    required this.mapController,
  });

  @override
  State<WindParticleLayer> createState() => _WindParticleLayerState();
}

class _WindParticleLayerState extends State<WindParticleLayer>
    with TickerProviderStateMixin {
  late Ticker _ticker;
  int _lastFrameMs = 0;
  static const _frameIntervalMs = 33; // ~30fps

  List<ParticleData> _particles = [];
  double _animPhase = 0.0;

  // Config LOD
  int _particleCount = 100;
  double _particleSpeed = 1.0;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _computeLOD();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _computeLOD() {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    if (dpr < 2.0) {
      _particleCount = 80;
      _particleSpeed = 0.7;
    } else if (dpr < 3.0) {
      _particleCount = 140;
      _particleSpeed = 1.0;
    } else {
      _particleCount = 200;
      _particleSpeed = 1.3;
    }
  }

  void _onTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    if (ms - _lastFrameMs < _frameIntervalMs) return; // skip → 30fps
    _lastFrameMs = ms;

    // Si pas de vecteur vent, pas de particules
    final vector = widget.provider.currentVector;
    if (vector == null) {
      if (_particles.isNotEmpty) {
        _particles = [];
        if (mounted) setState(() {});
      }
      return;
    }

    // Mise a jour de la phase d'animation
    _animPhase += 0.016 * _particleSpeed; // ~1 frame a 30fps
    if (_animPhase > 1.0) _animPhase -= 1.0;

    // Calculer les particules dans le Ticker (PAS dans paint)
    _particles = _generateParticles(vector);
    if (mounted) setState(() {});
  }

  /// Genere toutes les particules pre-calculees autour du spot.
  /// Cette methode est appelee dans le Ticker, pas dans paint().
  List<ParticleData> _generateParticles(WindVector vector) {
    if (_screenSize == Size.zero) return [];

    // Utiliser tout l'ecran comme zone de particules
    final screenW = _screenSize.width;
    final screenH = _screenSize.height;

    // Direction du vent en radians
    final windAngle = math.atan2(vector.v, vector.u);

    // Taille de ligne = vitesse en pixels (étoiles filantes fines)
    final lineLength = vector.speedKt * 3.0 * _particleSpeed;

    final particles = <ParticleData>[];
    final rng = math.Random(42);

    for (int i = 0; i < _particleCount; i++) {
      // Position aleatoire sur tout l'ecran
      final baseX = rng.nextDouble() * screenW;
      final baseY = rng.nextDouble() * screenH;

      // Deplacement le long de la direction du vent
      final phaseDist = (_animPhase + rng.nextDouble() * 0.3) * screenW;
      final px = (baseX + math.cos(windAngle) * phaseDist * lineLength * 0.15) % screenW;
      final py = (baseY + math.sin(windAngle) * phaseDist * lineLength * 0.15) % screenH;

      final wrappedX = px < 0 ? px + screenW : px;
      final wrappedY = py < 0 ? py + screenH : py;

      // Ligne style etoile filante: longueur variable
      final len = lineLength * (0.4 + rng.nextDouble() * 0.6);
      final trailStart = Offset(
        wrappedX - math.cos(windAngle) * len,
        wrappedY - math.sin(windAngle) * len,
      );
      final trailEnd = Offset(wrappedX, wrappedY);

      // Couleur + opacite
      final color = WindColors.forKnots(vector.speedKt);
      final opacity = 0.35 + rng.nextDouble() * 0.35;

      // Pas de cercle, juste une ligne (radius = 0)
      particles.add(ParticleData(
        position: trailEnd,
        radius: 0, // pas de cercle
        opacity: opacity,
        color: color,
        trailStart: trailStart,
        trailEnd: trailEnd,
      ));
    }

    return particles;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.provider.isEnabled || _particles.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: WindParticlePainter(
          particles: _particles,
          camera: widget.mapController.camera,
        ),
        size: Size.infinite,
      ),
    );
  }
}