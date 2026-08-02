import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/widgets/fish_image_framing.dart';

void main() {
  test('tous les poissons Intelligence Pêcheur ont une image locale valide',
      () {
    final decoded =
        jsonDecode(File('assets/fish_data.json').readAsStringSync());
    final fish = (decoded as List<dynamic>).cast<Map<String, dynamic>>();

    expect(
      fish.map((entry) => entry['id']).toSet(),
      containsAll(<String>{
        'daurade_royale',
        'loup_bar',
        'sar_commun',
        'congre',
        'pageot',
        'maquereau',
        'mulet',
        'sole',
      }),
    );

    expect(
      fish.map((entry) => entry['id']).toSet(),
      isNot(contains(anyOf('thon_rouge', 'rouget'))),
    );

    final fishById = <String, Map<String, dynamic>>{
      for (final entry in fish) entry['id'] as String: entry,
    };
    expect(fishById['sar_commun']?['name'], 'Sar commun');
    expect(fishById['sar_commun']?['scientificName'], 'Diplodus sargus');
    expect(
      fishById['sar_commun']?['imageUrl'],
      'assets/fish_images/sar commun.png',
    );
    expect(fishById['congre']?['name'], 'Congre');
    expect(fishById['congre']?['scientificName'], 'Conger conger');
    expect(
      fishById['congre']?['imageUrl'],
      'assets/fish_images/congre.png',
    );

    for (final entry in fish) {
      final imagePath = entry['imageUrl'] as String;
      expect(
        imagePath,
        startsWith('assets/fish_images/'),
        reason: 'Chemin local invalide pour ${entry['name']}',
      );
      expect(
        File(imagePath).existsSync(),
        isTrue,
        reason: 'Image absente pour ${entry['name']}: $imagePath',
      );
    }
  });

  test('chaque vignette Intelligence Pêcheur possède un cadrage explicite', () {
    final decoded =
        jsonDecode(File('assets/fish_data.json').readAsStringSync());
    final fish = (decoded as List<dynamic>).cast<Map<String, dynamic>>();

    for (final entry in fish) {
      final fishId = entry['id'] as String;
      expect(
        FishImageFraming.hasThumbnailFraming(fishId),
        isTrue,
        reason: 'Cadrage manquant pour $fishId',
      );
      expect(
        FishImageFraming.thumbnailScale(fishId),
        inInclusiveRange(1.0, 1.8),
      );
    }
  });
}
