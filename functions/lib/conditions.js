/**
 * conditions.js
 * Récupère marées + météo via Open-Meteo, calcule extrêmes de marée,
 * phase lunaire (formule astronomique hors ligne), et un score
 * d'activité poisson 0-100.
 */

const https = require('https');

// ─── Spots de pêche (lat/lon) ────────────────────────────────────────────────
const FISHING_SPOTS = [
  { spotId: 'casablanca', name: 'Casablanca', lat: 33.59, lon: -7.61 },
  { spotId: 'rabat',      name: 'Rabat',      lat: 34.02, lon: -6.84 },
  { spotId: 'agadir',     name: 'Agadir',     lat: 30.42, lon: -9.60 },
  { spotId: 'tanger',     name: 'Tanger',     lat: 35.77, lon: -5.80 },
  { spotId: 'essaouira',  name: 'Essaouira',  lat: 31.51, lon: -9.77 },
];

// ─── Helpers HTTP ────────────────────────────────────────────────────────────
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

// ─── Phase lunaire (formule astronomique hors ligne) ─────────────────────────
// Algorithme simplifié basé sur le nombre de julesiens (jours depuis 2000-01-01)
function getMoonPhase(date) {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();

  let yy = year;
  let mm = month;
  if (mm < 3) {
    yy -= 1;
    mm += 12;
  }
  const a = Math.floor(yy / 100);
  const b = 2 - a + Math.floor(a / 4);
  const jd =
    Math.floor(365.25 * (yy + 4716)) +
    Math.floor(30.6001 * (mm + 1)) +
    day + b - 1524.5;

  const daysSinceNew = jd - 2451549.5;
  const newMoons = daysSinceNew / 29.53058867;
  const phase = (newMoons - Math.floor(newMoons)) * 29.53058867;

  let illumination = 0;
  if (phase <= 14.765) {
    illumination = (phase / 14.765) * 100;
  } else {
    illumination = ((29.53058867 - phase) / 14.765) * 100;
  }

  let name = 'Waning';
  if (phase < 1.84566) name = 'New Moon';
  else if (phase < 5.53699) name = 'Waxing Crescent';
  else if (phase < 9.22831) name = 'First Quarter';
  else if (phase < 12.91963) name = 'Waxing Gibbous';
  else if (phase < 16.61096) name = 'Full Moon';
  else if (phase < 20.30228) name = 'Waning Gibbous';
  else if (phase < 23.99361) name = 'Last Quarter';
  else if (phase < 27.68493) name = 'Waning Crescent';
  else name = 'New Moon';

  return { age: phase, illumination, name };
}

// ─── Détection des extrêmes de marée (pics dans sea_level_height_msl) ───────
function findTideExtremes(times, heights) {
  const highs = [];
  const lows = [];

  for (let i = 1; i < heights.length - 1; i++) {
    const prev = heights[i - 1];
    const cur = heights[i];
    const next = heights[i + 1];

    if (cur > prev && cur > next) {
      highs.push({ time: times[i], height: cur });
    } else if (cur < prev && cur < next) {
      lows.push({ time: times[i], height: cur });
    }
  }

  const amplitude =
    highs.length > 0 && lows.length > 0
      ? Math.max(...highs.map(h => h.height)) - Math.min(...lows.map(l => l.height))
      : 0;

  return { highs, lows, amplitude };
}

