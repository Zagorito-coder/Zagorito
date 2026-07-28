import {createHash} from 'node:crypto';
import {createReadStream, existsSync, mkdirSync, readFileSync, statSync, writeFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import path from 'node:path';

const inventoryPath =
  process.argv.find((argument) => argument.startsWith('--inventory='))?.slice(12) ??
  '/tmp/boosterfish-spot-countries.json';
const outputDirectory =
  process.argv.find((argument) => argument.startsWith('--output='))?.slice(9) ??
  '/tmp/boosterfish_country_packs';
const dryRun = process.argv.includes('--dry-run');
const pmtilesBinary =
  process.env.PMTILES_BIN ?? '/tmp/pmtiles-cli-1.31.2/pmtiles';
const source =
  process.env.PMTILES_SOURCE ??
  'https://build.protomaps.com/20260722.pmtiles';
const maxZoom = 14;
const contextMarginDegrees = 0.35;
const minimumSpotCount = 30;
const arabCountryCodes = new Set([
  'AE',
  'BH',
  'DJ',
  'DZ',
  'EG',
  'IQ',
  'JO',
  'KM',
  'KW',
  'LB',
  'LY',
  'MA',
  'MR',
  'OM',
  'PS',
  'QA',
  'SA',
  'SD',
  'SO',
  'SY',
  'TN',
  'YE',
]);

function run(command, argumentsList, {capture = false} = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, argumentsList, {
      stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    });
    let output = '';
    if (capture) {
      child.stdout.on('data', (chunk) => {
        output += chunk;
      });
      child.stderr.on('data', (chunk) => {
        output += chunk;
      });
    }
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(`${command} exited with code ${code}\n${output}`));
      }
    });
  });
}

function paddedBounds(spotBounds) {
  return {
    minLongitude: Math.max(
      -180,
      spotBounds.minLongitude - contextMarginDegrees,
    ),
    minLatitude: Math.max(
      -85,
      spotBounds.minLatitude - contextMarginDegrees,
    ),
    maxLongitude: Math.min(
      180,
      spotBounds.maxLongitude + contextMarginDegrees,
    ),
    maxLatitude: Math.min(
      85,
      spotBounds.maxLatitude + contextMarginDegrees,
    ),
  };
}

function bboxArgument(bounds) {
  return [
    bounds.minLongitude,
    bounds.minLatitude,
    bounds.maxLongitude,
    bounds.maxLatitude,
  ]
    .map((value) => value.toFixed(6))
    .join(',');
}

function bytesFromEstimate(value, unit) {
  const multiplier = {
    B: 1,
    kB: 1000,
    KB: 1000,
    MB: 1000 ** 2,
    GB: 1000 ** 3,
  }[unit];
  return Math.round(Number(value) * multiplier);
}

function parseEstimatedBytes(output) {
  const match = /archive size of ([\d.]+) (B|kB|KB|MB|GB)/.exec(output);
  if (match == null) throw new Error(`Missing size estimate\n${output}`);
  return bytesFromEstimate(match[1], match[2]);
}

function continentValue(continent, countryCode) {
  if (countryCode === 'SH') return 'africa';
  return {
    Africa: 'africa',
    Asia: 'asia',
    'North America': 'northAmerica',
    Oceania: 'oceania',
    'South America': 'southAmerica',
  }[continent];
}

function sha256(filePath) {
  return new Promise((resolve, reject) => {
    const digest = createHash('sha256');
    const input = createReadStream(filePath);
    input.on('data', (chunk) => digest.update(chunk));
    input.on('error', reject);
    input.on('end', () => resolve(digest.digest('hex')));
  });
}

const inventory = JSON.parse(readFileSync(inventoryPath, 'utf8'));
const countries = inventory.includedCountries.filter(
  (country) =>
    arabCountryCodes.has(country.countryCode) &&
    country.spotCount >= minimumSpotCount,
);
mkdirSync(outputDirectory, {recursive: true});

if (dryRun) {
  const estimates = [];
  for (const [index, country] of countries.entries()) {
    const bounds = paddedBounds(country.spotBounds);
    const outputPath = path.join(outputDirectory, `${country.countryCode}.tmp`);
    process.stderr.write(
      `[${index + 1}/${countries.length}] ${country.countryCode} estimate\n`,
    );
    const output = await run(
      pmtilesBinary,
      [
        'extract',
        source,
        outputPath,
        `--bbox=${bboxArgument(bounds)}`,
        `--maxzoom=${maxZoom}`,
        '--download-threads=4',
        '--dry-run',
      ],
      {capture: true},
    );
    estimates.push({
      countryCode: country.countryCode,
      estimatedBytes: parseEstimatedBytes(output),
    });
  }

  const totalEstimatedBytes = estimates.reduce(
    (total, estimate) => total + estimate.estimatedBytes,
    0,
  );
  process.stdout.write(
    `${JSON.stringify({estimates, totalEstimatedBytes}, null, 2)}\n`,
  );
  process.exit(0);
}

const regions = [];
for (const [index, country] of countries.entries()) {
  const id = country.countryCode.toLowerCase();
  const fileName = `${id}.pmtiles`;
  const filePath = path.join(outputDirectory, fileName);
  const bounds = paddedBounds(country.spotBounds);
  process.stderr.write(
    `[${index + 1}/${countries.length}] ${country.countryCode} build\n`,
  );

  if (!existsSync(filePath)) {
    await run(pmtilesBinary, [
      'extract',
      source,
      filePath,
      `--bbox=${bboxArgument(bounds)}`,
      `--maxzoom=${maxZoom}`,
      '--download-threads=4',
    ]);
  }
  await run(pmtilesBinary, ['verify', filePath]);

  regions.push({
    id,
    countryCode: country.countryCode,
    continent: continentValue(country.continent, country.countryCode),
    names: country.names,
    file: fileName,
    sizeBytes: statSync(filePath).size,
    sha256: await sha256(filePath),
    minZoom: 0,
    maxZoom,
    bounds: [
      bounds.minLongitude,
      bounds.minLatitude,
      bounds.maxLongitude,
      bounds.maxLatitude,
    ],
    spotCount: country.spotCount,
  });
}

const manifest = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  source: 'Protomaps Basemap daily build 20260722',
  attribution: 'OpenStreetMap contributors, Protomaps',
  regions,
};
writeFileSync(
  path.join(outputDirectory, 'manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);
