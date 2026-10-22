'use strict';

const {initializeApp, getApps} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const catalog = require('./stations.json');

if (getApps().length === 0) initializeApp();

const hourMs = 60 * 60 * 1000;
const recoveryHours = 8;
const warningHours = 12;
const criticalHours = 24;
const futureToleranceMs = 5 * 60 * 1000;
const serviceAccount =
  'boosterfish-community-runtime@zagorito-9a0c4.iam.gserviceaccount.com';
const expectedSource = Object.freeze({
  provider: 'Open-Meteo',
  weatherModel: 'gfs_seamless',
  comparisonModel: 'ecmwf_ifs',
  marineModelSelection: 'best_match',
  marineCellSelection: 'sea',
  seaLevelVariable: 'sea_level_height_msl',
  seaLevelReference: 'global_mean_sea_level',
});
const fieldMask = Object.freeze([
  'spot_id', 'forecast_run_id', 'last_update', 'timestamp',
  'location_name', 'name', 'latitude', 'longitude', 'lat', 'lon',
  'timezone', 'utc_offset_seconds', 'coverage', 'source', 'schema_version',
  'tide_datum', 'gfs.forecast_run_id', 'gfs.spot_id',
]);

function timestampMillis(value, requireIsoString = false) {
  if (typeof value === 'string') {
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return NaN;
    return Date.parse(value);
  }
  if (requireIsoString) return NaN;
  if (value instanceof Date) return value.getTime();
  if (value && typeof value.toDate === 'function') {
    const date = value.toDate();
    return date instanceof Date ? date.getTime() : NaN;
  }
  return NaN;
}

function documentSpecs(stations = catalog.stations, aliases = catalog.aliases) {
  const specs = [];
  for (const station of stations) {
    for (const collection of ['spots_meteo', 'spots_index', 'conditions']) {
      specs.push({station, collection, path: `${collection}/${station.id}`, alias: false});
    }
    const alias = aliases[station.id];
    if (alias) specs.push({station, collection: 'conditions', path: `conditions/${alias}`, alias: true});
  }
  return specs;
}

function sameCoverage(left, right) {
  return !!left && !!right && ['weatherDays', 'marineDays', 'weatherStepHours', 'conditionsStepHours']
    .every((key) => left[key] === right[key]);
}

function validCoverage(value) {
  return !!value && value.weatherDays === 10
    && Number.isInteger(value.marineDays) && value.marineDays >= 7 && value.marineDays <= 8
    && value.weatherStepHours === 3 && value.conditionsStepHours === 1;
}

function finiteCoordinates(data, station, isConditions) {
  const latitude = data[isConditions ? 'lat' : 'latitude'];
  const longitude = data[isConditions ? 'lon' : 'longitude'];
  return typeof latitude === 'number' && Number.isFinite(latitude)
    && typeof longitude === 'number' && Number.isFinite(longitude)
    && Math.abs(latitude - station.lat) <= 1e-6
    && Math.abs(longitude - station.lon) <= 1e-6;
}

function validTimeZone(value) {
  if (typeof value !== 'string' || !value.trim() || value !== value.trim()) return false;
  try {
    new Intl.DateTimeFormat('en', {timeZone: value}).format(0);
    return true;
  } catch {
    return false;
  }
}

function validMarineCell(source, station) {
  const lat = source?.marineLatitude;
  const lon = source?.marineLongitude;
  const publishedDistance = source?.marineDistanceKm;
  if (typeof lat !== 'number' || !Number.isFinite(lat) || Math.abs(lat) > 90
    || typeof lon !== 'number' || !Number.isFinite(lon) || Math.abs(lon) > 180
    || typeof publishedDistance !== 'number' || !Number.isFinite(publishedDistance)
    || publishedDistance < 0 || publishedDistance > 30) return false;
  const radians = (degrees) => degrees * Math.PI / 180;
  const sinLatitude = Math.sin(radians(lat - station.lat) / 2);
  const sinLongitude = Math.sin(radians(lon - station.lon) / 2);
  const value = sinLatitude ** 2
    + Math.cos(radians(station.lat)) * Math.cos(radians(lat)) * sinLongitude ** 2;
  const distance = 6371 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(Math.max(0, 1 - value)));
  return distance <= 30 && Math.abs(publishedDistance - Math.round(distance * 10) / 10) <= 0.05;
}

