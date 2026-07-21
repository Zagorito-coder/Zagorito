import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models.dart';

void main() {
  group('Spot.fromCsv', () {
    test('conserve les virgules dans un champ entre guillemets', () {
      final spot = Spot.fromCsv(
        'Plage Test,33.5,-7.6,bar|dorade,"Zone rocheuse, acces facile"',
        index: 1,
      );

      expect(spot.name, 'Plage Test');
      expect(spot.latitude, 33.5);
      expect(spot.longitude, -7.6);
      expect(spot.fishTypes, ['bar', 'dorade']);
      expect(spot.notes, 'Zone rocheuse, acces facile');
    });

    test('accepte les guillemets doubles echappes', () {
      final spot = Spot.fromCsv(
        'Cap Test,35.0,-6.0,liche,"Spot dit ""du phare"""',
        index: 2,
      );

      expect(spot.notes, 'Spot dit "du phare"');
    });

    test('rejette une ligne dont les guillemets ne sont pas fermes', () {
      expect(
        () => Spot.fromCsv(
          'Cap Test,35.0,-6.0,liche,"Note incomplete',
          index: 3,
        ),
        throwsFormatException,
      );
    });
  });
}
