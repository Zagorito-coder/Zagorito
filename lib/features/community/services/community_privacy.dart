import 'dart:math' as math;

class ApproximateCommunityLocation {
  const ApproximateCommunityLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// Publishes only the centre of an approximately five-kilometre grid cell.
///
/// The exact private coordinates never leave the device through this helper.
ApproximateCommunityLocation approximateCommunityLocation({
  required double latitude,
  required double longitude,
}) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -85 ||
      latitude > 85 ||
      longitude < -180 ||
      longitude > 180) {
    throw const FormatException('Invalid coordinates');
  }
  const latitudeStep = 0.045;
  // Quantise the latitude used to calculate the longitude step as well.
  // Otherwise tiny latitude changes would slightly alter the public longitude
  // and could reveal more precision than the intended grid cell.
  final latitudeBand = ((latitude / 5).floor() * 5 + 2.5).clamp(-82.5, 82.5);
  final cosine = math.cos(latitudeBand * math.pi / 180).abs().clamp(0.2, 1.0);
  final longitudeStep = (latitudeStep / cosine).clamp(0.045, 0.225);

  double gridCentre(double value, double step) {
    return ((value / step).floor() + 0.5) * step;
  }

  return ApproximateCommunityLocation(
    latitude: gridCentre(latitude, latitudeStep).clamp(-85.0, 85.0),
    longitude: gridCentre(longitude, longitudeStep).clamp(-180.0, 180.0),
  );
}
