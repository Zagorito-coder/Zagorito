import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/features/community/services/community_privacy.dart';

void main() {
  test('community coordinates are reduced to a stable approximate grid cell',
      () {
    final first = approximateCommunityLocation(
      latitude: 33.5731104,
      longitude: -7.5898434,
    );
    final nearby = approximateCommunityLocation(
      latitude: 33.5739,
      longitude: -7.5901,
    );

    expect(first.latitude, nearby.latitude);
    expect(first.longitude, nearby.longitude);
    expect(first.latitude, isNot(33.5731104));
    expect(first.longitude, isNot(-7.5898434));
  });

  test('community coordinate reduction rejects impossible locations', () {
    expect(
      () => approximateCommunityLocation(latitude: 91, longitude: 0),
      throwsFormatException,
    );
    expect(
      () => approximateCommunityLocation(latitude: 0, longitude: 181),
      throwsFormatException,
    );
  });
}
