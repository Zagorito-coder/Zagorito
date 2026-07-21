// ============================================================
//  tide_service.dart — Conditions marines publiees par le backend
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/tide_data.dart';
import 'tide_forecast_mapper.dart';

class TideService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _stationCacheDuration = Duration(hours: 1);
  static const Duration _maximumForecastAge = Duration(hours: 72);

  static List<_ForecastStation>? _cachedStations;
  static DateTime? _stationsCachedAt;
  static Future<List<_ForecastStation>>? _stationLoadInProgress;

  /// Lit les conditions marines generees par le job serveur avec l'API
  /// commerciale Open-Meteo. La position sert uniquement a choisir localement
  /// la station publiee la plus proche et n'est jamais envoyee a Open-Meteo.
  static Future<TideData> fetchTides({
    double latitude = 33.57,
    double longitude = -7.59,
    String locationName = 'Casablanca Morocco',
  }) async {
    if (!_validCoordinates(latitude, longitude)) {
      return TideData.fallback(location: locationName);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final stations = await _loadStations();
        final station = _nearestStation(stations, latitude, longitude);
        if (station == null) {
          return TideData.fallback(location: locationName);
        }

        final snapshot = await _db
            .collection('spots_meteo')
            .doc(station.id)
            .get()
            .timeout(_requestTimeout);
        final data = snapshot.data();
        if (!snapshot.exists || data == null || !_isFresh(data['last_update'])) {
          return TideData.fallback(location: station.name);
        }

        return TideForecastMapper.fromDocument(
          data,
          fallbackLocation: station.name,
        );
      } catch (error) {
        debugPrint(
          '[TideService] Conditions publiees indisponibles '
          '(tentative ${attempt + 1}): $error',
        );
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          continue;
        }
      }
    }
    return TideData.fallback(location: locationName);
  }

  static bool _validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static bool _isFresh(dynamic value) {
    final DateTime? updatedAt = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      _ => null,
    };
    if (updatedAt == null) return false;
    final age = DateTime.now().difference(updatedAt);
    return age <= _maximumForecastAge && age >= const Duration(minutes: -5);
  }

  static Future<List<_ForecastStation>> _loadStations() async {
    final now = DateTime.now();
    final cached = _cachedStations;
    final cachedAt = _stationsCachedAt;
    if (cached != null &&
        cached.isNotEmpty &&
        cachedAt != null &&
        now.difference(cachedAt) < _stationCacheDuration) {
      return cached;
    }

    final pending = _stationLoadInProgress;
    if (pending != null) return pending;

    final load = _readStations();
    _stationLoadInProgress = load;
    try {
      final stations = await load;
      if (stations.isNotEmpty) {
        _cachedStations = stations;
        _stationsCachedAt = now;
      }
      return stations;
    } finally {
      if (identical(_stationLoadInProgress, load)) {
        _stationLoadInProgress = null;
      }
    }
  }

  static Future<List<_ForecastStation>> _readStations() async {
    final snapshot =
        await _db.collection('spots_index').get().timeout(_requestTimeout);
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return _ForecastStation(
        id: doc.id,
        name: data['name'] as String? ?? doc.id,
        latitude: (data['latitude'] as num?)?.toDouble() ?? double.nan,
        longitude: (data['longitude'] as num?)?.toDouble() ?? double.nan,
      );
    }).where((station) {
      return station.id.isNotEmpty &&
          _validCoordinates(station.latitude, station.longitude);
    }).toList(growable: false);
  }

  static _ForecastStation? _nearestStation(
    List<_ForecastStation> stations,
    double latitude,
    double longitude,
  ) {
    _ForecastStation? nearest;
    var shortestDistance = double.infinity;
    for (final station in stations) {
      final distance = _haversineKm(
        latitude,
        longitude,
        station.latitude,
        station.longitude,
      );
      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearest = station;
      }
    }
    return nearest;
  }

  static double _haversineKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusKm = 6371.0;
    const degreesToRadians = math.pi / 180;
    final deltaLatitude = (latitude2 - latitude1) * degreesToRadians;
    final deltaLongitude = (longitude2 - longitude1) * degreesToRadians;
    final latitude1Radians = latitude1 * degreesToRadians;
    final latitude2Radians = latitude2 * degreesToRadians;
    final a = math.sin(deltaLatitude / 2) * math.sin(deltaLatitude / 2) +
        math.cos(latitude1Radians) *
            math.cos(latitude2Radians) *
            math.sin(deltaLongitude / 2) *
            math.sin(deltaLongitude / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _ForecastStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const _ForecastStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
