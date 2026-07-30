import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'les outils ferment le spot et une nouvelle sélection ferme les outils',
    () {
      final source = File(
        'lib/main.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');

      expect(
        source,
        contains(
          "key: const ValueKey<String>('map-tools-toggle')",
        ),
      );
      expect(
        source,
        contains(
          'if (shouldOpen) {\n'
          '            _clearSelection();\n'
          '          }',
        ),
      );
      expect(
        source,
        contains(
          '_selectedSpot = spot;\n'
          '      _selectedUserSpot = null;\n'
          '      _pendingPersonalSpot = null;\n'
          "      _searchQuery = '';\n"
          '      _showToolsPanel = false;',
        ),
      );
    },
  );

  test('la fermeture du panneau désactive toujours le vent du spot', () {
    final source = File(
      'lib/main.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final clearSelectionStart = source.indexOf('void _clearSelection()');
    final nextMethod = source.indexOf(
      'void _startAddingSpot()',
      clearSelectionStart,
    );

    expect(clearSelectionStart, greaterThanOrEqualTo(0));
    expect(nextMethod, greaterThan(clearSelectionStart));

    final clearSelection = source.substring(clearSelectionStart, nextMethod);
    expect(
      clearSelection,
      contains("context.read<WindAnimationProvider>().disable();"),
    );
    expect(clearSelection, contains('setState(() => _selectedSpot = null);'));
  });
}
