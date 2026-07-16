// ============================================================================
// wind_animation_provider.dart
//
// ChangeNotifier qui gere l'etat de l'animation de vent sur la carte.
// - isEnabled: toggle ON/OFF (false par defaut = 0% CPU/GPU)
// - spotForecast: donnees meteo du spot selectionne (cache local)
// - selectedHourIndex: index du creneau horaire dans le slider
// - windData: vecteurs U/V pre-calcules pour le painter
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';

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

class WindAnimationProvider extends ChangeNotifier {
  bool _isEnabled = false;
  String? _spotId;
  SpotForecast? _forecast;
  int _selectedHourIndex = 0;
  WindVector? _currentVector;
  bool _isLoading = false;
  String? _error;

  final Map<String, SpotForecast> _cache = {};

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
      // DESACTIVER: on garde les donnees pour le panel, on stoppe juste l'animation
      _isEnabled = false;
      notifyListeners();
      return;
    }

    // ACTIVER: lancement asynchrone, mais l'UI voit _isEnabled = true
    // et _isLoading = true immediatement
    _isEnabled = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _fetchNearest(lat, lon);
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
        final d = _haversine(
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
      _error = e.toString();
      _isEnabled = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSpotData(String spotId) async {
    _spotId = spotId;

    if (_cache.containsKey(spotId)) {
      _forecast = _cache[spotId]!;
      _selectedHourIndex = _findClosestHourIndex(_forecast!);
      _computeVector();
      _isLoading = false;
      notifyListeners();
      return;
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
      _cache[spotId] = forecast;
      _forecast = forecast;
      _selectedHourIndex = _findClosestHourIndex(forecast);
      _computeVector();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isEnabled = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1 * 3.141592653589793 / 180) *
            _cos(lat2 * 3.141592653589793 / 180) *
            _sin(dLon / 2) * _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
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
    final angleRad = (270 - dirDeg) * 3.141592653589793 / 180.0;
    _currentVector = WindVector(
      u: speed * _cos(angleRad),
      v: speed * _sin(angleRad),
      speedKt: speed,
      directionDeg: dirDeg.toInt(),
    );
  }

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

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x;
    for (int i = 0; i < 20; i++) { g = (g + x / g) / 2; }
    return g;
  }

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0.0;
  }

  static double _atan(double x) {
    double r = 0, t = x, x2 = x * x;
    for (int i = 1; i < 20; i++) { r += t / (2 * i - 1); t *= -x2; }
    return r;
  }

  static double _cos(double x) {
    double r = 1.0, t = 1.0;
    for (int i = 1; i <= 10; i++) { t *= -x * x / (2 * i * (2 * i - 1)); r += t; }
    return r;
  }

  static double _sin(double x) {
    double r = x, t = x;
    for (int i = 1; i <= 10; i++) { t *= -x * x / (2 * i * (2 * i + 1)); r += t; }
    return r;
  }
}