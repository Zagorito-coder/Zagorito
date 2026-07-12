// ============================================================================
// wind_particle_painter.dart
//
// CustomPainter ultra-leger qui dessine des particules de vent animees.
// TOUS les calculs sont faits dans le Ticker (wind_particle_layer.dart).
// Ici on ne fait QUE drawCircle / drawLine avec des donnees pre-calculees.
//
// Optimisations:
// - ZERO math dans paint() → tout est pre-calcule
// - Pas de shader, pas de path complexe, pas de saveLayer
// - Couleurs statiques (pas de lerp par frame)
// - shouldRepaint strict (reference equality sur la liste de particules)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Une particule pre-calculee, prete a etre dessinee.
class ParticleData {
  final Offset position; // position ecran
  final double radius;
  final double opacity;
  final Color color;
  final Offset? trailStart; // debut de la trainee (null = pas de trainee)
  final Offset? trailEnd;

  const ParticleData({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.color,
    this.trailStart,
    this.trailEnd,
  });
}

/// Palette de couleurs statique par seuils de vent.
class WindColors {
  static const green = Color(0xFF4CAF50);
  static const orange = Color(0xFFFF9800);
  static const red = Color(0xFFF44336);

  static Color forKnots(double knots) {
    if (knots < 12) return green;
    if (knots < 22) return orange;
    return red;
  }

  static Color forKnotsWithAlpha(double knots, double alpha) {
    return forKnots(knots).withValues(alpha: alpha.clamp(0.0, 1.0));
  }
}

class WindParticlePainter extends CustomPainter {
  final List<ParticleData> particles;
  final MapCamera camera;

  WindParticlePainter({
    required this.particles,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Aucun calcul ici — tout est deja dans `particles`.
    // On dessine juste des cercles et des lignes.

    // 1. Dessiner les trainees (derriere les particules)
    // 1. Dessiner les trainees (lignes style etoiles filantes)
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (final p in particles) {
      if (p.trailStart != null && p.trailEnd != null) {
        trailPaint.color = p.color.withValues(alpha: p.opacity);
        canvas.drawLine(p.trailStart!, p.trailEnd!, trailPaint);
      }
    }

    // 2. Dessiner uniquement les particules avec radius > 0 (cercles)
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      if (p.radius > 0) {
        particlePaint.color = p.color.withValues(alpha: p.opacity);
        canvas.drawCircle(p.position, p.radius, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(WindParticlePainter oldDelegate) {
    // Repaint UNIQUEMENT si la liste de particules a change
    // (reference equality — le Ticker cree une nouvelle liste a chaque frame)
    return oldDelegate.particles != particles ||
        oldDelegate.camera != camera;
  }
}