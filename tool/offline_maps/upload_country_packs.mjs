import {readdirSync} from 'node:fs';
import {spawn} from 'node:child_process';
import path from 'node:path';

const bucket = 'boosterfish-offline-maps';
const inputDirectory =
  process.argv.find((argument) => argument.startsWith('--input='))?.slice(8) ??
  '/tmp/boosterfish_country_packs';

function run(command, argumentsList) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, argumentsList, {stdio: 'inherit'});
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} exited with code ${code}`));
      }
    });
  });
}

const packs = readdirSync(inputDirectory)
  .filter((fileName) => fileName.endsWith('.pmtiles'))
  .sort();

for (const [index, fileName] of packs.entries()) {
  process.stderr.write(`[${index + 1}/${packs.length}] Upload ${fileName}\n`);
  await run('npx', [
    'wrangler@latest',
    'r2',
    'object',
    'put',
    `${bucket}/${fileName}`,
    '--file',
    path.join(inputDirectory, fileName),
    '--content-type',
    'application/vnd.pmtiles',
    '--cache-control',
    'public, max-age=31536000, immutable',
    '--remote',
  ]);
}

process.stderr.write('Publishing manifest.json\n');
await run('npx', [
  'wrangler@latest',
  'r2',
  'object',
  'put',
  `${bucket}/manifest.json`,
  '--file',
  path.join(inputDirectory, 'manifest.json'),
  '--content-type',
  'application/json',
  '--cache-control',
  'public, max-age=300',
  '--remote',
]);
