import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/features/community/models/private_catch.dart';

void main() {
  test('private catch database round-trip keeps kilograms and account scope',
      () {
    final caughtAt = DateTime.utc(2026, 7, 20);
    final createdAt = DateTime.utc(2026, 7, 21);
    final original = PrivateCatch(
      id: 'private-catch-1',
      ownerUid: 'owner-1',
      photoPath: '/private/photo.jpg',
      species: 'Bar',
      weightKg: 4.25,
      spotName: 'Zone privée',
      latitude: 33.5,
      longitude: -7.6,
      montage: 'Surfcasting',
      bait: 'Sardine',
      notes: 'Mer agitée',
      advice: 'Pêcher au montant',
      caughtAt: caughtAt,
      createdAt: createdAt,
    );

    final restored = PrivateCatch.fromDatabase(original.toDatabase());
    expect(restored.ownerUid, 'owner-1');
    expect(restored.weightKg, 4.25);
    expect(restored.latitude, 33.5);
    expect(restored.longitude, -7.6);
    expect(
      restored.caughtAt.millisecondsSinceEpoch,
      caughtAt.millisecondsSinceEpoch,
    );
  });

  test('private catch limits are fixed at 20 photos and 2 MiB', () {
    expect(PrivateCatch.maximumItems, 20);
    expect(PrivateCatch.maximumPhotoBytes, 2 * 1024 * 1024);
    expect(
      PrivateCatchDraft(
        photoBytes: Uint8List(1),
        species: 'Bar',
        weightKg: 1,
        spotName: '',
        montage: '',
        bait: '',
        notes: '',
        advice: '',
        caughtAt: DateTime.utc(2026),
      ).weightKg,
      1,
    );
  });

  group('active publication protection', () {
    final now = DateTime.utc(2026, 9, 2, 8);

    PrivateCatch publishedAt(DateTime? date) => PrivateCatch(
          id: 'private-catch-1',
          ownerUid: 'owner-1',
          photoPath: '/private/photo.jpg',
          species: 'Bar',
          weightKg: 4.25,
          spotName: 'Zone privée',
          latitude: 33.5,
          longitude: -7.6,
          montage: '',
          bait: '',
          notes: '',
          advice: '',
          caughtAt: now,
          createdAt: now,
          publishedPostId: 'public-post-1',
          publishedAt: date,
        );

    test('blocks republication during the seven-day public lifetime', () {
      final item = publishedAt(now.subtract(const Duration(days: 6)));

      expect(
        item.hasActivePublicationAt(
          now,
          publicationLifetime: const Duration(days: 7),
        ),
        isTrue,
      );
    });

    test('allows republication once the seven-day lifetime has expired', () {
      final item = publishedAt(now.subtract(const Duration(days: 7)));

      expect(
        item.hasActivePublicationAt(
          now,
          publicationLifetime: const Duration(days: 7),
        ),
        isFalse,
      );
    });

    test('keeps legacy publication records protected when the date is absent',
        () {
      expect(
        publishedAt(null).hasActivePublicationAt(
          now,
          publicationLifetime: const Duration(days: 7),
        ),
        isTrue,
      );
    });
  });
}
