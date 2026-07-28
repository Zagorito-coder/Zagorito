import 'package:spots_app/models.dart';

class SpotSelectionRequest {
  const SpotSelectionRequest({required this.serial, required this.spot});

  final int serial;
  final Spot spot;
}
