import 'package:spots_app/models/user_spot.dart';

/// One-shot navigation request from "Mes spots" to the main map.
class UserSpotSelectionRequest {
  const UserSpotSelectionRequest({
    required this.serial,
    required this.spot,
  });

  final int serial;
  final UserSpot spot;
}