// ─── Score d'activité poisson 0-100 ──────────────────────────────────────────
function calculateActivityScore(moon, tideAmplitude, weatherHourly, nowIndex) {
  let score = 50;

  // Influence lunaire : pleine/nouvelle lune = meilleure activité
  const moonIllum = moon.illumination; // 0-100
  const moonFactor = 1 - Math.abs(moonIllum - 50) / 50; // 0 = quartier, 1 = pleine/nouvelle
  score += moonFactor * 20;

  // Amplitude de marée : forte amplitude = meilleure activité
  const tideFactor = Math.min(tideAmplitude / 2.0, 1); // normalisé à ~2m max
  score += tideFactor * 20;

  // Conditions météo (si dispo)
  if (weatherHourly && nowIndex >= 0) {
    const wind = weatherHourly.windspeed_10m?.[nowIndex] ?? 10;
    const wcode = weatherHourly.weathercode?.[nowIndex] ?? 0;

    // Vent modéré est idéal
    if (wind < 5) score += 5;
    else if (wind < 15) score += 10;
    else if (wind < 25) score += 0;
    else score -= 10;

    // Mauvais temps légèrement négatif
    if (wcode >= 51 && wcode <= 67) score -= 5; // pluie
    if (wcode >= 71) score -= 10; // neige/orage
  }

  // Heure de la journée : activité plus forte au lever/coucher du soleil
  const hour = new Date().getUTCHours();
  if ((hour >= 5 && hour <= 8) || (hour >= 17 && hour <= 20)) {
    score += 5;
  }

  return Math.max(0, Math.min(100, Math.round(score)));
}

// ─── Construction des conditions pour un spot ─────────────────────────────────
async function buildConditionsForSpot(spot) {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];

  // 1. Données marines (marées)
  const marineUrl =
    `https://marine-api.open-meteo.com/v1/marine?` +
    `latitude=${spot.lat}&longitude=${spot.lon}` +
    `&hourly=sea_level_height_msl` +
    `&start_date=${dateStr}&end_date=${dateStr}`;

  const marineData = await fetchJson(marineUrl);
  const tideTimes = marineData.hourly?.time ?? [];
  const tideHeights = marineData.hourly?.sea_level_height_msl ?? [];
  const tideExtremes = findTideExtremes(tideTimes, tideHeights);

  // 2. Données météo
  const forecastUrl =
    `https://api.open-meteo.com/v1/forecast?` +
    `latitude=${spot.lat}&longitude=${spot.lon}` +
    `&hourly=temperature_2m,weathercode,windspeed_10m,winddirection_10m` +
    `&start_date=${dateStr}&end_date=${dateStr}`;

  const forecastData = await fetchJson(forecastUrl);
  const weatherHourly = forecastData.hourly;

  // Index horaire actuel
  const currentHourStr = now.toISOString().slice(0, 13) + ':00';
  let nowIndex = -1;
  if (weatherHourly?.time) {
    nowIndex = weatherHourly.time.findIndex(t => t.startsWith(currentHourStr.slice(0, 13)));
    if (nowIndex === -1) nowIndex = 0;
  }

  // 3. Phase lunaire
  const moon = getMoonPhase(now);

  // 4. Score
  const activityScore = calculateActivityScore(
    moon,
    tideExtremes.amplitude,
    weatherHourly,
    nowIndex
  );

  return {
    spotId: spot.spotId,
    name: spot.name,
    lat: spot.lat,
    lon: spot.lon,
    timestamp: now.toISOString(),
    date: dateStr,
    tide: {
      currentHeight: tideHeights[nowIndex] ?? null,
      amplitudeMeters: Math.round(tideExtremes.amplitude * 100) / 100,
      nextHigh: tideExtremes.highs[0] ?? null,
      nextLow: tideExtremes.lows[0] ?? null,
    },
    weather: {
      temperatureC: weatherHourly?.temperature_2m?.[nowIndex] ?? null,
      weatherCode: weatherHourly?.weathercode?.[nowIndex] ?? null,
      windSpeedKmh: weatherHourly?.windspeed_10m?.[nowIndex] ?? null,
      windDirection: weatherHourly?.winddirection_10m?.[nowIndex] ?? null,
    },
    moon: {
      phaseName: moon.name,
      illuminationPercent: Math.round(moon.illumination),
      ageDays: Math.round(moon.age * 10) / 10,
    },
    activityScore,
  };
}

module.exports = {
  FISHING_SPOTS,
  buildConditionsForSpot,
};
