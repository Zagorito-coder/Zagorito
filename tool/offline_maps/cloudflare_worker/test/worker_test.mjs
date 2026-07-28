import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../src/index.mjs';

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
