import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/spots_canvas_layer.dart';

void main() {
  group('noms des spots sur la carte', () {
    test('commencent exactement au zoom 14', () {
      expect(shouldPaintSpotNames(13.999), isFalse);
      expect(shouldPaintSpotNames(14), isTrue);
      expect(shouldPaintSpotNames(15), isTrue);
      expect(shouldPaintSpotNames(16), isTrue);
      expect(
        shouldPaintSpotNames(15, hasSelectedSpot: true),
        isFalse,
      );
    });

    test('utilise la droite quand elle est libre', () {
      final rect = findSpotNameLabelRect(
        markerPosition: const Offset(100, 100),
        markerRadius: 6,
        labelSize: const Size(80, 20),
        viewport: const Rect.fromLTWH(0, 0, 240, 200),
        occupiedLabels: const <Rect>[],
        markerPositions: const <Offset>[Offset(100, 100)],
        markerIndex: 0,
      );

      expect(rect, const Rect.fromLTWH(111, 90, 80, 20));
    });

    test('bascule a gauche pres du bord droit', () {
      final rect = findSpotNameLabelRect(
        markerPosition: const Offset(220, 100),
        markerRadius: 6,
        labelSize: const Size(80, 20),
        viewport: const Rect.fromLTWH(0, 0, 240, 200),
        occupiedLabels: const <Rect>[],
        markerPositions: const <Offset>[Offset(220, 100)],
        markerIndex: 0,
      );

      expect(rect, const Rect.fromLTWH(129, 90, 80, 20));
    });

    test('evite un nom deja place et les autres marqueurs', () {
      final rect = findSpotNameLabelRect(
        markerPosition: const Offset(100, 100),
        markerRadius: 6,
        labelSize: const Size(80, 20),
        viewport: const Rect.fromLTWH(0, 0, 240, 200),
        occupiedLabels: const <Rect>[Rect.fromLTWH(111, 92, 84, 16)],
        markerPositions: const <Offset>[
          Offset(100, 100),
          Offset(70, 100),
        ],
        markerIndex: 0,
      );

      expect(rect, const Rect.fromLTWH(60, 69, 80, 20));
    });

    test('n affiche rien quand les quatre positions sont occupees', () {
      final rect = findSpotNameLabelRect(
        markerPosition: const Offset(100, 100),
        markerRadius: 6,
        labelSize: const Size(80, 20),
        viewport: const Rect.fromLTWH(0, 0, 240, 200),
        occupiedLabels: const <Rect>[
          Rect.fromLTWH(108, 88, 90, 24),
          Rect.fromLTWH(8, 88, 90, 24),
          Rect.fromLTWH(58, 66, 84, 24),
          Rect.fromLTWH(58, 108, 84, 24),
        ],
        markerPositions: const <Offset>[Offset(100, 100)],
        markerIndex: 0,
      );

      expect(rect, isNull);
    });
  });
}
