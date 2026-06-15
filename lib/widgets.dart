// ============================================================
//  widgets.dart — Composants UI réutilisables
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/l10n/app_localizations.dart';

/// Légende interactive des types de spots
class SpotLegend extends StatelessWidget {
  final SpotType? selectedType;
  final Function(SpotType?)? onTypeSelected;

  const SpotLegend({
    super.key,
    this.selectedType,
    this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.glassCard(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.legend_toggle,
                size: 14,
                color: tc.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('common.legend'),
                style: AppTextStyles.labelMedium(context).copyWith(
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...SpotType.values.map((type) => _buildLegendItem(context, type)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, SpotType type) {
    final tc = ThemeColors.of(context);
    final isSelected = selectedType == type;
    final color = type.color;

    return GestureDetector(
      onTap: () => onTypeSelected?.call(isSelected ? null : type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : tc.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 10 : 8,
              height: isSelected ? 10 : 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                type.label,
                style: AppTextStyles.labelMedium(context).copyWith(
                  color: isSelected
                      ? tc.textPrimary
                      : tc.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 12,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// Badge de compteur animé
class AnimatedCounter extends StatelessWidget {
  final int count;
  final String label;
  final Color? color;

  const AnimatedCounter({
    super.key,
    required this.count,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final effectiveColor = color ?? tc.oceanMedium;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              effectiveColor.withValues(alpha: 0.2),
              effectiveColor.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: effectiveColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: AppTextStyles.titleLarge(context).copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton flottant amélioré avec glassmorphism
class GlassFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  const GlassFloatingButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tc.surface.withValues(alpha: 0.9),
              tc.surfaceLight.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: tc.glassBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: tc.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: color ?? tc.textPrimary,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }
}

/// Indicateur de chargement animé
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: AppDecorations.glassCard(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                tc.oceanMedium,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: AppTextStyles.bodyMedium(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip d'information stylisé
class InfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final chipColor = color ?? tc.oceanMedium;

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: chipColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: chipColor.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: chip);
    }

    return chip;
  }
}

/// Header de section avec ligne décorative
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tc.oceanMedium, tc.oceanDeep],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: tc.textSecondary,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: AppTextStyles.labelLarge(context).copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Barre de recherche améliorée (Stateful pour gérer le bouton clear)
class EnhancedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSubmitted;

  const EnhancedSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Rechercher un spot...',
    this.onChanged,
    this.onClear,
    this.onSubmitted,
  });

  @override
  State<EnhancedSearchBar> createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant EnhancedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      decoration: AppDecorations.glassIntense(context),
      child: TextField(
        controller: widget.controller,
        style: AppTextStyles.bodyLarge(context),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTextStyles.bodyMedium(context),
          prefixIcon: Icon(
            Icons.search,
            color: tc.textSecondary,
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: tc.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: widget.onChanged,
        onSubmitted: (_) => widget.onSubmitted?.call(),
      ),
    );
  }
}

/// Panneau de détails animé
class AnimatedDetailsPanel extends StatelessWidget {
  final Widget child;
  final bool isVisible;
  final VoidCallback? onClose;

  const AnimatedDetailsPanel({
    super.key,
    required this.child,
    required this.isVisible,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: AppDecorations.glassIntense(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Effet de vague pour décoration
class WaveDecoration extends StatelessWidget {
  final double height;
  final Color? color;

  const WaveDecoration({
    super.key,
    this.height = 60,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _WavePainter(color: color ?? tc.oceanDeep),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height * 0.5 +
          10 * math.sin(x / size.width * 4 * math.pi);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
