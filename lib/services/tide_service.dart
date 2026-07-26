// ============================================================
//  tide_service.dart — Conditions marines publiees par le backend
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/tide_data.dart';
import 'tide_conditions_mapper.dart';

class TideService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _maximumForecastAge = Duration(hours: 36);
  static const List<_ForecastStation> _publishedStations = [
    _ForecastStation(
      id: 'casablanca',
      name: 'Casablanca, Maroc',
      latitude: 33.59,
      longitude: -7.61,
    ),
    _ForecastStation(
      id: 'rabat',
      name: 'Rabat, Maroc',
      latitude: 34.02,
      longitude: -6.84,
    ),
    _ForecastStation(
      id: 'agadir',
      name: 'Agadir, Maroc',
      latitude: 30.42,
      longitude: -9.60,
    ),
    _ForecastStation(
      id: 'tanger',
      name: 'Tanger, Maroc',
      latitude: 35.77,
      longitude: -5.80,
    ),
    _ForecastStation(
      id: 'essaouira',
      name: 'Essaouira, Maroc',
      latitude: 31.51,
      longitude: -9.77,
    ),
  ];

  /// Lit les marées et conditions marines publiées par le job serveur.
  ///
  /// La hauteur de marée vient exclusivement de `sea_level_height_msl`.
  /// La position sert uniquement à choisir localement la station publiée la
  /// plus proche et n'est jamais envoyée à Open-Meteo depuis le téléphone.
  static Future<TideData> fetchTides({
    double latitude = 33.57,
    double longitude = -7.59,
    String locationName = 'Casablanca Morocco',
  }) async {
    if (!_validCoordinates(latitude, longitude)) {
      return TideData.fallback(location: locationName);
    }

    final station = _nearestStation(
      _publishedStations,
      latitude,
      longitude,
    );
    if (station == null) {
      return TideData.fallback(location: locationName);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final snapshot = await _db
            .collection('conditions')
            .doc(station.id)
            .get()
            .timeout(_requestTimeout);
        final data = snapshot.data();
        if (!snapshot.exists || data == null || !_isFresh(data['timestamp'])) {
          return TideData.fallback(location: station.name);
        }

        return TideConditionsMapper.fromDocument(
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
      String raw => DateTime.tryParse(raw),
      _ => null,
    };
    if (updatedAt == null) return false;
    final age = DateTime.now().difference(updatedAt);
    return age <= _maximumForecastAge && age >= const Duration(minutes: -5);
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
