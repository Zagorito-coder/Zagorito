'use strict';

const {createHash, randomUUID} = require('node:crypto');
const {initializeApp} = require('firebase-admin/app');
const {
  getFirestore,
  FieldPath,
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore');
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
const runtimeServiceAccount =
  'boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com';
const communityAdminKey = defineSecret('COMMUNITY_ADMIN_KEY');
const workerBaseUrl =
  'https://boosterfish-offline-maps.boosterfish-maps.workers.dev/';
const cleanupCollection = 'community_cleanup_tasks';
const r2ObjectKeyPattern = /^[A-Za-z0-9_-]{20,225}$/;

class PermanentCleanupError extends Error {}

function communityRefs(firestore = db) {
  return {
    publicState: firestore.collection('community_state').doc('weekly_winner'),
    internalLeaderboard: firestore
      .collection('community_internal')
      .doc('weekly_leaderboard'),
  };
}

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

function safeAvatarUrl(value) {
  if (typeof value !== 'string' || value.length === 0 || value.length > 1024) {
    return '';
  }
  try {
    const url = new URL(value);
    if (
      url.protocol !== 'https:'
      || url.hostname !== 'lh3.googleusercontent.com'
      || url.port !== ''
      || url.username !== ''
      || url.password !== ''
      || url.pathname === '/'
      || url.hash !== ''
    ) {
      return '';
    }
    return url.toString();
  } catch (_) {
    return '';
  }
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
    || typeof data.createdAt?.toMillis !== 'function'
  ) {
    return null;
  }
  return {
    catchId: document.id,
    ownerUid: data.ownerUid,
    anglerName: data.anglerName,
    avatarUrl: safeAvatarUrl(data.avatarUrl),
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
    avatarUrl: safeAvatarUrl(candidate.avatarUrl),
    photoUrl: candidate.photoUrl,
    species: candidate.species,
    weightKg: candidate.weightKg,
    zoneName: candidate.zoneName,
    likeCount: candidate.likeCount,
    announcedAt: FieldValue.serverTimestamp(),
  };
}

function isValidR2ObjectKey(objectKey) {
  return typeof objectKey === 'string' && r2ObjectKeyPattern.test(objectKey);
}

async function deleteR2Photo(
  objectKey,
  {
    fetchImpl = fetch,
    adminKey = communityAdminKey.value(),
    timeoutSignal = AbortSignal.timeout(10000),
  } = {},
) {
  if (!isValidR2ObjectKey(objectKey)) {
    throw new PermanentCleanupError('Invalid R2 community photo object key.');
  }
  const response = await fetchImpl(
    new URL(
      `community-admin/photos/${encodeURIComponent(objectKey)}`,
      workerBaseUrl,
    ),
    {
      method: 'DELETE',
      headers: {'X-Community-Admin-Key': adminKey},
      signal: timeoutSignal,
    },
  );
  // DELETE is idempotent: a missing object is already in the desired state.
  if (response.status !== 204 && response.status !== 404) {
    throw new Error(`R2 deletion failed with HTTP ${response.status}.`);
  }
}

async function deleteDocuments(documents, firestore = db) {
  const references = documents.map((document) => document.ref);
  for (let offset = 0; offset < references.length; offset += 400) {
    const batch = firestore.batch();
    for (const reference of references.slice(offset, offset + 400)) {
      batch.delete(reference);
    }
    await batch.commit();
  }
}

async function deleteReportsForPost(postId, firestore = db) {
  const reports = await firestore
    .collection('community_reports')
    .where('postId', '==', postId)
    .get();
  await deleteDocuments(reports.docs, firestore);
}

function photoCleanupTaskId(catchId, objectKey) {
  return createHash('sha256')
    .update(String(catchId))
    .update('\0')
    .update(String(objectKey))
    .digest('hex');
}

function photoCleanupTaskRef(firestore, candidate) {
  return firestore
    .collection(cleanupCollection)
    .doc(photoCleanupTaskId(candidate.catchId, candidate.photoObjectKey));
}

