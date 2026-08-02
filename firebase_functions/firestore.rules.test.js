'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDocs,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  writeBatch,
  query,
  where,
  orderBy,
} = require('firebase/firestore');

const projectId = 'demo-boosterfish';
const [host, portText] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
let environment;

function catchData(ownerUid, expiresAt) {
  const objectKey = `${ownerUid}_abcdefghijklmnopqrstuvwx`;
  return {
    schemaVersion: 1,
    ownerUid,
    anglerName: 'Pêcheur Test',
    avatarUrl: '',
    photoUrl:
      `https://boosterfish-offline-maps.boosterfish-maps.workers.dev/` +
      `community-photos/${objectKey}`,
    photoObjectKey: objectKey,
    species: 'Bar',
    weightKg: 4.2,
    zoneName: 'Zone approximative',
    publicLatitude: 33.5925,
    publicLongitude: -7.6,
    montage: 'Surfcasting',
    bait: 'Sardine',
    notes: '',
    advice: '',
    status: 'published',
    likeCount: 0,
    reportCount: 0,
    createdAt: serverTimestamp(),
    expiresAt,
  };
}

async function seedAcceptedProfile(uid) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'community_profiles', uid), {
      schemaVersion: 1,
      ownerUid: uid,
      termsVersion: 1,
      termsAcceptedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
}

async function publish(
  db,
  uid,
  postId,
  photoOwnerUid = uid,
  overrides = {},
) {
  const batch = writeBatch(db);
  const data = catchData(
    uid,
    Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
  );
  const objectKey = `${photoOwnerUid}_abcdefghijklmnopqrstuvwx`;
  batch.set(
    doc(db, 'community_catches', postId),
    {
      ...data,
      ...overrides,
      photoObjectKey: objectKey,
      photoUrl:
        `https://boosterfish-offline-maps.boosterfish-maps.workers.dev/` +
        `community-photos/${objectKey}`,
    },
  );
  batch.set(doc(db, 'community_publish_state', uid), {
    schemaVersion: 1,
    ownerUid: uid,
    lastPostId: postId,
    lastPublishedAt: serverTimestamp(),
  });
  await batch.commit();
}

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {host, port: Number(portText)},
  });
});

test.beforeEach(async () => {
  await environment.clearFirestore();
});

test.after(async () => {
  await environment.cleanup();
});

test('publication requires consent and the atomic 24-hour state write',
    async () => {
  const ownerUid = 'owner-1';
  const ownerDb = environment
    .authenticatedContext(ownerUid)
    .firestore();
  await assertFails(publish(ownerDb, ownerUid, 'post-without-consent'));

  await seedAcceptedProfile(ownerUid);
  await assertFails(
    publish(ownerDb, ownerUid, 'foreign-photo', 'another-owner'),
  );
  await assertFails(
    setDoc(
      doc(ownerDb, 'community_catches', 'post-without-state'),
      catchData(
        ownerUid,
        Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ),
    ),
  );
  await assertSucceeds(publish(ownerDb, ownerUid, 'first-publication'));
  await assertFails(publish(ownerDb, ownerUid, 'second-publication'));
});

test('publication only accepts the strict Google avatar host', async () => {
  const allowedUid = 'avatar-allowed';
  await seedAcceptedProfile(allowedUid);
  await assertSucceeds(publish(
    environment.authenticatedContext(allowedUid).firestore(),
    allowedUid,
    'allowed-avatar',
    allowedUid,
    {
      avatarUrl:
        'https://lh3.googleusercontent.com/a/avatar_ABC-123=s96-c?sz=96',
    },
  ));

  for (const [uid, avatarUrl] of [
    ['avatar-tracker', 'https://tracker.example/avatar.png'],
    [
      'avatar-lookalike',
      'https://lh3.googleusercontent.com.tracker.example/avatar.png',
    ],
    [
      'avatar-credentials',
      'https://tracker.example@lh3.googleusercontent.com/avatar.png',
    ],
    ['avatar-port', 'https://lh3.googleusercontent.com:444/avatar.png'],
  ]) {
    await seedAcceptedProfile(uid);
    await assertFails(publish(
      environment.authenticatedContext(uid).firestore(),
      uid,
      `${uid}-post`,
      uid,
      {avatarUrl},
    ));
  }
});

test('active feed query is public while unbounded feed queries are denied',
    async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(
      doc(admin, 'community_catches', 'active'),
      {
        ...catchData(
          'owner-1',
          Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
        ),
        createdAt: Timestamp.now(),
      },
    );
    await setDoc(
      doc(admin, 'community_catches', 'expired'),
      {
        ...catchData(
          'owner-2',
          Timestamp.fromMillis(Date.now() - 10 * 60 * 1000),
        ),
        status: 'archived',
        createdAt: Timestamp.fromMillis(Date.now() - 8 * 24 * 60 * 60 * 1000),
      },
    );
  });
  const publicDb = environment.unauthenticatedContext().firestore();
  await assertSucceeds(
    getDocs(
      query(
        collection(publicDb, 'community_catches'),
        where('status', '==', 'published'),
        where('expiresAt', '>', Timestamp.now()),
        orderBy('expiresAt'),
      ),
    ),
  );
  await assertFails(
    getDocs(
      query(
        collection(publicDb, 'community_catches'),
        where('expiresAt', '>', Timestamp.now()),
        orderBy('expiresAt'),
      ),
    ),
  );
});

