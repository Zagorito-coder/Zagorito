import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/features/community/models/community_catch.dart';
import 'package:spots_app/features/community/widgets/live_community_catch_builder.dart';

CommunityCatch catchWithAvatar({
  String id = 'post-1',
  String anglerName = 'Nadir',
  String avatarId = '',
  String avatarUrl = '',
}) {
  return CommunityCatch(
    id: id,
    ownerUid: 'owner-1',
    anglerName: anglerName,
    avatarUrl: avatarUrl,
    avatarId: avatarId,
    photoUrl: 'https://example.invalid/catch.jpg',
    photoObjectKey: 'owner_abcdefghijklmnopqrstuvwx',
    species: 'Bar',
    weightKg: 2,
    zoneName: 'Zone',
    latitude: 30,
    longitude: -9,
    montage: '',
    bait: '',
    notes: '',
    advice: '',
    likeCount: 4,
    createdAt: DateTime(2026, 9, 19),
    expiresAt: DateTime(2026, 9, 26),
  );
}

void main() {
  testWidgets('an open detail follows a public nickname change',
      (tester) async {
    final stream = StreamController<List<CommunityCatch>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
      home: LiveCommunityCatchBuilder(
        initialItem: catchWithAvatar(),
        stream: stream.stream,
        builder: (_, item) => Text(item?.anglerName ?? 'unavailable'),
      ),
    ));
    expect(find.text('Nadir'), findsOneWidget);
    stream.add([catchWithAvatar(anglerName: 'NadirFish')]);
    await tester.pumpAndSettle();
    expect(find.text('NadirFish'), findsOneWidget);
    expect(find.text('Nadir'), findsNothing);
  });

  testWidgets('an open detail follows preset, photo and version changes',
      (tester) async {
    final stream = StreamController<List<CommunityCatch>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
      home: LiveCommunityCatchBuilder(
        initialItem: catchWithAvatar(avatarId: 'fisher_01'),
        stream: stream.stream,
        builder: (_, item) => Text(item == null
            ? 'unavailable'
            : '${item.id}:${item.avatarId}:${item.avatarUrl}'),
      ),
    ));
    expect(find.text('post-1:fisher_01:'), findsOneWidget);
    for (final url in ['photo.jpg?v=1', 'photo.jpg?v=2']) {
      stream.add([
        catchWithAvatar(id: 'other', avatarId: 'fisher_09'),
        catchWithAvatar(avatarUrl: url),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('post-1::$url'), findsOneWidget);
      expect(find.text('post-1:fisher_01:'), findsNothing);
    }
    stream.add([catchWithAvatar(avatarId: 'fisher_05')]);
    await tester.pumpAndSettle();
    expect(find.text('post-1:fisher_05:'), findsOneWidget);
  });

  testWidgets('a removed post never falls back to its initial identity',
      (tester) async {
    final stream = StreamController<List<CommunityCatch>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
      home: LiveCommunityCatchBuilder(
        initialItem: catchWithAvatar(avatarId: 'fisher_01'),
        stream: stream.stream,
        builder: (_, item) => Text(item?.avatarId ?? 'unavailable'),
      ),
    ));
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('unavailable'), findsOneWidget);
    expect(find.text('fisher_01'), findsNothing);
  });

  testWidgets('a stream error hides the stale detail and can recover',
      (tester) async {
    final stream = StreamController<List<CommunityCatch>>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
      home: LiveCommunityCatchBuilder(
        initialItem: catchWithAvatar(avatarId: 'fisher_01'),
        stream: stream.stream,
        builder: (_, item) => Text(item?.avatarId ?? 'unavailable'),
      ),
    ));
    stream.addError(StateError('permission denied'));
    await tester.pumpAndSettle();
    expect(find.text('unavailable'), findsOneWidget);
    stream.add([catchWithAvatar(avatarId: 'fisher_04')]);
    await tester.pumpAndSettle();
    expect(find.text('fisher_04'), findsOneWidget);
  });
}
