import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

import worker, {
  createWorker,
  hasExpectedAppCheckClaims,
  indexFirebaseJwks,
} from '../src/index.mjs';

function storedObject(bytes, contentType) {
  return {
    body: bytes,
    httpEtag: '"test-etag"',
    size: bytes.byteLength,
    writeHttpMetadata(headers) {
      headers.set('Content-Type', contentType);
    },
  };
}

function environment() {
  const data = new Map([
    [
      'manifest.json',
      storedObject(
        new TextEncoder().encode('{"schemaVersion":1}'),
        'application/json',
      ),
    ],
    [
      'ma.pmtiles',
      storedObject(
        Uint8Array.from({length: 100}, (_, index) => index),
        'application/vnd.pmtiles',
      ),
    ],
  ]);

  return {
    OFFLINE_MAPS: {
      async get(key, options) {
        const object = data.get(key);
        if (object == null || options?.range == null) return object ?? null;
        const {offset, length} = options.range;
        return {
          ...object,
          body: object.body.slice(offset, offset + length),
          size: length,
        };
      },
      async head(key) {
        return data.get(key) ?? null;
      },
    },
  };
}

function photoEnvironment({deleteFailures = 0, removeBeforeDeleteFailure = false} = {}) {
  const photos = new Map();
  const operations = {deleteCalls: 0, putCalls: 0};
  let remainingDeleteFailures = deleteFailures;
  const bucket = {
    async get(key) {
      return photos.get(key) ?? null;
    },
    async head(key) {
      return photos.get(key) ?? null;
    },
    async put(key, bytes, options) {
      operations.putCalls += 1;
      const body = new Uint8Array(bytes);
      photos.set(key, {
        ...storedObject(body, options.httpMetadata.contentType),
        customMetadata: options.customMetadata,
      });
    },
    async delete(key) {
      operations.deleteCalls += 1;
      if (remainingDeleteFailures > 0) {
        remainingDeleteFailures -= 1;
        if (removeBeforeDeleteFailure) photos.delete(key);
        throw new Error('Injected R2 delete failure');
      }
      photos.delete(key);
    },
  };
  return {
    operations,
    photos,
    env: {
      SPOT_PHOTOS: bucket,
      COMMUNITY_PHOTOS: bucket,
      COMMUNITY_ADMIN_KEY: 'test-secret-key-with-at-least-32-characters',
    },
  };
}

function authenticatedPhotoWorker({
  uid = 'owner-1',
  canReview = false,
  appCheck = 'android-app-id',
} = {}) {
  return createWorker({
    authenticate: async () => ({uid, canReview}),
    authenticateAppCheck: async () => appCheck,
  });
}

const jpegBytes = Uint8Array.of(0xff, 0xd8, 0xff, 0xdb, 0, 1, 0xff, 0xd9);
const webpBytes = Uint8Array.from([
  ...new TextEncoder().encode('RIFF'),
  4, 0, 0, 0,
  ...new TextEncoder().encode('WEBP'),
]);

test('serves only the explicit offline map files', async () => {
  const response = await worker.fetch(
    new Request('https://maps.example/private.txt'),
    environment(),
  );
  assert.equal(response.status, 404);
});

test('serves a resumable byte range with exact headers', async () => {
  const response = await worker.fetch(
    new Request('https://maps.example/ma.pmtiles', {
      headers: {Range: 'bytes=10-19'},
    }),
    environment(),
  );

  assert.equal(response.status, 206);
  assert.equal(response.headers.get('content-length'), '10');
  assert.equal(response.headers.get('content-range'), 'bytes 10-19/100');
  assert.deepEqual(
    new Uint8Array(await response.arrayBuffer()),
    Uint8Array.from({length: 10}, (_, index) => index + 10),
  );
});

test('rejects malformed and out-of-bounds ranges', async () => {
  for (const range of ['bytes=100-', 'bytes=20-10', 'bytes=0-1,3-4']) {
    const response = await worker.fetch(
      new Request('https://maps.example/ma.pmtiles', {headers: {Range: range}}),
      environment(),
    );
    assert.equal(response.status, 416);
    assert.equal(response.headers.get('content-range'), 'bytes */100');
  }
});

test('requires Firebase authentication for photo uploads', async () => {
  const photoWorker = createWorker({authenticate: async () => null});
  const {env} = photoEnvironment();
  const response = await photoWorker.fetch(
    new Request(
      'https://maps.example/spot-photos/abcdefghijklmnopqrst-1234567890',
      {
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        body: jpegBytes,
      },
    ),
    env,
  );
  assert.equal(response.status, 401);
});

