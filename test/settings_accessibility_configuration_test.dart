import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les paramètres restent défilables et exposent les licences', () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();

    expect(source, contains("ValueKey('settings-scroll-view')"));
    expect(source, contains('AlwaysScrollableScrollPhysics'));
    expect(source, isNot(contains('NeverScrollableScrollPhysics')));
    expect(source, contains('showLicensePage('));
    expect(source, contains('BoxConstraints(minHeight: 56)'));
    expect(source, contains('assets/settings_hero.webp'));
    expect(source, contains('assets/settings_fishing_banner.webp'));
    expect(source, contains('cacheWidth:'));
  });
}
