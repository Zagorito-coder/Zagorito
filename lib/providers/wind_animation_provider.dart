// ============================================================================
// wind_animation_provider.dart
//
// ChangeNotifier qui gere l'etat de l'animation de vent sur la carte.
// - isEnabled: toggle ON/OFF (false par defaut = 0% CPU/GPU)
// - spotForecast: donnees meteo du spot selectionne (cache local avec TTL)
// - selectedHourIndex: index du creneau horaire dans le slider
// - windData: vecteurs U/V pre-calcules pour le painter
// ============================================================================

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/utils/geo_utils.dart';

/// Vecteur vent pre-calcule pour le CustomPainter.
class WindVector {
  final double u;
  final double v;
  final double speedKt;
  final int directionDeg;

  const WindVector({
    required this.u,
    required this.v,
    required this.speedKt,
    required this.directionDeg,
  });
}

class _CachedForecast {
  final SpotForecast forecast;
  final DateTime timestamp;
  const _CachedForecast({required this.forecast, required this.timestamp});
}

class WindAnimationProvider extends ChangeNotifier {
  bool _isEnabled = false;
  String? _spotId;
  SpotForecast? _forecast;
  int _selectedHourIndex = 0;
  WindVector? _currentVector;
  bool _isLoading = false;
  String? _error;

  final Map<String, _CachedForecast> _cache = {};
  static const int _maxCacheEntries = 50;
  static const Duration _cacheTtl = Duration(minutes: 30);

  bool get isEnabled => _isEnabled;
  String? get spotId => _spotId;
  SpotForecast? get forecast => _forecast;
  int get selectedHourIndex => _selectedHourIndex;
  WindVector? get currentVector => _currentVector;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get slotCount => _forecast?.slots.length ?? 0;

  /// Toggle ON/OFF. ON = trouve le spot meteo le plus proche et charge.
  /// OFF = desactive immediatement (synchrone).
  void toggleNearest(double lat, double lon) {
    if (_isEnabled) {
      disable();
      return;
    }
    enableNearest(lat, lon);
  }

  /// Active l'animation de vent et charge les donnees du spot le plus proche.
  void enableNearest(double lat, double lon) {
    if (_isEnabled) return;
    _isEnabled = true;
    _isLoading = true;
    _error = null;
    notifyListeners();
    _fetchNearest(lat, lon);
  }

  /// Desactive l'animation de vent (conserve les donnees en cache).
  void disable() {
    if (!_isEnabled) return;
    _isEnabled = false;
    notifyListeners();
  }

  /// Charge les donnees vent pour le panel (sans activer l'animation)
  Future<void> fetchForPanel(double lat, double lon) async {
    if (_currentVector != null) return; // deja charge
    await _fetchNearest(lat, lon);
  }

  Future<void> _fetchNearest(double lat, double lon) async {
    try {
      final spots = await ForecastFirestoreService.listAvailableSpots();
      if (spots.isEmpty) {
        _error = 'Aucun spot meteo disponible';
        _isEnabled = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      String nearestId = spots.first['id'] as String;
      double minDist = double.infinity;
      for (final s in spots) {
        final d = haversineKm(
          lat, lon,
          (s['latitude'] as num).toDouble(),
          (s['longitude'] as num).toDouble(),
        );
        if (d < minDist) {
          minDist = d;
          nearestId = s['id'] as String;
        }
      }

      await _loadSpotData(nearestId);
    } catch (e) {
      debugPrint('[WindAnimationProvider] Erreur fetchNearest: $e');
      _error = e.toString();
      _isEnabled = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSpotData(String spotId) async {
    _spotId = spotId;

    if (_cache.containsKey(spotId)) {
      final cached = _cache[spotId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        _forecast = cached.forecast;
        _selectedHourIndex = _findClosestHourIndex(_forecast!);
        _computeVector();
        _isLoading = false;
        notifyListeners();
        return;
      }
      // TTL expire, on recharge
      _cache.remove(spotId);
    }

    try {
      final forecast = await ForecastFirestoreService.fetchSpot(spotId);
      if (forecast == null || forecast.slots.isEmpty) {
        _error = 'Aucune donnee meteo pour ce spot';
        _isEnabled = false;
        _isLoading = false;
        notifyListeners();
        return;
      }
      _evictCacheIfNeeded();
      _cache[spotId] = _CachedForecast(forecast: forecast, timestamp: DateTime.now());
      _forecast = forecast;
      _selectedHourIndex = _findClosestHourIndex(forecast);
      _computeVector();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[WindAnimationProvider] Erreur loadSpotData: $e');
      _error = e.toString();
      _isEnabled = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _evictCacheIfNeeded() {
    while (_cache.length >= _maxCacheEntries) {
      final oldest = _cache.entries
          .reduce((a, b) =>
              a.value.timestamp.isBefore(b.value.timestamp) ? a : b);
      _cache.remove(oldest.key);
    }
  }

  void selectHourIndex(int index) {
    if (_forecast == null || index < 0 || index >= _forecast!.slots.length) return;
    if (index == _selectedHourIndex) return;
    _selectedHourIndex = index;
    _computeVector();
    notifyListeners();
  }

  int _findClosestHourIndex(SpotForecast forecast) {
    final now = DateTime.now();
    int best = 0;
    double bestDiff = double.infinity;
    for (int i = 0; i < forecast.slots.length; i++) {
      final diff = forecast.slots[i].dateTime.difference(now).abs().inMinutes.toDouble();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  void _computeVector() {
    if (_forecast == null) {
      _currentVector = null;
      return;
    }
    final slot = _forecast!.slots[_selectedHourIndex];
    final speed = slot.windGustKnots > 0 ? slot.windGustKnots : slot.windSpeedKnots;
    final dirDeg = slot.windDirectionDeg;
    final angleRad = (270 - dirDeg) * pi / 180.0;
    _currentVector = WindVector(
      u: speed * cos(angleRad),
      v: speed * sin(angleRad),
      speedKt: speed,
      directionDeg: dirDeg.toInt(),
    );
  }

  /// Vide le cache explicitement (utile pour le debug ou le logout).
  void clearCache() => _cache.clear();

  static String directionToText(int deg) {
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                  'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO'];
    final index = ((deg + 11.25) / 22.5).floor() % 16;
    return dirs[index];
  }

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }
}