import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les écrans ne téléchargent pas de police à l’exécution', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final tidePage = File('lib/pages/tide_page.dart').readAsStringSync();

    expect(pubspec, isNot(contains('google_fonts:')));
    expect(tidePage, isNot(contains('GoogleFonts.')));
    expect(tidePage, isNot(contains('package:google_fonts')));
  });
}