function initialCleanupTask(candidate, reason) {
  const valid = isValidR2ObjectKey(candidate.photoObjectKey);
  return {
    schemaVersion: 1,
    type: 'delete_community_catch',
    catchId: typeof candidate.catchId === 'string' ? candidate.catchId : '',
    photoObjectKey: typeof candidate.photoObjectKey === 'string'
      ? candidate.photoObjectKey
      : '',
    reasons: [reason],
    // Même une clé R2 historique invalide doit passer une première fois dans
    // le processeur : le document Firestore et ses sous-collections sont alors
    // supprimés, puis seule la suppression R2 impossible reste explicitement
    // bloquée pour investigation.
    state: 'pending',
    attempts: 0,
    nextAttemptAt: Timestamp.now(),
    ...(!valid ? {lastError: 'invalid_r2_object_key'} : {}),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function enqueuePhotoCleanup(candidate, reason, firestore = db) {
  if (
    typeof candidate.photoObjectKey !== 'string'
    || candidate.photoObjectKey.length === 0
  ) {
    return null;
  }
  const reference = photoCleanupTaskRef(firestore, candidate);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      transaction.create(reference, initialCleanupTask(candidate, reason));
      return;
    }
    transaction.set(reference, {
      reasons: FieldValue.arrayUnion(reason),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
  return reference;
}

function cleanupRetryDate(attempts, reference = new Date()) {
  const safeAttempts = Number.isInteger(attempts) && attempts > 0 ? attempts : 1;
  const delayMinutes = Math.min(360, 5 * (2 ** Math.min(safeAttempts - 1, 7)));
  return new Date(reference.getTime() + delayMinutes * 60 * 1000);
}

function errorSummary(error) {
  const message = typeof error?.message === 'string'
    ? error.message
    : String(error);
  return message.replace(/[\r\n]+/g, ' ').slice(0, 300);
}

async function claimCleanupTask(reference, firestore = db) {
  const token = randomUUID();
  const now = Timestamp.now();
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) return null;
    const data = snapshot.data();
    if (data.state === 'blocked') return null;
    if (
      data.state === 'processing'
      && typeof data.leaseExpiresAt?.toMillis === 'function'
      && data.leaseExpiresAt.toMillis() > now.toMillis()
    ) {
      return null;
    }
    if (
      typeof data.nextAttemptAt?.toMillis === 'function'
      && data.nextAttemptAt.toMillis() > now.toMillis()
    ) {
      return null;
    }
    const attempts = Number.isInteger(data.attempts) ? data.attempts + 1 : 1;
    transaction.update(reference, {
      state: 'processing',
      attempts,
      leaseToken: token,
      leaseExpiresAt: Timestamp.fromMillis(now.toMillis() + 120000),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {...data, attempts, leaseToken: token};
  });
}

async function finishCleanupTask(reference, leaseToken, firestore = db) {
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (snapshot.exists && snapshot.data().leaseToken === leaseToken) {
      transaction.delete(reference);
    }
  });
}

