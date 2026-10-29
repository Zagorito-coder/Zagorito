import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/technique.dart';

void main() {
  const ids = <String>{
    'palomar',
    'uni',
    'improved-clinch',
    'rapala',
    'blood',
    'albright',
    'fg',
    'dropper-loop',
    'three-way-swivel-rig',
    'yucatan',
    'snell',
    'perfection-loop',
    'bimini-twist',
    'san-diego-jam',
    'offshore-swivel',
  };

  test('chaque tutoriel référence une illustration locale dédiée', () {
    for (final id in ids) {
      final technique = Technique.fromCsvRow([
        id,
        'Nom',
        'Catégorie',
        'Description',
        '',
        'Poissons',
        'Technique',
        'Facile',
        'Matériel',
        'Conseil',
        'Étape 1|Étape 2|Étape 3|Étape 4',
      ]);
      final expectedPath = 'assets/images/techniques_v2/$id.webp';

      expect(technique.photoUrl, expectedPath, reason: id);
      expect(File(expectedPath).existsSync(), isTrue, reason: id);
    }
  });

  test('les quatre catalogues ont les mêmes identifiants dans le même ordre',
      () {
    const suffixes = ['Fr', 'En', 'Es', 'Ar'];
    List<String>? reference;

    for (final suffix in suffixes) {
      final file = File('assets/peche_Montagestechnique_database$suffix.csv');
      final rows = file
          .readAsLinesSync()
          .skip(1)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final catalogIds = rows.map((line) => line.split(';').first).toList();

      expect(catalogIds.toSet(), ids, reason: suffix);
      expect(catalogIds.length, ids.length, reason: suffix);
      reference ??= catalogIds;
      expect(catalogIds, reference, reason: suffix);
      for (final row in rows) {
        final columns = row.split(';');
        expect(columns.length, 11, reason: '$suffix: $row');
        expect(
          columns[10].split('|').where((step) => step.trim().isNotEmpty).length,
          greaterThanOrEqualTo(4),
          reason: '$suffix: tutoriel incomplet pour ${columns.first}',
        );
      }
    }
  });
}
