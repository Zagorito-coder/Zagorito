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
and keeps the R2 bucket private.

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
