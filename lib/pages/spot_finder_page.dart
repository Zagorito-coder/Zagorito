// ============================================================
//  spot_finder_page.dart — Wrapper pour la carte existante
//  Transmet les spots déjà chargés depuis le splash
// ============================================================

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:spots_app/main.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/spot_selection_request.dart';
import 'package:spots_app/models/user_spot_selection_request.dart';

class SpotFinderPage extends StatelessWidget {
  final List<Spot>? initialSpots;
  final ValueListenable<int>? addSpotRequests;
  final ValueListenable<SpotSelectionRequest?>? spotSelectionRequests;
  final ValueListenable<UserSpotSelectionRequest?>? userSpotSelectionRequests;
  final VoidCallback? onOpenMySpots;

  const SpotFinderPage({
    super.key,
    this.initialSpots,
    this.addSpotRequests,
    this.spotSelectionRequests,
    this.userSpotSelectionRequests,
    this.onOpenMySpots,
  });

  @override
  Widget build(BuildContext context) {
    return MapScreen(
      initialSpots: initialSpots,
      addSpotRequests: addSpotRequests,
      spotSelectionRequests: spotSelectionRequests,
      userSpotSelectionRequests: userSpotSelectionRequests,
      onOpenMySpots: onOpenMySpots,
    );
  }
}
