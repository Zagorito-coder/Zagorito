import fs from 'node:fs';

const spotsPath = process.argv[2] ?? 'assets/spots.csv';
const countriesPath =
  process.argv[3] ?? '/tmp/ne_10m_admin_0_countries.geojson';

function parseCsvRow(line) {
  const values = [];
  let current = '';
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (character === '"') {
      if (quoted && line[index + 1] === '"') {
        current += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === ',' && !quoted) {
      values.push(current);
      current = '';
    } else {
      current += character;
    }
  }
  if (quoted) throw new Error('Unclosed CSV quote');
  values.push(current);
  return values;
}

function geometryPolygons(geometry) {
  if (geometry.type === 'Polygon') return [geometry.coordinates];
  if (geometry.type === 'MultiPolygon') return geometry.coordinates;
  return [];
}

function ringBounds(ring) {
  return ring.reduce(
    (bounds, [longitude, latitude]) => ({
      minLongitude: Math.min(bounds.minLongitude, longitude),
      minLatitude: Math.min(bounds.minLatitude, latitude),
      maxLongitude: Math.max(bounds.maxLongitude, longitude),
      maxLatitude: Math.max(bounds.maxLatitude, latitude),
    }),
    {
      minLongitude: Infinity,
      minLatitude: Infinity,
      maxLongitude: -Infinity,
      maxLatitude: -Infinity,
    },
  );
}

function mergeBounds(boundsList) {
  return boundsList.reduce(
    (bounds, value) => ({
      minLongitude: Math.min(bounds.minLongitude, value.minLongitude),
      minLatitude: Math.min(bounds.minLatitude, value.minLatitude),
      maxLongitude: Math.max(bounds.maxLongitude, value.maxLongitude),
      maxLatitude: Math.max(bounds.maxLatitude, value.maxLatitude),
    }),
    {
      minLongitude: Infinity,
      minLatitude: Infinity,
      maxLongitude: -Infinity,
      maxLatitude: -Infinity,
    },
  );
}

function pointInRing(longitude, latitude, ring) {
  let inside = false;
  for (let current = 0, previous = ring.length - 1;
      current < ring.length;
      previous = current, current += 1) {
    const [currentLongitude, currentLatitude] = ring[current];
    const [previousLongitude, previousLatitude] = ring[previous];
    const crossesLatitude =
      currentLatitude > latitude !== previousLatitude > latitude;
    if (!crossesLatitude) continue;

    const crossingLongitude =
      ((previousLongitude - currentLongitude) *
        (latitude - currentLatitude)) /
        (previousLatitude - currentLatitude) +
      currentLongitude;
    if (longitude < crossingLongitude) inside = !inside;
  }
  return inside;
}

function pointInPolygon(longitude, latitude, polygon) {
  if (!pointInRing(longitude, latitude, polygon[0])) return false;
  return !polygon
    .slice(1)
    .some((hole) => pointInRing(longitude, latitude, hole));
}

function squaredDistanceToBounds(longitude, latitude, bounds) {
  const longitudeDistance =
    longitude < bounds.minLongitude
      ? bounds.minLongitude - longitude
      : longitude > bounds.maxLongitude
        ? longitude - bounds.maxLongitude
        : 0;
  const latitudeDistance =
    latitude < bounds.minLatitude
      ? bounds.minLatitude - latitude
      : latitude > bounds.maxLatitude
        ? latitude - bounds.maxLatitude
        : 0;
  return longitudeDistance ** 2 + latitudeDistance ** 2;
}

function squaredDistanceToSegment(point, start, end) {
  const latitudeRadians = (point[1] * Math.PI) / 180;
  const longitudeScale = Math.cos(latitudeRadians);
  const px = point[0] * longitudeScale;
  const py = point[1];
  const sx = start[0] * longitudeScale;
  const sy = start[1];
  const ex = end[0] * longitudeScale;
  const ey = end[1];
  const dx = ex - sx;
  const dy = ey - sy;
  if (dx === 0 && dy === 0) return (px - sx) ** 2 + (py - sy) ** 2;

  const fraction = Math.max(
    0,
    Math.min(1, ((px - sx) * dx + (py - sy) * dy) / (dx ** 2 + dy ** 2)),
  );
  const nearestX = sx + fraction * dx;
  const nearestY = sy + fraction * dy;
  return (px - nearestX) ** 2 + (py - nearestY) ** 2;
}

