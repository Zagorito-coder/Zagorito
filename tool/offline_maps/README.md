# Offline map packs

The app downloads immutable vector PMTiles files from:

`https://boosterfish-offline-maps.boosterfish-maps.workers.dev/`

`OFFLINE_MAP_BASE_URL` can override this production URL at build time.

## Catalog policy

Only Arab countries represented by at least 30 bundled spots are published.
The app enforces the same policy when parsing a remote manifest. European,
non-Arab, and under-threshold entries are rejected.

The current catalog contains 11 packs and 5,992 spots:

- United Arab Emirates
- Bahrain
- Algeria
- Egypt
- Libya
- Morocco
- Oman
- Saudi Arabia
- Syria
- Tunisia
- Yemen

## Sources and license

Map source: Protomaps Basemap daily build `20260722`, derived from
OpenStreetMap.

Country boundaries used for the reproducible inventory come from Natural
Earth `ne_10m_admin_0_countries`.

The map data is an ODbL Produced Work. The app keeps visible attribution to
`OpenStreetMap contributors` and Protomaps. PMTiles binaries are generated
artifacts and must not be committed to the repository.

Country flag assets in `assets/flags/` are the 4:3 waving renders from
[Flagpedia/FlagCDN](https://flagpedia.net/download/icons), whose flag images
are published in the public domain for commercial and non-commercial use.
They are bundled as lossless WebP files so the manager remains fully offline.
The Syria asset uses the current green-white-black flag with three red stars.

## Reproducible generation

From the repository root:

```sh
node tool/offline_maps/discover_spot_countries.mjs \
  assets/spots.csv \
  /tmp/ne_10m_admin_0_countries.geojson \
  > /tmp/boosterfish-spot-countries.json

node tool/offline_maps/build_country_packs.mjs \
  --dry-run \
  --inventory=/tmp/boosterfish-spot-countries.json \
  --output=/tmp/boosterfish_country_packs

node tool/offline_maps/build_country_packs.mjs \
  --inventory=/tmp/boosterfish-spot-countries.json \
  --output=/tmp/boosterfish_country_packs
```

## Cloudflare R2 endpoint

The production endpoint is defined in `cloudflare_worker/`. It exposes only
the manifest and the generated country packs, supports resumable byte ranges,
and keeps the R2 buckets private. It also mediates personal and community photo
access. Photo mutations require Firebase Auth and Firebase App Check; personal
photo reads remain private to their owner (or a reviewer) and community photo
reads are public while the corresponding publication is retained. Photo
responses use `no-store` so deleting the R2 object revokes subsequent reads.

Run the Worker tests before any deployment:

```sh
node --test tool/offline_maps/cloudflare_worker/test/worker_test.mjs
```

Deploy from the repository root:

```sh
npx wrangler deploy \
  --config tool/offline_maps/cloudflare_worker/wrangler.jsonc

node tool/offline_maps/upload_country_packs.mjs \
  --input=/tmp/boosterfish_country_packs

node tool/offline_maps/verify_deployment.mjs \
  --manifest=/tmp/boosterfish_country_packs/manifest.json \
  --base-url=https://boosterfish-offline-maps.boosterfish-maps.workers.dev/
```

### Safe photo-security rollout

Do not deploy the Worker change that enforces App Check on personal photo
mutations until the mobile client version that sends `X-Firebase-AppCheck` for
both `PUT` and `DELETE /spot-photos/...` is ready. Sending the header is
backwards-compatible with the old Worker, so the safe order is mobile client
first, Worker second. Validate the final flow from a Google Play Internal build
because a cable-installed APK does not prove Play Integrity attestation.

The Worker retries an R2 deletion up to three times. A missing object returns
`204`, so callers can replay a deletion safely. Persistent storage failures
return `503`; the caller must retain its cleanup reference and retry rather than
deleting that reference.

The previous Worker allowed downstream clients to cache community photos for
24 hours and personal photos for one hour. After deploying this version:

1. verify that no Cloudflare Cache Rule or custom-domain rule overrides
   `Cache-Control: no-store` for `/spot-photos/*` or `/community-photos/*`;
2. purge these URL prefixes if the Worker is also exposed through a proxied
   custom domain; the current `workers.dev` endpoint does not use the Workers
   Cache API, but already cached browser responses cannot be remotely erased;
3. allow the previous 24-hour client cache window to expire before treating
   revocation as fully migrated, then verify that a deleted URL returns `404`.

Cloudflare references: [R2 Cache API limitations](https://developers.cloudflare.com/r2/examples/cache-api/)
and [single-file/prefix purge](https://developers.cloudflare.com/cache/how-to/purge-cache/).

### Community-photo lifecycle fallback (remote configuration)

Ordinary community publications live for at most seven days and a winner is
retained only until the following weekly selection. Once the cleanup cron has
been deployed and observed successfully, apply the checked-in 14-day safety
net to **`boosterfish-community-photos` only**:

```sh
npx wrangler r2 bucket lifecycle set boosterfish-community-photos \
  --file tool/offline_maps/cloudflare_worker/community_photos_lifecycle.json \
  --config tool/offline_maps/cloudflare_worker/wrangler.jsonc

npx wrangler r2 bucket lifecycle list boosterfish-community-photos \
  --config tool/offline_maps/cloudflare_worker/wrangler.jsonc
```

Before applying it, inventory the bucket, reconcile objects with current
Firestore publications/winner state, remove confirmed orphans, and verify that
the weekly selection and five-minute cleanup jobs are healthy. Lifecycle
deletion is asynchronous and is only a fallback, not a replacement for those
jobs. Never apply an age-based lifecycle to `boosterfish-spot-photos`: personal
spots have no fixed retention deadline and valid photos would be destroyed.

The lifecycle command changes Cloudflare state and is intentionally not part of
`wrangler.jsonc` or the Worker deployment. Cloudflare requires a separate
bucket-level lifecycle operation; see the [R2 lifecycle documentation](https://developers.cloudflare.com/r2/buckets/object-lifecycles/).
