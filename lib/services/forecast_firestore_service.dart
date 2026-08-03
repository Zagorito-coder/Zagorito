// ============================================================================
// forecast_firestore_service.dart
//
// Lit le document Firestore rempli chaque nuit par harvest_forecast.py
// (collection "spots_meteo") et le convertit en List<ForecastSlot>
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:spots_app/utils/geo_utils.dart';
import 'package:spots_app/widgets/forecast_table.dart';

class GfsWeatherPoint {
  final DateTime dateTime;
  final double? pressureHpa;
  final double? precipitationProbabilityPct;
  final double? relativeHumidityPct;

  const GfsWeatherPoint({
    required this.dateTime,
    this.pressureHpa,
    this.precipitationProbabilityPct,
    this.relativeHumidityPct,
  });
}

class GfsWeatherTimeline {
  final String locationName;
  final List<GfsWeatherPoint> points;

  const GfsWeatherTimeline({
    required this.locationName,
    required this.points,
  });

  GfsWeatherPoint? nearestTo(
    DateTime target, {
    Duration tolerance = const Duration(minutes: 90),
  }) {
    GfsWeatherPoint? nearest;
    var shortestDifference = const Duration(days: 365);
    for (final point in points) {
      final difference = point.dateTime.difference(target).abs();
      if (difference < shortestDifference) {
        shortestDifference = difference;
        nearest = point;
      }
    }
    return shortestDifference <= tolerance ? nearest : null;
  }
}

class SpotForecast {
  final String locationName;
  final DateTime? lastUpdate;
  final List<ForecastSlot> slots;
  final List<DateTime> dayStarts;
  final List<int> dayStartIndexes;

  // Nouveaux champs spot (Phase 4)
  final double? latitude;
  final double? longitude;
  final String? sunrise;
  final String? sunset;
  final double? waterTempC;

  SpotForecast({
    required this.locationName,
    required this.lastUpdate,
    required this.slots,
    required this.dayStarts,
    required this.dayStartIndexes,
    this.latitude,
    this.longitude,
    this.sunrise,
    this.sunset,
    this.waterTempC,
  });
}

class ForecastFirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _gfsCacheDuration = Duration(minutes: 20);
  static final Map<String, _GfsCacheEntry> _gfsCache = {};
  static final Map<String, Future<GfsWeatherTimeline?>> _gfsRequests = {};
  static List<Map<String, dynamic>>? _spotIndexCache;

  /// Liste tous les spots disponibles avec leurs coordonnees.
  /// Utilise la collection legere `spots_index` creee par harvest_forecast.py
  /// pour eviter de charger les donnees de forecast completes (OOM).
  static Future<List<Map<String, dynamic>>> listAvailableSpots() async {
    try {
      final snap = await _db.collection('spots_index').get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': d['name'] ?? doc.id,
          'latitude': (d['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (d['longitude'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return [];
      rethrow;
    }
  }

  /// Lit le même bloc `models.wind` que le tableau « Vent GFS » sans créer la
  /// liste complète des 15 jours. Le document Firestore brut est libéré après
  /// extraction et seul un petit créneau de 42 heures reste en cache.
  static Future<GfsWeatherTimeline?> fetchNearestGfsWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final spots = _spotIndexCache ??= await listAvailableSpots();
    if (spots.isEmpty) return null;

    Map<String, dynamic>? nearest;
    var shortestDistance = double.infinity;
    for (final spot in spots) {
      final spotLatitude = (spot['latitude'] as num?)?.toDouble();
      final spotLongitude = (spot['longitude'] as num?)?.toDouble();
      if (spotLatitude == null || spotLongitude == null) continue;
      final distance = haversineKm(
        latitude,
        longitude,
        spotLatitude,
        spotLongitude,
      );
      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearest = spot;
      }
    }
    final spotId = nearest?['id'] as String?;
    return spotId == null ? null : fetchGfsWeather(spotId);
  }

  static Future<GfsWeatherTimeline?> fetchGfsWeather(String spotId) {
    final cached = _gfsCache[spotId];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _gfsCacheDuration) {
      return Future.value(cached.timeline);
    }

    final running = _gfsRequests[spotId];
    if (running != null) return running;

    final request = _fetchGfsWeather(spotId);
    _gfsRequests[spotId] = request;
    return request.whenComplete(() => _gfsRequests.remove(spotId));
  }

  static Future<GfsWeatherTimeline?> _fetchGfsWeather(String spotId) async {
    try {
      final doc = await _db.collection('spots_meteo').doc(spotId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      final timeline = parseGfsWeather(data, now: DateTime.now());
      if (timeline == null) return null;
      _gfsCache[spotId] = _GfsCacheEntry(
        fetchedAt: DateTime.now(),
        timeline: timeline,
      );
      return timeline;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @visibleForTesting
  static GfsWeatherTimeline? parseGfsWeather(
    Map<String, dynamic> data, {
    required DateTime now,
  }) {
    final points = <GfsWeatherPoint>[];
    final earliest = now.subtract(const Duration(hours: 6));
    final latest = now.add(const Duration(hours: 36));
    final days = data['days'];
    if (days is! List<dynamic>) return null;

    for (final rawDay in days) {
      final day = _asStringMap(rawDay);
      final slots = day?['slots'];
      if (slots is! List<dynamic>) continue;
      for (final rawSlot in slots) {
        final slot = _asStringMap(rawSlot);
        final timeRaw = slot?['hour'];
        final dateTime = timeRaw is String ? DateTime.tryParse(timeRaw) : null;
        if (slot == null ||
            dateTime == null ||
            dateTime.isBefore(earliest) ||
            dateTime.isAfter(latest)) {
          continue;
        }
        final models = _asStringMap(slot['models']);
        final wind = _asStringMap(models?['wind']);
        final pressure = _boundedNumber(
          wind,
          'pressure_msl',
          minimum: 800,
          maximum: 1200,
        );
        final rain = _boundedNumber(
          wind,
          'precip_prob_pct',
          minimum: 0,
          maximum: 100,
        );
        final humidity = _boundedNumber(
          wind,
          'rel_humidity_pct',
          minimum: 0,
          maximum: 100,
        );
        if (pressure == null && rain == null && humidity == null) continue;
        points.add(
          GfsWeatherPoint(
            dateTime: dateTime,
            pressureHpa: pressure,
            precipitationProbabilityPct: rain,
            relativeHumidityPct: humidity,
          ),
        );
      }
    }

    if (points.isEmpty) return null;
    points.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return GfsWeatherTimeline(
      locationName: data['location_name'] as String? ?? '',
      points: List.unmodifiable(points),
    );
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map<dynamic, dynamic>) return null;
    return Map<String, dynamic>.from(value);
  }

  static double? _boundedNumber(
    Map<String, dynamic>? map,
    String key, {
    required double minimum,
    required double maximum,
  }) {
    final value = (map?[key] as num?)?.toDouble();
    if (value == null ||
        !value.isFinite ||
        value < minimum ||
        value > maximum) {
      return null;
    }
    return value;
  }

  /// Recupere une seule fois les previsions d'un spot.
  static Future<SpotForecast?> fetchSpot(String spotId) async {
    try {
      final doc = await _db.collection('spots_meteo').doc(spotId).get();
      if (!doc.exists) {
        throw Exception('Spot "$spotId" introuvable dans Firestore.');
      }
      return _parseDoc(doc.data()!);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Version "temps reel" : stream.
  static Stream<SpotForecast?> watchSpot(String spotId) {
    return _db
        .collection('spots_meteo')
        .doc(spotId)
        .snapshots()
        .handleError((e) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            return null;
          }
          throw e;
        })
        .where((doc) => doc.exists)
        .map((doc) => _parseDoc(doc.data()!));
  }

  static SpotForecast _parseDoc(Map<String, dynamic> data) {
    final days = (data['days'] as List<dynamic>? ?? []);
    final List<ForecastSlot> allSlots = [];
    final List<DateTime> dayStarts = [];
    final List<int> dayStartIndexes = [];

    for (final dayRaw in days) {
      final day = dayRaw as Map<String, dynamic>;
      final slotsRaw = (day['slots'] as List<dynamic>? ?? []);
      if (slotsRaw.isEmpty) continue;

      dayStartIndexes.add(allSlots.length);
      bool first = true;

      for (final slotRaw in slotsRaw) {
        final s = slotRaw as Map<String, dynamic>;
        final dt = DateTime.parse(s['hour'] as String);
        if (first) dayStarts.add(DateTime(dt.year, dt.month, dt.day));

        // Lire le sous-objet models (additif, null si absent)
        final modelsRaw = s['models'] as Map<String, dynamic>?;
        final modelWindRaw =
            WindModelSlot.fromJson(modelsRaw?['wind'] as Map<String, dynamic>?);
        final modelHiresRaw = WindModelSlot.fromJson(
            modelsRaw?['hires'] as Map<String, dynamic>?);
        final modelWaveRaw =
            WaveModelSlot.fromJson(modelsRaw?['wave'] as Map<String, dynamic>?);
        // Ne garder que si donnees reelles (pas objet vide)
        final modelWind = modelWindRaw.hasData ? modelWindRaw : null;
        final modelHires = modelHiresRaw.hasData ? modelHiresRaw : null;
        final modelWave = modelWaveRaw.hasData ? modelWaveRaw : null;

        allSlots.add(ForecastSlot(
          dateTime: dt,
          windSpeedKnots: (s['wind_speed_kt'] as num?)?.toDouble() ?? 0,
          windGustKnots: (s['wind_gust_kt'] as num?)?.toDouble() ?? 0,
          windDirectionDeg: (s['wind_dir_deg'] as num?)?.toDouble() ?? 0,
          waveHeightM: (s['wave_height_m'] as num?)?.toDouble() ?? 0,
          wavePeriodS: (s['wave_period_s'] as num?)?.toDouble() ?? 0,
          waveDirectionDeg: (s['wave_dir_deg'] as num?)?.toDouble() ?? 0,
          temperatureC: (s['temp_c'] as num?)?.toInt() ?? 0,
          cloudCoverPct: (s['cloud_pct'] as num?)?.toInt(),
          precipProbPct: (s['precip_pct'] as num?)?.toInt(),
          ratingStars: (s['rating'] as num?)?.toInt() ?? 0,
          isNewDay: first,
          modelWind: modelWind,
          modelHires: modelHires,
          modelWave: modelWave,
        ));
        first = false;
      }
    }

    final ts = data['last_update'];
    final lastUpdate = ts is Timestamp ? ts.toDate() : null;

    final sunrise = data['sunrise'] as String?;
    final sunset = data['sunset'] as String?;
    final waterTempC = (data['water_temp_c'] as num?)?.toDouble();

    return SpotForecast(
      locationName: data['location_name'] as String? ?? '',
      lastUpdate: lastUpdate,
      slots: allSlots,
      dayStarts: dayStarts,
      dayStartIndexes: dayStartIndexes,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      sunrise: sunrise,
      sunset: sunset,
      waterTempC: waterTempC,
    );
  }
}

class _GfsCacheEntry {
  final DateTime fetchedAt;
  final GfsWeatherTimeline timeline;

  const _GfsCacheEntry({
    required this.fetchedAt,
    required this.timeline,
  });
}