test('one like transaction is valid, self-like and direct counters are denied',
    async () => {
  const ownerUid = 'owner-1';
  const likerUid = 'liker-1';
  await seedAcceptedProfile(ownerUid);
  await publish(
    environment.authenticatedContext(ownerUid).firestore(),
    ownerUid,
    'liked-post',
  );
  const likerDb = environment.authenticatedContext(likerUid).firestore();
  const post = doc(likerDb, 'community_catches', 'liked-post');
  const like = doc(post, 'likes', likerUid);

  await assertFails(
    runTransaction(likerDb, async (transaction) => {
      const snapshot = await transaction.get(post);
      transaction.update(post, {likeCount: snapshot.data().likeCount + 1});
    }),
  );
  await assertSucceeds(
    runTransaction(likerDb, async (transaction) => {
      const postSnapshot = await transaction.get(post);
      const likeSnapshot = await transaction.get(like);
      assert.equal(likeSnapshot.exists(), false);
      transaction.set(like, {
        schemaVersion: 1,
        likerUid,
        postOwnerUid: ownerUid,
        createdAt: serverTimestamp(),
      });
      transaction.update(post, {
        likeCount: postSnapshot.data().likeCount + 1,
      });
    }),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(likerDb, 'community_catches', 'liked-post', 'likes'),
        where('likerUid', '==', likerUid),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collectionGroup(likerDb, 'likes'),
        where('likerUid', '==', likerUid),
      ),
    ),
  );

  const ownerDb = environment.authenticatedContext(ownerUid).firestore();
  await assertFails(
    runTransaction(ownerDb, async (transaction) => {
      const ownPost = doc(ownerDb, 'community_catches', 'liked-post');
      const ownLike = doc(ownPost, 'likes', ownerUid);
      const snapshot = await transaction.get(ownPost);
      transaction.set(ownLike, {
        schemaVersion: 1,
        likerUid: ownerUid,
        postOwnerUid: ownerUid,
        createdAt: serverTimestamp(),
      });
      transaction.update(ownPost, {
        likeCount: snapshot.data().likeCount + 1,
      });
    }),
  );
});

test('reports and blocks cannot target the current user', async () => {
  const ownerUid = 'owner-1';
  const ownerDb = environment.authenticatedContext(ownerUid).firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'community_reports', `${ownerUid}_post-1`), {
      schemaVersion: 1,
      reporterUid: ownerUid,
      postId: 'post-1',
      postOwnerUid: ownerUid,
      reason: 'other',
      status: 'pending',
      createdAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(
      doc(ownerDb, 'community_blocks', ownerUid, 'users', ownerUid),
      {
        schemaVersion: 1,
        ownerUid,
        blockedUid: ownerUid,
        createdAt: serverTimestamp(),
      },
    ),
  );
});

test('a report cannot be deleted, updated, or recreated by its author',
    async () => {
  const ownerUid = 'reported-owner';
  const reporterUid = 'reporter-1';
  await seedAcceptedProfile(ownerUid);
  await publish(
    environment.authenticatedContext(ownerUid).firestore(),
    ownerUid,
    'reported-post',
  );
  const reporterDb = environment
    .authenticatedContext(reporterUid)
    .firestore();
  const report = doc(
    reporterDb,
    'community_reports',
    `${reporterUid}_reported-post`,
  );
  const data = {
    schemaVersion: 1,
    reporterUid,
    postId: 'reported-post',
    postOwnerUid: ownerUid,
    reason: 'other',
    status: 'pending',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(report, data));
  await assertFails(deleteDoc(report));
  await assertFails(setDoc(report, {...data, reason: 'privacy'}));
});

test('reports are rejected for expired or non-published catches', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'community_catches', 'under-review'), {
      ...catchData(
        'owner-1',
        Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
      ),
      status: 'under_review',
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(admin, 'community_catches', 'expired-report-target'), {
      ...catchData(
        'owner-1',
        Timestamp.fromMillis(Date.now() - 60 * 1000),
      ),
      createdAt: Timestamp.fromMillis(Date.now() - 8 * 24 * 60 * 60 * 1000),
    });
  });
  const reporterUid = 'reporter-1';
  const reporterDb = environment.authenticatedContext(reporterUid).firestore();
  for (const postId of ['under-review', 'expired-report-target']) {
    await assertFails(setDoc(
      doc(reporterDb, 'community_reports', `${reporterUid}_${postId}`),
      {
        schemaVersion: 1,
        reporterUid,
        postId,
        postOwnerUid: 'owner-1',
        reason: 'other',
        status: 'pending',
        createdAt: serverTimestamp(),
      },
    ));
  }
});

test('only the owner can remove a published catch', async () => {
  const ownerUid = 'owner-1';
  await seedAcceptedProfile(ownerUid);
  const ownerDb = environment.authenticatedContext(ownerUid).firestore();
  await publish(ownerDb, ownerUid, 'owner-removal');

  const otherDb = environment.authenticatedContext('other-user').firestore();
  await assertFails(
    deleteDoc(doc(otherDb, 'community_catches', 'owner-removal')),
  );
  await assertSucceeds(
    deleteDoc(doc(ownerDb, 'community_catches', 'owner-removal')),
  );
});
