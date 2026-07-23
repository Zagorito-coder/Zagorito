// ============================================================
//  home_page.dart — Données et contrat fonctionnel de l'accueil
// ============================================================

import 'package:flutter/material.dart';

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
  TideData _tideData = TideData.fallback();
  bool _isLoading = true;
  late List<Spot> _spots;

  @override
  void initState() {
    super.initState();
    _spots = widget.initialSpots ?? [];
    // Les chargements historiques restent non bloquants au premier frame.
    _loadTides();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    if (_spots.isNotEmpty) return;
    final spots = await SpotService.loadSpots();
    if (mounted) {
      setState(() => _spots = spots);
    }
  }

  Future<void> _loadTides() async {
    final data = await TideService.fetchTides();
    if (mounted) {
      setState(() {
        _tideData = data;
        _isLoading = false;
      });
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
