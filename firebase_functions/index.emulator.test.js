'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {
  handleCommunityReportCreated,
  photoCleanupTaskId,
  processPhotoCleanupTask,
  recalculateCommunityReportCount,
  reconcileCommunityReportCountsPage,
  replaceLeaderboardState,
} = require('./index.js').__test;

const projectId = 'demo-boosterfish';
let adminApp;
let firestore;
let environment;

function catchData(overrides = {}) {
  return {
    ownerUid: 'owner-1',
    anglerName: 'Pêcheur Test',
    avatarUrl: '',
    photoUrl: 'https://example.invalid/community-photo',
    photoObjectKey: 'owner_abcdefghijklmnopqrstuvwx',
    species: 'Bar',
    weightKg: 4.2,
    zoneName: 'Zone approximative',
    likeCount: 0,
    reportCount: 0,
    status: 'published',
    createdAt: Timestamp.now(),
    expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    ...overrides,
  };
}

async function createReport(id, postId = 'post-1') {
  const reference = firestore.collection('community_reports').doc(id);
  await reference.set({
    reporterUid: id,
    postId,
    postOwnerUid: 'owner-1',
    reason: 'other',
    status: 'pending',
    createdAt: Timestamp.now(),
  });
  return reference.get();
}

test.before(async () => {
  const [host, portText] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {host, port: Number(portText)},
  });
  adminApp = initializeApp({projectId}, `community-functions-${Date.now()}`);
  firestore = getFirestore(adminApp);
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await environment.cleanup();
  await deleteApp(adminApp);
});

test('report creation is idempotent under duplicate event delivery',
    async () => {
  await firestore.collection('community_catches').doc('post-1').set(catchData());
  const reportSnapshot = await createReport('reporter-1');
  const event = {data: reportSnapshot};

  await Promise.all([
    handleCommunityReportCreated(event, firestore),
    handleCommunityReportCreated(event, firestore),
  ]);

  const post = await firestore.collection('community_catches').doc('post-1').get();
  assert.equal(post.data().reportCount, 1);
  assert.equal(post.data().status, 'published');
});

test('report aggregate is exact, hides at three, and can be recalculated down',
    async () => {
  await firestore.collection('community_catches').doc('post-1').set(catchData());
  const reports = await Promise.all(
    ['reporter-1', 'reporter-2', 'reporter-3'].map(
      (reporter) => createReport(reporter),
    ),
  );
  await Promise.all(
    reports.map((report) => handleCommunityReportCreated(
      {data: report},
      firestore,
    )),
  );
  let post = await firestore.collection('community_catches').doc('post-1').get();
  assert.equal(post.data().reportCount, 3);
  assert.equal(post.data().status, 'under_review');

  await firestore.collection('community_reports').doc('reporter-3').delete();
  await recalculateCommunityReportCount('post-1', {firestore});
  post = await firestore.collection('community_catches').doc('post-1').get();
  assert.equal(post.data().reportCount, 2);
  assert.equal(post.data().status, 'under_review');
});

test('scheduled reconciliation repairs pre-existing report aggregates',
    async () => {
  await firestore.collection('community_catches').doc('post-1').set(catchData({
    reportCount: 99,
  }));
  await createReport('reporter-1');
  await createReport('reporter-2');

  assert.equal(await reconcileCommunityReportCountsPage(firestore), 1);
  const post = await firestore.collection('community_catches').doc('post-1').get();
  const cursor = await firestore
    .collection('community_internal')
    .doc('report_reconciliation')
    .get();
  assert.equal(post.data().reportCount, 2);
  assert.equal(post.data().status, 'published');
  assert.equal(cursor.data().lastPostId, '');
});

test('empty weekly selection atomically clears old state and queues cleanup',
    async () => {
  const candidate = {
    catchId: 'old-catch',
    ownerUid: 'owner-1',
    anglerName: 'Ancien',
    avatarUrl: '',
    photoUrl: 'https://example.invalid/old-photo',
    photoObjectKey: 'owner_abcdefghijklmnopqrstuvwx',
    species: 'Bar',
    weightKg: 4.2,
    zoneName: 'Zone',
    likeCount: 2,
    createdAt: Timestamp.now(),
  };
  await firestore
    .collection('community_internal')
    .doc('weekly_leaderboard')
    .set({weekId: '2026-07-20', candidates: [candidate]});
  await firestore
    .collection('community_state')
    .doc('weekly_winner')
    .set({weekId: '2026-07-20', catchId: 'old-catch'});

  const retired = await replaceLeaderboardState([], '2026-07-27', firestore);
  assert.equal(retired.length, 1);
  const [leaderboard, winner, taskSnapshot] = await Promise.all([
    firestore.collection('community_internal').doc('weekly_leaderboard').get(),
    firestore.collection('community_state').doc('weekly_winner').get(),
    firestore.collection('community_cleanup_tasks')
      .doc(photoCleanupTaskId(candidate.catchId, candidate.photoObjectKey))
      .get(),
  ]);
  assert.equal(leaderboard.exists, false);
  assert.equal(winner.exists, false);
  assert.equal(taskSnapshot.exists, true);
  assert.equal(taskSnapshot.data().state, 'pending');
});

