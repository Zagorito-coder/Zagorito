// ============================================================
//  theme.dart — Thème personnalisé Spots App  
//  Support Clair ☀️ / Sombre 🌙 avec bascule dynamique
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spots_app/theme_controller.dart';

// ═══════════════════════════════════════════════════════════
//  PALETTES STATIQUES (compatibilité ascendante)
// ═══════════════════════════════════════════════════════════

/// Palette originale — mode SOMBRE (conservée pour compatibilité).
class AppColors {
  // Fonds
  static const Color background = Color(0xFF0A0E1F);
  static const Color surface    = Color(0xFF14182B);
  static const Color surfaceLight = Color(0xFF1E2340);

  // Accents océaniques
  static const Color oceanDeep   = Color(0xFF006994);
  static const Color oceanMedium = Color(0xFF0099CC);
  static const Color oceanLight  = Color(0xFF00B4D8);
  static const Color oceanFoam   = Color(0xFF90E0EF);

  // Accents pêche
  static const Color sunset = Color(0xFFFF6B35);
  static const Color coral  = Color(0xFFFF8C69);
  static const Color sand   = Color(0xFFF4E4C1);

  // Texte
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFFB0B8C8);
  static const Color textMuted     = Color(0xFF6B7280);

  // États
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);

  // Premium
  static const Color gold      = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE55C);
}

/// Palette — mode CLAIR ☀️ (inspirée ciel océanique lumineux).
class AppColorsLight {
  // Fonds
  static const Color background   = Color(0xFFF0F4F8);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFE8EDF2);

  // Accents océaniques (plus saturés pour contraster sur fond clair)
  static const Color oceanDeep   = Color(0xFF005A87);
  static const Color oceanMedium = Color(0xFF0088BB);
  static const Color oceanLight  = Color(0xFF00A3C4);
  static const Color oceanFoam   = Color(0xFF0077A3);

  // Accents pêche
  static const Color sunset = Color(0xFFE85D2E);
  static const Color coral  = Color(0xFFD96C50);
  static const Color sand   = Color(0xFFC9A96E);

  // Texte
  static const Color textPrimary   = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF5A6A7A);
  static const Color textMuted     = Color(0xFF8A9AAA);

  // États
  static const Color success = Color(0xFF0D9E6F);
  static const Color warning = Color(0xFFD97706);
  static const Color error   = Color(0xFFDC2626);

  // Premium
  static const Color gold      = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFB8860B);
}

// ═══════════════════════════════════════════════════════════
//  COULEURS ADAPTATIVES (utiliser celles-ci dans le UI)
// ═══════════════════════════════════════════════════════════

/// Accès dynamique aux couleurs selon le thème actif.
/// Usage : `ThemeColors.of(context).background`
class ThemeColors {
  final bool _isDark;

  const ThemeColors._(this._isDark);

  factory ThemeColors.of(BuildContext context) {
    return ThemeColors._(ThemeController.instance.isDark);
  }

  // Fonds
  Color get background   => _isDark ? AppColors.background   : AppColorsLight.background;
  Color get surface      => _isDark ? AppColors.surface      : AppColorsLight.surface;
  Color get surfaceLight => _isDark ? AppColors.surfaceLight : AppColorsLight.surfaceLight;
  Color get surfaceElevated => _isDark ? AppColors.surfaceLight : AppColorsLight.surfaceLight;

  // Accents océaniques
  Color get oceanDeep   => _isDark ? AppColors.oceanDeep   : AppColorsLight.oceanDeep;
  Color get oceanMedium => _isDark ? AppColors.oceanMedium : AppColorsLight.oceanMedium;
  Color get oceanLight  => _isDark ? AppColors.oceanLight  : AppColorsLight.oceanLight;
  Color get oceanFoam   => _isDark ? AppColors.oceanFoam   : AppColorsLight.oceanFoam;

  // Accents pêche
  Color get sunset => _isDark ? AppColors.sunset : AppColorsLight.sunset;
  Color get coral  => _isDark ? AppColors.coral  : AppColorsLight.coral;
  Color get sand   => _isDark ? AppColors.sand   : AppColorsLight.sand;

  // Texte
  Color get textPrimary   => _isDark ? AppColors.textPrimary   : AppColorsLight.textPrimary;
  Color get textSecondary => _isDark ? AppColors.textSecondary : AppColorsLight.textSecondary;
  Color get textMuted     => _isDark ? AppColors.textMuted     : AppColorsLight.textMuted;

  // États
  Color get success => _isDark ? AppColors.success : AppColorsLight.success;
  Color get warning => _isDark ? AppColors.warning : AppColorsLight.warning;
  Color get error   => _isDark ? AppColors.error   : AppColorsLight.error;

  // Premium
  Color get gold      => _isDark ? AppColors.gold      : AppColorsLight.gold;
  Color get goldLight => _isDark ? AppColors.goldLight : AppColorsLight.goldLight;

