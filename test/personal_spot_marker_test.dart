import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/widgets/personal_spots_map_layer.dart';

void main() {
  const spot = UserSpot(
    id: 'private-spot',
    name: 'Spot privé',
    latitude: 30.5,
    longitude: -9.7,
    notes: '',
    dangerNotes: '',
    status: SpotModerationStatus.pending,
  );

  testWidgets(
    'un spot personnel reprend le point public en bleu marine',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PersonalSpotMapMarker(
                spot: spot,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(personalSpotMarkerNavy, const Color(0xFF0B2852));
      expect(
        find.byKey(const ValueKey<String>('personal-spot-navy-dot')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_on_rounded), findsNothing);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('personal-map-spot-private-spot'),
        ),
      );
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'la sélection conserve le style goutte avec la couleur personnelle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PersonalSpotMapMarker(
                spot: spot,
                selected: true,
                onTap: _noop,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('selected-personal-spot-navy-pin'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.phishing), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsNothing);
    },
  );
}

void _noop() {}
