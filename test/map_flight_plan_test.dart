import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/utils/map_flight_plan.dart';

void main() {
  test('le vol commence et termine exactement aux positions demandées', () {
    final plan = MapFlightPlan.adaptive(
      start: const LatLng(31, -8),
      target: const LatLng(35, -2),
      startZoom: 16,
      targetZoom: 16,
      distanceKm: 700,
    );

    expect(plan.centerAt(0), const LatLng(31, -8));
    expect(plan.centerAt(1), const LatLng(35, -2));
    expect(plan.zoomAt(0), 16);
    expect(plan.zoomAt(1), 16);
    expect(plan.cruiseZoom, lessThan(plan.startZoom));
  });

  test('la durée augmente avec la distance tout en restant bornée', () {
    MapFlightPlan plan(double distanceKm) => MapFlightPlan.adaptive(
          start: const LatLng(31, -8),
          target: const LatLng(32, -7),
          startZoom: 10,
          targetZoom: 16,
          distanceKm: distanceKm,
        );

    expect(plan(100).duration, greaterThan(plan(1).duration));
    expect(plan(100000).duration, const Duration(milliseconds: 1800));
    expect(plan(0).duration, const Duration(milliseconds: 750));
  });

  test('le trajet choisit le chemin court à travers l’antiméridien', () {
    final plan = MapFlightPlan.adaptive(
      start: const LatLng(0, 179),
      target: const LatLng(0, -179),
      startZoom: 8,
      targetZoom: 16,
      distanceKm: 220,
    );

    expect(plan.centerAt(0.46).longitude.abs(), greaterThan(170));
    expect(plan.centerAt(1), const LatLng(0, -179));
  });

  test('le zoom reste au niveau de croisière pendant la traversée', () {
    final plan = MapFlightPlan.adaptive(
      start: const LatLng(31, -8),
      target: const LatLng(35, -2),
      startZoom: 16,
      targetZoom: 16,
      distanceKm: 700,
    );

    expect(plan.zoomAt(0.4), plan.cruiseZoom);
    expect(plan.zoomAt(0.6), plan.cruiseZoom);
  });
}
