'use strict';

const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {defineSecret} = require('firebase-functions/params');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentDeleted,
} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');

initializeApp();

const db = getFirestore();
const region = 'europe-west1';
const communityAdminKey = defineSecret('COMMUNITY_ADMIN_KEY');
const workerBaseUrl =
  'https://boosterfish-offline-maps.boosterfish-maps.workers.dev/';
const publicState = db.collection('community_state').doc('weekly_winner');
const internalLeaderboard = db
  .collection('community_internal')
  .doc('weekly_leaderboard');

function previousUtcWeek(reference = new Date()) {
  const current = new Date(reference);
  current.setUTCHours(0, 0, 0, 0);
  const day = current.getUTCDay();
  const daysSinceMonday = (day + 6) % 7;
  const thisMonday = new Date(current);
  thisMonday.setUTCDate(current.getUTCDate() - daysSinceMonday);
  const start = new Date(thisMonday);
  start.setUTCDate(thisMonday.getUTCDate() - 7);
  return {
    start,
    end: thisMonday,
    weekId: start.toISOString().slice(0, 10),
  };
}

function candidateFromDocument(document) {
  const data = document.data();
  const requiredStrings = [
    'ownerUid',
    'anglerName',
    'photoUrl',
    'photoObjectKey',
    'species',
    'zoneName',
  ];
  if (
    data.status !== 'published'
    || requiredStrings.some(
      (field) => typeof data[field] !== 'string' || data[field].length === 0,
    )
    || typeof data.weightKg !== 'number'
    || !Number.isFinite(data.weightKg)
    || !Number.isInteger(data.likeCount)
    || data.likeCount < 0
  ) {
    return null;
  }
  return {
    catchId: document.id,
    ownerUid: data.ownerUid,
    anglerName: data.anglerName,
    avatarUrl: typeof data.avatarUrl === 'string' ? data.avatarUrl : '',
    photoUrl: data.photoUrl,
    photoObjectKey: data.photoObjectKey,
    species: data.species,
    weightKg: data.weightKg,
    zoneName: data.zoneName,
    likeCount: data.likeCount,
    createdAt: data.createdAt,
  };
}

function publicWinner(candidate, weekId) {
  return {
    schemaVersion: 1,
    weekId,
    catchId: candidate.catchId,
    anglerName: candidate.anglerName,
    avatarUrl: candidate.avatarUrl,
    photoUrl: candidate.photoUrl,
    species: candidate.species,
    weightKg: candidate.weightKg,
    zoneName: candidate.zoneName,
    likeCount: candidate.likeCount,
    announcedAt: FieldValue.serverTimestamp(),
  };
}

async function deleteR2Photo(objectKey) {
  if (typeof objectKey !== 'string' || objectKey.length === 0) return true;
  const response = await fetch(
    new URL(`community-admin/photos/${objectKey}`, workerBaseUrl),
    {
      method: 'DELETE',
      headers: {'X-Community-Admin-Key': communityAdminKey.value()},
    },
  );
  return response.status === 204;
}

async function deleteDocuments(documents) {
  const references = documents.map((document) => document.ref);
  for (let offset = 0; offset < references.length; offset += 400) {
    const batch = db.batch();
    for (const reference of references.slice(offset, offset + 400)) {
      batch.delete(reference);
    }
    await batch.commit();
  }
}

async function deleteReportsForPost(postId) {
  const reports = await db
    .collection('community_reports')
    .where('postId', '==', postId)
    .get();
  await deleteDocuments(reports.docs);
}

async function deleteCatchDocument(document, {deletePhoto = true} = {}) {
  const data = document.data();
  if (
    deletePhoto
    && typeof data.photoObjectKey === 'string'
    && !await deleteR2Photo(data.photoObjectKey)
  ) {
    throw new Error(`Unable to delete R2 object for ${document.id}`);
  }
  await db.recursiveDelete(document.ref);
  await deleteReportsForPost(document.id);
}

async function promoteAfterRemoval(catchId) {
  const snapshot = await internalLeaderboard.get();
  if (!snapshot.exists) return;
  const data = snapshot.data();
  const candidates = Array.isArray(data.candidates)
    ? data.candidates.filter((candidate) => candidate.catchId !== catchId)
    : [];
  if (candidates.length === (data.candidates?.length ?? 0)) return;

  if (candidates.length === 0) {
    await Promise.all([
      internalLeaderboard.delete(),
      publicState.delete(),
    ]);
    return;
  }
  const next = candidates[0];
  await Promise.all([
    internalLeaderboard.set({
      schemaVersion: 1,
      weekId: data.weekId,
      candidates,
      updatedAt: FieldValue.serverTimestamp(),
    }),
    publicState.set(publicWinner(next, data.weekId)),
  ]);
}

