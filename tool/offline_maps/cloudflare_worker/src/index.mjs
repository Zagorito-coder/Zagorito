const allowedObjects = new Set([
  'manifest.json',
  'ae.pmtiles',
  'bh.pmtiles',
  'dz.pmtiles',
  'eg.pmtiles',
  'ly.pmtiles',
  'ma.pmtiles',
  'om.pmtiles',
  'sa.pmtiles',
  'sy.pmtiles',
  'tn.pmtiles',
  'ye.pmtiles',
]);

const commonHeaders = {
  'Access-Control-Allow-Headers':
    'Authorization, Content-Type, Range, X-Firebase-AppCheck',
  'Access-Control-Allow-Methods': 'GET, HEAD, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Expose-Headers':
    'Accept-Ranges, Content-Length, Content-Range, ETag',
  'X-Content-Type-Options': 'nosniff',
};

const firebaseProjectId = 'zagorito-9a0c4';
const firebaseProjectNumber = '68722970471';
const firebaseAndroidAppId =
  '1:68722970471:android:22dce79885650fc112e9c2';
const firebaseJwksUrl =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const firebaseAppCheckJwksUrl =
  'https://firebaseappcheck.googleapis.com/v1/jwks';
const maximumPhotoBytes = 2 * 1024 * 1024;
const maximumDeleteAttempts = 3;
const photoContentTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

function errorResponse(status, message, extraHeaders = {}) {
  return new Response(message, {
    status,
    headers: {
      ...commonHeaders,
      ...extraHeaders,
      'Cache-Control': 'no-store',
      'Content-Type': 'text/plain; charset=utf-8',
    },
  });
}

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...commonHeaders,
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}

function emptyResponse(status) {
  return new Response(null, {
    status,
    headers: {
      ...commonHeaders,
      'Cache-Control': 'no-store',
    },
  });
}

function offlineObjectKey(request) {
  const path = new URL(request.url).pathname;
  if (path === '/' || path.includes('%2f') || path.includes('%2F')) return null;

  let decodedPath;
  try {
    decodedPath = decodeURIComponent(path);
  } catch {
    return null;
  }

  const key = decodedPath.slice(1);
  return allowedObjects.has(key) ? key : null;
}

function photoObjectKey(request) {
  const path = new URL(request.url).pathname;
  const match = /^\/spot-photos\/([A-Za-z0-9_-]{20,96})$/.exec(path);
  return match?.[1] ?? null;
}

function communityPhotoObjectKey(request) {
  const path = new URL(request.url).pathname;
  const match = /^\/community-photos\/([A-Za-z0-9_-]{20,225})$/.exec(path);
  return match?.[1] ?? null;
}

function communityAdminPhotoObjectKey(request) {
  const path = new URL(request.url).pathname;
  const match =
    /^\/community-admin\/photos\/([A-Za-z0-9_-]{20,225})$/.exec(path);
  return match?.[1] ?? null;
}

function parseRange(value, size) {
  if (value == null) return null;
  const match = /^bytes=(\d+)-(\d*)$/.exec(value.trim());
  if (match == null) return false;

  const start = Number(match[1]);
  const requestedEnd = match[2] === '' ? size - 1 : Number(match[2]);
  if (
    !Number.isSafeInteger(start) ||
    !Number.isSafeInteger(requestedEnd) ||
    start < 0 ||
    start >= size ||
    requestedEnd < start
  ) {
    return false;
  }

  const end = Math.min(requestedEnd, size - 1);
  return {
    end,
    length: end - start + 1,
    offset: start,
  };
}

function responseHeaders(object, key, contentLength) {
  const headers = new Headers(commonHeaders);
  object.writeHttpMetadata(headers);
  headers.set('Accept-Ranges', 'bytes');
  headers.set('Content-Length', String(contentLength));
  headers.set('ETag', object.httpEtag);
  headers.set(
    'Cache-Control',
    key.endsWith('.pmtiles')
      ? 'public, max-age=31536000, immutable'
      : 'public, max-age=300, must-revalidate',
  );
  return headers;
}

