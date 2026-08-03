import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la localisation reste facultative au démarrage', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final forecastSource =
        File('lib/pages/forecast_page.dart').readAsStringSync();

    expect(
      mainSource,
      contains('unawaited(_initLocation(requestAccess: false));'),
    );
    expect(forecastSource, isNot(contains('Geolocator.requestPermission()')));
  });

  test('les actions GPS partagent une explication et une récupération', () {
    final helper =
        File('lib/widgets/location_access_feedback.dart').readAsStringSync();
    final privateCatch = File(
      'lib/features/community/widgets/private_catch_form_sheet.dart',
    ).readAsStringSync();
    final communityMap = File(
      'lib/features/community/widgets/community_map_view.dart',
    ).readAsStringSync();

    expect(helper, contains('locationAccess.rationale'));
    expect(helper, contains('Geolocator.openAppSettings()'));
    expect(helper, contains('Geolocator.openLocationSettings()'));
    expect(privateCatch, contains('ensureLocationAccess(context)'));
    expect(communityMap, contains('ensureLocationAccess(context)'));
  });
}