function squaredDistanceToCountry(longitude, latitude, country) {
  let minimum = Infinity;
  for (const polygon of country.polygons) {
    for (const ring of polygon) {
      for (let index = 1; index < ring.length; index += 1) {
        minimum = Math.min(
          minimum,
          squaredDistanceToSegment(
            [longitude, latitude],
            ring[index - 1],
            ring[index],
          ),
        );
      }
    }
  }
  return minimum;
}

const rawSpots = fs.readFileSync(spotsPath, 'utf8').split(/\r?\n/).slice(1);
const spots = rawSpots
  .filter((line) => line.trim() !== '')
  .map((line, index) => {
    const columns = parseCsvRow(line);
    const latitude = Number(columns[1]);
    const longitude = Number(columns[2]);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new Error(`Invalid coordinates on CSV line ${index + 2}`);
    }
    return {latitude, longitude, name: columns[0].trim()};
  });

const geoJson = JSON.parse(fs.readFileSync(countriesPath, 'utf8'));
const countries = geoJson.features
  .map((feature) => {
    const polygons = geometryPolygons(feature.geometry);
    const bounds = mergeBounds(
      polygons.map((polygon) => ringBounds(polygon[0])),
    );
    const properties = feature.properties;
    return {
      bounds,
      continent: properties.CONTINENT,
      countryCode:
        properties.ISO_A2_EH === '-99'
          ? properties.ISO_A2
          : properties.ISO_A2_EH,
      names: {
        ar: properties.NAME_AR,
        en: properties.NAME_EN,
        es: properties.NAME_ES,
        fr: properties.NAME_FR,
      },
      polygons,
    };
  })
  .filter((country) => /^[A-Z]{2}$/.test(country.countryCode));

const assignments = new Map();
let farthestOffshoreDistanceKm = 0;

for (const spot of spots) {
  let country = countries.find(
    (candidate) =>
      squaredDistanceToBounds(
        spot.longitude,
        spot.latitude,
        candidate.bounds,
      ) === 0 &&
      candidate.polygons.some((polygon) =>
        pointInPolygon(spot.longitude, spot.latitude, polygon),
      ),
  );

  let offshoreDistanceKm = 0;
  if (country == null) {
    const nearbyCountries = countries
      .map((candidate) => ({
        candidate,
        boundsDistance: squaredDistanceToBounds(
          spot.longitude,
          spot.latitude,
          candidate.bounds,
        ),
      }))
      .sort((left, right) => left.boundsDistance - right.boundsDistance)
      .slice(0, 8);
    const nearest = nearbyCountries
      .map(({candidate}) => ({
        candidate,
        distance: squaredDistanceToCountry(
          spot.longitude,
          spot.latitude,
          candidate,
        ),
      }))
      .sort((left, right) => left.distance - right.distance)[0];
    country = nearest.candidate;
    offshoreDistanceKm = Math.sqrt(nearest.distance) * 111.32;
    farthestOffshoreDistanceKm = Math.max(
      farthestOffshoreDistanceKm,
      offshoreDistanceKm,
    );
  }

  const current = assignments.get(country.countryCode) ?? {
    continent: country.continent,
    countryCode: country.countryCode,
    names: country.names,
    spotCount: 0,
    spotBounds: {
      minLongitude: Infinity,
      minLatitude: Infinity,
      maxLongitude: -Infinity,
      maxLatitude: -Infinity,
    },
    farthestOffshoreDistanceKm: 0,
  };
  current.spotCount += 1;
  current.spotBounds.minLongitude = Math.min(
    current.spotBounds.minLongitude,
    spot.longitude,
  );
  current.spotBounds.minLatitude = Math.min(
    current.spotBounds.minLatitude,
    spot.latitude,
  );
  current.spotBounds.maxLongitude = Math.max(
    current.spotBounds.maxLongitude,
    spot.longitude,
  );
  current.spotBounds.maxLatitude = Math.max(
    current.spotBounds.maxLatitude,
    spot.latitude,
  );
  current.farthestOffshoreDistanceKm = Math.max(
    current.farthestOffshoreDistanceKm,
    offshoreDistanceKm,
  );
  assignments.set(country.countryCode, current);
}

const allCountries = [...assignments.values()].sort((left, right) =>
  left.countryCode.localeCompare(right.countryCode),
);
const includedCountries = allCountries.filter(
  (country) => country.continent !== 'Europe',
);
const excludedCountries = allCountries.filter(
  (country) => country.continent === 'Europe',
);

console.log(
  JSON.stringify(
    {
      excludedCountries,
      farthestOffshoreDistanceKm,
      includedCountries,
      spotCount: spots.length,
    },
    null,
    2,
  ),
);
