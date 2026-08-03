import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le badge Mes spots suit uniquement une création confirmée', () {
    final mapSource = File('lib/main.dart').readAsStringSync();
    final confirmation = mapSource.indexOf('if (!created || !mounted) return;');
    final notification = mapSource.indexOf(
      'widget.onPersonalSpotCreated?.call();',
    );

    expect(confirmation, greaterThanOrEqualTo(0));
    expect(notification, greaterThan(confirmation));
    expect(mapSource, contains('duration: const Duration(seconds: 3)'));
    expect(mapSource, contains('persist: false'));
  });

  test('le badge est persistant, plafonné et effacé à la consultation', () {
    final shellSource = File('lib/app_shell.dart').readAsStringSync();

    expect(shellSource, contains('unread_personal_spot_badge_count'));
    expect(shellSource, contains('notifyPersonalSpotCreated'));
    expect(shellSource, contains("badgeCount > 99 ? '99+'"));
    expect(shellSource, contains("'personal-spot-notification-badge'"));
    expect(shellSource, contains('final openedMySpots = index == 2;'));
    expect(shellSource, contains('_persistPersonalSpotBadge(0)'));
  });
}
