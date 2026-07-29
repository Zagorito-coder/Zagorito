// ============================================================
//  spot_details_panel.dart — Panneau de détails compact et adaptatif
//  Layout stable sans overflow en portrait et paysage
//  ✅ CORRIGÉ : adaptatif clair/sombre via ThemeColors
//  ✅ VENT : vitesse + direction + slider timeline
// ============================================================

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/fishing_shop.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/services/favorite_spot_service.dart';
import 'package:spots_app/services/shop_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/providers/wind_animation_provider.dart';
import 'package:spots_app/widgets/open_meteo_attribution.dart';
import 'package:spots_app/widgets/wind_particle_painter.dart';

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
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) await _launchFallback(url);
    } catch (_) {
      await _launchFallback(url);
    }
  }

  Future<void> _launchFallback(String originalUrl) async {
    String fallbackUrl = originalUrl;
    if (originalUrl.startsWith('waze://')) {
      fallbackUrl =
          'https://waze.com/ul?ll=${spot.latitude},${spot.longitude}&navigate=yes';
    } else if (originalUrl.startsWith('geo:') ||
        originalUrl.startsWith('comgooglemaps://')) {
      final dest = '${spot.latitude},${spot.longitude}';
      fallbackUrl = 'https://www.google.com/maps/search/?api=1&query=$dest';
    }
    await launchUrl(Uri.parse(fallbackUrl),
        mode: LaunchMode.externalApplication);
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
      final distA = distance.as(
          LengthUnit.Kilometer, spotLatLng, LatLng(a.latitude, a.longitude));
      final distB = distance.as(
          LengthUnit.Kilometer, spotLatLng, LatLng(b.latitude, b.longitude));
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

  String _translateDirection(String code) {
    const map = {
      'N': 'Nord',
      'NNE': 'N-N-E',
      'NE': 'Nord-Est',
      'ENE': 'E-N-E',
      'E': 'Est',
      'ESE': 'E-S-E',
      'SE': 'Sud-Est',
      'SSE': 'S-S-E',
      'S': 'Sud',
      'SSO': 'S-S-O',
      'SO': 'Sud-Ouest',
      'OSO': 'O-S-O',
      'O': 'Ouest',
      'ONO': 'O-N-O',
      'NO': 'Nord-Ouest',
      'NNO': 'N-N-O',
    };
    return map[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final spotColor = spot.type.color;
    final nearbySpots = _getNearbySpots();

    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxHeight < 220;
        return RepaintBoundary(
          child: Container(
            padding: dense
                ? const EdgeInsets.fromLTRB(7, 5, 7, 5)
                : const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const [
                        Color(0xD407192C),
                        Color(0xC9031020),
                      ]
                    : const [
                        Color(0xD6FFFFFF),
                        Color(0xC4E9F7FC),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: tc.oceanLight.withValues(alpha: 0.52),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: tc.oceanLight.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
                BoxShadow(
                  color: tc.shadowColor.withValues(alpha: 0.72),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactHeader(context, spotColor, dense: dense),
                SizedBox(height: dense ? 3 : 4),
                SizedBox(
                  height: dense ? 46 : 50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildSpeciesDashboard(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildSpotActions(context, dense: dense),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: dense ? 4 : 5),
                Expanded(child: _buildWindSection(context)),
                OpenMeteoAttribution(
                  padding: dense
                      ? const EdgeInsets.fromLTRB(2, 0, 2, 0)
                      : const EdgeInsets.fromLTRB(3, 1, 3, 1),
                ),
                SizedBox(height: dense ? 1 : 2),
                _buildNearbyDashboard(context, nearbySpots, dense: dense),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactHeader(
    BuildContext context,
    Color spotColor, {
    required bool dense,
  }) {
    final tc = ThemeColors.of(context);
    return SizedBox(
      height: dense ? 38 : 40,
      child: Row(
        children: [
          Container(
            width: dense ? 28 : 31,
            height: dense ? 28 : 31,
            decoration: BoxDecoration(
              color: spotColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: spotColor.withValues(alpha: 0.52),
                width: 0.8,
              ),
            ),
            child: Icon(
              Icons.place_rounded,
              color: spotColor,
              size: dense ? 16 : 17,
            ),
          ),
          SizedBox(width: dense ? 6 : 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: dense ? 13.5 : 14.5,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: dense ? 2 : 3),
                Row(
                  children: [
                    Flexible(
                      child: _DashboardTag(
                        icon: Icons.circle,
                        label: spot.type.label,
                        color: spotColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: _DashboardTag(
                        icon: Icons.near_me_rounded,
                        label: distanceText,
                        color: tc.oceanLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: dense ? 4 : 5),
          _FavoriteButton(spot: spot, dense: dense),
          SizedBox(width: dense ? 2 : 3),
          Semantics(
            button: true,
            label: 'Fermer les détails du spot',
            child: Material(
              color: tc.textPrimary.withValues(alpha: 0.055),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                child: SizedBox(
                  width: dense ? 28 : 31,
                  height: dense ? 28 : 31,
                  child: Icon(
                    Icons.close_rounded,
                    color: tc.textSecondary,
                    size: dense ? 17 : 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesDashboard(BuildContext context) {
    final tc = ThemeColors.of(context);
    final fishTypes = spot.fishTypes;
    return _DashboardSection(
      title: 'ESPÈCES',
      icon: Icons.set_meal_rounded,
      accent: tc.success,
      child: fishTypes.isEmpty
          ? Center(
              child: Text(
                'Non renseignées',
                textAlign: TextAlign.center,
                style: TextStyle(color: tc.textMuted, fontSize: 9.5),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: fishTypes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Icon(
                      Icons.set_meal_rounded,
                      size: 12,
                      color: tc.success.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fishTypes[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tc.textPrimary.withValues(alpha: 0.88),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSpotActions(
    BuildContext context, {
    required bool dense,
  }) {
    final tc = ThemeColors.of(context);
    return _DashboardSection(
      title: 'INFORMATIONS',
      icon: Icons.info_outline_rounded,
      accent: tc.oceanLight,
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 12,
                  color: tc.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    spot.notes.isEmpty ? 'Notes indisponibles' : spot.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 9.5,
                      height: 1.22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Ouvrir ce spot dans Google Maps',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl(_googleMapsUrl),
                child: Container(
                  width: dense ? 52 : 58,
                  height: 27,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.48),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        color: Color(0xFF4285F4),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Maps',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF63C7FF)
                                    : const Color(0xFF176BCB),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyDashboard(
    BuildContext context,
    List<Spot> nearbySpots, {
    required bool dense,
  }) {
    final tc = ThemeColors.of(context);
    return SizedBox(
      height: dense ? 36 : 40,
      child: Row(
        children: [
          _NearestShopCard(
            key: ValueKey('nearest-shop-${spot.id}'),
            spot: spot,
          ),
          if (nearbySpots.isNotEmpty) const SizedBox(width: 5),
          SizedBox(
            width: dense ? 56 : 60,
            child: Row(
              children: [
                Icon(
                  Icons.explore_outlined,
                  color: tc.oceanLight,
                  size: 13,
                ),
                SizedBox(width: dense ? 3 : 4),
                Expanded(
                  child: Text(
                    'SPOTS\nVOISINS',
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: dense ? 8 : 8.5,
                      height: 1.08,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (nearbySpots.isNotEmpty) const SizedBox(width: 5),
          Expanded(
            child: nearbySpots.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: nearbySpots.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
                    itemBuilder: (context, index) {
                      final nearbySpot = nearbySpots[index];
                      return _NearbySpotCard(
                        spot: nearbySpot,
                        distance: _getSpotDistance(nearbySpot),
                        isCloser: _isCloserSpot(nearbySpot),
                        onTap: () => onSpotSelected(nearbySpot),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Section vent: vitesse + direction + slider timeline
  /// Le slider a exactement 8 positions (0h, 3h, 6h... 21h), une par heure unique.
  /// Chaque position selectionne le slot le plus proche de maintenant pour cette heure.
  Widget _buildWindSection(BuildContext context) {
    final wind = context.watch<WindAnimationProvider>();

    // Charger les donnees si pas encore fait (independant du toggle)
    if (wind.currentVector == null && !wind.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        wind.fetchForPanel(spot.latitude, spot.longitude);
      });
      return _buildWindPlaceholder(context, loading: true);
    }

    // Loading state
    if (wind.isLoading && wind.forecast == null) {
      return _buildWindPlaceholder(context, loading: true);
    }

    if (wind.currentVector == null) {
      return _buildWindPlaceholder(context, loading: false);
    }

    final tc = ThemeColors.of(context);
    final vector = wind.currentVector!;
    final dirCode = WindAnimationProvider.directionToText(vector.directionDeg);
    final dirText = _translateDirection(dirCode);
    final windColor = WindColors.forKnots(vector.speedKt);

    final slots = wind.forecast?.slots ?? [];
    if (slots.isEmpty) {
      return _buildWindPlaceholder(context, loading: false);
    }

    // Construire le mapping: pour chaque heure unique, le slot le plus proche de now
    final now = DateTime.now();
    final hourToBestSlot =
        <int, int>{}; // heure -> index du slot le plus proche
    for (int i = 0; i < slots.length; i++) {
      final h = slots[i].dateTime.hour;
      if (!hourToBestSlot.containsKey(h)) {
        hourToBestSlot[h] = i;
      } else {
        final existingDist =
            slots[hourToBestSlot[h]!].dateTime.difference(now).abs();
        final newDist = slots[i].dateTime.difference(now).abs();
        if (newDist < existingDist) hourToBestSlot[h] = i;
      }
    }
    final sortedHours = hourToBestSlot.keys.toList()..sort();
    final displaySlots = sortedHours.map((h) => hourToBestSlot[h]!).toList();
    final displayCount = displaySlots.length;

    // Trouver la position d'affichage correspondant a l'index selectionne
    int currentDisplayIndex = 0;
    final selectedHour = wind.selectedHourIndex < slots.length
        ? slots[wind.selectedHourIndex].dateTime.hour
        : sortedHours.first;
    for (int i = 0; i < displayCount; i++) {
      if (sortedHours[i] == selectedHour) {
        currentDisplayIndex = i;
        break;
      }
    }

    final selectedSlot = wind.selectedHourIndex < slots.length
        ? slots[wind.selectedHourIndex]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
      decoration: BoxDecoration(
        color: tc.textPrimary.withValues(alpha: 0.032),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: windColor.withValues(alpha: 0.30),
          width: 0.65,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.air_rounded, color: windColor, size: 11),
              const SizedBox(width: 3),
              Text(
                'VENT',
                style: TextStyle(
                  color: windColor,
                  fontSize: 8,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.55,
                ),
              ),
              const Spacer(),
              Text(
                '${(vector.speedKt * 1.852).toStringAsFixed(1)} km/h',
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: windColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: windColor.withValues(alpha: 0.30),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  dirText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: windColor,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selectedSlot != null)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Text(
                    '${selectedSlot.dateTime.hour}h',
                    style: TextStyle(
                      color: windColor,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (displayCount > 1) ...[
            const SizedBox(height: 3),
            SizedBox(
              height: 14,
              child: Row(
                children: sortedHours.map((h) {
                  final isActive = h == selectedHour;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final slotIdx = hourToBestSlot[h]!;
                        wind.selectHourIndex(slotIdx);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          '${h}h',
                          maxLines: 1,
                          style: TextStyle(
                            color: isActive ? windColor : tc.textMuted,
                            fontSize: isActive ? 11 : 10.5,
                            height: 1,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: windColor,
                  inactiveTrackColor: tc.textPrimary.withValues(alpha: 0.10),
                  thumbColor: windColor,
                  overlayColor: windColor.withValues(alpha: 0.08),
                ),
                child: Slider(
                  value: currentDisplayIndex.toDouble(),
                  min: 0,
                  max: (displayCount - 1).toDouble(),
                  divisions: displayCount - 1,
                  onChanged: (v) {
                    final slotIdx = displaySlots[v.round()];
                    wind.selectHourIndex(slotIdx);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWindPlaceholder(
    BuildContext context, {
    required bool loading,
  }) {
    final tc = ThemeColors.of(context);
    return _DashboardSection(
      title: 'VENT',
      icon: Icons.air_rounded,
      accent: tc.warning,
      child: Center(
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: tc.oceanLight,
                ),
              )
            : Text(
                'Données indisponibles',
                textAlign: TextAlign.center,
                style: TextStyle(color: tc.textMuted, fontSize: 9.5),
              ),
      ),
    );
  }

  bool _isCloserSpot(Spot nearbySpot) {
    if (currentPosition == null) return false;
    const distance = Distance();
    final currentLatLng =
        LatLng(currentPosition!.latitude, currentPosition!.longitude);
    final distCurrent = distance.as(LengthUnit.Kilometer, currentLatLng,
        LatLng(spot.latitude, spot.longitude));
    final distNearby = distance.as(LengthUnit.Kilometer, currentLatLng,
        LatLng(nearbySpot.latitude, nearbySpot.longitude));
    return distNearby < distCurrent;
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.spot, required this.dense});

  final Spot spot;
  final bool dense;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _isSaving = false;

  Future<void> _toggle({required bool isFavorite}) async {
    if (_isSaving) return;
    final auth = context.read<AuthService>();
    if (auth.uid == null) {
      final shouldSignIn = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.tr('mySpots.signInTitle')),
              content: Text(context.tr('mySpots.favoriteSignIn')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.tr('common.cancel')),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(context.tr('settings.signInGoogle')),
                ),
              ],
            ),
          ) ??
          false;
      if (!shouldSignIn || !mounted) return;
      final signedIn = await auth.signInWithGoogle();
      if (!signedIn || !mounted) return;
    }

    setState(() => _isSaving = true);
    try {
      if (isFavorite) {
        await FavoriteSpotService.instance.remove(widget.spot.id);
      } else {
        await FavoriteSpotService.instance.add(widget.spot);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                isFavorite
                    ? 'mySpots.favoriteRemoved'
                    : 'mySpots.favoriteAdded',
              ),
            ),
          ),
        );
      }
    } on FavoriteSpotException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                error.failure == FavoriteSpotFailure.limitReached
                    ? 'mySpots.favoriteLimitReached'
                    : 'mySpots.favoriteError',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.favoriteError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final uid = auth.uid;
        if (uid == null) {
          return _button(context, tc, isFavorite: false);
        }
        return StreamBuilder<bool>(
          stream:
              FavoriteSpotService.instance.watchIsFavorite(uid, widget.spot.id),
          builder: (context, snapshot) {
            return _button(
              context,
              tc,
              isFavorite: snapshot.data ?? false,
            );
          },
        );
      },
    );
  }

  Widget _button(
    BuildContext context,
    ThemeColors tc, {
    required bool isFavorite,
  }) {
    final size = widget.dense ? 28.0 : 31.0;
    return Tooltip(
      message: context.tr(
        isFavorite ? 'mySpots.removeFavorite' : 'mySpots.addFavorite',
      ),
      child: Material(
        color: tc.textPrimary.withValues(alpha: 0.055),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _isSaving ? null : () => _toggle(isFavorite: isFavorite),
          child: SizedBox.square(
            dimension: size,
            child: _isSaving
                ? Padding(
                    padding: const EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tc.oceanMedium,
                    ),
                  )
                : Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? tc.error : tc.textSecondary,
                    size: widget.dense ? 17 : 18,
                  ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  NEAREST FISHING SHOP — chargement unique et non bloquant
// ──────────────────────────────────────────────

class _NearestShopCard extends StatefulWidget {
  final Spot spot;

  const _NearestShopCard({
    super.key,
    required this.spot,
  });

  @override
  State<_NearestShopCard> createState() => _NearestShopCardState();
}

class _NearestShopCardState extends State<_NearestShopCard> {
  static Future<List<FishingShop>>? _sharedShops;

  late Future<FishingShop?> _nearestShop;

  @override
  void initState() {
    super.initState();
    _nearestShop = _findNearestShop();
  }

  Future<FishingShop?> _findNearestShop() async {
    final shops = await (_sharedShops ??= ShopService.loadShops());
    if (shops.isEmpty) return null;

    FishingShop nearest = shops.first;
    double nearestDistance = ShopService.distanceBetween(widget.spot, nearest);
    for (final shop in shops.skip(1)) {
      final shopDistance = ShopService.distanceBetween(widget.spot, shop);
      if (shopDistance < nearestDistance) {
        nearest = shop;
        nearestDistance = shopDistance;
      }
    }
    return nearest;
  }

  Future<void> _openDirections(FishingShop shop) async {
    final destination = '${shop.latitude},${shop.longitude}';
    final nativeUri = Uri.parse('geo:$destination?q=$destination');
    try {
      if (await launchUrl(
        nativeUri,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Le lien web ci-dessous reste disponible si aucun gestionnaire geo.
    }
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$destination',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return FutureBuilder<FishingShop?>(
      future: _nearestShop,
      builder: (context, snapshot) {
        final shop = snapshot.data;

        return Semantics(
          button: shop != null,
          label: shop == null
              ? 'Recherche du magasin de pêche le plus proche'
              : 'Magasin de pêche le plus proche : ${shop.name}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: shop == null ? null : () => _openDirections(shop),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 112,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: tc.warning.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: tc.warning.withValues(alpha: 0.34),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: tc.warning.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: tc.warning,
                        size: 11,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? Text(
                              'Magasin proche…',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tc.textSecondary,
                                fontSize: 8.5,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : shop == null
                              ? Text(
                                  'Aucun magasin',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tc.textMuted,
                                    fontSize: 8.5,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MAGASIN · ${shop.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tc.textPrimary,
                                        fontSize: 9,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${ShopService.distanceBetween(widget.spot, shop).toStringAsFixed(1)} km',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tc.warning,
                                        fontSize: 8.5,
                                        height: 1,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                    if (shop != null)
                      Icon(
                        Icons.near_me_rounded,
                        color: tc.warning,
                        size: 11,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

    return Semantics(
      button: true,
      label: '${spot.name}, $distance',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 94,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: tc.textPrimary.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: spotColor.withValues(alpha: 0.32),
                width: 0.7,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: spotColor.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: spotColor.withValues(alpha: 0.30),
                      width: 0.6,
                    ),
                  ),
                  child: Icon(
                    isCloser ? Icons.near_me_rounded : Icons.place_outlined,
                    color: isCloser ? tc.success : spotColor,
                    size: 11,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tc.textPrimary,
                          fontSize: 9,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        distance,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCloser ? tc.success : tc.textMuted,
                          fontSize: 8.5,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tc.textMuted,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DashboardTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.32),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: icon == Icons.circle ? 5 : 9),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _DashboardSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
      decoration: BoxDecoration(
        color: tc.textPrimary.withValues(alpha: 0.032),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
          width: 0.65,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 10),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(child: child),
        ],
      ),
    );
  }
}
