import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('App Check est activé avant les autres services Firebase', () {
    final source = File('lib/splash_bootstrap.dart').readAsStringSync();

    final firebaseInitialization =
        source.indexOf('await Firebase.initializeApp');
    final appCheckActivation =
        source.indexOf('await _activateAppCheckSafely();');
    final crashReportingInitialization =
        source.indexOf('await CrashReportingService.initialize();');
    final appShellNavigation =
        source.indexOf('Navigator.of(context).pushReplacement(');

    expect(firebaseInitialization, greaterThanOrEqualTo(0));
    expect(appCheckActivation, greaterThan(firebaseInitialization));
    expect(
      appCheckActivation,
      lessThan(crashReportingInitialization),
      reason:
          'App Check doit être actif avant que Crashlytics utilise Firebase.',
    );
    expect(
      appCheckActivation,
      lessThan(appShellNavigation),
      reason:
          'App Check doit être actif avant que les écrans utilisent Firestore.',
    );
    expect(
      'await _activateAppCheckSafely();'.allMatches(source),
      hasLength(1),
      reason: 'App Check ne doit être activé qu’une fois au démarrage.',
    );
  });
}