async function deferCleanupTask(
  reference,
  leaseToken,
  attempts,
  error,
  firestore = db,
) {
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists || snapshot.data().leaseToken !== leaseToken) return;
    if (error instanceof PermanentCleanupError) {
      transaction.update(reference, {
        state: 'blocked',
        lastError: errorSummary(error),
        leaseToken: FieldValue.delete(),
        leaseExpiresAt: FieldValue.delete(),
        nextAttemptAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    transaction.update(reference, {
      state: 'pending',
      lastError: errorSummary(error),
      nextAttemptAt: Timestamp.fromDate(cleanupRetryDate(attempts)),
      leaseToken: FieldValue.delete(),
      leaseExpiresAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function processPhotoCleanupTask(
  reference,
  {
    firestore = db,
    deletePhoto = deleteR2Photo,
  } = {},
) {
  const task = await claimCleanupTask(reference, firestore);
  if (task == null) return {processed: false, deferred: false};
  try {
    if (typeof task.catchId === 'string' && task.catchId.length > 0) {
      const catchReference = firestore
        .collection('community_catches')
        .doc(task.catchId);
      await firestore.recursiveDelete(catchReference);
      await deleteReportsForPost(task.catchId, firestore);
    }
    await deletePhoto(task.photoObjectKey);
    await finishCleanupTask(reference, task.leaseToken, firestore);
    return {processed: true, deferred: false};
  } catch (error) {
    await deferCleanupTask(
      reference,
      task.leaseToken,
      task.attempts,
      error,
      firestore,
    );
    console.error('Community cleanup deferred', {
      taskId: reference.id,
      attempts: task.attempts,
      error: errorSummary(error),
    });
    return {processed: false, deferred: true};
  }
}

async function deleteCatchDocument(document, firestore = db) {
  const data = document.data();
  const taskReference = await enqueuePhotoCleanup({
    catchId: document.id,
    photoObjectKey: data.photoObjectKey,
  }, 'catch_deletion', firestore);
  if (taskReference == null) {
    await firestore.recursiveDelete(document.ref);
    await deleteReportsForPost(document.id, firestore);
    return;
  }
  await processPhotoCleanupTask(taskReference, {firestore});
}

async function promoteAfterRemoval(catchId, firestore = db) {
  const {internalLeaderboard, publicState} = communityRefs(firestore);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(internalLeaderboard);
    if (!snapshot.exists) {
      transaction.delete(publicState);
      return;
    }
    const data = snapshot.data();
    const existing = Array.isArray(data.candidates) ? data.candidates : [];
    const candidates = existing.filter(
      (candidate) => candidate.catchId !== catchId,
    );
    if (candidates.length === existing.length) return;
    if (candidates.length === 0) {
      transaction.delete(internalLeaderboard);
      transaction.delete(publicState);
      return;
    }
    transaction.set(internalLeaderboard, {
      schemaVersion: 1,
      weekId: data.weekId,
      candidates,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(publicState, publicWinner(candidates[0], data.weekId));
  });
}

async function replaceLeaderboardState(
  candidates,
  weekId,
  firestore = db,
) {
  const {internalLeaderboard, publicState} = communityRefs(firestore);
  return firestore.runTransaction(async (transaction) => {
    const oldSnapshot = await transaction.get(internalLeaderboard);
    const oldCandidates = oldSnapshot.exists
      && Array.isArray(oldSnapshot.data().candidates)
      ? oldSnapshot.data().candidates
      : [];
    const retainedIds = new Set(candidates.map((candidate) => candidate.catchId));
    const retired = oldCandidates.filter(
      (candidate) => !retainedIds.has(candidate.catchId),
    );
    const taskEntries = retired
      .filter((candidate) => typeof candidate.photoObjectKey === 'string'
        && candidate.photoObjectKey.length > 0)
      .map((candidate) => ({
        candidate,
        reference: photoCleanupTaskRef(firestore, candidate),
      }));
    const taskSnapshots = await Promise.all(
      taskEntries.map((entry) => transaction.get(entry.reference)),
    );
    for (let index = 0; index < taskEntries.length; index += 1) {
      const {candidate, reference} = taskEntries[index];
      if (!taskSnapshots[index].exists) {
        transaction.create(
          reference,
          initialCleanupTask(candidate, 'leaderboard_rotation'),
        );
      } else {
        transaction.set(reference, {
          reasons: FieldValue.arrayUnion('leaderboard_rotation'),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
    if (candidates.length === 0) {
      transaction.delete(internalLeaderboard);
      transaction.delete(publicState);
    } else {
      transaction.set(internalLeaderboard, {
        schemaVersion: 1,
        weekId,
        candidates,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(publicState, publicWinner(candidates[0], weekId));
    }
    return retired;
  });
}

async function processRetiredCandidates(candidates, firestore = db) {
  for (const candidate of candidates) {
    if (
      typeof candidate.photoObjectKey !== 'string'
      || candidate.photoObjectKey.length === 0
    ) {
      const document = await firestore
        .collection('community_catches')
        .doc(candidate.catchId)
        .get();
      if (document.exists) await deleteCatchDocument(document, firestore);
      continue;
    }
    await processPhotoCleanupTask(
      photoCleanupTaskRef(firestore, candidate),
      {firestore},
    );
  }
}

function statusAfterReportRecalculation(data, reportCount) {
  if (reportCount >= 3 && data.status === 'published') return 'under_review';
  // A post already under review remains quarantined until a trusted moderator
  // decides its outcome. Recalculation repairs the aggregate without silently
  // overriding a moderation decision.
  return data.status;
}

async function recalculateCommunityReportCount(
  postId,
  {
    firestore = db,
    requiredReportReference = null,
  } = {},
) {
  const postReference = firestore.collection('community_catches').doc(postId);
  const reportsQuery = firestore
    .collection('community_reports')
    .where('postId', '==', postId);
  return firestore.runTransaction(async (transaction) => {
    const requiredReport = requiredReportReference == null
      ? null
      : await transaction.get(requiredReportReference);
    const post = await transaction.get(postReference);
    const reports = await transaction.get(reportsQuery);
    if (requiredReport != null && !requiredReport.exists) {
      return {exists: post.exists, removedFromLeaderboard: false};
    }
    if (!post.exists) return {exists: false, removedFromLeaderboard: false};
    const data = post.data();
    const reportCount = reports.size;
    const status = statusAfterReportRecalculation(data, reportCount);
    const removedFromLeaderboard = data.status === 'published'
      && status === 'under_review';
    transaction.update(postReference, {reportCount, status});
    return {exists: true, reportCount, status, removedFromLeaderboard};
  });
}

async function handleCommunityReportCreated(event, firestore = db) {
  const report = event.data?.data();
  if (report == null || typeof report.postId !== 'string') return;
  const result = await recalculateCommunityReportCount(report.postId, {
    firestore,
    requiredReportReference: event.data.ref,
  });
  if (result.removedFromLeaderboard) {
    await promoteAfterRemoval(report.postId, firestore);
  }
}

async function reconcileCommunityReportCountsPage(firestore = db) {
  const cursorReference = firestore
    .collection('community_internal')
    .doc('report_reconciliation');
  const cursorSnapshot = await cursorReference.get();
  const lastPostId = cursorSnapshot.exists
    && typeof cursorSnapshot.data().lastPostId === 'string'
    ? cursorSnapshot.data().lastPostId
    : '';
  let query = firestore
    .collection('community_catches')
    .orderBy(FieldPath.documentId())
    .limit(100);
  if (lastPostId.length > 0) query = query.startAfter(lastPostId);
  const posts = await query.get();
  for (const post of posts.docs) {
    const result = await recalculateCommunityReportCount(post.id, {firestore});
    if (result.removedFromLeaderboard) {
      await promoteAfterRemoval(post.id, firestore);
    }
  }
  await cursorReference.set({
    schemaVersion: 1,
    lastPostId: posts.size === 100 ? posts.docs.at(-1).id : '',
    updatedAt: FieldValue.serverTimestamp(),
  });
  return posts.size;
}

exports.selectWeeklyCommunityWinner = onSchedule(
  {
    region,
    serviceAccount: runtimeServiceAccount,
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
    const retired = await replaceLeaderboardState(candidates, week.weekId);
    await processRetiredCandidates(retired);
  },
);

exports.cleanupExpiredCommunityCatches = onSchedule(
  {
    region,
    serviceAccount: runtimeServiceAccount,
    schedule: '2-59/5 * * * *',
    timeZone: 'UTC',
    secrets: [communityAdminKey],
    retryCount: 3,
  },
  async () => {
    const {internalLeaderboard} = communityRefs();
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

exports.retryCommunityCleanupTasks = onSchedule(
  {
    region,
    serviceAccount: runtimeServiceAccount,
    schedule: '3-59/5 * * * *',
    timeZone: 'UTC',
    secrets: [communityAdminKey],
    retryCount: 3,
  },
  async () => {
    const tasks = await db
      .collection(cleanupCollection)
      .where('nextAttemptAt', '<=', Timestamp.now())
      .limit(100)
      .get();
    for (const task of tasks.docs) {
      await processPhotoCleanupTask(task.ref);
    }
  },
);

exports.reconcileCommunityReportCounts = onSchedule(
  {
    region,
    serviceAccount: runtimeServiceAccount,
    schedule: '17 * * * *',
    timeZone: 'UTC',
    retryCount: 3,
    timeoutSeconds: 300,
    memory: '256MiB',
  },
  async () => reconcileCommunityReportCountsPage(),
);

exports.onCommunityReportCreated = onDocumentCreated(
  {
    document: 'community_reports/{reportId}',
    region,
    serviceAccount: runtimeServiceAccount,
    retry: true,
  },
  async (event) => handleCommunityReportCreated(event),
);

exports.onCommunityCatchDeleted = onDocumentDeleted(
  {
    document: 'community_catches/{postId}',
    region,
    serviceAccount: runtimeServiceAccount,
    secrets: [communityAdminKey],
    retry: true,
  },
  async (event) => {
    const deleted = event.data;
    if (deleted == null) return;
    const data = deleted.data();
    // Persist the external side effect before any best-effort processing.
    const taskReference = await enqueuePhotoCleanup({
      catchId: event.params.postId,
      photoObjectKey: data.photoObjectKey,
    }, 'firestore_delete_trigger');
    const likes = await deleted.ref.collection('likes').get();
    await deleteDocuments(likes.docs);
    await deleteReportsForPost(event.params.postId);
    await promoteAfterRemoval(event.params.postId);
    if (taskReference != null) await processPhotoCleanupTask(taskReference);
  },
);

exports.deleteCommunityAccountData = onCall(
  {
    region,
    serviceAccount: runtimeServiceAccount,
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
      const affectedPostIds = new Set(
        reportedByUser.docs
          .map((document) => document.data().postId)
          .filter((postId) => typeof postId === 'string'),
      );
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
      for (const postId of affectedPostIds) {
        await recalculateCommunityReportCount(postId);
      }
      await Promise.all([
        db.collection('community_profiles').doc(uid).delete(),
        db.collection('community_public_profiles').doc(uid).delete(),
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

exports.__test = {
  cleanupRetryDate,
  deleteR2Photo,
  handleCommunityReportCreated,
  isValidR2ObjectKey,
  photoCleanupTaskId,
  processPhotoCleanupTask,
  recalculateCommunityReportCount,
  reconcileCommunityReportCountsPage,
  replaceLeaderboardState,
  safeAvatarUrl,
  previousUtcWeek,
};