function analyzeDocuments(documents, now = new Date(), stations = catalog.stations, aliases = catalog.aliases) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime())) throw new TypeError('Invalid monitor time.');
  const specs = documentSpecs(stations, aliases);
  const issues = [];
  const stationAges = new Map();
  let checkedDocuments = 0;
  for (const spec of specs) {
    const data = documents.get(spec.path);
    const addIssue = (reason) => issues.push({stationId: spec.station.id, path: spec.path, reason});
    if (!data || typeof data !== 'object') {
      addIssue('missing_document');
      continue;
    }
    checkedDocuments++;
    const conditions = spec.collection === 'conditions';
    const name = spec.collection === 'spots_meteo' ? data.location_name : data.name;
    if (data.spot_id !== spec.station.id || name !== spec.station.name
      || !finiteCoordinates(data, spec.station, conditions)) addIssue('station_identity');
    const run = data.forecast_run_id;
    if (typeof run !== 'string' || run.trim() !== run || !run) addIssue('missing_run');
    const weather = documents.get(`spots_meteo/${spec.station.id}`);
    if (weather && run !== weather.forecast_run_id) addIssue('station_run_mismatch');
    const millis = timestampMillis(conditions ? data.timestamp : data.last_update, spec.alias);
    if (!Number.isFinite(millis) || millis > now.getTime() + futureToleranceMs) {
      addIssue(spec.alias ? 'invalid_legacy_timestamp' : 'invalid_timestamp');
    } else {
      const age = Math.max(0, (now.getTime() - millis) / hourMs);
      stationAges.set(spec.station.id, Math.max(age, stationAges.get(spec.station.id) ?? 0));
    }
    if (spec.collection === 'spots_index') continue;
    if (!validCoverage(data.coverage)) addIssue('invalid_coverage');
    if (weather && !sameCoverage(data.coverage, weather.coverage)) addIssue('coverage_mismatch');
    if (!data.source || Object.entries(expectedSource).some(([key, value]) => data.source[key] !== value)) addIssue('invalid_source');
    if (!validTimeZone(data.timezone)
      || !Number.isInteger(data.utc_offset_seconds) || Math.abs(data.utc_offset_seconds) > 18 * 3600) addIssue('invalid_time_zone');
    if (weather && (data.timezone !== weather.timezone || data.utc_offset_seconds !== weather.utc_offset_seconds)) addIssue('time_zone_mismatch');
    if (conditions && (data.schema_version !== 2 || data.tide_datum !== 'global_mean_sea_level'
      || data.gfs?.forecast_run_id !== run || data.gfs?.spot_id !== spec.station.id)) addIssue('invalid_conditions_identity');
    if (conditions && !validMarineCell(data.source, spec.station)) addIssue('invalid_marine_cell');
  }
  const byStation = stations.map((station) => {
    const ageHours = stationAges.get(station.id);
    const invalid = issues.some((issue) => issue.stationId === station.id);
    return {
      stationId: station.id,
      ageHours: Number.isFinite(ageHours) ? Math.round(ageHours * 1000) / 1000 : null,
      status: invalid || ageHours >= criticalHours ? 'critical'
        : ageHours >= warningHours ? 'warning'
          : ageHours >= recoveryHours ? 'recovery_due' : 'healthy',
    };
  });
  const criticalStations = byStation.filter((item) => item.status === 'critical').map((item) => item.stationId);
  const warningStations = byStation.filter((item) => item.status === 'warning').map((item) => item.stationId);
  const recoveryDueStations = byStation.filter((item) => item.ageHours >= recoveryHours || item.status === 'critical').map((item) => item.stationId);
  const morocco = byStation.filter((item) => item.stationId.endsWith('_maroc'));
  return {
    schemaVersion: 1,
    checkedAt: now.toISOString(),
    status: criticalStations.length ? 'critical' : warningStations.length ? 'warning'
      : recoveryDueStations.length ? 'recovery_due' : 'healthy',
    expectedStations: stations.length,
    checkedStations: byStation.length,
    expectedDocuments: specs.length,
    checkedDocuments,
    thresholdsHours: {recovery: recoveryHours, warning: warningHours, critical: criticalHours, clientExpiry: 36},
    criticalStations,
    warningStations,
    recoveryDueStations,
    morocco: {stations: morocco.length, critical: morocco.filter((item) => item.status === 'critical').length,
      warning: morocco.filter((item) => item.status === 'warning').length},
    stations: byStation,
    issues,
    automaticallyDispatchesCollection: false,
  };
}

async function runWatchdog({firestore, now = new Date(), log = logger}) {
  const specs = documentSpecs();
  const refs = specs.map((spec) => firestore.doc(spec.path));
  const documents = new Map();
  // One strongly consistent read selects metadata only, never forecast arrays,
  // community data, API credentials or authentication tokens.
  const snapshots = await firestore.getAll(...refs, {fieldMask: [...fieldMask]});
  for (const snapshot of snapshots) {
    if (snapshot.exists) documents.set(snapshot.ref.path, snapshot.data());
  }
  const summary = analyzeDocuments(documents, now);
  // This collection has no client allow rule. It remains private by default.
  await firestore.doc('collector_health/weather-watchdog').set({
    ...summary,
    observedAt: FieldValue.serverTimestamp(),
  });
  const logged = {status: summary.status, checkedDocuments: summary.checkedDocuments,
    criticalStations: summary.criticalStations, warningStations: summary.warningStations,
    recoveryDueStations: summary.recoveryDueStations};
  if (summary.status === 'critical') log.error('Weather freshness critical', logged);
  else if (summary.status === 'warning') log.warn('Weather freshness warning', logged);
  else log.info('Weather freshness checked', logged);
  return summary;
}

exports.monitorWeatherFreshness = onSchedule({
  region: 'europe-west1',
  serviceAccount,
  schedule: '43 * * * *',
  timeZone: 'UTC',
  maxInstances: 1,
  concurrency: 1,
  retryCount: 1,
  timeoutSeconds: 120,
  memory: '256MiB',
}, async () => {
  try {
    return await runWatchdog({firestore: getFirestore()});
  } catch (error) {
    // Avoid raw exception bodies or request headers in structured monitoring.
    logger.error('Weather freshness monitor execution failed', {
      code: typeof error?.code === 'string' || typeof error?.code === 'number' ? error.code : 'unknown',
    });
    throw error;
  }
});

exports.__test = {analyzeDocuments, documentSpecs, timestampMillis, runWatchdog, fieldMask, catalog};