async function handleHead(bucket, key) {
  const object = await bucket.head(key);
  if (object == null) return errorResponse(404, 'Not found');

  return new Response(null, {
    status: 200,
    headers: responseHeaders(object, key, object.size),
  });
}

async function handleGet(request, bucket, key) {
  const rangeValue = request.headers.get('Range');
  if (rangeValue == null) {
    const object = await bucket.get(key);
    if (object == null) return errorResponse(404, 'Not found');

    return new Response(object.body, {
      status: 200,
      headers: responseHeaders(object, key, object.size),
    });
  }

  const metadata = await bucket.head(key);
  if (metadata == null) return errorResponse(404, 'Not found');

  const range = parseRange(rangeValue, metadata.size);
  if (range === false) {
    return errorResponse(416, 'Range not satisfiable', {
      'Content-Range': `bytes */${metadata.size}`,
    });
  }

  const object = await bucket.get(key, {
    range: {
      length: range.length,
      offset: range.offset,
    },
  });
  if (object == null) return errorResponse(404, 'Not found');

  const headers = responseHeaders(object, key, range.length);
  headers.set(
    'Content-Range',
    `bytes ${range.offset}-${range.end}/${metadata.size}`,
  );
  return new Response(object.body, {status: 206, headers});
}

function decodeBase64Url(value) {
  const normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  const padded = normalized.padEnd(
    normalized.length + ((4 - (normalized.length % 4)) % 4),
    '=',
  );
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function decodeJwtSection(value) {
  return JSON.parse(textDecoder.decode(decodeBase64Url(value)));
}

async function defaultAuthenticate(request, getJwks) {
  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return null;
  const token = authorization.slice(7).trim();
  const sections = token.split('.');
  if (sections.length !== 3) return null;

  let header;
  let payload;
  try {
    header = decodeJwtSection(sections[0]);
    payload = decodeJwtSection(sections[1]);
  } catch {
    return null;
  }
  if (
    header.alg !== 'RS256'
    || typeof header.kid !== 'string'
    || payload.aud !== firebaseProjectId
    || payload.iss !== `https://securetoken.google.com/${firebaseProjectId}`
    || typeof payload.sub !== 'string'
    || payload.sub.length === 0
    || payload.sub.length > 128
  ) {
    return null;
  }

  const now = Math.floor(Date.now() / 1000);
  if (
    typeof payload.exp !== 'number'
    || payload.exp <= now
    || typeof payload.iat !== 'number'
    || payload.iat > now + 300
  ) {
    return null;
  }

  try {
    const jwks = await getJwks();
    const jwk = jwks[header.kid];
    if (jwk == null) return null;
    const key = await crypto.subtle.importKey(
      'jwk',
      jwk,
      {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'},
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      decodeBase64Url(sections[2]),
      textEncoder.encode(`${sections[0]}.${sections[1]}`),
    );
    return valid
      ? {uid: payload.sub, canReview: payload.spotReviewer === true}
      : null;
  } catch {
    return null;
  }
}

export function hasExpectedAppCheckClaims(header, payload) {
  if (
    header == null
    || typeof header !== 'object'
    || payload == null
    || typeof payload !== 'object'
  ) {
    return false;
  }
  const audience = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  return !(
    header.alg !== 'RS256'
    || header.typ !== 'JWT'
    || typeof header.kid !== 'string'
    || payload.iss
      !== `https://firebaseappcheck.googleapis.com/${firebaseProjectNumber}`
    || !audience.includes(`projects/${firebaseProjectNumber}`)
    || typeof payload.sub !== 'string'
    || payload.sub !== firebaseAndroidAppId
  );
}

function isOwnerScopedCommunityPhotoKey(key, ownerUid) {
  return typeof ownerUid === 'string'
    && ownerUid.length > 0
    && ownerUid.length <= 128
    && key.startsWith(`${ownerUid}_`)
    && key.length > ownerUid.length + 20;
}

async function defaultAuthenticateAppCheck(request, getJwks) {
  const token = request.headers.get('X-Firebase-AppCheck') ?? '';
  const sections = token.split('.');
  if (sections.length !== 3) return null;

  let header;
  let payload;
  try {
    header = decodeJwtSection(sections[0]);
    payload = decodeJwtSection(sections[1]);
  } catch {
    return null;
  }
  if (!hasExpectedAppCheckClaims(header, payload)) {
    return null;
  }

  const now = Math.floor(Date.now() / 1000);
  if (
    typeof payload.exp !== 'number'
    || payload.exp <= now
    || typeof payload.iat !== 'number'
    || payload.iat > now + 300
  ) {
    return null;
  }
  try {
    const jwks = await getJwks();
    const jwk = jwks[header.kid];
    if (jwk == null) return null;
    const key = await crypto.subtle.importKey(
      'jwk',
      jwk,
      {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'},
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      decodeBase64Url(sections[2]),
      textEncoder.encode(`${sections[0]}.${sections[1]}`),
    );
    return valid ? payload.sub : null;
  } catch {
    return null;
  }
}

function createJwksLoader() {
  let cachedJwks = null;
  let expiresAt = 0;
  return async () => {
    if (cachedJwks != null && Date.now() < expiresAt) return cachedJwks;
    const response = await fetch(firebaseJwksUrl, {
      cf: {cacheEverything: true, cacheTtl: 3600},
    });
    if (!response.ok) throw new Error('Firebase keys unavailable');
    cachedJwks = indexFirebaseJwks(await response.json());
    expiresAt = Date.now() + 60 * 60 * 1000;
    return cachedJwks;
  };
}

function createAppCheckJwksLoader() {
  let cachedJwks = null;
  let expiresAt = 0;
  return async () => {
    if (cachedJwks != null && Date.now() < expiresAt) return cachedJwks;
    const response = await fetch(firebaseAppCheckJwksUrl, {
      cf: {cacheEverything: true, cacheTtl: 21600},
    });
    if (!response.ok) throw new Error('Firebase App Check keys unavailable');
    cachedJwks = indexFirebaseJwks(await response.json());
    expiresAt = Date.now() + 6 * 60 * 60 * 1000;
    return cachedJwks;
  };
}

export function indexFirebaseJwks(payload) {
  if (payload == null || typeof payload !== 'object') return {};
  if (!Array.isArray(payload.keys)) return payload;
  return Object.fromEntries(
    payload.keys
      .filter((key) => key != null && typeof key.kid === 'string')
      .map((key) => [key.kid, key]),
  );
}

async function handlePhotoGet(request, bucket, key, actor) {
  const object = request.method === 'HEAD'
    ? await bucket.head(key)
    : await bucket.get(key);
  if (object == null) return errorResponse(404, 'Not found');
  if (
    object.customMetadata?.ownerUid !== actor.uid
    && actor.canReview !== true
  ) {
    return errorResponse(403, 'Forbidden');
  }
  const headers = responseHeaders(object, key, object.size);
  // Authenticated photos must never enter a shared or browser HTTP cache.
  // `Vary` is kept as an additional defence if an intermediary ignores
  // `private`/`no-store`.
  headers.set('Cache-Control', 'private, no-store');
  headers.set('Vary', 'Authorization');
  return new Response(request.method === 'HEAD' ? null : object.body, {
    status: 200,
    headers,
  });
}

async function readRequestBodyWithinLimit(request, maximumBytes) {
  if (request.body == null) return new Uint8Array(0);

  const reader = request.body.getReader();
  const chunks = [];
  let totalBytes = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      const chunk = value instanceof Uint8Array
        ? value
        : new Uint8Array(value);
      totalBytes += chunk.byteLength;
      if (totalBytes > maximumBytes) {
        await reader.cancel('Photo exceeds the accepted size');
        return null;
      }
      chunks.push(chunk);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

async function handlePhotoPut(request, bucket, key, ownerUid) {
  const contentType = (request.headers.get('Content-Type') ?? '')
    .split(';', 1)[0]
    .trim()
    .toLowerCase();
  if (!photoContentTypes.has(contentType)) {
    return errorResponse(415, 'Unsupported image type');
  }
  const announcedLengthHeader = request.headers.get('Content-Length');
  const announcedLength = Number(announcedLengthHeader);
  if (
    announcedLengthHeader != null
    &&
    Number.isFinite(announcedLength)
    && (announcedLength <= 0 || announcedLength > maximumPhotoBytes)
  ) {
    return errorResponse(413, 'Image exceeds 2 MB');
  }

  const existing = await bucket.head(key);
  if (
    existing != null
    && existing.customMetadata?.ownerUid !== ownerUid
  ) {
    return errorResponse(403, 'Forbidden');
  }
  const bytes = await readRequestBodyWithinLimit(request, maximumPhotoBytes);
  if (bytes == null || bytes.byteLength === 0) {
    return errorResponse(413, 'Image exceeds 2 MB');
  }
  if (!hasExpectedImageSignature(bytes, contentType)) {
    return errorResponse(415, 'Image content does not match its type');
  }
  await bucket.put(key, bytes, {
    httpMetadata: {contentType},
    customMetadata: {ownerUid},
  });

  const url = new URL(request.url);
  url.search = `?v=${Date.now()}`;
  return jsonResponse(201, {photoUrl: url.toString()});
}

function hasExpectedImageSignature(bytes, contentType) {
  if (contentType === 'image/jpeg') {
    return bytes.length >= 4
      && bytes[0] === 0xff
      && bytes[1] === 0xd8
      && bytes[2] === 0xff;
  }
  if (contentType === 'image/png') {
    const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    return bytes.length >= signature.length
      && signature.every((value, index) => bytes[index] === value);
  }
  if (contentType === 'image/webp') {
    return bytes.length >= 12
      && String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF'
      && String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP';
  }
  return false;
}

async function handlePublicPhotoGet(request, bucket, key) {
  const object = request.method === 'HEAD'
    ? await bucket.head(key)
    : await bucket.get(key);
  if (object == null) return errorResponse(404, 'Not found');
  const headers = responseHeaders(object, key, object.size);
  // Community photos are revoked by deleting their R2 object. Do not allow a
  // browser or intermediary to keep serving the bytes after that deletion.
  headers.set('Cache-Control', 'no-store');
  return new Response(request.method === 'HEAD' ? null : object.body, {
    status: 200,
    headers,
  });
}

async function deleteObjectWithRetry(bucket, key) {
  let lastError;
  for (let attempt = 0; attempt < maximumDeleteAttempts; attempt += 1) {
    try {
      // R2 DELETE is idempotent. A retry is therefore safe when the first call
      // deleted the object but its response was lost.
      await bucket.delete(key);
      return;
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error('Unable to delete R2 object');
}

async function hasValidAdminKey(request, configuredKey) {
  const supplied = request.headers.get('X-Community-Admin-Key') ?? '';
  if (
    typeof configuredKey !== 'string'
    || configuredKey.length < 32
    || supplied.length !== configuredKey.length
  ) {
    return false;
  }
  const [suppliedDigest, configuredDigest] = await Promise.all([
    crypto.subtle.digest('SHA-256', textEncoder.encode(supplied)),
    crypto.subtle.digest('SHA-256', textEncoder.encode(configuredKey)),
  ]);
  const suppliedBytes = new Uint8Array(suppliedDigest);
  const configuredBytes = new Uint8Array(configuredDigest);
  let difference = 0;
  for (let index = 0; index < suppliedBytes.length; index += 1) {
    difference |= suppliedBytes[index] ^ configuredBytes[index];
  }
  return difference === 0;
}

async function handlePhotoDelete(bucket, key, ownerUid) {
  const object = await bucket.head(key);
  if (object == null) return emptyResponse(204);
  if (object.customMetadata?.ownerUid !== ownerUid) {
    return errorResponse(403, 'Forbidden');
  }
  await deleteObjectWithRetry(bucket, key);
  return emptyResponse(204);
}

export function createWorker({
  authenticate,
  authenticateAppCheck,
  getJwks = createJwksLoader(),
  getAppCheckJwks = createAppCheckJwksLoader(),
} = {}) {
  const authenticateRequest = authenticate
    ?? ((request) => defaultAuthenticate(request, getJwks));
  const authenticateAppRequest = authenticateAppCheck
    ?? ((request) => defaultAuthenticateAppCheck(request, getAppCheckJwks));

  return {
    async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return emptyResponse(204);
    }

    const adminPhotoKey = communityAdminPhotoObjectKey(request);
    if (adminPhotoKey != null) {
      if (request.method !== 'DELETE') {
        return errorResponse(405, 'Method not allowed', {Allow: 'DELETE'});
      }
      if (!await hasValidAdminKey(request, env.COMMUNITY_ADMIN_KEY)) {
        return errorResponse(401, 'Unauthorized');
      }
      try {
        await deleteObjectWithRetry(env.COMMUNITY_PHOTOS, adminPhotoKey);
        return emptyResponse(204);
      } catch {
        return errorResponse(503, 'Storage temporarily unavailable');
      }
    }

    const communityPhotoKey = communityPhotoObjectKey(request);
    if (communityPhotoKey != null) {
      try {
        if (
          request.method !== 'GET'
          && request.method !== 'HEAD'
          && request.method !== 'PUT'
          && request.method !== 'DELETE'
        ) {
          return errorResponse(405, 'Method not allowed', {
            Allow: 'GET, HEAD, PUT, DELETE',
          });
        }
        if (request.method === 'GET' || request.method === 'HEAD') {
          return await handlePublicPhotoGet(
            request,
            env.COMMUNITY_PHOTOS,
            communityPhotoKey,
          );
        }
        const authentication = await authenticateRequest(request);
        if (authentication == null) return errorResponse(401, 'Unauthorized');
        const appId = await authenticateAppRequest(request);
        if (appId == null) {
          return errorResponse(401, 'Invalid Firebase App Check token');
        }
        const actor = typeof authentication === 'string'
          ? {uid: authentication}
          : authentication;
        if (!isOwnerScopedCommunityPhotoKey(communityPhotoKey, actor.uid)) {
          return errorResponse(403, 'Forbidden');
        }
        return request.method === 'PUT'
          ? await handlePhotoPut(
              request,
              env.COMMUNITY_PHOTOS,
              communityPhotoKey,
              actor.uid,
            )
          : await handlePhotoDelete(
              env.COMMUNITY_PHOTOS,
              communityPhotoKey,
              actor.uid,
            );
      } catch {
        return errorResponse(503, 'Storage temporarily unavailable');
      }
    }

    const photoKey = photoObjectKey(request);
    if (photoKey != null) {
      try {
        if (
          request.method !== 'GET'
          && request.method !== 'HEAD'
          && request.method !== 'PUT'
          && request.method !== 'DELETE'
        ) {
          return errorResponse(405, 'Method not allowed', {
            Allow: 'GET, HEAD, PUT, DELETE',
          });
        }
        const authentication = await authenticateRequest(request);
        if (authentication == null) return errorResponse(401, 'Unauthorized');
        const actor = typeof authentication === 'string'
          ? {uid: authentication, canReview: false}
          : authentication;
        if (request.method === 'GET' || request.method === 'HEAD') {
          return await handlePhotoGet(
            request,
            env.SPOT_PHOTOS,
            photoKey,
            actor,
          );
        }
        const appId = await authenticateAppRequest(request);
        if (appId == null) {
          return errorResponse(401, 'Invalid Firebase App Check token');
        }
        return request.method === 'PUT'
          ? await handlePhotoPut(request, env.SPOT_PHOTOS, photoKey, actor.uid)
          : await handlePhotoDelete(env.SPOT_PHOTOS, photoKey, actor.uid);
      } catch {
        return errorResponse(503, 'Storage temporarily unavailable');
      }
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return errorResponse(405, 'Method not allowed', {
        Allow: 'GET, HEAD',
      });
    }

    const key = offlineObjectKey(request);
    if (key == null) return errorResponse(404, 'Not found');

    try {
      return request.method === 'HEAD'
        ? await handleHead(env.OFFLINE_MAPS, key)
        : await handleGet(request, env.OFFLINE_MAPS, key);
    } catch {
      return errorResponse(503, 'Storage temporarily unavailable');
    }
    },
  };
}

export default createWorker();
