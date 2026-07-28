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
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, Range',
  'Access-Control-Allow-Methods': 'GET, HEAD, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Expose-Headers':
    'Accept-Ranges, Content-Length, Content-Range, ETag',
  'X-Content-Type-Options': 'nosniff',
};

const firebaseProjectId = 'zagorito-9a0c4';
const firebaseJwksUrl =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const maximumPhotoBytes = 2 * 1024 * 1024;
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
  headers.set('Cache-Control', 'public, max-age=3600, must-revalidate');
  return new Response(request.method === 'HEAD' ? null : object.body, {
    status: 200,
    headers,
  });
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
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > maximumPhotoBytes) {
    return errorResponse(413, 'Image exceeds 2 MB');
  }
  await bucket.put(key, bytes, {
    httpMetadata: {contentType},
    customMetadata: {ownerUid},
  });

  const url = new URL(request.url);
  url.search = `?v=${Date.now()}`;
  return jsonResponse(201, {photoUrl: url.toString()});
}

async function handlePhotoDelete(bucket, key, ownerUid) {
  const object = await bucket.head(key);
  if (object == null) return new Response(null, {status: 204});
  if (object.customMetadata?.ownerUid !== ownerUid) {
    return errorResponse(403, 'Forbidden');
  }
  await bucket.delete(key);
  return new Response(null, {status: 204});
}

export function createWorker({
  authenticate,
  getJwks = createJwksLoader(),
} = {}) {
  const authenticateRequest = authenticate
    ?? ((request) => defaultAuthenticate(request, getJwks));

  return {
    async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {status: 204, headers: commonHeaders});
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
