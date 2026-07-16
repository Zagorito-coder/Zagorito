// ============================================================
//  fish_provider.dart — État global pour le système Fish Intelligence
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:spots_app/models.dart';
import 'package:spots_app/models/fish_model.dart';

class FishProvider extends ChangeNotifier {
  static final FishProvider _instance = FishProvider._internal();
  static FishProvider get instance => _instance;

  FishProvider._internal();

  factory FishProvider() => _instance;

  // ── ÉTAT ──
  FishModel? _selectedFish;
  List<FishModel> _allFish = [];
  List<Spot> _nearbySpots = [];
  bool _isFishBarVisible = false;
  bool _isFishModalVisible = false;
  bool _isLoadingFish = false;
  bool _isLoadingNearby = false;

  // ── GETTERS ──
  FishModel? get selectedFish => _selectedFish;
  List<FishModel> get allFish => List.unmodifiable(_allFish);
  List<Spot> get nearbySpots => List.unmodifiable(_nearbySpots);
  bool get isFishBarVisible => _isFishBarVisible;
  bool get isFishModalVisible => _isFishModalVisible;
  bool get isLoadingFish => _isLoadingFish;
  bool get isLoadingNearby => _isLoadingNearby;

  // ── MÉTHODES UI ──
  Future<void> selectFish(
    FishModel fish,
    List<Spot> allSpots,
    Position? position,
  ) async {
    _selectedFish = fish;
    _isFishModalVisible = true;
    _nearbySpots = [];
    notifyListeners();

    await _computeNearbySpots(allSpots, position);
  }

  void deselectFish() {
    _selectedFish = null;
    _isFishModalVisible = false;
    _nearbySpots = [];
    notifyListeners();
  }

  void toggleFishBar() {
    _isFishBarVisible = !_isFishBarVisible;
    notifyListeners();
  }

  void closeFishModal() {
    _isFishModalVisible = false;
    notifyListeners();
  }

  void openFishBar() {
    _isFishBarVisible = true;
    notifyListeners();
  }

  void closeFishBar() {
    _isFishBarVisible = false;
    notifyListeners();
  }

  // ── CHARGEMENT DONNÉES ──
  Future<void> loadFishData() async {
    if (_isLoadingFish || _allFish.isNotEmpty) return;

    _isLoadingFish = true;
    notifyListeners();

    try {
      final raw = await rootBundle.loadString('assets/fish_data.json');
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _allFish = decoded
          .map((json) => FishModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _allFish = [];
    } finally {
      _isLoadingFish = false;
      notifyListeners();
    }
  }

  // ── LOGIQUE DE FILTRAGE SPOTS ──
  Future<void> _computeNearbySpots(
    List<Spot> allSpots,
    Position? position,
  ) async {
    if (_selectedFish == null || allSpots.isEmpty) return;

    _isLoadingNearby = true;
    notifyListeners();

    try {
      final args = _NearbyArgs(
        fish: _selectedFish!,
        spots: allSpots,
        position: position,
      );
      _nearbySpots = await Isolate.run(() => _filterAndSortSpots(args));
    } catch (_) {
      _nearbySpots = [];
    } finally {
      _isLoadingNearby = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  static List<Spot> _filterAndSortSpots(_NearbyArgs args) {
    final fish = args.fish;
    final allSpots = args.spots;
    final position = args.position;
    const limit = 10;

    final compatible = allSpots.where((spot) {
      return fish.compatibleSpotTypes.any((type) {
        final normalized = type.toLowerCase();
        return spot.fishTypes.any((ft) => ft.toLowerCase() == normalized) ||
            _spotTypeMatches(spot, normalized);
      });
    }).toList();

    if (position == null) {
      return compatible.take(limit).toList();
    }

    final origin = LatLng(position.latitude, position.longitude);
    const distance = Distance();

    compatible.sort((a, b) {
      final da = distance.as(
        LengthUnit.Kilometer,
        origin,
        LatLng(a.latitude, a.longitude),
      );
      final db = distance.as(
        LengthUnit.Kilometer,
        origin,
        LatLng(b.latitude, b.longitude),
      );
      return da.compareTo(db);
    });

    return compatible.take(limit).toList();
  }

  static bool _spotTypeMatches(Spot spot, String normalizedFishType) {
    final typeLabel = spot.type.label.toLowerCase();
    switch (normalizedFishType) {
      case 'mer':
        return true;
      case 'estuaire':
        return typeLabel.contains('estuaire') || typeLabel.contains('baie');
      case 'port':
        return typeLabel.contains('port') || typeLabel.contains('digue');
      case 'baie':
        return typeLabel.contains('baie') || typeLabel.contains('plage');
      case 'haute_mer':
        return false;
      default:
        return false;
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

}

class _NearbyArgs {
  final FishModel fish;
  final List<Spot> spots;
  final Position? position;

  const _NearbyArgs({
    required this.fish,
    required this.spots,
    this.position,
  });
}
