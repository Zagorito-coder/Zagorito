'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const communityFunctions = require('./index.js');
const {
  cleanupRetryDate,
  deleteR2Photo,
  isValidR2ObjectKey,
  photoCleanupTaskId,
  safeAvatarUrl,
  safeAvatarId,
  previousUtcWeek,
  avatarPatch,
  currentProfileAvatar,
  currentProfileName,
  hasPublicAvatarIdentity,
  profileIdentityPatch,
} = communityFunctions.__test;

test('previousUtcWeek returns the complete previous Monday-to-Monday window', () => {
  const result = previousUtcWeek(new Date('2026-07-29T18:30:00.000Z'));
  assert.equal(result.weekId, '2026-07-20');
  assert.equal(result.start.toISOString(), '2026-07-20T00:00:00.000Z');
  assert.equal(result.end.toISOString(), '2026-07-27T00:00:00.000Z');
});

test('previousUtcWeek is stable when called on a Monday', () => {
  const result = previousUtcWeek(new Date('2026-07-27T00:05:00.000Z'));
  assert.equal(result.weekId, '2026-07-20');
  assert.equal(result.end.toISOString(), '2026-07-27T00:00:00.000Z');
});

test('safeAvatarUrl only retains trusted Google and owned Storage paths', () => {
  const allowed =
    'https://lh3.googleusercontent.com/a/avatar_ABC-123=s96-c?sz=96';
  assert.equal(safeAvatarUrl(allowed), allowed);
  const storageAvatar =
    'https://firebasestorage.googleapis.com/v0/b/'
    + 'zagorito-9a0c4.firebasestorage.app/o/'
    + 'profile_avatars%2Fowner-1%2Favatar.jpg'
    + '?alt=media&token=abcdefghijklmnopqrst-1234567890&v=1788312345678';
  assert.equal(safeAvatarUrl(storageAvatar), storageAvatar);
  assert.equal(safeAvatarUrl('https://tracker.example/avatar.png'), '');
  assert.equal(
    safeAvatarUrl(
      'https://lh3.googleusercontent.com.tracker.example/avatar.png',
    ),
    '',
  );
  assert.equal(
    safeAvatarUrl(
      'https://tracker.example@lh3.googleusercontent.com/avatar.png',
    ),
    '',
  );
  assert.equal(
    safeAvatarUrl('https://lh3.googleusercontent.com:444/avatar.png'),
    '',
  );
  assert.equal(
    safeAvatarUrl(storageAvatar.replace('owner-1', '..%2Fother')),
    '',
  );
  assert.equal(safeAvatarUrl(storageAvatar.replace('v=1788312345678', 'v=x')), '');
  assert.equal(safeAvatarUrl(`${storageAvatar}&v=1788312345679`), '');
  assert.equal(safeAvatarId('fisher_01'), 'fisher_01');
  assert.equal(safeAvatarId('fisher_10'), 'fisher_10');
  assert.equal(safeAvatarId('fisher_11'), '');
});

test('R2 object keys and cleanup task IDs are deterministic and constrained',
    () => {
  const valid = 'owner_abcdefghijklmnopqrstuvwx';
  assert.equal(isValidR2ObjectKey(valid), true);
  assert.equal(isValidR2ObjectKey('../community-photo'), false);
  assert.equal(isValidR2ObjectKey('short'), false);
  assert.equal(
    photoCleanupTaskId('catch-1', valid),
    photoCleanupTaskId('catch-1', valid),
  );
  assert.notEqual(
    photoCleanupTaskId('catch-1', valid),
    photoCleanupTaskId('catch-2', valid),
  );
  assert.equal(photoCleanupTaskId('catch-1', valid).length, 64);
});

test('cleanup backoff starts at five minutes and is capped at six hours',
    () => {
  const now = new Date('2026-08-01T10:00:00.000Z');
  assert.equal(
    cleanupRetryDate(1, now).toISOString(),
    '2026-08-01T10:05:00.000Z',
  );
  assert.equal(
    cleanupRetryDate(50, now).toISOString(),
    '2026-08-01T16:00:00.000Z',
  );
});