test('failed R2 cleanup remains queued and succeeds on a later retry',
    async () => {
  const candidate = {
    catchId: 'old-catch',
    photoObjectKey: 'owner_abcdefghijklmnopqrstuvwx',
  };
  await firestore.collection('community_catches').doc(candidate.catchId)
    .set(catchData());
  await firestore.collection('community_internal').doc('weekly_leaderboard')
    .set({weekId: '2026-07-20', candidates: [candidate]});
  await replaceLeaderboardState([], '2026-07-27', firestore);
  const taskReference = firestore.collection('community_cleanup_tasks')
    .doc(photoCleanupTaskId(candidate.catchId, candidate.photoObjectKey));
  let calls = 0;
  const first = await processPhotoCleanupTask(taskReference, {
    firestore,
    deletePhoto: async () => {
      calls += 1;
      throw new Error('temporary R2 outage');
    },
  });
  assert.equal(first.deferred, true);
  assert.equal((await taskReference.get()).data().state, 'pending');
  assert.equal(
    (await firestore.collection('community_catches').doc('old-catch').get())
      .exists,
    false,
  );

  await taskReference.update({nextAttemptAt: Timestamp.now()});
  const second = await processPhotoCleanupTask(taskReference, {
    firestore,
    deletePhoto: async () => {
      calls += 1;
    },
  });
  assert.equal(second.processed, true);
  assert.equal((await taskReference.get()).exists, false);
  assert.equal(calls, 2);
});

test('invalid legacy R2 key never prevents Firestore catch deletion',
    async () => {
  const candidate = {
    catchId: 'legacy-invalid-catch',
    photoObjectKey: '../invalid-object-key',
  };
  await firestore.collection('community_catches').doc(candidate.catchId)
    .set(catchData({photoObjectKey: candidate.photoObjectKey}));
  await firestore.collection('community_internal').doc('weekly_leaderboard')
    .set({weekId: '2026-07-20', candidates: [candidate]});
  await replaceLeaderboardState([], '2026-07-27', firestore);

  const taskReference = firestore.collection('community_cleanup_tasks')
    .doc(photoCleanupTaskId(candidate.catchId, candidate.photoObjectKey));
  const result = await processPhotoCleanupTask(taskReference, {firestore});
  const [post, task] = await Promise.all([
    firestore.collection('community_catches').doc(candidate.catchId).get(),
    taskReference.get(),
  ]);

  assert.equal(result.deferred, true);
  assert.equal(post.exists, false);
  assert.equal(task.exists, true);
  assert.equal(task.data().state, 'blocked');
  assert.match(task.data().lastError, /Invalid R2/);
});

test('cleanup lease prevents concurrent duplicate R2 deletion', async () => {
  const candidate = {
    catchId: 'old-catch',
    photoObjectKey: 'owner_abcdefghijklmnopqrstuvwx',
  };
  await firestore.collection('community_internal').doc('weekly_leaderboard')
    .set({weekId: '2026-07-20', candidates: [candidate]});
  await replaceLeaderboardState([], '2026-07-27', firestore);
  const taskReference = firestore.collection('community_cleanup_tasks')
    .doc(photoCleanupTaskId(candidate.catchId, candidate.photoObjectKey));
  let calls = 0;
  const deletePhoto = async () => {
    calls += 1;
    await new Promise((resolve) => setTimeout(resolve, 25));
  };
  const results = await Promise.all([
    processPhotoCleanupTask(taskReference, {firestore, deletePhoto}),
    processPhotoCleanupTask(taskReference, {firestore, deletePhoto}),
  ]);
  assert.equal(calls, 1);
  assert.equal(results.filter((result) => result.processed).length, 1);
  assert.equal((await taskReference.get()).exists, false);
});
