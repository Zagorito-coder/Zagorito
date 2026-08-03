import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la fiche Intelligence utilise un scroll paresseux par spot', () {
    final source = File(
      'lib/widgets/fish_intelligence_modal.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(source, contains("'fish-intelligence-scroll'"));
    expect(source, contains('child: CustomScrollView('));
    expect(source, isNot(contains('child: SingleChildScrollView(')));
    expect(source, contains('delegate: SliverChildBuilderDelegate('));
    expect(source, contains('childCount: nearbySpots.length'));
    expect(source, contains('onTap: () => onSpotSelected(spot)'));
  });

  test('la scène cartographique est mise au repos derrière la fiche', () {
    final source = File(
      'lib/main.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(source, contains('listenable: FishProvider.instance'));
    expect(
      source,
      contains('enabled: !FishProvider.instance.isFishModalVisible'),
    );
    expect(
      source,
      contains(
        'if (fp.isFishModalVisible) {\n'
        '                      return const SizedBox.shrink();\n'
        '                    }',
      ),
    );
  });
}
