import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/compass_readings.dart';

void main() {
  test('Course over ground utilise le GPS et Heading le cap magnétique', () {
    final readings = CompassReadings(
      magneticHeadingDegrees: 42,
      gpsCourseOverGroundDegrees: 218,
    );

    expect(readings.displayValues, hasLength(2));
    expect(
      readings.displayValues.first.kind,
      CompassMetricKind.courseOverGround,
    );
    expect(readings.displayValues.first.degrees, 218);
    expect(readings.displayValues.last.kind, CompassMetricKind.heading);
    expect(readings.displayValues.last.degrees, 42);
  });

  test('le nord à 0 degré reste une donnée valide', () {
    final readings = CompassReadings(
      magneticHeadingDegrees: 0,
      gpsCourseOverGroundDegrees: 360,
    );

    expect(readings.magneticHeadingDegrees, 0);
    expect(readings.gpsCourseOverGroundDegrees, 0);
  });

  test('les valeurs non disponibles restent distinctes des valeurs à 0 degré',
      () {
    final readings = CompassReadings(
      magneticHeadingDegrees: double.nan,
      gpsCourseOverGroundDegrees: null,
    );

    expect(readings.magneticHeadingDegrees, isNull);
    expect(readings.gpsCourseOverGroundDegrees, isNull);
  });
}
