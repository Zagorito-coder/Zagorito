// ============================================================
//  spot_finder_page.dart — Wrapper pour la carte existante
//  Utilise le MapScreen existant comme page plein écran
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/main.dart';

class SpotFinderPage extends StatelessWidget {
  const SpotFinderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Réutilise directement le MapScreen existant
    return const MapScreen();
  }
}
