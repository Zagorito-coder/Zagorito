import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les paramètres restent défilables et exposent les licences', () {
    final source = File('lib/pages/settings_page.dart').readAsStringSync();

    expect(source, contains("ValueKey('settings-scroll-view')"));
    expect(source, contains('AlwaysScrollableScrollPhysics'));
    expect(source, isNot(contains('NeverScrollableScrollPhysics')));
    expect(source, contains('showLicensePage('));
    expect(source, contains('PackageInfo.fromPlatform()'));
    expect(source, contains('packageInfo.buildNumber'));
    expect(source, isNot(contains("applicationVersion: '1.0.6'")));
    expect(source, contains('BoxConstraints(minHeight: 56)'));
    expect(source, contains('assets/settings_hero.webp'));
    expect(source, contains('assets/settings_fishing_banner.webp'));
    expect(source, contains('cacheWidth:'));
  });

  test('le raccourci Mes spots ouvre l onglet réel sans écran factice', () {
    final settingsSource =
        File('lib/pages/settings_page.dart').readAsStringSync();
    final shellSource = File('lib/app_shell.dart').readAsStringSync();

    expect(settingsSource, contains('final VoidCallback? onOpenMySpots;'));
    expect(settingsSource, contains('onTap: onOpenMySpots!'));
    expect(settingsSource, isNot(contains('_showComingSoon')));
    expect(
      shellSource,
      contains(
        'onOpenMySpots: () => appShellKey.currentState?.navigateTo(2),',
      ),
    );
  });
}
