// ============================================================
//  app_localizations.dart — Système de localisation i18n
//  Langues : Français (par défaut) 🇫🇷, English 🇬🇧, العربية 🇸🇦
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Énumération des langues supportées
enum AppLanguage {
  french('fr', 'Français', '🇫🇷'),
  english('en', 'English', '🇬🇧'),
  arabic('ar', 'العربية', '🇸🇦');

  final String code;
  final String label;
  final String flag;

  const AppLanguage(this.code, this.label, this.flag);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.french,
    );
  }

  /// Retourne le Locale Flutter correspondant
  Locale get locale {
    switch (this) {
      case AppLanguage.arabic:
        return const Locale('ar', '');
      case AppLanguage.english:
        return const Locale('en', '');
      case AppLanguage.french:
        return const Locale('fr', '');
    }
  }

  /// Direction du texte pour cette langue
  TextDirection get textDirection {
    switch (this) {
      case AppLanguage.arabic:
        return TextDirection.rtl;
      case AppLanguage.english:
      case AppLanguage.french:
        return TextDirection.ltr;
    }
  }
}

/// Contrôleur global de la langue (singleton)
class LanguageController extends ChangeNotifier {
  LanguageController._();
  static final LanguageController instance = LanguageController._();

  AppLanguage _currentLang = AppLanguage.french;

  AppLanguage get currentLang => _currentLang;
  Locale get locale => _currentLang.locale;
  bool get isRtl => _currentLang.textDirection == TextDirection.rtl;
  String get langCode => _currentLang.code;

  /// Change la langue active
  void setLanguage(AppLanguage lang) {
    if (_currentLang == lang) return;
    _currentLang = lang;
    notifyListeners();
  }

  /// Bascule vers la langue suivante (pour un cycle rapide)
  void cycleLanguage() {
    final idx = AppLanguage.values.indexOf(_currentLang);
    final next = AppLanguage.values[(idx + 1) % AppLanguage.values.length];
    setLanguage(next);
  }
}

/// Extension pratique sur BuildContext pour accéder aux traductions
extension LocalizedString on BuildContext {
  String tr(String key) => AppLocalizations.of(this).translate(key);
  String trArgs(String key, {required Map<String, String> args}) =>
      AppLocalizations.of(this).trArgs(key, args: args);
}

/// Classe principale de localisation — charge les traductions JSON
class AppLocalizations {
  final Locale locale;
  late Map<String, dynamic> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('fr', ''),
    Locale('en', ''),
    Locale('ar', ''),
  ];

  /// Traduit une clé. Supporte les clés imbriquées avec des points.
  /// Ex: "home.title" → {"home": {"title": "..."}}
  String translate(String key) {
    final keys = key.split('.');
    dynamic value = _localizedStrings;
    for (final k in keys) {
      if (value is! Map<String, dynamic>) return key;
      value = value[k];
      if (value == null) return key;
    }
    return value.toString();
  }

  /// Traduit avec interpolation de variables
  /// Ex: tr('welcome.name', args: {'name': 'John'})
  String trArgs(String key, {required Map<String, String> args}) {
    String result = translate(key);
    args.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
    return result;
  }

  Future<bool> load() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      _localizedStrings = json.decode(jsonString) as Map<String, dynamic>;
      return true;
    } catch (e) {
      // Fallback: charge le français si la langue demandée n'existe pas
      if (locale.languageCode != 'fr') {
        final fallback = await rootBundle.loadString('assets/lang/fr.json');
        _localizedStrings = json.decode(fallback) as Map<String, dynamic>;
        return true;
      }
      _localizedStrings = {};
      return false;
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['fr', 'en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
