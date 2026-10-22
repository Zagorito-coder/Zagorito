'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {__test: {analyzeDocuments, documentSpecs, timestampMillis, runWatchdog, fieldMask, catalog}} = require('./index');

const now = new Date('2026-10-22T12:00:00Z');
const station = {id: 'agadir_maroc', name: 'Agadir, Maroc', lat: 30.42, lon: -9.6};
const source = {
  provider: 'Open-Meteo', weatherModel: 'gfs_seamless', comparisonModel: 'ecmwf_ifs',
  marineModelSelection: 'best_match', marineCellSelection: 'sea',
  seaLevelVariable: 'sea_level_height_msl', seaLevelReference: 'global_mean_sea_level',
  marineLatitude: station.lat, marineLongitude: station.lon, marineDistanceKm: 0,
};
const coverage = {weatherDays: 10, marineDays: 8, weatherStepHours: 3, conditionsStepHours: 1};

function fixture(stations = [station], aliases = {agadir_maroc: 'agadir'}, ageHours = 1, marineDays = 8) {
  const documents = new Map();
  for (const spec of documentSpecs(stations, aliases)) {
    const time = new Date(now.getTime() - ageHours * 3600000);
    const conditions = spec.collection === 'conditions';
    const data = {
      spot_id: spec.station.id,
      forecast_run_id: 'run-1',
      [conditions ? 'timestamp' : 'last_update']: spec.alias ? time.toISOString() : time,
      [spec.collection === 'spots_meteo' ? 'location_name' : 'name']: spec.station.name,
      [conditions ? 'lat' : 'latitude']: spec.station.lat,
      [conditions ? 'lon' : 'longitude']: spec.station.lon,
      timezone: 'Africa/Casablanca', utc_offset_seconds: 0,
      source: {...source, marineLatitude: spec.station.lat, marineLongitude: spec.station.lon},
      coverage: {...coverage, marineDays},
      schema_version: 2, tide_datum: 'global_mean_sea_level',
      gfs: {spot_id: spec.station.id, forecast_run_id: 'run-1'},
    };
    documents.set(spec.path, data);
  }
  return documents;
}

test('frozen catalogue monitors all 135 stations, 35 Moroccan stations and five historical aliases', () => {
  const specs = documentSpecs();
  assert.equal(catalog.stations.length, 135);
  assert.equal(catalog.stations.filter((item) => item.id.endsWith('_maroc')).length, 35);
  assert.equal(specs.length, 410);
  assert.equal(new Set(specs.map((item) => item.path)).size, 410);
  assert.equal(specs.filter((item) => item.alias).length, 5);
});

test('complete current metadata and valid seven-day fallback stay healthy', () => {
  for (const days of [7, 8]) {
    const summary = analyzeDocuments(fixture(undefined, undefined, 1, days), now, [station], {agadir_maroc: 'agadir'});
    assert.equal(summary.status, 'healthy');
    assert.equal(summary.checkedDocuments, 4);
    assert.deepEqual(summary.issues, []);
    assert.equal(summary.automaticallyDispatchesCollection, false);
  }
});

test('recovery, warning and critical thresholds are exact and precede the 36-hour client expiry', () => {
  for (const [age, expected] of [[7.99, 'healthy'], [8, 'recovery_due'], [11.99, 'recovery_due'], [12, 'warning'], [23.99, 'warning'], [24, 'critical']]) {
    const summary = analyzeDocuments(fixture(undefined, undefined, age), now, [station], {agadir_maroc: 'agadir'});
    assert.equal(summary.status, expected, String(age));
    assert.equal(summary.recoveryDueStations.length, age >= 8 ? 1 : 0);
  }
});

test('a missing historical alias is critical even when the canonical station is fresh', () => {
  const documents = fixture();
  documents.delete('conditions/agadir');
  const summary = analyzeDocuments(documents, now, [station], {agadir_maroc: 'agadir'});
  assert.equal(summary.status, 'critical');
  assert.equal(summary.morocco.critical, 1);
  assert.deepEqual(summary.issues.map((item) => item.reason), ['missing_document']);
});

test('future timestamps and malformed legacy timestamps cannot fake freshness', () => {
  const documents = fixture();
  documents.get('spots_meteo/agadir_maroc').last_update = new Date(now.getTime() + 301000);
  documents.get('conditions/agadir').timestamp = now;
  const summary = analyzeDocuments(documents, now, [station], {agadir_maroc: 'agadir'});
  assert.equal(summary.status, 'critical');
  assert(summary.issues.some((item) => item.reason === 'invalid_timestamp'));
  assert(summary.issues.some((item) => item.reason === 'invalid_legacy_timestamp'));
  assert(Number.isNaN(timestampMillis('2026-10-22T12:00:00')));
});

test('mixed runs, wrong coordinates and inconsistent coverage are not reported healthy', () => {
  const documents = fixture();
  documents.get('spots_index/agadir_maroc').forecast_run_id = 'another-run';
  documents.get('conditions/agadir_maroc').lat += 1;
  documents.get('conditions/agadir').coverage.marineDays = 7;
  const summary = analyzeDocuments(documents, now, [station], {agadir_maroc: 'agadir'});
  assert.equal(summary.status, 'critical');
  for (const reason of ['station_run_mismatch', 'station_identity', 'coverage_mismatch']) {
    assert(summary.issues.some((item) => item.reason === reason), reason);
  }
});

test('unsupported six-day coverage, invented source, unknown timezone and distant marine cell are rejected', () => {
  const documents = fixture();
  documents.get('spots_meteo/agadir_maroc').coverage.marineDays = 6;
  documents.get('conditions/agadir_maroc').source.provider = 'Another provider';
  documents.get('conditions/agadir_maroc').timezone = 'Invalid/Zone';
  documents.get('conditions/agadir').source.marineLatitude += 1;
  const summary = analyzeDocuments(documents, now, [station], {agadir_maroc: 'agadir'});
  assert.equal(summary.status, 'critical');
  for (const reason of ['invalid_coverage', 'invalid_source', 'invalid_time_zone', 'invalid_marine_cell']) {
    assert(summary.issues.some((item) => item.reason === reason), reason);
  }
});

test('cloud monitor requests metadata only and writes one private health document without touching forecasts', async () => {
  const documents = fixture(catalog.stations, catalog.aliases);
  const writes = [];
  let reads = 0;
  const firestore = {
    doc(path) {
      return {path, async set(data) {writes.push({path, data});}};
    },
    async getAll(...args) {
      reads++;
      const options = args.pop();
      assert.deepEqual(options.fieldMask, [...fieldMask]);
      assert(!options.fieldMask.some((field) => field === 'days' || field.includes('hourly')));
      return args.map((ref) => ({ref, exists: documents.has(ref.path), data: () => documents.get(ref.path)}));
    },
  };
  const events = [];
  const log = Object.fromEntries(['info', 'warn', 'error'].map((level) => [level, (...args) => events.push({level, args})]));
  const summary = await runWatchdog({firestore, now, log});
  assert.equal(reads, 1);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].path, 'collector_health/weather-watchdog');
  assert.equal(summary.status, 'healthy');
  assert.equal(summary.checkedDocuments, 410);
  assert.equal(events[0].level, 'info');
});

test('read failure cannot produce a fabricated healthy report or write forecast data', async () => {
  let writes = 0;
  const firestore = {doc: (path) => ({path, async set() {writes++;}}), getAll: async () => {throw new Error('unavailable');}};
  await assert.rejects(runWatchdog({firestore, now}), /unavailable/);
  assert.equal(writes, 0);
});
