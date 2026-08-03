enum CompassMetricKind { courseOverGround, heading }

final class CompassMetricValue {
  const CompassMetricValue({
    required this.kind,
    required this.label,
    required this.degrees,
  });

  final CompassMetricKind kind;
  final String label;
  final double? degrees;
}

/// Sépare explicitement le cap GPS du cap magnétique avant affichage.
final class CompassReadings {
  CompassReadings({
    required double? magneticHeadingDegrees,
    required double? gpsCourseOverGroundDegrees,
  })  : magneticHeadingDegrees = _normalize(magneticHeadingDegrees),
        gpsCourseOverGroundDegrees = _normalize(gpsCourseOverGroundDegrees);

  final double? magneticHeadingDegrees;
  final double? gpsCourseOverGroundDegrees;

  List<CompassMetricValue> get displayValues => [
        CompassMetricValue(
          kind: CompassMetricKind.courseOverGround,
          label: 'Course over ground',
          degrees: gpsCourseOverGroundDegrees,
        ),
        CompassMetricValue(
          kind: CompassMetricKind.heading,
          label: 'Heading',
          degrees: magneticHeadingDegrees,
        ),
      ];

  static double? _normalize(double? value) {
    if (value == null || !value.isFinite) return null;
    return ((value % 360) + 360) % 360;
  }
}
