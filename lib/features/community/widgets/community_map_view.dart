import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/features/community/models/community_catch.dart';
import 'package:spots_app/features/community/services/community_repository.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_tile_layer.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';
import 'package:spots_app/widgets/finite_marker_layer.dart';
import 'package:spots_app/widgets/location_access_feedback.dart';

const _likedHeartColor = Color(0xFF1877F2);

class CommunityMapView extends StatefulWidget {
  const CommunityMapView({super.key});

  @override
  State<CommunityMapView> createState() => _CommunityMapViewState();
}

class _CommunityMapViewState extends State<CommunityMapView> {
  final _repository = CommunityRepository.instance;
  final _mapController = MapController();
  late final Stream<List<CommunityCatch>> _catchesStream;
  late final Stream<WeeklyCommunityWinner?> _winnerStream;
  late Stream<Set<String>> _likesStream;
  late Stream<List<CommunityBlockedUser>> _blockedUsersStream;
  StreamSubscription<User?>? _authSubscription;
  String? _likesOwnerUid;
  String? _selectedId;
  int _zoomBand = 5;
  bool _winnerExpanded = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _catchesStream = _repository.watchActiveCatches();
    _winnerStream = _repository.watchWeeklyWinner();
    _likesOwnerUid = FirebaseAuth.instance.currentUser?.uid;
    _likesStream = _repository.watchMyLikes();
    _blockedUsersStream = _repository.watchBlockedUsers();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        if (!mounted || user?.uid == _likesOwnerUid) return;
        setState(() {
          _likesOwnerUid = user?.uid;
          _likesStream = _repository.watchMyLikes();
          _blockedUsersStream = _repository.watchBlockedUsers();
        });
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    return StreamBuilder<List<CommunityCatch>>(
      stream: _catchesStream,
      builder: (context, catchSnapshot) {
        return StreamBuilder<List<CommunityBlockedUser>>(
          stream: _blockedUsersStream,
          builder: (context, blockedSnapshot) {
            final blockedIds =
                (blockedSnapshot.data ?? const <CommunityBlockedUser>[])
                    .map((item) => item.uid)
                    .toSet();
            final catches = (catchSnapshot.data ?? const <CommunityCatch>[])
                .where((item) => !blockedIds.contains(item.ownerUid))
                .toList(growable: false);
            final selected = _selectedCatch(catches);
            return StreamBuilder<Set<String>>(
              stream: _likesStream,
              builder: (context, likesSnapshot) {
                final likes = likesSnapshot.data ?? const <String>{};
                return Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(30.5, -9.7),
                          initialZoom: 5.2,
                          minZoom: 3,
                          maxZoom: 17,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.drag |
                                InteractiveFlag.flingAnimation |
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.doubleTapZoom |
                                InteractiveFlag.doubleTapDragZoom,
                          ),
                          onTap: (_, __) => _clearSelection(),
                          onPositionChanged: (camera, _) {
                            final next = camera.zoom.floor();
                            if (next != _zoomBand && mounted) {
                              setState(() => _zoomBand = next);
                            }
                          },
                        ),
                        children: [
                          const AppTileLayer(style: MapStyle.satellite),
                          if (palette.isDark)
                            IgnorePointer(
                              child: ColoredBox(
                                color: const Color(0xFF001329)
                                    .withValues(alpha: 0.34),
                              ),
                            ),
                          AppMapAttribution(style: MapStyle.satellite),
                          FiniteMarkerLayer(
                            markers: _markers(catches, selected, palette),
                          ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      start: 12,
                      child: _ApproximateZonePill(palette: palette),
                    ),
                    PositionedDirectional(
                      top: 8,
                      end: 10,
                      child: Column(
                        children: [
                          _MapCircleButton(
                            tooltip: context.tr('community.centerOnMe'),
                            icon: _locating
                                ? Icons.hourglass_top_rounded
                                : Icons.my_location_rounded,
                            palette: palette,
                            onTap: _locating ? null : _centerOnUser,
                          ),
                          const SizedBox(height: 8),
                          _MapCircleButton(
                            tooltip: context.tr('community.fitCatches'),
                            icon: Icons.center_focus_strong_rounded,
                            palette: palette,
                            onTap: catches.isEmpty ? null : () => _fit(catches),
                          ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      top: 58,
                      start: 12,
                      end: 74,
                      child: StreamBuilder<WeeklyCommunityWinner?>(
                        stream: _winnerStream,
                        builder: (context, snapshot) {
                          final winner = snapshot.data;
                          if (winner == null) return const SizedBox.shrink();
                          return _WeeklyWinnerBanner(
                            winner: winner,
                            expanded: _winnerExpanded,
                            palette: palette,
                            onToggle: () => setState(
                              () => _winnerExpanded = !_winnerExpanded,
                            ),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _CatchShelf(
                        catches: catches,
                        selected: selected,
                        likedIds: likes,
                        loading: catchSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !catchSnapshot.hasData,
                        error: catchSnapshot.hasError,
                        palette: palette,
                        onSelect: _select,
                        onOpen: (item) => _openDetails(
                          item,
                          likes.contains(item.id),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  CommunityCatch? _selectedCatch(List<CommunityCatch> catches) {
    final id = _selectedId;
    if (id == null) return null;
    for (final item in catches) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<Marker> _markers(
    List<CommunityCatch> catches,
    CommunityCatch? selected,
    BoosterFishPagePalette palette,
  ) {
    return [
      for (final group in _cluster(catches, _zoomBand))
        Marker(
          point: group.point,
          width: group.items.length == 1 ? 64 : 58,
          height: group.items.length == 1 ? 72 : 58,
          alignment: Alignment.topCenter,
          child: group.items.length == 1
              ? _CatchMapMarker(
                  item: group.items.single,
                  selected: selected?.id == group.items.single.id,
                  palette: palette,
                  onTap: () => _select(group.items.single),
                )
              : _CatchClusterMarker(
                  count: group.items.length,
                  palette: palette,
                  onTap: () {
                    _mapController.move(
                      group.point,
                      math.min(17, _mapController.camera.zoom + 2),
                    );
                  },
                ),
        ),
    ];
  }

  List<_CatchCluster> _cluster(List<CommunityCatch> catches, int zoomBand) {
    final cellSize = switch (zoomBand) {
      <= 4 => 3.0,
      5 => 1.5,
      6 => 0.7,
      7 => 0.32,
      8 => 0.15,
      9 => 0.075,
      _ => 0.001,
    };
    final grouped = <String, List<CommunityCatch>>{};
    for (final item in catches) {
      final key =
          '${(item.latitude / cellSize).floor()}:${(item.longitude / cellSize).floor()}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped.values.map((items) {
      final latitude =
          items.fold<double>(0, (sum, item) => sum + item.latitude) /
              items.length;
      final longitude =
          items.fold<double>(0, (sum, item) => sum + item.longitude) /
              items.length;
      return _CatchCluster(
        point: LatLng(latitude, longitude),
        items: items,
      );
    }).toList(growable: false);
  }

  void _clearSelection() {
    if (_selectedId == null) return;
    setState(() => _selectedId = null);
  }

  void _select(CommunityCatch item) {
    setState(() => _selectedId = item.id);
    _mapController.move(
      LatLng(item.latitude, item.longitude),
      math.max(9, _mapController.camera.zoom),
    );
  }

  void _fit(List<CommunityCatch> catches) {
    if (catches.length == 1) {
      _mapController.move(
        LatLng(catches.single.latitude, catches.single.longitude),
        10,
      );
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          for (final item in catches) LatLng(item.latitude, item.longitude),
        ],
        padding: const EdgeInsets.fromLTRB(42, 92, 42, 260),
        maxZoom: 12,
      ),
    );
  }

  Future<void> _centerOnUser() async {
    setState(() => _locating = true);
    try {
      if (!await ensureLocationAccess(context)) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        10.5,
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openDetails(CommunityCatch item, bool liked) async {
    final blockedUid = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatchDetailsSheet(
        item: item,
        initiallyLiked: liked,
        repository: _repository,
      ),
    );
    if (!mounted || blockedUid == null) return;
    setState(() {
      if (_selectedId == item.id) _selectedId = null;
    });
  }
}

class _CatchCluster {
  const _CatchCluster({required this.point, required this.items});

  final LatLng point;
  final List<CommunityCatch> items;
}

class _ApproximateZonePill extends StatelessWidget {
  const _ApproximateZonePill({required this.palette});

  final BoosterFishPagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.navy.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: Color(0xFF58E5FF),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            context.tr('community.approximateZones'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.tooltip,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final BoosterFishPagePalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.navy.withValues(alpha: 0.9),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        color: const Color(0xFF58E5FF),
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _CatchMapMarker extends StatelessWidget {
  const _CatchMapMarker({
    required this.item,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final CommunityCatch item;
  final bool selected;
  final BoosterFishPagePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 52 : 44,
            height: selected ? 52 : 44,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? palette.accent : Colors.white,
              border: Border.all(
                color: selected ? Colors.white : palette.accent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: item.photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: palette.navy,
                  child: const Icon(
                    Icons.set_meal_rounded,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: palette.navy,
                  child: const Icon(
                    Icons.set_meal_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 3,
            height: 9,
            color: selected ? palette.accent : Colors.white,
          ),
        ],
      ),
    );
  }
}

class _CatchClusterMarker extends StatelessWidget {
  const _CatchClusterMarker({
    required this.count,
    required this.palette,
    required this.onTap,
  });

  final int count;
  final BoosterFishPagePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [palette.accent, const Color(0xFF0757B8)],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.set_meal_rounded, size: 16, color: Colors.white),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyWinnerBanner extends StatelessWidget {
  const _WeeklyWinnerBanner({
    required this.winner,
    required this.expanded,
    required this.palette,
    required this.onToggle,
  });

  final WeeklyCommunityWinner winner;
  final bool expanded;
  final BoosterFishPagePalette palette;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.navy.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          height: expanded ? 72 : 42,
          child: Row(
            children: [
              Container(
                width: expanded ? 54 : 28,
                height: expanded ? 54 : 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.gold, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: winner.photoUrl,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 9),
              Icon(
                Icons.emoji_events_rounded,
                color: palette.gold,
                size: expanded ? 24 : 19,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: expanded
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('community.weeklyWinner'),
                            style: TextStyle(
                              color: palette.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            winner.anglerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${winner.species} • ${_formatWeight(winner.weightKg)} kg • ${winner.likeCount} ♥',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '${context.tr('community.weeklyWinner')} • ${winner.anglerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatchShelf extends StatelessWidget {
  const _CatchShelf({
    required this.catches,
    required this.selected,
    required this.likedIds,
    required this.loading,
    required this.error,
    required this.palette,
    required this.onSelect,
    required this.onOpen,
  });

  final List<CommunityCatch> catches;
  final CommunityCatch? selected;
  final Set<String> likedIds;
  final bool loading;
  final bool error;
  final BoosterFishPagePalette palette;
  final ValueChanged<CommunityCatch> onSelect;
  final ValueChanged<CommunityCatch> onOpen;

  @override
  Widget build(BuildContext context) {
    final ordered = [
      if (selected != null) selected!,
      for (final item in catches)
        if (item.id != selected?.id) item,
    ];
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(
      284.0,
      math.max(240.0, viewportWidth * 0.74),
    );
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.isDark ? 0.97 : 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
        border: Border(
          top: BorderSide(color: palette.borderStrong),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: palette.textMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('community.catchesNearMe'),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(Icons.public_rounded, size: 17, color: palette.accent),
                const SizedBox(width: 5),
                Text(
                  '${catches.length}',
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error
                    ? _ShelfMessage(
                        icon: Icons.cloud_off_rounded,
                        text: context.tr('community.feedUnavailable'),
                        palette: palette,
                      )
                    : ordered.isEmpty
                        ? _ShelfMessage(
                            icon: Icons.set_meal_outlined,
                            text: context.tr('community.noPublicCatches'),
                            palette: palette,
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            itemCount: ordered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final item = ordered[index];
                              return _PublicCatchCard(
                                item: item,
                                selected: selected?.id == item.id,
                                liked: likedIds.contains(item.id),
                                palette: palette,
                                width: cardWidth,
                                onTap: () {
                                  onSelect(item);
                                  onOpen(item);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ShelfMessage extends StatelessWidget {
  const _ShelfMessage({
    required this.icon,
    required this.text,
    required this.palette,
  });

  final IconData icon;
  final String text;
  final BoosterFishPagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.textMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicCatchCard extends StatelessWidget {
  const _PublicCatchCard({
    required this.item,
    required this.selected,
    required this.liked,
    required this.palette,
    required this.width,
    required this.onTap,
  });

  final CommunityCatch item;
  final bool selected;
  final bool liked;
  final BoosterFishPagePalette palette;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? palette.accent : palette.divider,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? palette.accent.withValues(alpha: 0.16)
                    : palette.shadowColor,
                blurRadius: selected ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: item.photoUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(
                    color: palette.oceanDeep,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          color: palette.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: palette.oceanDeep,
                    child: Center(
                      child: Icon(
                        Icons.set_meal_rounded,
                        color: palette.accent,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: 62,
                padding: const EdgeInsets.fromLTRB(10, 7, 11, 7),
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  border: Border(
                    top: BorderSide(color: palette.divider),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: palette.oceanDeep,
                      foregroundImage: item.avatarUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(item.avatarUrl),
                      child: item.avatarUrl.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              color: palette.accent,
                              size: 17,
                            )
                          : null,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.anglerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.species,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_formatWeight(item.weightKg)} kg',
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color:
                                  liked ? _likedHeartColor : palette.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.likeCount}',
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatchDetailsSheet extends StatefulWidget {
  const _CatchDetailsSheet({
    required this.item,
    required this.initiallyLiked,
    required this.repository,
  });

  final CommunityCatch item;
  final bool initiallyLiked;
  final CommunityRepository repository;

  @override
  State<_CatchDetailsSheet> createState() => _CatchDetailsSheetState();
}

class _CatchDetailsSheetState extends State<_CatchDetailsSheet> {
  late bool _liked = widget.initiallyLiked;
  late int _likeCount = widget.item.likeCount;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = BoosterFishPagePalette.of(context);
    final item = widget.item;
    final likeColor = _liked ? _likedHeartColor : palette.textMuted;
    final compactActionStyle = OutlinedButton.styleFrom(
      foregroundColor: palette.textSecondary,
      backgroundColor: palette.surfaceElevated.withValues(
        alpha: palette.isDark ? 0.72 : 0.9,
      ),
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: palette.divider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      ),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CachedNetworkImage(
                    imageUrl: item.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        ColoredBox(color: palette.surfaceElevated),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: palette.surfaceElevated,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: palette.oceanDeep,
                    foregroundImage: item.avatarUrl.isEmpty
                        ? null
                        : CachedNetworkImageProvider(item.avatarUrl),
                    child: item.avatarUrl.isEmpty
                        ? Icon(Icons.person_rounded, color: palette.accent)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.anglerName,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${item.species} • ${_formatWeight(item.weightKg)} kg',
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('community.like'),
                    onPressed: _busy ? null : _toggleLike,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(38),
                      maximumSize: const Size.square(38),
                      padding: EdgeInsets.zero,
                      backgroundColor: likeColor.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: likeColor.withValues(alpha: 0.26),
                      ),
                    ),
                    icon: Icon(
                      _liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: likeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      color: likeColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailRow(
                icon: Icons.shield_outlined,
                label: context.tr('community.approximateZone'),
                value: item.zoneName,
                palette: palette,
              ),
              if (item.montage.isNotEmpty)
                _DetailRow(
                  icon: Icons.device_hub_rounded,
                  label: context.tr('community.rig'),
                  value: item.montage,
                  palette: palette,
                ),
              if (item.bait.isNotEmpty)
                _DetailRow(
                  icon: Icons.grass_rounded,
                  label: context.tr('community.bait'),
                  value: item.bait,
                  palette: palette,
                ),
              if (item.notes.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: context.tr('community.notes'),
                  value: item.notes,
                  palette: palette,
                ),
              if (item.advice.isNotEmpty)
                _DetailRow(
                  icon: Icons.lightbulb_outline_rounded,
                  label: context.tr('community.advice'),
                  value: item.advice,
                  palette: palette,
                ),
              const SizedBox(height: 14),
              if (FirebaseAuth.instance.currentUser?.uid != item.ownerUid)
                SizedBox(
                  height: 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _report,
                          style: compactActionStyle,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                size: 15,
                                color: palette.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('community.reportPost'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _block,
                          style: compactActionStyle,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 15,
                                color: palette.error.withValues(alpha: 0.82),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('community.blockUser'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _busy ? null : _removeOwnPublication,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.error,
                    side: BorderSide(
                      color: palette.error.withValues(alpha: 0.7),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(context.tr('community.removePublication')),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleLike() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _message('community.signInRequired');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.toggleLike(widget.item);
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount = math.max(0, _likeCount + (_liked ? 1 : -1));
      });
    } on CommunityException catch (error) {
      _message(
        error.failure == CommunityFailure.ownPostLike
            ? 'community.ownPostLike'
            : 'community.actionFailed',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('community.reportPost')),
        children: [
          for (final reason in const [
            'child_safety',
            'false_catch',
            'inappropriate',
            'privacy',
            'other',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, reason),
              child: Text(context.tr('community.reportReason.$reason')),
            ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.reportPost(item: widget.item, reason: reason);
      _message('community.reportSent');
    } catch (_) {
      _message('community.actionFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('community.blockUser')),
        content: Text(context.tr('community.blockUserConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('community.block')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.repository.blockUser(
        blockedUid: widget.item.ownerUid,
        blockedDisplayName: widget.item.anglerName,
      );
      if (mounted) Navigator.pop(context, widget.item.ownerUid);
    } catch (_) {
      _message('community.actionFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeOwnPublication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('community.removePublication')),
        content: Text(context.tr('community.removePublicationConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: BoosterFishPagePalette.of(context).error,
            ),
            child: Text(context.tr('community.remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.repository.removeOwnPublication(widget.item);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('community.publicationRemoved'))),
      );
    } on CommunityException {
      _message('community.actionFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(key))),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final String value;
  final BoosterFishPagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: palette.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatWeight(double value) {
  return value.toStringAsFixed(value < 10 ? 2 : 1).replaceFirst(
        RegExp(r'\.?0+$'),
        '',
      );
}
