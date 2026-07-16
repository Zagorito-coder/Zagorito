// ============================================================
//  theme_controller.dart — Gestionnaire du thème Clair / Sombre
//  ChangeNotifier singleton — persiste via SharedPreferences
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur global du thème. Utilisé via [ThemeController.instance].
class ThemeController extends ChangeNotifier {
  ThemeController._() {
    _load();
  }
  static final ThemeController instance = ThemeController._();

  bool _isDark = false;

  bool get isDark => _isDark;
  bool get isLight => !_isDark;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('theme_is_dark') ?? false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', _isDark);
  }

  /// Bascule entre clair et sombre, puis notifie tous les listeners.
  void toggle() {
    _isDark = !_isDark;
    _save();
    notifyListeners();
  }

  /// Force un thème spécifique.
  void setDark(bool value) {
    if (_isDark == value) return;
    _isDark = value;
    _save();
    notifyListeners();
  }
}
