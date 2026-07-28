import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const baseUrl =
  process.argv.find((argument) => argument.startsWith('--base-url='))?.slice(11) ??
  'https://boosterfish-offline-maps.boosterfish-maps.workers.dev/';
const manifestPath =
  process.argv.find((argument) => argument.startsWith('--manifest='))?.slice(11) ??
  '/tmp/boosterfish_country_packs/manifest.json';

const expectedManifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const manifestResponse = await fetch(new URL('manifest.json', baseUrl), {
  headers: {'Cache-Control': 'no-cache'},
});
assert.equal(manifestResponse.status, 200);
assert.match(
  manifestResponse.headers.get('content-type') ?? '',
  /^application\/json/,
);
const remoteManifest = await manifestResponse.json();
assert.deepEqual(remoteManifest, expectedManifest);

for (const region of remoteManifest.regions) {
  const fileUrl = new URL(region.file, baseUrl);
  const headResponse = await fetch(fileUrl, {method: 'HEAD'});
  assert.equal(headResponse.status, 200, `${region.countryCode} HEAD`);
  assert.equal(
    Number(headResponse.headers.get('content-length')),
    region.sizeBytes,
    `${region.countryCode} size`,
  );
  assert.equal(
    headResponse.headers.get('content-type'),
    'application/vnd.pmtiles',
    `${region.countryCode} content type`,
  );
  assert.equal(headResponse.headers.get('accept-ranges'), 'bytes');

  const rangeResponse = await fetch(fileUrl, {
    headers: {Range: 'bytes=0-15'},
  });
  assert.equal(rangeResponse.status, 206, `${region.countryCode} range`);
  assert.equal(
    rangeResponse.headers.get('content-range'),
    `bytes 0-15/${region.sizeBytes}`,
    `${region.countryCode} content range`,
  );
  const header = new Uint8Array(await rangeResponse.arrayBuffer());
  assert.equal(header.byteLength, 16);
  assert.deepEqual(
    [...header.slice(0, 8)],
    [0x50, 0x4d, 0x54, 0x69, 0x6c, 0x65, 0x73, 0x03],
    `${region.countryCode} PMTiles header`,
  );
}

const missingResponse = await fetch(new URL('private.txt', baseUrl));
assert.equal(missingResponse.status, 404);

const invalidRangeResponse = await fetch(
  new URL(remoteManifest.regions[0].file, baseUrl),
  {headers: {Range: 'bytes=9999999999-'}},
);
assert.equal(invalidRangeResponse.status, 416);

const methodResponse = await fetch(new URL('manifest.json', baseUrl), {
  method: 'POST',
});
assert.equal(methodResponse.status, 405);

console.log(
  `Verified ${remoteManifest.regions.length} country packs at ${baseUrl}`,
);
