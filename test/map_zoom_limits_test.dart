import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/utils/map_zoom_limits.dart';

void main() {
  test('la sélection automatique et le zoom manuel restent séparés', () {
    expect(MapZoomLimits.automaticCitySearch, 9.5);
    expect(MapZoomLimits.automaticSpotSelection, 16.0);
    expect(MapZoomLimits.manualMaximum, 20.0);
    expect(
      MapZoomLimits.automaticSpotSelection,
      lessThan(MapZoomLimits.manualMaximum),
    );
    expect(
      MapZoomLimits.automaticCitySearch,
      lessThan(MapZoomLimits.automaticSpotSelection),
    );
  });

  test('le zoom demandé par le pêcheur est borné entre 3x et 20x', () {
    expect(MapZoomLimits.clampManual(2), 3.0);
    expect(MapZoomLimits.clampManual(17), 17.0);
    expect(MapZoomLimits.clampManual(20), 20.0);
    expect(MapZoomLimits.clampManual(18), 18.0);
    expect(MapZoomLimits.clampManual(23), 20.0);
  });
}
