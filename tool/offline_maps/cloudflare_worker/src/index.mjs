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
  'Access-Control-Allow-Headers': 'Range',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Expose-Headers':
    'Accept-Ranges, Content-Length, Content-Range, ETag',
  'X-Content-Type-Options': 'nosniff',
};

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

function objectKey(request) {
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

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {status: 204, headers: commonHeaders});
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return errorResponse(405, 'Method not allowed', {Allow: 'GET, HEAD'});
    }

    const key = objectKey(request);
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