exports.selectWeeklyCommunityWinner = onSchedule(
  {
    region,
    schedule: '1 0 * * 1',
    timeZone: 'UTC',
    secrets: [communityAdminKey],
    retryCount: 3,
  },
  async () => {
    const week = previousUtcWeek();
    const snapshot = await db
      .collection('community_catches')
      .where('createdAt', '>=', Timestamp.fromDate(week.start))
      .where('createdAt', '<', Timestamp.fromDate(week.end))
      .get();
    const candidates = snapshot.docs
      .map(candidateFromDocument)
      .filter(Boolean)
      .sort((left, right) => {
        if (right.likeCount !== left.likeCount) {
          return right.likeCount - left.likeCount;
        }
        return left.createdAt.toMillis() - right.createdAt.toMillis();
      })
      .slice(0, 10);
    if (candidates.length === 0) return;

    const oldSnapshot = await internalLeaderboard.get();
    const oldCandidates = oldSnapshot.exists
      && Array.isArray(oldSnapshot.data().candidates)
      ? oldSnapshot.data().candidates
      : [];
    const retainedKeys = new Set(
      candidates.map((candidate) => candidate.photoObjectKey),
    );

    await Promise.all([
      internalLeaderboard.set({
        schemaVersion: 1,
        weekId: week.weekId,
        candidates,
        updatedAt: FieldValue.serverTimestamp(),
      }),
      publicState.set(publicWinner(candidates[0], week.weekId)),
    ]);

    for (const previous of oldCandidates) {
      if (!retainedKeys.has(previous.photoObjectKey)) {
        await deleteR2Photo(previous.photoObjectKey);
        const oldDocument = await db
          .collection('community_catches')
          .doc(previous.catchId)
          .get();
        if (oldDocument.exists) {
          await deleteCatchDocument(oldDocument, {deletePhoto: false});
        }
      }
    }
  },
);

exports.cleanupExpiredCommunityCatches = onSchedule(
  {
    region,
    schedule: '2-59/5 * * * *',
    timeZone: 'UTC',
    secrets: [communityAdminKey],
    retryCount: 3,
  },
  async () => {
    const leaderboard = await internalLeaderboard.get();
    const protectedCatchIds = new Set(
      leaderboard.exists && Array.isArray(leaderboard.data().candidates)
        ? leaderboard.data().candidates.map((candidate) => candidate.catchId)
        : [],
    );
    const expired = await db
      .collection('community_catches')
      .where('expiresAt', '<=', Timestamp.now())
      .limit(200)
      .get();
    for (const document of expired.docs) {
      if (protectedCatchIds.has(document.id)) {
        if (document.data().status === 'published') {
          await document.ref.update({
            status: 'archived',
            archivedAt: FieldValue.serverTimestamp(),
          });
        }
      } else {
        await deleteCatchDocument(document);
      }
    }
  },
);

exports.onCommunityReportCreated = onDocumentCreated(
  {
    document: 'community_reports/{reportId}',
    region,
  },
  async (event) => {
    const report = event.data?.data();
    if (report == null || typeof report.postId !== 'string') return;
    const reference = db.collection('community_catches').doc(report.postId);
    let hidden = false;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      const count = Number.isInteger(snapshot.data().reportCount)
        ? snapshot.data().reportCount
        : 0;
      const nextCount = count + 1;
      hidden = nextCount >= 3;
      transaction.update(reference, {
        reportCount: nextCount,
        ...(hidden ? {status: 'under_review'} : {}),
      });
    });
    if (hidden) await promoteAfterRemoval(report.postId);
  },
);

exports.onCommunityCatchDeleted = onDocumentDeleted(
  {
    document: 'community_catches/{postId}',
    region,
    secrets: [communityAdminKey],
  },
  async (event) => {
    const deleted = event.data;
    if (deleted == null) return;
    const data = deleted.data();
    const likes = await deleted.ref.collection('likes').get();
    await deleteDocuments(likes.docs);
    await deleteReportsForPost(event.params.postId);
    await promoteAfterRemoval(event.params.postId);
    if (
      typeof data.photoObjectKey === 'string'
      && !await deleteR2Photo(data.photoObjectKey)
    ) {
      throw new Error(`Unable to delete R2 object for ${event.params.postId}`);
    }
  },
);

exports.deleteCommunityAccountData = onCall(
  {
    region,
    enforceAppCheck: true,
    secrets: [communityAdminKey],
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (uid == null) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    try {
      const owned = await db
        .collection('community_catches')
        .where('ownerUid', '==', uid)
        .get();
      for (const document of owned.docs) {
        await promoteAfterRemoval(document.id);
        await deleteCatchDocument(document);
      }

      const likes = await db
        .collectionGroup('likes')
        .where('likerUid', '==', uid)
        .get();
      for (const like of likes.docs) {
        const postReference = like.ref.parent.parent;
        if (postReference == null) {
          await like.ref.delete();
          continue;
        }
        await db.runTransaction(async (transaction) => {
          const [post, currentLike] = await Promise.all([
            transaction.get(postReference),
            transaction.get(like.ref),
          ]);
          if (!currentLike.exists) return;
          transaction.delete(like.ref);
          if (post.exists) {
            const count = Number.isInteger(post.data().likeCount)
              ? post.data().likeCount
              : 0;
            transaction.update(postReference, {
              likeCount: Math.max(0, count - 1),
            });
          }
        });
      }

      const [reportedByUser, reportsAboutUser, ownedBlocks, blocksOfUser] =
        await Promise.all([
          db.collection('community_reports').where('reporterUid', '==', uid).get(),
          db.collection('community_reports').where('postOwnerUid', '==', uid).get(),
          db.collection('community_blocks').doc(uid).collection('users').get(),
          db.collectionGroup('users').where('blockedUid', '==', uid).get(),
        ]);
      const unique = new Map();
      for (const document of [
        ...reportedByUser.docs,
        ...reportsAboutUser.docs,
        ...ownedBlocks.docs,
        ...blocksOfUser.docs,
      ]) {
        unique.set(document.ref.path, document);
      }
      await deleteDocuments([...unique.values()]);
      await Promise.all([
        db.collection('community_profiles').doc(uid).delete(),
        db.collection('community_publish_state').doc(uid).delete(),
      ]);
      return {deleted: true};
    } catch (error) {
      console.error('Community account cleanup failed', {
        code: error?.code,
        message: error?.message,
      });
      throw new HttpsError(
        'internal',
        'Community account data could not be deleted.',
      );
    }
  },
);

exports.__test = {previousUtcWeek};
