'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
const {
  deleteCommunityAccountDataForUid,
  handleCommunityReportCreated,
  photoCleanupTaskId,
  processPhotoCleanupTask,
  recalculateCommunityReportCount,
  reconcileCommunityReportCountsPage,
  retryCommunityCleanupTasksPage,
  replaceLeaderboardState,
  synchronizeProfileIdentity,
  synchronizeProfileDocuments,
  handlePublicProfileWritten,
  handleCommunityCatchCreated,
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

test('account deletion removes the owner data without touching other users',
    async () => {
  const uid = 'account-owner';
  const otherUid = 'other-owner';
  const ownedPost = firestore.collection('community_catches').doc('owned-post');
  const survivorPost =
    firestore.collection('community_catches').doc('survivor-post');
  const deletedLike = survivorPost.collection('likes').doc(uid);
  const survivorLike = survivorPost.collection('likes').doc(otherUid);
  const ownedBlock = firestore.collection('community_blocks').doc(uid)
    .collection('users').doc(otherUid);
  const reverseBlock = firestore.collection('community_blocks').doc(otherUid)
    .collection('users').doc(uid);
  const survivorBlock = firestore.collection('community_blocks').doc(otherUid)
    .collection('users').doc('third-user');

  await Promise.all([
    ownedPost.set(catchData({
      ownerUid: uid,
      photoObjectKey: 'owner_abcdefghijklmnopqrstuvwx',
      likeCount: 1,
    })),
    ownedPost.collection('likes').doc(otherUid).set({likerUid: otherUid}),
    survivorPost.set(catchData({
      ownerUid: otherUid,
      photoObjectKey: 'other_abcdefghijklmnopqrstuvwx',
      likeCount: 2,
      reportCount: 2,
    })),
    deletedLike.set({likerUid: uid}),
    survivorLike.set({likerUid: otherUid}),
    firestore.collection('community_reports').doc('reported-by-owner').set({
      reporterUid: uid,
      postId: survivorPost.id,
      postOwnerUid: otherUid,
    }),
    firestore.collection('community_reports').doc('report-about-owner').set({
      reporterUid: otherUid,
      postId: ownedPost.id,
      postOwnerUid: uid,
    }),
    firestore.collection('community_reports').doc('survivor-report').set({
      reporterUid: otherUid,
      postId: survivorPost.id,
      postOwnerUid: otherUid,
    }),
    ownedBlock.set({blockedUid: otherUid}),
    reverseBlock.set({blockedUid: uid}),
    survivorBlock.set({blockedUid: 'third-user'}),
    firestore.collection('community_profiles').doc(uid).set({accepted: true}),
    firestore.collection('community_public_profiles').doc(uid)
      .set({displayName: 'Anonymous'}),
    firestore.collection('community_publish_state').doc(uid)
      .set({lastPublishedAt: Timestamp.now()}),
  ]);

  const deletedPhotos = [];
  const deletedProfileAvatars = [];
  await deleteCommunityAccountDataForUid(uid, {
    firestore,
    deletePhoto: async (objectKey) => deletedPhotos.push(objectKey),
    deleteProfileAvatar: async (ownerUid) =>
      deletedProfileAvatars.push(ownerUid),
  });

  const [
    ownedPostAfter,
    survivorPostAfter,
    deletedLikeAfter,
    survivorLikeAfter,
    reportedByOwnerAfter,
    reportAboutOwnerAfter,
    survivorReportAfter,
    ownedBlockAfter,
    reverseBlockAfter,
    survivorBlockAfter,
    profileAfter,
    publicProfileAfter,
    publishStateAfter,
    cleanupTasksAfter,
  ] = await Promise.all([
    ownedPost.get(),
    survivorPost.get(),
    deletedLike.get(),
    survivorLike.get(),
    firestore.collection('community_reports').doc('reported-by-owner').get(),
    firestore.collection('community_reports').doc('report-about-owner').get(),
    firestore.collection('community_reports').doc('survivor-report').get(),
    ownedBlock.get(),
    reverseBlock.get(),
    survivorBlock.get(),
    firestore.collection('community_profiles').doc(uid).get(),
    firestore.collection('community_public_profiles').doc(uid).get(),
    firestore.collection('community_publish_state').doc(uid).get(),
    firestore.collection('community_cleanup_tasks').get(),
  ]);

  assert.equal(ownedPostAfter.exists, false);
  assert.equal(survivorPostAfter.exists, true);
  assert.equal(survivorPostAfter.data().likeCount, 1);
  assert.equal(survivorPostAfter.data().reportCount, 1);
  assert.equal(deletedLikeAfter.exists, false);
  assert.equal(survivorLikeAfter.exists, true);
  assert.equal(reportedByOwnerAfter.exists, false);
  assert.equal(reportAboutOwnerAfter.exists, false);
  assert.equal(survivorReportAfter.exists, true);
  assert.equal(ownedBlockAfter.exists, false);
  assert.equal(reverseBlockAfter.exists, false);
  assert.equal(survivorBlockAfter.exists, true);
  assert.equal(profileAfter.exists, false);
  assert.equal(publicProfileAfter.exists, false);
  assert.equal(publishStateAfter.exists, false);
  assert.equal(cleanupTasksAfter.empty, true);
  assert.deepEqual(deletedPhotos, ['owner_abcdefghijklmnopqrstuvwx']);
  assert.deepEqual(deletedProfileAvatars, [uid]);
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
  const retried = await retryCommunityCleanupTasksPage(firestore, {
    deletePhoto: async () => {
      calls += 1;
    },
  });
  assert.equal(retried, 1);
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

function avatarUrl(version = '1789812345678') {
  return 'https://firebasestorage.googleapis.com/v0/b/'
    + 'zagorito-9a0c4.firebasestorage.app/o/'
    + 'profile_avatars%2Fowner-1%2Favatar.jpg'
    + `?alt=media&token=abcdefghijklmnopqrst-1234567890&v=${version}`;
}

async function saveAvatarProfile(overrides = {}) {
  const ref = firestore.collection('community_public_profiles').doc('owner-1');
  await ref.set({
    schemaVersion: 2,
    ownerUid: 'owner-1',
    publicDisplayName: 'Pêcheur Test',
    publishAnonymously: false,
    avatarSource: 'custom',
    avatarId: '',
    avatarUrl: avatarUrl(),
    ...overrides,
  });
  return ref.get();
}

test('profile sync updates existing avatars, never other content or anonymity',
    async () => {
  await saveAvatarProfile();
  const originals = new Map();
  for (const [id, extra] of [
    ['legacy-public', {avatarId: 'fisher_01'}],
    ['explicit-public', {publishAnonymously: false, avatarId: 'fisher_02'}],
    ['legacy-anonymous', {anglerName: 'Pêcheur anonyme'}],
    ['explicit-anonymous', {publishAnonymously: true}],
    ['other-owner', {ownerUid: 'owner-2', avatarId: 'fisher_03'}],
    ['archived', {status: 'archived', avatarId: 'fisher_04'}],
  ]) {
    const data = catchData({...extra, likeCount: 7, reportCount: 2});
    originals.set(id, data);
    await firestore.collection('community_catches').doc(id).set(data);
  }
  const options = {firestore};
  assert.equal(await synchronizeProfileIdentity('owner-1', options), 3);
  assert.equal(await synchronizeProfileIdentity('owner-1', options), 0);
  for (const [id, original] of originals) {
    const after = (await firestore.collection('community_catches').doc(id).get())
      .data();
    const changed = ['legacy-public', 'explicit-public', 'archived'].includes(id);
    assert.deepEqual(after, changed
      ? {...original, avatarId: '', avatarUrl: avatarUrl()} : original);
  }
  // Selecting anonymity for future posts must not reveal old anonymous posts
  // or rename/retroactively anonymize the already public ones.
  await saveAvatarProfile({
    publishAnonymously: true, avatarSource: 'preset', avatarId: 'fisher_08',
    avatarUrl: '',
  });
  assert.equal(await synchronizeProfileIdentity('owner-1', options), 3);
  assert.equal((await firestore.collection('community_catches')
    .doc('legacy-anonymous').get()).data().avatarUrl, '');
});

test('nickname sync updates only owned public posts and weekly copies',
    async () => {
  await saveAvatarProfile({
    publicDisplayName: 'Nouveau surnom', avatarSource: 'google',
    avatarId: '', avatarUrl: '',
  });
  const old = catchData({
    avatarUrl: 'https://lh3.googleusercontent.com/a/original=s96-c',
    likeCount: 7, reportCount: 2,
  });
  const anonymous = catchData({
    anglerName: 'Pêcheur anonyme', publishAnonymously: true,
  });
  const other = catchData({ownerUid: 'owner-2'});
  const posts = firestore.collection('community_catches');
  await Promise.all([
    posts.doc('public').set(old),
    posts.doc('archived').set({...old, status: 'archived'}),
    posts.doc('anonymous').set(anonymous),
    posts.doc('other').set(other),
  ]);
  const candidate = {...old, catchId: 'public'};
  const leaderboard = firestore.collection('community_internal')
    .doc('weekly_leaderboard');
  const winner = firestore.collection('community_state').doc('weekly_winner');
  const initialWinner = {
    catchId: 'public', anglerName: old.anglerName,
    avatarUrl: old.avatarUrl, weekId: 'week', announcedAt: Timestamp.now(),
  };
  await leaderboard.set({weekId: 'week', candidates: [candidate]});
  await winner.set(initialWinner);

  assert.equal(await synchronizeProfileIdentity('owner-1', {firestore}), 2);
  assert.equal(await synchronizeProfileIdentity('owner-1', {firestore}), 0);
  for (const id of ['public', 'archived']) {
    assert.deepEqual((await posts.doc(id).get()).data(), {
      ...old, ...(id === 'archived' ? {status: 'archived'} : {}),
      anglerName: 'Nouveau surnom',
    });
  }
  assert.deepEqual((await posts.doc('anonymous').get()).data(), anonymous);
  assert.deepEqual((await posts.doc('other').get()).data(), other);
  assert.deepEqual((await leaderboard.get()).data().candidates, [
    {...candidate, anglerName: 'Nouveau surnom'},
  ]);
  assert.deepEqual((await winner.get()).data(), {
    ...initialWinner, anglerName: 'Nouveau surnom',
  });
});

test('anonymous profile choice does not retroactively rename public posts',
    async () => {
  await saveAvatarProfile({
    publishAnonymously: true, publicDisplayName: '',
    avatarSource: 'google', avatarId: '', avatarUrl: '',
  });
  const post = firestore.collection('community_catches').doc('public');
  await post.set(catchData());
  assert.equal(await synchronizeProfileIdentity('owner-1', {firestore}), 0);
  assert.equal((await post.get()).data().anglerName, 'Pêcheur Test');
  await saveAvatarProfile({
    publicDisplayName: 'Nouveau surnom', avatarSource: 'google',
    avatarId: '', avatarUrl: '',
  });
  assert.equal(await synchronizeProfileIdentity('owner-1', {firestore}), 1);
  assert.equal((await post.get()).data().anglerName, 'Nouveau surnom');
});

test('late and duplicate profile events cannot restore an older photo',
    async () => {
  const oldProfile = await saveAvatarProfile();
  const post = firestore.collection('community_catches').doc('post-1');
  await post.set(catchData({avatarId: 'fisher_01'}));
  const latestUrl = avatarUrl('1789812345679');
  await saveAvatarProfile({avatarUrl: latestUrl});
  const oldEvent = {params: {userId: 'owner-1'}, data: {after: oldProfile}};
  await Promise.all([
    handlePublicProfileWritten(oldEvent, {firestore}),
    handlePublicProfileWritten(oldEvent, {firestore}),
  ]);
  assert.equal((await post.get()).data().avatarUrl, latestUrl);
  await firestore.collection('community_public_profiles').doc('owner-1').delete();
  await handlePublicProfileWritten(oldEvent, {firestore});
  assert.equal((await post.get()).data().avatarUrl, latestUrl);
});

test('late nickname events use the latest profile, not the event snapshot',
    async () => {
  const olderProfile = await saveAvatarProfile({
    publicDisplayName: 'Ancien surnom', avatarSource: 'google',
    avatarId: '', avatarUrl: '',
  });
  const post = firestore.collection('community_catches').doc('post-1');
  await post.set(catchData());
  await saveAvatarProfile({
    publicDisplayName: 'Dernier surnom', avatarSource: 'google',
    avatarId: '', avatarUrl: '',
  });
  const event = {params: {userId: 'owner-1'}, data: {after: olderProfile}};
  await Promise.all([
    handlePublicProfileWritten(event, {firestore}),
    handlePublicProfileWritten(event, {firestore}),
  ]);
  assert.equal((await post.get()).data().anglerName, 'Dernier surnom');
});

test('a post created from a stale device profile is reconciled on creation',
    async () => {
  await saveAvatarProfile();
  const post = firestore.collection('community_catches').doc('new-post');
  await post.set(catchData({avatarId: 'fisher_01'}));
  const event = {data: await post.get()};
  await handleCommunityCatchCreated(event, {firestore});
  assert.equal((await post.get()).data().avatarUrl, avatarUrl());
  await post.delete();
  await handleCommunityCatchCreated(event, {firestore});
  assert.equal((await post.get()).exists, false);
});

test('a new post from a stale device receives the current nickname',
    async () => {
  await saveAvatarProfile({
    publicDisplayName: 'Nouveau surnom', avatarSource: 'google',
    avatarId: '', avatarUrl: '',
  });
  const post = firestore.collection('community_catches').doc('new-post');
  const original = catchData({
    avatarUrl: 'https://lh3.googleusercontent.com/a/original=s96-c',
  });
  await post.set(original);
  await handleCommunityCatchCreated({data: await post.get()}, {firestore});
  assert.deepEqual((await post.get()).data(), {
    ...original, anglerName: 'Nouveau surnom',
  });
});

test('profile synchronization paginates beyond one transaction page', async () => {
  await saveAvatarProfile({avatarSource: 'preset', avatarId: 'fisher_06'});
  const batch = firestore.batch();
  for (let index = 0; index < 103; index += 1) {
    batch.set(firestore.collection('community_catches').doc(`page-${index}`),
      catchData({avatarId: 'fisher_01'}));
  }
  await batch.commit();
  assert.equal(await synchronizeProfileIdentity('owner-1', {firestore}), 103);
  assert.equal(await synchronizeProfileIdentity('owner-1', {firestore}), 0);
});

test('custom and preset transitions clear the previous avatar kind',
    async () => {
  const post = firestore.collection('community_catches').doc('post-1');
  await post.set(catchData({avatarId: 'fisher_01'}));
  const options = {firestore};
  for (const [profile, expected] of [
    [{}, {avatarId: '', avatarUrl: avatarUrl()}],
    [{avatarUrl: avatarUrl('1789812345679')},
      {avatarId: '', avatarUrl: avatarUrl('1789812345679')}],
    [{avatarSource: 'preset', avatarId: 'fisher_07', avatarUrl: ''},
      {avatarId: 'fisher_07', avatarUrl: ''}],
  ]) {
    await saveAvatarProfile(profile);
    await synchronizeProfileIdentity('owner-1', options);
    const data = (await post.get()).data();
    assert.equal(data.avatarId, expected.avatarId);
    assert.equal(data.avatarUrl, expected.avatarUrl);
  }
});

test('Google choice leaves unchanged names and avatars untouched on late events',
    async () => {
  const previousProfile = await saveAvatarProfile();
  await saveAvatarProfile({avatarSource: 'google', avatarId: '', avatarUrl: ''});
  const post = firestore.collection('community_catches').doc('google-post');
  const original = catchData({
    avatarId: '', avatarUrl: 'https://lh3.googleusercontent.com/a/original=s96-c',
  });
  await post.set(original);
  const olderPost = firestore.collection('community_catches').doc('preset-post');
  const older = catchData({avatarId: 'fisher_03'});
  await olderPost.set(older);
  const leaderboard = firestore.collection('community_internal')
    .doc('weekly_leaderboard');
  const winner = firestore.collection('community_state').doc('weekly_winner');
  const candidate = {...original, catchId: post.id};
  await leaderboard.set({candidates: [candidate], weekId: 'week'});
  await winner.set(candidate);
  const options = {firestore};
  assert.equal(await synchronizeProfileIdentity('owner-1', options), 0);
  await handleCommunityCatchCreated({data: await post.get()}, options);
  await handlePublicProfileWritten({
    params: {userId: 'owner-1'}, data: {after: previousProfile},
  }, options);
  assert.deepEqual((await post.get()).data(), original);
  assert.deepEqual((await olderPost.get()).data(), older);
  assert.deepEqual((await winner.get()).data(), candidate);
  assert.deepEqual((await leaderboard.get()).data(), {
    candidates: [candidate], weekId: 'week',
  });
  // Opting back into a gallery photo enables sync again, without Auth lookup.
  await saveAvatarProfile();
  assert.equal(await synchronizeProfileIdentity('owner-1', options), 2);
  assert.equal((await post.get()).data().avatarUrl, avatarUrl());
});

test('missing profiles and invalid avatar URLs leave current posts untouched',
    async () => {
  const post = firestore.collection('community_catches').doc('post-1');
  const original = catchData({avatarId: 'fisher_01'});
  await post.set(original);
  await synchronizeProfileIdentity('owner-1', {firestore});
  await saveAvatarProfile({avatarUrl: avatarUrl().replace('owner-1', 'other')});
  await synchronizeProfileIdentity('owner-1', {firestore});
  assert.deepEqual((await post.get()).data(), original);
  await saveAvatarProfile();
  await post.delete();
  assert.equal(await synchronizeProfileDocuments('owner-1', [post], {firestore}), 0);
  assert.equal((await post.get()).exists, false);
});

test('weekly copies stay in sync without changing rank, names or announcement',
    async () => {
  await saveAvatarProfile();
  const candidate = {
    ...catchData({avatarId: 'fisher_01'}), catchId: 'winner',
  };
  const other = {...candidate, ownerUid: 'other', catchId: 'other'};
  const leaderboard = firestore.collection('community_internal')
    .doc('weekly_leaderboard');
  const winner = firestore.collection('community_state').doc('weekly_winner');
  await leaderboard.set({candidates: [candidate, other], weekId: 'week'});
  const initialWinner = {
    catchId: 'winner', anglerName: 'Pêcheur Test', avatarId: 'fisher_01',
    avatarUrl: '', weekId: 'week', announcedAt: Timestamp.now(), likeCount: 9,
  };
  await winner.set(initialWinner);
  await synchronizeProfileIdentity('owner-1', {firestore});
  assert.deepEqual((await winner.get()).data(), {
    ...initialWinner, avatarId: '', avatarUrl: avatarUrl(),
  });
  assert.deepEqual((await leaderboard.get()).data().candidates, [
    {...candidate, avatarId: '', avatarUrl: avatarUrl()}, other,
  ]);
});

test('weekly selection re-reads identity data instead of restoring stale snapshots',
    async () => {
  const old = {...catchData({avatarId: 'fisher_01'}), catchId: 'winner'};
  await firestore.collection('community_catches').doc('winner').set({
    ...old, anglerName: 'Nouveau surnom', avatarId: '', avatarUrl: avatarUrl(),
  });
  await replaceLeaderboardState([old], 'week', firestore);
  const winner = await firestore.collection('community_state')
    .doc('weekly_winner').get();
  assert.equal(winner.data().avatarUrl, avatarUrl());
  assert.equal(winner.data().avatarId, '');
  assert.equal(winner.data().anglerName, 'Nouveau surnom');
});
