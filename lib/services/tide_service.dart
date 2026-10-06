// ============================================================
//  tide_service.dart — Conditions marines publiees par le backend
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../data/marine_weather_points.dart';
import '../models/tide_data.dart';
import '../utils/station_time_zone.dart';
import 'astronomy_service.dart';
import 'casablanca_tide_reference.dart';
import 'tide_conditions_mapper.dart';

class TideService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _maximumForecastAge = Duration(hours: 36);
  static const String casablancaTimeZoneId = 'Africa/Casablanca';
  static const String unavailableLocationLabel =
      'Données marines indisponibles';

  /// Même rayon que le catalogue partagé Marées/Marées Pro. Au-delà, aucune
  /// ville distante n'est substituée silencieusement à la position demandée.
  static const double maximumTideStationDistanceKm = 75.0;

  static final List<TideStation> _publishedStations = marineWeatherPoints
      .map(
        (point) => TideStation(
          id: point.id,
          name: point.name,
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      )
      .toList(growable: false);

  static TideStation? stationForPosition(double latitude, double longitude) =>
      _nearestStation(_publishedStations, latitude, longitude);

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
        Map<String, dynamic>? data;
        for (final documentId in _conditionDocumentIds(station.id)) {
          final snapshot = await _db
              .collection('conditions')
              .doc(documentId)
              .get()
              .timeout(_requestTimeout);
          final candidate = snapshot.data();
          if (snapshot.exists &&
              candidate != null &&
              _isFresh(candidate['timestamp'])) {
            data = candidate;
            break;
          }
        }
        if (data == null) {
          return _fallbackForStation(station);
        }

        final mapped = TideConditionsMapper.fromDocument(
          data,
          fallbackLocation: station.name,
        );
        return station.id == 'casablanca_maroc' &&
                mapped.tideHeightDatum != TideHeightDatum.casablancaBmi
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
    return _fallbackForStation(station);
  }

  /// Repli hors ligne déterministe pour la station de Casablanca.
  ///
  /// Les hauteurs proviennent des constituants harmoniques locaux embarqués,
  /// sans appel réseau. Les champs météo et houle restent volontairement
  /// indisponibles au lieu d'afficher des valeurs inventées.
  @visibleForTesting
  static TideData casablancaOfflineFallback({DateTime? now}) {
    final referenceInstant = (now ?? DateTime.now()).toUtc();
    final referenceTime = StationTimeZone.civilAt(
      referenceInstant,
      timeZoneId: casablancaTimeZoneId,
    );
    final start = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
    );
    final startInstant = StationTimeZone.instantAt(
      start,
      timeZoneId: casablancaTimeZoneId,
    );
    final points = List<TidePoint>.generate(49, (index) {
      final instant = startInstant.add(Duration(hours: index));
      final time = StationTimeZone.civilAt(
        instant,
        timeZoneId: casablancaTimeZoneId,
      );
      return TidePoint(
        time: time,
        instantUtc: instant,
        height: CasablancaTideReference.heightAtUtc(instant),
      );
    }, growable: false);
    final low = points.map((point) => point.height).reduce(math.min);
    final high = points.map((point) => point.height).reduce(math.max);
    final next = points
            .where((point) => point.instantUtc!.isAfter(referenceInstant))
            .firstOrNull ??
        points.last;

    return TideData(
      hourlyPoints: points,
      low: low,
      high: high,
      next: next.height,
      waveHeight: 0,
      location: 'Casablanca, Maroc',
      generatedAt: null,
      utcOffsetSeconds: StationTimeZone.offsetSecondsAt(
        referenceInstant,
        timeZoneId: casablancaTimeZoneId,
      ),
      timeZoneId: casablancaTimeZoneId,
      tideHeightDatum: TideHeightDatum.casablancaBmi,
      astro: AstronomyService.calculate(referenceTime, low, high),
    );
  }

  static TideData _fallbackForStation(TideStation station) =>
      station.id == 'casablanca_maroc'
          ? casablancaOfflineFallback()
          : TideData.fallback(location: station.name);

  /// Compatibilité de transition : les versions antérieures du backend ont
  /// publié cinq documents sans suffixe pays. Ils restent lisibles jusqu'à la
  /// première récolte v2, sans jamais servir de repli à une autre ville.
  static List<String> _conditionDocumentIds(String stationId) {
    const legacyIds = <String, String>{
      'casablanca_maroc': 'casablanca',
      'rabat_maroc': 'rabat',
      'agadir_maroc': 'agadir',
      'tanger_maroc': 'tanger',
      'essaouira_maroc': 'essaouira',
    };
    final legacy = legacyIds[stationId];
    return legacy == null ? <String>[stationId] : <String>[stationId, legacy];
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

  static TideStation? _nearestStation(
    List<TideStation> stations,
    double latitude,
    double longitude,
  ) =>
      _nearestWithinRadius<TideStation>(
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

class TideStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const TideStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
