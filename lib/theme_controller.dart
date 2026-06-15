// ============================================================
//  theme_controller.dart — Gestionnaire du thème Clair / Sombre
//  ChangeNotifier singleton — aucune dépendance externe
// ============================================================

import 'package:flutter/material.dart';

/// Contrôleur global du thème. Utilisé via [ThemeController.instance].
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  bool _isDark = true;

  bool get isDark => _isDark;
  bool get isLight => !_isDark;

  /// Bascule entre clair et sombre, puis notifie tous les listeners.
  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  /// Force un thème spécifique.
  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
  }
}
