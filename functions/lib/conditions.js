/**
 * conditions.js
 * Récupère marées + météo via Open-Meteo pour une liste de spots,
 * calcule extrêmes de marée, phase lunaire et score d'activité poisson.
 */

const FISHING_SPOTS = [
  { spotId: "tanger", name: "Tanger", lat: 35.78, lon: -5.81 },
  { spotId: "casablanca", name: "Casablanca", lat: 33.60, lon: -7.62 },
  { spotId: "agadir", name: "Agadir", lat: 30.43, lon: -9.60 },
  { spotId: "essaouira", name: "Essaouira", lat: 31.51, lon: -9.77 },
  { spotId: "alhoceima", name: "Al Hoceima", lat: 35.25, lon: -3.93 },
  { spotId: "nador", name: "Nador", lat: 35.17, lon: -2.93 },
  { spotId: "dakhla", name: "Dakhla", lat: 23.68, lon: -15.96 },
  { spotId: "marseille", name: "Marseille", lat: 43.30, lon: 5.37 },
  { spotId: "nice", name: "Nice", lat: 43.70, lon: 7.27 },
  { spotId: "barcelone", name: "Barcelone", lat: 41.38, lon: 2.17 },
];

/**
 * Calcule la phase lunaire (0 = nouvelle lune, 0.5 = pleine lune, etc.)
 * Formule astronomique simplifiée (Conway)
 */
function getMoonPhase(date) {
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  const day = date.getDate();

  let r = year % 100;
  r %= 19;
  if (r > 9) r -= 19;
  r = ((r * 11) % 30) + month + day;
  if (month < 3) r += 2;
  r -= (year < 2000) ? 4 : 8.3;
  r = Math.floor(r + 0.5) % 30;
  if (r < 0) r += 30;

  const phase = r / 29.53; // normalisé 0..1
  return phase;
}

/**
 * Convertit une phase lunaire 0..1 en nom lisible
 */
function moonPhaseName(phase) {
  if (phase < 0.03 || phase > 0.97) return "Nouvelle lune";
  if (phase < 0.22) return "Croissant";
  if (phase < 0.28) return "Premier quartier";
  if (phase < 0.47) return "Gibbeuse croissante";
  if (phase < 0.53) return "Pleine lune";
  if (phase < 0.72) return "Gibbeuse décroissante";
  if (phase < 0.78) return "Dernier quartier";
  return "Dernier croissant";
}

/**
 * Score lunaire 0-100 basé sur la proximité avec NM/PL
 */
function moonScore(phase) {
  // 0 (NM) et 0.5 (PL) = 100
  // 0.25 et 0.75 = 40
  const distFromNm = Math.abs(phase - 0.0);
  const distFromPl = Math.abs(phase - 0.5);
  const minDist = Math.min(distFromNm, distFromPl);
  return Math.round(100 - minDist * 2 * 120); // 100 à NM/PL, baisse ensuite
}

/**
 * Trouve les extrêmes (pics et creux) dans une série temporelle
 */
function findExtremes(times, values) {
  const extremes = [];
  for (let i = 1; i < values.length - 1; i++) {
    if (values[i] > values[i - 1] && values[i] > values[i + 1]) {
      extremes.push({ type: "high", time: times[i], value: values[i] });
    } else if (values[i] < values[i - 1] && values[i] < values[i + 1]) {
      extremes.push({ type: "low", time: times[i], value: values[i] });
    }
  }
  return extremes;
}

/**
 * Récupère les données marines (marées) via Open-Meteo Marine API
 */
async function fetchMarineData(lat, lon) {
  const url = `https://marine-api.open-meteo.com/v1/marine?latitude=${lat}&longitude=${lon}&hourly=sea_level_height_msl`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Marine API error: ${res.status}`);
  const data = await res.json();
  return {
    times: data.hourly.time,
    seaLevel: data.hourly.sea_level_height_msl,
  };
}

/**
 * Récupère les données météo via Open-Meteo Forecast API
 */
async function fetchWeatherData(lat, lon) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,wind_speed_10m,wind_direction_10m,pressure_msl,weather_code`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Weather API error: ${res.status}`);
  const data = await res.json();
  return data.current;
}

/**
 * Score d'activité poisson 0-100
 */
function computeActivityScore(tideExtremes, moonPhaseValue, weather) {
  const mScore = Math.max(0, Math.min(100, moonScore(moonPhaseValue)));

  // Amplitude de marée
  let tideAmplitude = 0;
  if (tideExtremes.length >= 2) {
    const highs = tideExtremes.filter((e) => e.type === "high").map((e) => e.value);
    const lows = tideExtremes.filter((e) => e.type === "low").map((e) => e.value);
    if (highs.length && lows.length) {
      const avgHigh = highs.reduce((a, b) => a + b, 0) / highs.length;
      const avgLow = lows.reduce((a, b) => a + b, 0) / lows.length;
      tideAmplitude = Math.abs(avgHigh - avgLow);
    }
  }
  // Plus l'amplitude est grande, mieux c'est (max ~2m = 100)
  const tideScore = Math.min(100, tideAmplitude * 50);

  // Météo
  let weatherScore = 70; // base
  if (weather.temperature_2m !== undefined) {
    const temp = weather.temperature_2m;
    if (temp >= 15 && temp <= 25) weatherScore += 15;
    else if (temp >= 10 && temp <= 30) weatherScore += 5;
    else weatherScore -= 10;
  }
  if (weather.wind_speed_10m !== undefined) {
    const wind = weather.wind_speed_10m;
    if (wind < 15) weatherScore += 10;
    else if (wind < 25) weatherScore += 0;
    else weatherScore -= 15;
  }
  if (weather.pressure_msl !== undefined) {
    const press = weather.pressure_msl;
    if (press > 1020) weatherScore += 5;
    else if (press < 1005) weatherScore -= 10;
  }
  weatherScore = Math.max(0, Math.min(100, weatherScore));

  // Score global pondéré
  const globalScore = Math.round(mScore * 0.35 + tideScore * 0.35 + weatherScore * 0.30);
  return Math.max(0, Math.min(100, globalScore));
}

/**
 * Construit l'objet conditions complet pour un spot
 */
async function buildConditionsForSpot(spot) {
  const now = new Date();
  const moonPhaseValue = getMoonPhase(now);

  const marine = await fetchMarineData(spot.lat, spot.lon);
  const weather = await fetchWeatherData(spot.lat, spot.lon);
  const tideExtremes = findExtremes(marine.times, marine.seaLevel);

  const activityScore = computeActivityScore(tideExtremes, moonPhaseValue, weather);

  return {
    spotId: spot.spotId,
    name: spot.name,
    lat: spot.lat,
    lon: spot.lon,
    updatedAt: now.toISOString(),
    moonPhase: moonPhaseName(moonPhaseValue),
    moonPhaseValue: parseFloat(moonPhaseValue.toFixed(4)),
    tideExtremes: tideExtremes.map((e) => ({
      type: e.type,
      time: e.time,
      value: parseFloat(e.value.toFixed(3)),
    })),
    weather: {
      temperature: weather.temperature_2m,
      windSpeed: weather.wind_speed_10m,
      windDirection: weather.wind_direction_10m,
      pressure: weather.pressure_msl,
      weatherCode: weather.weather_code,
    },
    activityScore,
  };
}

module.exports = {
  FISHING_SPOTS,
  buildConditionsForSpot,
};
