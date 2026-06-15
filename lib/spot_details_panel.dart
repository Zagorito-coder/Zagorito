// ============================================================
//  spot_details_panel.dart — Panneau de détails grand format
//  Layout stable sans overflow
//  ✅ CORRIGÉ : adaptatif clair/sombre via ThemeColors
// ============================================================

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/theme.dart';

class SpotDetailsPanel extends StatelessWidget {
  final Spot spot;
  final String distanceText;
  final bool isPremium;
  final VoidCallback onClose;
  final VoidCallback onPremiumTap;
  final LatLng? currentPosition;
  final List<Spot> allSpots;
  final Function(Spot) onSpotSelected;

  const SpotDetailsPanel({
    super.key,
    required this.spot,
    required this.distanceText,
    required this.isPremium,
    required this.onClose,
    required this.onPremiumTap,
    this.currentPosition,
    required this.allSpots,
    required this.onSpotSelected,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) await _launchFallback(url);
    } catch (_) {
      await _launchFallback(url);
    }
  }

  Future<void> _launchFallback(String originalUrl) async {
    String fallbackUrl = originalUrl;
    if (originalUrl.startsWith('waze://')) {
      fallbackUrl = 'https://waze.com/ul?ll=${spot.latitude},${spot.longitude}&navigate=yes';
    } else if (originalUrl.startsWith('geo:') || originalUrl.startsWith('comgooglemaps://')) {
      final dest = '${spot.latitude},${spot.longitude}';
      fallbackUrl = 'https://www.google.com/maps/search/?api=1&query=$dest';
    }
    await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
  }

  String get _googleMapsUrl {
    final dest = '${spot.latitude},${spot.longitude}';
    return 'geo:$dest?q=$dest';
  }

  List<Spot> _getNearbySpots() {
    if (allSpots.length < 2) return [];
    const distance = Distance();
    final spotLatLng = LatLng(spot.latitude, spot.longitude);
    final sortedSpots = List<Spot>.from(allSpots)
      ..removeWhere((s) => s.id == spot.id);
    sortedSpots.sort((a, b) {
      final distA = distance.as(LengthUnit.Kilometer, spotLatLng, LatLng(a.latitude, a.longitude));
      final distB = distance.as(LengthUnit.Kilometer, spotLatLng, LatLng(b.latitude, b.longitude));
      return distA.compareTo(distB);
    });
    return sortedSpots.take(4).toList();
  }

  String _getSpotDistance(Spot s) {
    if (currentPosition == null) return '';
    const distance = Distance();
    final km = distance.as(
      LengthUnit.Kilometer,
      LatLng(currentPosition!.latitude, currentPosition!.longitude),
      LatLng(s.latitude, s.longitude),
    );
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final spotColor = spot.type.color;
    final nearbySpots = _getNearbySpots();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tc.textPrimary.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: spotColor.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: tc.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: spotColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: spotColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.place, color: spotColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spot.type.label,
                      style: TextStyle(
                        color: spotColor.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tc.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.close, color: tc.textSecondary, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── CHIPS ROW ──
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  label: spot.type.label,
                  color: spotColor,
                  icon: Icons.place,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoChip(
                  label: distanceText,
                  color: tc.oceanLight,
                  icon: Icons.near_me,
                ),
              ),
            ],
          ),

          // ── FISH TYPES ──
          if (spot.fishTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (isPremium)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: spot.fishTypes
                    .map((f) => _InfoChip(label: f, color: tc.success, icon: Icons.set_meal))
                    .toList(),
              )
            else
              _PremiumGate(label: 'Types de poissons — Premium', onTap: onPremiumTap),
          ],

          // ── NOTES ──
          if (spot.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (isPremium)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tc.textPrimary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tc.textPrimary.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  spot.notes,
                  style: TextStyle(
                    color: tc.textPrimary.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              _PremiumGate(label: 'Notes detaillees — Premium', onTap: onPremiumTap),
          ],

          const SizedBox(height: 8),

          // ── GOOGLE MAPS BUTTON ──
          GestureDetector(
            onTap: () => _launchUrl(_googleMapsUrl),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4285F4).withValues(alpha: 0.25),
                    const Color(0xFF4285F4).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.place, color: Colors.white, size: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ouvrir dans Google Maps',
                    style: TextStyle(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── SPOTS VOISINS (prend l'espace restant) ──
          if (nearbySpots.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: tc.divider, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.explore_outlined, color: tc.gold.withValues(alpha: 0.8), size: 13),
                const SizedBox(width: 6),
                Text(
                  'SPOTS VOISINS',
                  style: TextStyle(
                    color: tc.gold.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 82,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: nearbySpots.asMap().entries.map((entry) {
                    final nearbySpot = entry.value;
                    final isLast = entry.key == nearbySpots.length - 1;
                    final isCloser = _isCloserSpot(nearbySpot);
                    return Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 8),
                      child: _NearbySpotCard(
                        spot: nearbySpot,
                        distance: _getSpotDistance(nearbySpot),
                        isCloser: isCloser,
                        onTap: () => onSpotSelected(nearbySpot),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  bool _isCloserSpot(Spot nearbySpot) {
    if (currentPosition == null) return false;
    const distance = Distance();
    final currentLatLng = LatLng(currentPosition!.latitude, currentPosition!.longitude);
    final distCurrent = distance.as(
        LengthUnit.Kilometer, currentLatLng, LatLng(spot.latitude, spot.longitude));
    final distNearby = distance.as(
        LengthUnit.Kilometer, currentLatLng, LatLng(nearbySpot.latitude, nearbySpot.longitude));
    return distNearby < distCurrent;
  }
}

// ──────────────────────────────────────────────
//  NEARBY SPOT CARD — compacte
// ──────────────────────────────────────────────

class _NearbySpotCard extends StatelessWidget {
  final Spot spot;
  final String distance;
  final bool isCloser;
  final VoidCallback onTap;

  const _NearbySpotCard({
    required this.spot,
    required this.distance,
    required this.isCloser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final spotColor = spot.type.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        decoration: BoxDecoration(
          color: tc.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: spotColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: icon + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: spotColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(Icons.place, color: spotColor, size: 11),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCloser
                        ? tc.success.withValues(alpha: 0.12)
                        : tc.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isCloser
                          ? tc.success.withValues(alpha: 0.4)
                          : tc.textPrimary.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCloser ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCloser ? tc.success : tc.textMuted,
                        size: 8,
                      ),
                      const SizedBox(width: 1),
                      Text(
                        isCloser ? 'Proche' : 'Loin',
                        style: TextStyle(
                          color: isCloser ? tc.success : tc.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Name
            Text(
              spot.name,
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Type + Distance
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: spotColor),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    spot.type.label,
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.7),
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  distance,
                  style: TextStyle(
                    color: spotColor.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  INFO CHIP
// ──────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _InfoChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  PREMIUM GATE
// ──────────────────────────────────────────────

class _PremiumGate extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PremiumGate({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tc.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tc.gold.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tc.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.lock_outline, color: tc.gold, size: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tc.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tc.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'DEBLOQUER',
                style: TextStyle(
                  color: tc.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
