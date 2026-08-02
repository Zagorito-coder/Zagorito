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

import 'dart:async';
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
  late final ValueNotifier<List<ParticleData>> _particles;
  StreamSubscription<MapEvent>? _mapEventSubscription;
  Timer? _mapIdleTimer;
  bool _mapIsMoving = false;
  bool _reduceMotion = false;
  int _lastFrameMs = 0;
  int _frameIntervalMs = 40; // 25 fps par défaut sur téléphone modeste

  List<_ParticleSeed> _particleSeeds = const [];
  double _animPhase = 0.0;

  // Config LOD
  int _particleCount = 100;
  double _particleSpeed = 1.0;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _particles = ValueNotifier<List<ParticleData>>(const []);
    _ticker = createTicker(_onTick);
    widget.provider.addListener(_onProviderChanged);
    _listenToMapEvents();
    if (widget.provider.isEnabled) {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(covariant WindParticleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider != oldWidget.provider) {
      oldWidget.provider.removeListener(_onProviderChanged);
      widget.provider.addListener(_onProviderChanged);
    }
    if (widget.mapController != oldWidget.mapController) {
      _listenToMapEvents();
    }
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduceMotion = media.disableAnimations || media.accessibleNavigation;
    final previousCount = _particleCount;
    final previousSize = _screenSize;
    _screenSize = media.size;
    _computeLOD(media);
    if (previousCount != _particleCount || previousSize != _screenSize) {
      _createParticleSeeds();
    }
    _syncTicker();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    _mapIdleTimer?.cancel();
    unawaited(_mapEventSubscription?.cancel());
    _ticker.dispose();
    _particles.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _syncTicker();
    setState(() {});
  }

  void _listenToMapEvents() {
    unawaited(_mapEventSubscription?.cancel());
    _mapEventSubscription = widget.mapController.mapEventStream.listen((event) {
      if (event is! MapEventMove &&
          event is! MapEventFlingAnimation &&
          event is! MapEventDoubleTapZoom &&
          event is! MapEventScrollWheelZoom &&
          event is! MapEventMoveStart &&
          event is! MapEventMoveEnd &&
          event is! MapEventFlingAnimationStart &&
          event is! MapEventFlingAnimationEnd &&
          event is! MapEventDoubleTapZoomStart &&
          event is! MapEventDoubleTapZoomEnd) {
        return;
      }
      _mapIdleTimer?.cancel();
      if (!_mapIsMoving) {
        _mapIsMoving = true;
        _syncTicker();
      }
      _mapIdleTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        _mapIsMoving = false;
        _syncTicker();
      });
    });
  }

  void _syncTicker() {
    final shouldAnimate =
        mounted && widget.provider.isEnabled && !_mapIsMoving && !_reduceMotion;
    if (shouldAnimate) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    if (_ticker.isActive) return;
    // Ticker.elapsed repart de zéro à chaque start(). Le filtre 30 fps doit
    // donc repartir du même référentiel, sinon toutes les trames d'un second
    // démarrage sont rejetées jusqu'à rattraper la durée du premier.
    _lastFrameMs = 0;
    _ticker.start();
  }

  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastFrameMs = 0;
    _particles.value = const [];
    _animPhase = 0.0;
  }

  void _computeLOD(MediaQueryData media) {
    final physicalPixels = media.size.width *
        media.size.height *
        media.devicePixelRatio *
        media.devicePixelRatio;
    if (media.size.shortestSide <= 400 || physicalPixels >= 2500000) {
      _particleCount = 48;
      _particleSpeed = 0.75;
      _frameIntervalMs = 40;
    } else if (media.size.shortestSide <= 600) {
      _particleCount = 64;
      _particleSpeed = 0.9;
      _frameIntervalMs = 40;
    } else {
      _particleCount = 80;
      _particleSpeed = 1.0;
      _frameIntervalMs = 33;
    }
  }

  void _createParticleSeeds() {
    final random = math.Random(42);
    _particleSeeds = List<_ParticleSeed>.generate(
      _particleCount,
      (_) => _ParticleSeed(
        xRatio: random.nextDouble(),
        yRatio: random.nextDouble(),
        phaseOffset: random.nextDouble() * 0.3,
        lengthFactor: 0.4 + random.nextDouble() * 0.6,
        opacity: 0.35 + random.nextDouble() * 0.35,
      ),
      growable: false,
    );
  }

  void _onTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    if (ms - _lastFrameMs < _frameIntervalMs) return;
    final previousFrameMs = _lastFrameMs;
    _lastFrameMs = ms;

    // Si pas de vecteur vent, pas de particules
    final vector = widget.provider.currentVector;
    if (vector == null) {
      if (_particles.value.isNotEmpty) _particles.value = const [];
      return;
    }

    final elapsedSeconds = previousFrameMs == 0
        ? _frameIntervalMs / 1000.0
        : ((ms - previousFrameMs) / 1000.0).clamp(0.0, 0.1);
    _animPhase = (_animPhase + elapsedSeconds * 0.48 * _particleSpeed) % 1.0;

    _particles.value = _generateParticles(vector);
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
    final color = WindColors.forKnots(vector.speedKt);

    for (final seed in _particleSeeds) {
      final baseX = seed.xRatio * screenW;
      final baseY = seed.yRatio * screenH;

      // Deplacement le long de la direction du vent
      final phaseDist = (_animPhase + seed.phaseOffset) * screenW;
      final px = (baseX + math.cos(windAngle) * phaseDist * lineLength * 0.15) %
          screenW;
      final py = (baseY + math.sin(windAngle) * phaseDist * lineLength * 0.15) %
          screenH;

      final wrappedX = px < 0 ? px + screenW : px;
      final wrappedY = py < 0 ? py + screenH : py;

      // Ligne style etoile filante: longueur variable
      final len = lineLength * seed.lengthFactor;
      final trailStart = Offset(
        wrappedX - math.cos(windAngle) * len,
        wrappedY - math.sin(windAngle) * len,
      );
      final trailEnd = Offset(wrappedX, wrappedY);

      // Pas de cercle, juste une ligne (radius = 0)
      particles.add(ParticleData(
        position: trailEnd,
        radius: 0, // pas de cercle
        opacity: seed.opacity,
        color: color,
        trailStart: trailStart,
        trailEnd: trailEnd,
      ));
    }

    return particles;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.provider.isEnabled || _reduceMotion) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: WindParticlePainter(
          particles: _particles,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticleSeed {
  const _ParticleSeed({
    required this.xRatio,
    required this.yRatio,
    required this.phaseOffset,
    required this.lengthFactor,
    required this.opacity,
  });

  final double xRatio;
  final double yRatio;
  final double phaseOffset;
  final double lengthFactor;
  final double opacity;
}
