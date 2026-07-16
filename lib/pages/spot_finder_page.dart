// ============================================================
//  spot_finder_page.dart — Wrapper pour la carte existante
//  Transmet les spots déjà chargés depuis le splash
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/main.dart';
import 'package:spots_app/models.dart';

class SpotFinderPage extends StatelessWidget {
  final List<Spot>? initialSpots;
  const SpotFinderPage({super.key, this.initialSpots});

  @override
  Widget build(BuildContext context) {
    return MapScreen(initialSpots: initialSpots);
  }
}
