import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/marine_weather_points.dart';

class MarineCoordinates {
  final double latitude;
  final double longitude;
  const MarineCoordinates(this.latitude, this.longitude);
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

enum MarineLocationIssue { permission, disabled, unavailable }

/// Shared, foreground-only location selection. No provider requests or writes
/// to Firebase; preference storage is local to the device.
class MarineLocationController extends ChangeNotifier {
  MarineLocationController({
    Future<MarineCoordinates> Function(bool)? locate,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  })  : _locate = locate ?? _devicePosition,
        _preferences = preferences ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static final instance = MarineLocationController();
  static const preferenceKey = 'marine_location_v1';
  final Future<MarineCoordinates> Function(bool) _locate;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  Future<void>? _restoreFuture;
  Future<void>? _initialization;
  Future<void> _writeQueue = Future.value();
  bool _disposed = false;
  int _request = 0;
  int revision = 0;
  bool automatic = true;
  bool locating = false;
  bool lastKnown = false;
  MarineCoordinates? coordinates;
  MarineWeatherPoint? weatherPoint;
  MarineLocationIssue? issue;
  DateTime? _lastAttempt;

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await _restore();
    if (!_disposed && automatic) await refresh();
  }

  Future<void> _restore() => _restoreFuture ??= _readPreference();
  Future<void> _readPreference() async {
    try {
      final raw = (await _preferences()).getString(preferenceKey);
      if (raw == null || _disposed) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['mode'] == 'manual') {
        final point =
            marineWeatherPoints.where((p) => p.id == data['id']).firstOrNull;
        if (point == null) return;
        automatic = false;
        weatherPoint = point;
        coordinates = MarineCoordinates(point.latitude, point.longitude);
      } else if (data['mode'] == 'auto') {
        final position = MarineCoordinates(
            (data['lat'] as num).toDouble(), (data['lon'] as num).toDouble());
        if (!position.valid) return;
        coordinates = position;
        weatherPoint =
            nearestMarineWeatherPoint(position.latitude, position.longitude);
        lastKnown = true;
      } else {
        return;
      }
      revision++;
      _notify();
    } catch (_) {/* Invalid preferences must never invent a default city. */}
  }

  Future<void> selectManual(MarineWeatherPoint point) async {
    await _restore();
    if (_disposed) return;
    _request++;
    automatic = false;
    locating = false;
    lastKnown = false;
    issue = null;
    coordinates = MarineCoordinates(point.latitude, point.longitude);
    weatherPoint = point;
    revision++;
    _notify();
    await _persist();
  }

  Future<void> useMyPosition() async {
    await _restore();
    if (_disposed) return;
    automatic = true;
    unawaited(_persist());
    await refresh(requestPermission: true, force: true);
  }

  Future<void> refresh(
      {bool requestPermission = false, bool force = false}) async {
    await _restore();
    if (_disposed || !automatic || locating) return;
    if (!force &&
        _lastAttempt != null &&
        _now().difference(_lastAttempt!) < const Duration(minutes: 5)) {
      return;
    }
    final request = ++_request;
    _lastAttempt = _now();
    locating = true;
    lastKnown = coordinates != null;
    issue = null;
    _notify();
    try {
      final position = await _locate(requestPermission);
      if (_disposed || request != _request || !automatic) return;
      if (!position.valid) throw MarineLocationIssue.unavailable;
      coordinates = position;
      weatherPoint =
          nearestMarineWeatherPoint(position.latitude, position.longitude);
      lastKnown = false;
      revision++;
      _notify();
      await _persist();
    } catch (error) {
      if (_disposed || request != _request) return;
      issue = error is MarineLocationIssue
          ? error
          : MarineLocationIssue.unavailable;
      lastKnown = coordinates != null;
    } finally {
      if (!_disposed && request == _request) {
        locating = false;
        _notify();
      }
    }
  }

  Future<void> _persist() {
    final position = coordinates;
    if (position == null) return Future.value();
    final raw = jsonEncode(automatic
        ? {'mode': 'auto', 'lat': position.latitude, 'lon': position.longitude}
        : {'mode': 'manual', 'id': weatherPoint!.id});
    // Serialize writes so a slow earlier GPS result cannot overwrite a choice.
    _writeQueue = _writeQueue.then((_) async {
      try {
        await (await _preferences()).setString(preferenceKey, raw);
      } catch (_) {
        /* Selection remains usable if local storage is unavailable. */
      }
    });
    return _writeQueue;
  }

  static Future<MarineCoordinates> _devicePosition(bool request) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw MarineLocationIssue.disabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw MarineLocationIssue.permission;
    }
    final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10)));
    return MarineCoordinates(position.latitude, position.longitude);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
