// ============================================================
//  tide_service.dart — Conditions marines publiees par le backend
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/tide_data.dart';
import 'casablanca_tide_reference.dart';
import 'tide_conditions_mapper.dart';

class TideService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _maximumForecastAge = Duration(hours: 36);
  static const String unavailableLocationLabel =
      'Données marines indisponibles';

  /// Une station marégraphique publiée ne représente une position que dans un
  /// rayon côtier de 100 km. Hors de ce rayon, le service doit utiliser son
  /// repli explicite plutôt qu'une station marocaine éloignée.
  static const double maximumTideStationDistanceKm = 100.0;

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
    String? locationName,
  }) async {
    if (!_validCoordinates(latitude, longitude)) {
      return TideData.fallback(location: _fallbackLocation(locationName));
    }

    final station = _nearestStation(
      _publishedStations,
      latitude,
      longitude,
    );
    if (station == null) {
      return TideData.fallback(location: _fallbackLocation(locationName));
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

        final mapped = TideConditionsMapper.fromDocument(
          data,
          fallbackLocation: station.name,
        );
        return station.id == 'casablanca'
            ? CasablancaTideReference.calibrateForecast(mapped)
            : mapped;
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
    return TideData.fallback(location: station.name);
  }

  static String _fallbackLocation(String? locationName) {
    final normalized = locationName?.trim();
    return normalized == null || normalized.isEmpty
        ? unavailableLocationLabel
        : normalized;
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
  ) =>
      _nearestWithinRadius<_ForecastStation>(
        stations: stations,
        latitude: latitude,
        longitude: longitude,
        latitudeOf: (station) => station.latitude,
        longitudeOf: (station) => station.longitude,
        maximumDistanceKm: maximumTideStationDistanceKm,
      );

  /// Sélection pure exposée pour vérifier la règle de rayon sans initialiser
  /// Firebase. Les cartes invalides sont ignorées et aucun identifiant n'est
  /// renvoyé si la station la plus proche se trouve au-delà du seuil.
  @visibleForTesting
  static String? nearestTideStationIdWithinRadius({
    required Iterable<Map<String, dynamic>> stations,
    required double latitude,
    required double longitude,
  }) {
    final validStations = stations.where((station) {
      final id = station['id'];
      final stationLatitude = (station['latitude'] as num?)?.toDouble();
      final stationLongitude = (station['longitude'] as num?)?.toDouble();
      return id is String &&
          id.trim().isNotEmpty &&
          stationLatitude != null &&
          stationLongitude != null &&
          _validCoordinates(stationLatitude, stationLongitude);
    });
    final nearest = _nearestWithinRadius<Map<String, dynamic>>(
      stations: validStations,
      latitude: latitude,
      longitude: longitude,
      latitudeOf: (station) => (station['latitude'] as num).toDouble(),
      longitudeOf: (station) => (station['longitude'] as num).toDouble(),
      maximumDistanceKm: maximumTideStationDistanceKm,
    );
    return nearest?['id'] as String?;
  }

  static T? _nearestWithinRadius<T>({
    required Iterable<T> stations,
    required double latitude,
    required double longitude,
    required double Function(T station) latitudeOf,
    required double Function(T station) longitudeOf,
    required double maximumDistanceKm,
  }) {
    if (!_validCoordinates(latitude, longitude) ||
        !maximumDistanceKm.isFinite ||
        maximumDistanceKm < 0) {
      return null;
    }

    T? nearest;
    var shortestDistance = double.infinity;
    for (final station in stations) {
      final stationLatitude = latitudeOf(station);
      final stationLongitude = longitudeOf(station);
      if (!_validCoordinates(stationLatitude, stationLongitude)) continue;
      final distance = _haversineKm(
        latitude,
        longitude,
        stationLatitude,
        stationLongitude,
      );
      if (distance <= maximumDistanceKm && distance < shortestDistance) {
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
