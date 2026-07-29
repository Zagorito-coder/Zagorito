import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/services/user_spot_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/widgets/finite_marker_layer.dart';

/// Distinguishes private user-created spots from the public catalog while
/// preserving the catalog marker's visual language.
const Color personalSpotMarkerNavy = Color(0xFF0B2852);

/// Displays the signed-in user's private spots on the main map.
///
/// Provider lookup is guarded so isolated map widget tests can still mount
/// without initializing Firebase authentication.
class PersonalSpotsMapLayer extends StatelessWidget {
  const PersonalSpotsMapLayer({
    super.key,
    required this.onSpotTap,
    this.selectedSpotId,
  });

  final ValueChanged<UserSpot> onSpotTap;
  final String? selectedSpotId;

  @override
  Widget build(BuildContext context) {
    final AuthService auth;
    try {
      auth = Provider.of<AuthService>(context);
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final uid = auth.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<UserSpot>>(
      stream: UserSpotService.instance.watchUserSpots(uid),
      builder: (context, snapshot) {
        final spots = snapshot.data;
        if (spots == null || spots.isEmpty) {
          return const SizedBox.shrink();
        }
        return FiniteMarkerLayer(
          markers: [
            for (final spot in spots)
              if (spot.id != selectedSpotId &&
                  spot.latitude.isFinite &&
                  spot.longitude.isFinite)
                Marker(
                  width: 32,
                  height: 32,
                  point: LatLng(spot.latitude, spot.longitude),
                  child: PersonalSpotMapMarker(
                    spot: spot,
                    onTap: () => onSpotTap(spot),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class PersonalSpotMapMarker extends StatelessWidget {
  const PersonalSpotMapMarker({
    super.key,
    required this.spot,
    required this.onTap,
    this.selected = false,
  });

  final UserSpot spot;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return Semantics(
      key: ValueKey<String>(
        selected
            ? 'selected-personal-map-spot-${spot.id}'
            : 'personal-map-spot-${spot.id}',
      ),
      button: true,
      label: spot.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: selected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 168),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tc.surface.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: personalSpotMarkerNavy, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: tc.shadowColor,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: personalSpotMarkerNavy,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tc.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SelectedPersonalSpotPin(),
                ],
              )
            : const Center(
                child: _PersonalSpotDot(),
              ),
      ),
    );
  }
}

class _PersonalSpotDot extends StatelessWidget {
  const _PersonalSpotDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('personal-spot-navy-dot'),
      width: 14,
      height: 14,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: personalSpotMarkerNavy.withValues(alpha: 0.9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.92),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: personalSpotMarkerNavy.withValues(alpha: 0.22),
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
          ),
          Positioned(
            left: 3.1,
            top: 3.1,
            child: Container(
              width: 3.4,
              height: 3.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPersonalSpotPin extends StatelessWidget {
  const _SelectedPersonalSpotPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('selected-personal-spot-navy-pin'),
      width: 38,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 53,
              height: 29,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: personalSpotMarkerNavy.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: ClipPath(
              clipper: _PersonalSpotDropClipper(),
              child: Container(
                width: 38,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      personalSpotMarkerNavy.withValues(alpha: 0.95),
                      personalSpotMarkerNavy.withValues(alpha: 0.65),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: personalSpotMarkerNavy.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.phishing,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 34.5,
            child: Container(
              width: 13,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalSpotDropClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) => ui.Path()
    ..moveTo(size.width * 0.5, 0)
    ..cubicTo(
      size.width * 0.05,
      size.height * 0.25,
      size.width * 0.05,
      size.height * 0.65,
      size.width * 0.5,
      size.height,
    )
    ..cubicTo(
      size.width * 0.95,
      size.height * 0.65,
      size.width * 0.95,
      size.height * 0.25,
      size.width * 0.5,
      0,
    )
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}