test('requires App Check for personal photo mutations', async () => {
  const photoWorker = createWorker({
    authenticate: async () => 'owner-1',
    authenticateAppCheck: async () => null,
  });
  const {env, operations, photos} = photoEnvironment();
  const key = 'abcdefghijklmnopqrst-1234567890';
  const url = `https://maps.example/spot-photos/${key}`;

  const upload = await photoWorker.fetch(
    new Request(url, {
      method: 'PUT',
      headers: {'Content-Type': 'image/jpeg'},
      body: jpegBytes,
    }),
    env,
  );
  assert.equal(upload.status, 401);
  assert.equal(operations.putCalls, 0);

  photos.set(key, {
    ...storedObject(jpegBytes, 'image/jpeg'),
    customMetadata: {ownerUid: 'owner-1'},
  });
  const deletion = await photoWorker.fetch(
    new Request(url, {method: 'DELETE'}),
    env,
  );
  assert.equal(deletion.status, 401);
  assert.equal(operations.deleteCalls, 0);
  assert.equal(photos.has(key), true);
});

test('indexes the Firebase public JWKS response by key id', () => {
  const first = {kid: 'first-key', kty: 'RSA'};
  const second = {kid: 'second-key', kty: 'RSA'};
  assert.deepEqual(indexFirebaseJwks({keys: [first, second]}), {
    'first-key': first,
    'second-key': second,
  });
});

test('accepts App Check claims only for the official Android app', () => {
  const header = {alg: 'RS256', typ: 'JWT', kid: 'firebase-key'};
  const officialClaims = {
    aud: ['projects/68722970471'],
    iss: 'https://firebaseappcheck.googleapis.com/68722970471',
    sub: '1:68722970471:android:22dce79885650fc112e9c2',
  };
  assert.equal(hasExpectedAppCheckClaims(header, officialClaims), true);
  assert.equal(
    hasExpectedAppCheckClaims(header, {
      ...officialClaims,
      sub: '1:68722970471:android:another-app',
    }),
    false,
  );
  assert.equal(
    hasExpectedAppCheckClaims({...header, alg: 'none'}, officialClaims),
    false,
  );
  assert.equal(
    hasExpectedAppCheckClaims({...header, typ: undefined}, officialClaims),
    false,
  );
  assert.equal(
    hasExpectedAppCheckClaims(header, {
      ...officialClaims,
      aud: ['projects/another-project'],
    }),
    false,
  );
});

test('stores one photo and serves it only to its owner', async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env, photos} = photoEnvironment();
  const url =
    'https://maps.example/spot-photos/abcdefghijklmnopqrst-1234567890';
  const upload = await photoWorker.fetch(
    new Request(url, {
      method: 'PUT',
      headers: {'Content-Type': 'image/webp'},
      body: webpBytes,
    }),
    env,
  );
  assert.equal(upload.status, 201);
  assert.equal(photos.size, 1);
  assert.match((await upload.json()).photoUrl, /\?v=\d+$/);

  const download = await photoWorker.fetch(new Request(url), env);
  assert.equal(download.status, 200);
  assert.equal(download.headers.get('content-type'), 'image/webp');
  assert.equal(download.headers.get('cache-control'), 'private, no-store');
  assert.equal(download.headers.get('vary'), 'Authorization');
  assert.deepEqual(
    new Uint8Array(await download.arrayBuffer()),
    webpBytes,
  );

  const otherUserWorker = createWorker({
    authenticate: async () => 'owner-2',
  });
  const forbidden = await otherUserWorker.fetch(new Request(url), env);
  assert.equal(forbidden.status, 403);
});

test('rejects a photo larger than 2 MB', async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env} = photoEnvironment();
  const response = await photoWorker.fetch(
    new Request(
      'https://maps.example/spot-photos/abcdefghijklmnopqrst-1234567890',
      {
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        body: new Uint8Array(2 * 1024 * 1024 + 1),
      },
    ),
    env,
  );
  assert.equal(response.status, 413);
});

test('rejects a photo whose bytes do not match its declared type', async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env} = photoEnvironment();
  const response = await photoWorker.fetch(
    new Request(
      'https://maps.example/spot-photos/abcdefghijklmnopqrst-1234567890',
      {
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        body: Uint8Array.of(1, 2, 3, 4),
      },
    ),
    env,
  );
  assert.equal(response.status, 415);
});