test('R2 deletion is idempotent for 204/404 and rejects other statuses',
    async () => {
  for (const status of [204, 404]) {
    let requestedUrl;
    await deleteR2Photo('owner_abcdefghijklmnopqrstuvwx', {
      adminKey: 'test-key',
      fetchImpl: async (url, options) => {
        requestedUrl = url.toString();
        assert.equal(options.method, 'DELETE');
        assert.equal(options.headers['X-Community-Admin-Key'], 'test-key');
        return {status};
      },
    });
    assert.match(requestedUrl, /community-admin\/photos\/owner_/);
  }
  await assert.rejects(
    deleteR2Photo('owner_abcdefghijklmnopqrstuvwx', {
      adminKey: 'test-key',
      fetchImpl: async () => ({status: 503}),
    }),
    /HTTP 503/,
  );
  await assert.rejects(
    deleteR2Photo('../invalid-object-key', {
      adminKey: 'test-key',
      fetchImpl: async () => ({status: 204}),
    }),
    /Invalid R2/,
  );
});

test('Firestore cleanup triggers explicitly enable delivery retries', () => {
  assert.equal(
    communityFunctions.onCommunityReportCreated
      .__endpoint.eventTrigger.retry,
    true,
  );
  assert.equal(
    communityFunctions.onCommunityCatchDeleted
      .__endpoint.eventTrigger.retry,
    true,
  );
});

test('all community functions use the dedicated least-privilege identity',
    () => {
  const expected =
    'boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com';
  const functions = [
    communityFunctions.selectWeeklyCommunityWinner,
    communityFunctions.cleanupExpiredCommunityCatches,
    communityFunctions.reconcileCommunityReportCounts,
    communityFunctions.onCommunityReportCreated,
    communityFunctions.onCommunityCatchDeleted,
    communityFunctions.onCommunityPublicProfileWritten,
    communityFunctions.onCommunityCatchCreated,
    communityFunctions.deleteCommunityAccountData,
  ];
  for (const fn of functions) {
    assert.equal(fn.__endpoint.serviceAccountEmail, expected);
  }
});

test('avatar sync triggers are retried and use the expected documents', () => {
  for (const [fn, document] of [
    [communityFunctions.onCommunityPublicProfileWritten,
      'community_public_profiles/{userId}'],
    [communityFunctions.onCommunityCatchCreated, 'community_catches/{postId}'],
  ]) {
    assert.equal(fn.__endpoint.eventTrigger.retry, true);
    assert.equal(fn.__endpoint.eventTrigger.eventFilterPathPatterns.document,
      document);
  }
});

test('avatar synchronization preserves explicit and legacy anonymity', () => {
  assert.equal(hasPublicAvatarIdentity({anglerName: 'Nadir'}), true);
  assert.equal(hasPublicAvatarIdentity({
    anglerName: 'Nadir', publishAnonymously: false,
  }), true);
  for (const data of [
    {},
    {anglerName: ''},
    {anglerName: 'Pêcheur anonyme'},
    {anglerName: ' Pêcheur anonyme '},
    {anglerName: 'Pêcheur anonyme', publishAnonymously: false},
    {anglerName: 'Nadir', publishAnonymously: true},
    {anglerName: 'Nadir', publishAnonymously: 'false'},
  ]) {
    assert.equal(hasPublicAvatarIdentity(data), false);
    assert.equal(avatarPatch(data, {avatarId: 'fisher_02', avatarUrl: ''}), null);
  }
});

test('current avatar resolves only presets and owned custom photos', () => {
  const base = {schemaVersion: 2, ownerUid: 'owner-1'};
  const googlePhoto = 'https://lh3.googleusercontent.com/a/test=s96-c';
  assert.deepEqual(currentProfileAvatar({
    ...base, avatarSource: 'preset', avatarId: 'fisher_10',
  }, 'owner-1'), {avatarId: 'fisher_10', avatarUrl: ''});
  const photo = 'https://firebasestorage.googleapis.com/v0/b/'
    + 'zagorito-9a0c4.firebasestorage.app/o/'
    + 'profile_avatars%2Fowner-1%2Favatar.jpg'
    + '?alt=media&token=abcdefghijklmnopqrst-1234567890&v=1788312345678';
  assert.deepEqual(currentProfileAvatar({
    ...base, avatarSource: 'custom', avatarUrl: photo,
  }, 'owner-1'), {avatarId: '', avatarUrl: photo});
  for (const profile of [
    null,
    {...base, schemaVersion: 1, avatarSource: 'google'},
    {...base, ownerUid: 'other', avatarSource: 'google'},
    {...base, avatarSource: 'preset', avatarId: 'fisher_99'},
    {...base, avatarSource: 'custom', avatarUrl: googlePhoto},
    {...base, avatarSource: 'custom', avatarUrl: photo.replace('owner-1', 'other')},
    {...base, avatarSource: 'custom', avatarUrl: 'https://evil.invalid/x'},
    {...base, avatarSource: 'unknown'},
  ]) {
    assert.equal(currentProfileAvatar(profile, 'owner-1'), null);
  }
});