  // Helpers pour opacité / overlay
  Color get divider => _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
  Color get glassBorder => _isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
  Color get shadowColor => _isDark ? Colors.black.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.10);
  Color get navOverlay  => _isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
  Color get iconInactive => textMuted;
}

// ═══════════════════════════════════════════════════════════
//  STYLES DE TEXTE ADAPTATIFS
// ═══════════════════════════════════════════════════════════

class AppTextStyles {
  static const String fontFamily = 'Inter';

  static TextStyle headlineLarge(BuildContext context) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: ThemeColors.of(context).textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle headlineMedium(BuildContext context) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ThemeColors.of(context).textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle headlineSmall(BuildContext context) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ThemeColors.of(context).textPrimary,
      );

  static TextStyle titleLarge(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ThemeColors.of(context).textPrimary,
      );

  static TextStyle bodyLarge(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ThemeColors.of(context).textPrimary,
        height: 1.5,
      );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: ThemeColors.of(context).textSecondary,
        height: 1.4,
      );

  static TextStyle labelLarge(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ThemeColors.of(context).textSecondary,
        letterSpacing: 0.5,
      );

  static TextStyle labelMedium(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: ThemeColors.of(context).textMuted,
        letterSpacing: 0.3,
      );
}

// ═══════════════════════════════════════════════════════════
//  DÉCORATIONS ADAPTATIVES
// ═══════════════════════════════════════════════════════════

class AppDecorations {
  static BoxDecoration glassCard(BuildContext context) {
    final tc = ThemeColors.of(context);
    return BoxDecoration(
      color: tc.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: tc.glassBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: tc.shadowColor,
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassIntense(BuildContext context) {
    final tc = ThemeColors.of(context);
    return BoxDecoration(
      color: tc.surface.withValues(alpha: 0.70),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: tc.glassBorder.withValues(alpha: 0.15),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: tc.shadowColor.withValues(alpha: 0.4),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: tc.oceanDeep.withValues(alpha: 0.08),
          blurRadius: 40,
          spreadRadius: 5,
        ),
      ],
    );
  }

  static BoxDecoration primaryButton(BuildContext context) {
    final tc = ThemeColors.of(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tc.oceanMedium, tc.oceanDeep],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: tc.oceanDeep.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration secondaryButton(BuildContext context) {
    final tc = ThemeColors.of(context);
    return BoxDecoration(
      color: tc.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tc.glassBorder, width: 1),
    );
  }

  static BoxDecoration inputField(BuildContext context) {
    final tc = ThemeColors.of(context);
    return BoxDecoration(
      color: tc.surface.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tc.glassBorder, width: 1),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  THÈMES MATERIAL COMPLETS
// ═══════════════════════════════════════════════════════════

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(isDark: true);
  static ThemeData get lightTheme => _buildTheme(isDark: false);

  static ThemeData _buildTheme({required bool isDark}) {
    final tc = ThemeColors._(isDark);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: tc.background,

      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: tc.oceanMedium,
        onPrimary: Colors.white,
        secondary: tc.sunset,
        onSecondary: Colors.white,
        surface: tc.surface,
        onSurface: tc.textPrimary,
        error: tc.error,
        onError: Colors.white,
        surfaceContainerHighest: tc.surfaceLight,
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: tc.background.withValues(alpha: 0.9),
        foregroundColor: tc.textPrimary,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tc.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: tc.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: tc.oceanMedium,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tc.textPrimary,
          side: BorderSide(color: tc.glassBorder.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tc.oceanLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tc.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tc.surface.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tc.oceanMedium, width: 2),
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: tc.textSecondary,
          height: 1.4,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: tc.textSecondary,
          height: 1.4,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tc.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: tc.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: tc.textPrimary,
          height: 1.5,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tc.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: tc.divider,
        thickness: 1,
      ),

      iconTheme: IconThemeData(
        color: tc.textSecondary,
        size: 24,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tc.background,
        selectedItemColor: tc.oceanLight,
        unselectedItemColor: tc.textMuted,
        elevation: 0,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  BOUTON TOGGLE CLAIR / SOMBRE (réutilisable)
// ═══════════════════════════════════════════════════════════

/// Icône animée + tap pour basculer le thème.
/// À placer dans l'AppBar ou n'importe où dans le UI.
class ThemeToggleButton extends StatelessWidget {
  final double size;
  const ThemeToggleButton({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final isDark = ThemeController.instance.isDark;

    return GestureDetector(
      onTap: () => ThemeController.instance.toggle(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tc.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: tc.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.5, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
            key: ValueKey<bool>(isDark),
            color: isDark ? tc.gold : tc.oceanMedium,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EXTENSIONS (compatibilité)
// ═══════════════════════════════════════════════════════════

extension ThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
}
