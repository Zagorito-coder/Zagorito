import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme_controller.dart';
import 'app_back_button.dart';

/// Couche visuelle opt-in du thème BoosterFish.
///
/// Elle est indépendante du ThemeData global afin que les écrans
/// cartographiques et les pages de marées restent strictement inchangés.
class BoosterFishPagePalette {
  final bool isDark;

  const BoosterFishPagePalette(this.isDark);

  factory BoosterFishPagePalette.of(BuildContext context) =>
      BoosterFishPagePalette(ThemeController.instance.isDark);

  Color get background =>
      isDark ? const Color(0xFF020817) : const Color(0xFFF7FAFE);
  Color get surface =>
      isDark ? const Color(0xFF07172C) : const Color(0xFFFFFFFF);
  Color get surfaceElevated =>
      isDark ? const Color(0xFF0A203B) : const Color(0xFFF0F7FD);
  Color get navy => isDark ? const Color(0xFF03142B) : const Color(0xFF0B2852);
  Color get accent =>
      isDark ? const Color(0xFF19D7FF) : const Color(0xFF078FF0);
  Color get textPrimary =>
      isDark ? const Color(0xFFF4F8FF) : const Color(0xFF071A3F);
  Color get textSecondary =>
      isDark ? const Color(0xFFA8B9D2) : const Color(0xFF526786);
  Color get textMuted =>
      isDark ? const Color(0xFF8095B4) : const Color(0xFF7185A2);
  Color get borderStrong =>
      isDark ? const Color(0xFF3C8CBF) : const Color(0xFFB8D6F1);
  Color get divider =>
      isDark ? const Color(0xFF183654) : const Color(0xFFDDEAF5);
  Color get oceanLight => accent;
  Color get oceanMedium =>
      isDark ? const Color(0xFF15BFEA) : const Color(0xFF087FD5);
  Color get oceanDeep =>
      isDark ? const Color(0xFF06254A) : const Color(0xFFDCEEFF);
  Color get gold => const Color(0xFFF2B84B);
  Color get success =>
      isDark ? const Color(0xFF38D996) : const Color(0xFF178B63);
  Color get warning =>
      isDark ? const Color(0xFFFFB45A) : const Color(0xFFB86500);
  Color get error => isDark ? const Color(0xFFFF7F8A) : const Color(0xFFCE3344);
  Color get shadowColor => navy.withValues(alpha: isDark ? 0.34 : 0.10);

  List<Color> get backgroundGradient => isDark
      ? const [Color(0xFF020817), Color(0xFF041226), Color(0xFF020817)]
      : const [Color(0xFFF9FCFF), Color(0xFFF2F8FE), Color(0xFFFFFFFF)];
}

class BoosterFishPageShell extends StatelessWidget {
  final Widget child;

  const BoosterFishPageShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BoosterFishPageBackgroundPainter(palette),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class BoosterFishPageHeader extends StatelessWidget {
  final String title;
  final String eyebrow;
  final String? subtitle;
  final bool backToHome;

  const BoosterFishPageHeader({
    super.key,
    required this.title,
    required this.eyebrow,
    this.subtitle,
    this.backToHome = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppBackButton(
          color: palette.textSecondary,
          toHome: backToHome,
        ),
        const SizedBox(width: 4),
        Container(
          width: 38,
          height: 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.25),
                blurRadius: 16,
              ),
            ],
          ),
          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class BoosterFishGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BoosterFishGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.isDark ? 0.94 : 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.isDark
              ? palette.accent.withValues(alpha: 0.44)
              : palette.borderStrong,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.isDark
                ? palette.accent.withValues(alpha: 0.10)
                : palette.navy.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class BoosterFishPageHero extends StatelessWidget {
  final String assetPath;
  final double height;
  final AlignmentGeometry alignment;

  const BoosterFishPageHero({
    super.key,
    required this.assetPath,
    this.height = 142,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.isDark
              ? palette.accent.withValues(alpha: 0.62)
              : palette.borderStrong,
        ),
        boxShadow: [
          BoxShadow(
            color:
                palette.accent.withValues(alpha: palette.isDark ? 0.20 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: alignment,
            filterQuality: FilterQuality.high,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: palette.isDark
                    ? [
                        const Color(0x00020817),
                        const Color(0x22020817),
                        const Color(0x66020817),
                      ]
                    : [
                        const Color(0x00FFFFFF),
                        const Color(0x0AFFFFFF),
                        const Color(0x24071A3F),
                      ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    palette.accent,
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterFishPageBackgroundPainter extends CustomPainter {
  final BoosterFishPagePalette palette;

  const _BoosterFishPageBackgroundPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: palette.backgroundGradient,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.accent.withValues(alpha: palette.isDark ? 0.12 : 0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.55, 0),
          radius: size.width * 0.9,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final wave = Paint()
      ..color = palette.accent.withValues(alpha: palette.isDark ? 0.045 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < 5; row++) {
      final yBase = size.height * (0.54 + row * 0.08);
      final path = Path()..moveTo(0, yBase);
      for (var x = 0.0; x <= size.width; x += 12) {
        path.lineTo(x, yBase + math.sin(x / 38 + row) * 9);
      }
      canvas.drawPath(path, wave);
    }
  }

  @override
  bool shouldRepaint(covariant _BoosterFishPageBackgroundPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark;
}
