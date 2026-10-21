// ============================================================
//  home_page.dart — Données et contrat fonctionnel de l'accueil
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/marine_location_controller.dart';

import '../models.dart';
import '../models/tide_data.dart';
import '../services/spot_service.dart';
import '../services/tide_service.dart';
import 'home_dashboard.dart';

class HomePage extends StatefulWidget {
  final List<Spot>? initialSpots;
  final VoidCallback? onNavigateToSpots;
  final VoidCallback? onNavigateToSpecies;
  final VoidCallback? onNavigateToTechniques;
  final VoidCallback? onNavigateToCommunity;
  final VoidCallback? onNavigateToShops;
  final VoidCallback? onNavigateToTides;
  final VoidCallback? onNavigateToTidesV2;

  const HomePage({
    super.key,
    this.initialSpots,
    this.onNavigateToSpots,
    this.onNavigateToSpecies,
    this.onNavigateToTechniques,
    this.onNavigateToCommunity,
    this.onNavigateToShops,
    this.onNavigateToTides,
    this.onNavigateToTidesV2,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _location = MarineLocationController.instance;
  int _locationRevision = -1;
  int _loadRequest = 0;
  TideData _tideData =
      TideData.fallback(location: TideService.unavailableLocationLabel);
  bool _isLoading = true;
  late List<Spot> _spots;

  @override
  void initState() {
    super.initState();
    _spots = widget.initialSpots ?? [];
    // Les chargements historiques restent non bloquants au premier frame.
    _location.addListener(_onLocationChanged);
    unawaited(_location.initialize().then((_) {
      if (mounted) _onLocationChanged();
    }));
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    if (_spots.isNotEmpty) return;
    final spots = await SpotService.loadSpots();
    if (mounted) {
      setState(() => _spots = spots);
    }
  }

  void _onLocationChanged() {
    if (!mounted || _locationRevision == _location.revision) return;
    _locationRevision = _location.revision;
    unawaited(_loadTides());
  }

  @override
  void dispose() {
    _location.removeListener(_onLocationChanged);
    _loadRequest++;
    super.dispose();
  }

  Future<void> _loadTides() async {
    final request = ++_loadRequest;
    final position = _location.coordinates;
    setState(() {
      _tideData =
          TideData.fallback(location: TideService.unavailableLocationLabel);
      _isLoading = position != null;
    });
    if (position == null) return;
    try {
      final data = await TideService.fetchTides(
          latitude: position.latitude, longitude: position.longitude);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _tideData = data;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadTides();
  }

  @override
  Widget build(BuildContext context) {
    return HomeDashboard(
      tideData: _tideData,
      isLoading: _isLoading,
      spots: _spots,
      onRefresh: _refresh,
      onNavigateToSpots: widget.onNavigateToSpots,
      onNavigateToSpecies: widget.onNavigateToSpecies,
      onNavigateToTechniques: widget.onNavigateToTechniques,
      onNavigateToCommunity: widget.onNavigateToCommunity,
      onNavigateToShops: widget.onNavigateToShops,
      onNavigateToTides: widget.onNavigateToTides,
      onNavigateToTidesV2: widget.onNavigateToTidesV2,
    );
  }
}