test('stops reading an unbounded upload after the 2 MB limit', async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env, operations} = photoEnvironment();
  let producedChunks = 0;
  let cancelled = false;
  const body = new ReadableStream({
    pull(controller) {
      producedChunks += 1;
      controller.enqueue(new Uint8Array(1024 * 1024));
      if (producedChunks === 100) controller.close();
    },
    cancel() {
      cancelled = true;
    },
  });
  const response = await photoWorker.fetch(
    new Request(
      'https://maps.example/spot-photos/abcdefghijklmnopqrst-1234567890',
      {
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        body,
        duplex: 'half',
      },
    ),
    env,
  );

  assert.equal(response.status, 413);
  assert.equal(cancelled, true);
  assert.ok(producedChunks < 100);
  assert.equal(operations.putCalls, 0);
});

test('reviewers can inspect but cannot mutate another owner photo', async () => {
  const photoWorker = authenticatedPhotoWorker({
    uid: 'reviewer-1',
    canReview: true,
  });
  const {env, operations, photos} = photoEnvironment();
  const key = 'abcdefghijklmnopqrst-1234567890';
  const url = `https://maps.example/spot-photos/${key}`;
  photos.set(key, {
    ...storedObject(jpegBytes, 'image/jpeg'),
    customMetadata: {ownerUid: 'owner-1'},
  });

  const download = await photoWorker.fetch(new Request(url), env);
  assert.equal(download.status, 200);
  const overwrite = await photoWorker.fetch(
    new Request(url, {
      method: 'PUT',
      headers: {'Content-Type': 'image/jpeg'},
      body: jpegBytes,
    }),
    env,
  );
  const deletion = await photoWorker.fetch(
    new Request(url, {method: 'DELETE'}),
    env,
  );
  assert.equal(overwrite.status, 403);
  assert.equal(deletion.status, 403);
  assert.equal(operations.putCalls, 0);
  assert.equal(operations.deleteCalls, 0);
  assert.equal(photos.has(key), true);
});

test('personal photo deletion is idempotent and retries lost responses',
    async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env, operations, photos} = photoEnvironment({
    deleteFailures: 1,
    removeBeforeDeleteFailure: true,
  });
  const key = 'abcdefghijklmnopqrst-1234567890';
  const url = `https://maps.example/spot-photos/${key}`;
  photos.set(key, {
    ...storedObject(jpegBytes, 'image/jpeg'),
    customMetadata: {ownerUid: 'owner-1'},
  });

  const first = await photoWorker.fetch(
    new Request(url, {method: 'DELETE'}),
    env,
  );
  const replay = await photoWorker.fetch(
    new Request(url, {method: 'DELETE'}),
    env,
  );
  assert.equal(first.status, 204);
  assert.equal(replay.status, 204);
  assert.equal(operations.deleteCalls, 2);
  assert.equal(photos.has(key), false);
  assert.equal(first.headers.get('cache-control'), 'no-store');

  const revoked = await photoWorker.fetch(new Request(url), env);
  assert.equal(revoked.status, 404);
  assert.equal(revoked.headers.get('cache-control'), 'no-store');
});

test('persistent R2 deletion failures return a retryable error', async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env, operations, photos} = photoEnvironment({deleteFailures: 3});
  const key = 'abcdefghijklmnopqrst-1234567890';
  const url = `https://maps.example/spot-photos/${key}`;
  photos.set(key, {
    ...storedObject(jpegBytes, 'image/jpeg'),
    customMetadata: {ownerUid: 'owner-1'},
  });

  const response = await photoWorker.fetch(
    new Request(url, {method: 'DELETE'}),
    env,
  );
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(operations.deleteCalls, 3);
  assert.equal(photos.has(key), true);
});

test('community photos require auth and App Check to upload, then are public', async () => {
  const photoWorker = createWorker({
    authenticate: async () => 'owner-1',
    authenticateAppCheck: async () => 'android-app-id',
  });
  const {env} = photoEnvironment();
  const url =
    'https://maps.example/community-photos/owner-1_abcdefghijklmnopqrstuvwx';
  const upload = await photoWorker.fetch(
    new Request(url, {
      method: 'PUT',
      headers: {
        'Content-Type': 'image/jpeg',
        'X-Firebase-AppCheck': 'verified-by-test',
      },
      body: jpegBytes,
    }),
    env,
  );
  assert.equal(upload.status, 201);

  const publicWorker = createWorker({
    authenticate: async () => null,
    authenticateAppCheck: async () => null,
  });
  const download = await publicWorker.fetch(new Request(url), env);
  assert.equal(download.status, 200);
  assert.equal(download.headers.get('content-type'), 'image/jpeg');
  assert.equal(download.headers.get('cache-control'), 'no-store');
  assert.deepEqual(
    new Uint8Array(await download.arrayBuffer()),
    jpegBytes,
  );
});

