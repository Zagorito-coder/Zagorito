import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/l10n/app_localizations.dart';

void main() {
  test('les quatre catalogues de langue ont les mêmes clés non vides', () {
    const languageCodes = ['fr', 'en', 'es', 'ar'];
    final catalogs = <String, Map<String, String>>{};

    for (final code in languageCodes) {
      final json = jsonDecode(
        File('assets/lang/$code.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      catalogs[code] = _flatten(json);
    }

    final referenceKeys = catalogs['fr']!.keys.toSet();
    for (final entry in catalogs.entries) {
      expect(
        entry.value.keys.toSet(),
        referenceKeys,
        reason: 'Clés de traduction différentes pour ${entry.key}',
      );
      expect(
        entry.value.values.every((value) => value.trim().isNotEmpty),
        isTrue,
        reason: 'Traduction vide dans ${entry.key}',
      );
    }

    expect(catalogs['fr']!['map.searchHint'], 'Rechercher un spot...');
    expect(
      catalogs['fr']!['mySpots.favoriteLimitReached'],
      contains('30 favoris'),
    );
    expect(
      catalogs['fr']!['mySpots.personalLimitReached'],
      contains('30 spots personnels'),
    );
    expect(
      catalogs['fr']!['mySpots.addToMine'],
      'Ajouter à mes spots',
    );
    expect(
      catalogs['fr']!['mySpots.tapLocation'],
      startsWith('Maintenez'),
    );
    expect(referenceKeys, isNot(contains('mySpots.saveAndSubmit')));
    expect(referenceKeys, isNot(contains('mySpots.reviewNotice')));
    expect(referenceKeys, isNot(contains('mySpots.status.pending')));
  });

  test('la langue arabe utilise le drapeau marocain sans changer de locale',
      () {
    expect(AppLanguage.arabic.flag, '🇲🇦');
    expect(AppLanguage.arabic.code, 'ar');
    expect(AppLanguage.arabic.locale.languageCode, 'ar');
  });
}

Map<String, String> _flatten(
  Map<String, dynamic> source, [
  String prefix = '',
]) {
  final result = <String, String>{};
  for (final entry in source.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      result.addAll(_flatten(value, key));
    } else {
      result[key] = value.toString();
    }
  }
  return result;
}
