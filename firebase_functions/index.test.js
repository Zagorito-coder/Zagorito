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
  previousUtcWeek,
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

test('safeAvatarUrl only retains the exact trusted Google host', () => {
  const allowed =
    'https://lh3.googleusercontent.com/a/avatar_ABC-123=s96-c?sz=96';
  assert.equal(safeAvatarUrl(allowed), allowed);
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
    communityFunctions.deleteCommunityAccountData,
  ];
  for (const fn of functions) {
    assert.equal(fn.__endpoint.serviceAccountEmail, expected);
  }
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