test('community photo upload rejects a missing App Check token', async () => {
  const photoWorker = createWorker({
    authenticate: async () => 'owner-1',
    authenticateAppCheck: async () => null,
  });
  const {env} = photoEnvironment();
  const response = await photoWorker.fetch(
    new Request(
      'https://maps.example/community-photos/owner-1_abcdefghijklmnopqrstuvwx',
      {
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        body: jpegBytes,
      },
    ),
    env,
  );
  assert.equal(response.status, 401);
});

test('community photo upload rejects a key outside the owner namespace',
    async () => {
  const photoWorker = createWorker({
    authenticate: async () => 'owner-1',
    authenticateAppCheck: async () => 'android-app-id',
  });
  const {env, photos} = photoEnvironment();
  const response = await photoWorker.fetch(
    new Request(
      'https://maps.example/community-photos/owner-2_abcdefghijklmnopqrstuvwx',
      {
        method: 'PUT',
        headers: {'Content-Type': 'image/jpeg'},
        body: jpegBytes,
      },
    ),
    env,
  );
  assert.equal(response.status, 403);
  assert.equal(photos.size, 0);
});

test('community admin deletion requires the server secret', async () => {
  const photoWorker = createWorker({
    authenticate: async () => 'owner-1',
    authenticateAppCheck: async () => 'android-app-id',
  });
  const {env, operations, photos} = photoEnvironment({
    deleteFailures: 1,
    removeBeforeDeleteFailure: true,
  });
  const key = 'owner-1_abcdefghijklmnopqrstuvwx';
  photos.set(key, {
    ...storedObject(jpegBytes, 'image/jpeg'),
    customMetadata: {ownerUid: 'owner-1'},
  });
  const url = `https://maps.example/community-admin/photos/${key}`;

  const unauthorized = await photoWorker.fetch(
    new Request(url, {method: 'DELETE'}),
    env,
  );
  assert.equal(unauthorized.status, 401);
  assert.equal(photos.has(key), true);

  const deleted = await photoWorker.fetch(
    new Request(url, {
      method: 'DELETE',
      headers: {'X-Community-Admin-Key': env.COMMUNITY_ADMIN_KEY},
    }),
    env,
  );
  assert.equal(deleted.status, 204);
  assert.equal(photos.has(key), false);

  const revoked = await photoWorker.fetch(new Request(
    `https://maps.example/community-photos/${key}`,
  ), env);
  assert.equal(revoked.status, 404);
  assert.equal(revoked.headers.get('cache-control'), 'no-store');

  const replay = await photoWorker.fetch(
    new Request(url, {
      method: 'DELETE',
      headers: {'X-Community-Admin-Key': env.COMMUNITY_ADMIN_KEY},
    }),
    env,
  );
  assert.equal(replay.status, 204);
  assert.equal(operations.deleteCalls, 3);
});

test('rejects encoded path traversal without touching photo storage',
    async () => {
  const photoWorker = authenticatedPhotoWorker();
  const {env, operations, photos} = photoEnvironment();
  for (const path of [
    'spot-photos/%2e%2e%2fabcdefghijklmnopqrst',
    'community-photos/owner-1%2fabcdefghijklmnopqrstuvwx',
    'community-admin/photos/%2e%2e%2fabcdefghijklmnopqrst',
  ]) {
    const response = await photoWorker.fetch(
      new Request(`https://maps.example/${path}`, {method: 'PUT'}),
      env,
    );
    assert.equal(response.status, 405);
  }
  assert.equal(operations.putCalls, 0);
  assert.equal(operations.deleteCalls, 0);
  assert.equal(photos.size, 0);
});

test('community R2 lifecycle fallback is exactly 14 days', async () => {
  const lifecycleUrl = new URL(
    '../community_photos_lifecycle.json',
    import.meta.url,
  );
  const lifecycle = JSON.parse(await readFile(lifecycleUrl, 'utf8'));
  assert.deepEqual(lifecycle, {
    rules: [
      {
        id: 'expire-community-photos-after-14-days',
        enabled: true,
        conditions: {prefix: ''},
        deleteObjectsTransition: {
          condition: {type: 'Age', maxAge: 14 * 24 * 60 * 60},
        },
      },
    ],
  });
});
