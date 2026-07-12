// ============================================================
//  language_selector.dart — Sélecteur de langue "mignon" flags only
//  3 drapeaux en ligne avec glow animé, sans texte visible
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Sélecteur compact "mignon" : seulement 3 drapeaux en ligne
/// avec effet glow, scale et border animés sur la sélection.
class CuteLanguageSelector extends StatelessWidget {
  const CuteLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, _) {
        final current = LanguageController.instance.currentLang;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((lang) {
            final isSelected = current == lang;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _CuteFlagButton(
                lang: lang,
                isSelected: isSelected,
                onTap: () {
                  if (!isSelected) {
                    HapticFeedback.selectionClick();
                    LanguageController.instance.setLanguage(lang);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bouton drapeau "mignon" — glow + scale + border animés
// ─────────────────────────────────────────────────────────────

class _CuteFlagButton extends StatefulWidget {
  final AppLanguage lang;
  final bool isSelected;
  final VoidCallback onTap;

  const _CuteFlagButton({
    required this.lang,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CuteFlagButton> createState() => _CuteFlagButtonState();
}

class _CuteFlagButtonState extends State<_CuteFlagButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isSelected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _CuteFlagButton old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSelected && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _glowColor {
    switch (widget.lang) {
      case AppLanguage.french:
        return const Color(0xFF0055A4); // bleu France
      case AppLanguage.english:
        return const Color(0xFFCF142B); // rouge UK
      case AppLanguage.arabic:
        return const Color(0xFF0B7A3E); // vert arabe
      case AppLanguage.spanish:
        return const Color(0xFFAA151B); // rouge Espagne
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = widget.isSelected
              ? 1.0 + (_pulseController.value * 0.12)
              : 1.0;
          final scale = _pressed ? 0.85 : pulse;
          final glowOpacity = widget.isSelected
              ? 0.35 + (_pulseController.value * 0.25)
              : 0.0;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Glow externe doux quand sélectionné
                boxShadow: [
                  if (widget.isSelected)
                    BoxShadow(
                      color: _glowColor.withValues(alpha: glowOpacity),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cercle de fond avec gradient subtil
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                tc.surfaceLight.withValues(alpha: 0.95),
                                tc.surface.withValues(alpha: 0.8),
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                tc.surfaceLight.withValues(alpha: 0.5),
                                tc.surfaceLight.withValues(alpha: 0.3),
                              ],
                            ),
                      border: Border.all(
                        color: widget.isSelected
                            ? _glowColor.withValues(alpha: 0.7)
                            : tc.glassBorder.withValues(alpha: 0.3),
                        width: widget.isSelected ? 2.5 : 1.2,
                      ),
                    ),
                  ),
                  // Drapeau emoji centré
                  Text(
                    widget.lang.flag,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.0,
                    ),
                  ),
                  // Petit indicateur "active dot" en bas à droite
                  if (widget.isSelected)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _glowColor,
                          border: Border.all(
                            color: tc.background,
                            width: 1.5,
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
    );
  }
}
