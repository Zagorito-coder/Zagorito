import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/services/favorite_spot_service.dart';
import 'package:spots_app/services/user_spot_service.dart';

void main() {
  test('moderation status defaults safely to pending', () {
    expect(
      SpotModerationStatus.fromValue('approved'),
      SpotModerationStatus.approved,
    );
    expect(
      SpotModerationStatus.fromValue('rejected'),
      SpotModerationStatus.rejected,
    );
    expect(
      SpotModerationStatus.fromValue('unexpected'),
      SpotModerationStatus.pending,
    );
  });

  test('location key rounds coordinates for moderation review', () {
    expect(
      UserSpotService.locationKey(30.421987, -9.612345),
      '30.422_-9.612',
    );
  });

  test('photo and duplicate limits stay explicit', () {
    expect(UserSpot.maximumPhotoBytes, 2 * 1024 * 1024);
    expect(UserSpot.duplicateRadiusMeters, 100);
  });

  test('favorite and personal spot quotas stay independent', () {
    expect(FavoriteSpotService.maximumFavorites, 30);
    expect(UserSpot.maximumPersonalSpots, 30);
  });
}