test('Google profile choices never produce a synchronization patch', () => {
  for (const avatarUrl of ['', 'https://lh3.googleusercontent.com/a/current']) {
    const avatar = currentProfileAvatar({
      schemaVersion: 2, ownerUid: 'owner-1', avatarSource: 'google', avatarUrl,
    }, 'owner-1');
    assert.equal(avatar, null);
    assert.equal(avatarPatch({anglerName: 'Nadir', avatarId: 'fisher_01'}, avatar),
      null);
  }
});

test('avatar patches are limited to avatar fields and duplicates are no-ops', () => {
  const avatar = {avatarId: '', avatarUrl: 'https://lh3.googleusercontent.com/a/x'};
  assert.equal(avatarPatch({anglerName: 'Nadir', ...avatar}, avatar), null);
  assert.deepEqual(avatarPatch({
    anglerName: 'Nadir', avatarId: 'fisher_01', avatarUrl: '', likeCount: 17,
  }, avatar), avatar);
  assert.equal(avatarPatch({anglerName: 'Nadir'}, null), null);
});

test('public names require the owned non-anonymous profile', () => {
  const profile = {
    schemaVersion: 2, ownerUid: 'owner-1', publishAnonymously: false,
    avatarSource: 'google', publicDisplayName: '  Nouveau surnom  ',
  };
  assert.equal(currentProfileName(profile, 'owner-1'), 'Nouveau surnom');
  assert.equal(currentProfileName({...profile, schemaVersion: 1}, 'owner-1'),
    'Nouveau surnom');
  for (const invalid of [
    null,
    {...profile, ownerUid: 'owner-2'},
    {...profile, schemaVersion: 3},
    {...profile, publishAnonymously: true},
    {...profile, publicDisplayName: ' '},
    {...profile, publicDisplayName: 'x'},
    {...profile, publicDisplayName: 'x'.repeat(41)},
    {...profile, publicDisplayName: 'Pêcheur anonyme'},
  ]) {
    assert.equal(currentProfileName(invalid, 'owner-1'), null);
  }
});

test('nickname patch changes only public names and never anonymous posts', () => {
  const post = {anglerName: 'Ancien', avatarId: 'fisher_01', likeCount: 17};
  assert.deepEqual(profileIdentityPatch(post, null, 'Nouveau'),
    {anglerName: 'Nouveau'});
  const avatar = {avatarId: 'fisher_02', avatarUrl: ''};
  assert.deepEqual(profileIdentityPatch(post, avatar, 'Nouveau'), {
    avatarId: 'fisher_02', avatarUrl: '', anglerName: 'Nouveau',
  });
  assert.deepEqual(avatar, {avatarId: 'fisher_02', avatarUrl: ''});
  assert.equal(profileIdentityPatch({...post, anglerName: 'Nouveau'}, null,
    'Nouveau'), null);
  assert.equal(profileIdentityPatch({...post, publishAnonymously: true}, null,
    'Nouveau'), null);
  assert.equal(profileIdentityPatch({...post, anglerName: 'Pêcheur anonyme'},
    null, 'Nouveau'), null);
});

test('community maintenance stays within the three free scheduler jobs',
    () => {
  const scheduledFunctions = [
    communityFunctions.selectWeeklyCommunityWinner,
    communityFunctions.cleanupExpiredCommunityCatches,
    communityFunctions.reconcileCommunityReportCounts,
  ];
  assert.equal(
    scheduledFunctions.filter(
      (fn) => fn.__endpoint.scheduleTrigger != null,
    ).length,
    3,
  );
  assert.equal(communityFunctions.retryCommunityCleanupTasks, undefined);
});
