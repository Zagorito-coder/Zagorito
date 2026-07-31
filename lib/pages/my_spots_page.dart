import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/models/user_spot.dart';
import 'package:spots_app/services/auth_service.dart';
import 'package:spots_app/services/favorite_spot_service.dart';
import 'package:spots_app/services/user_spot_service.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/app_tile_layer.dart';
import 'package:spots_app/widgets/authenticated_spot_photo.dart';
import 'package:spots_app/widgets/finite_map_controller.dart';
import 'package:spots_app/widgets/finite_marker_layer.dart';
import 'package:spots_app/widgets/personal_spots_map_layer.dart';
import 'package:spots_app/widgets/user_spot_form_sheet.dart';

class MySpotsPage extends StatelessWidget {
  const MySpotsPage({
    super.key,
    required this.onAddSpot,
    required this.onOpenFavorite,
    required this.onOpenPersonal,
  });

  final VoidCallback onAddSpot;
  final ValueChanged<Spot> onOpenFavorite;
  final ValueChanged<UserSpot> onOpenPersonal;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final palette = _ShelfPalette.of(context);
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: palette.background,
            surfaceTintColor: Colors.transparent,
            title: Text(
              context.tr('mySpots.title'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
          ),
          body: Consumer<AuthService>(
            builder: (context, auth, _) {
              final uid = auth.uid;
              if (uid == null) return _SignInView(auth: auth);
              return StreamBuilder<List<Spot>>(
                stream: FavoriteSpotService.instance.watchFavorites(uid),
                builder: (context, favoriteSnapshot) {
                  return StreamBuilder<List<UserSpot>>(
                    stream: UserSpotService.instance.watchUserSpots(uid),
                    builder: (context, personalSnapshot) {
                      if (favoriteSnapshot.hasError ||
                          personalSnapshot.hasError) {
                        return const _ErrorView();
                      }
                      if (!favoriteSnapshot.hasData ||
                          !personalSnapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: palette.accent,
                          ),
                        );
                      }
                      return _MapShelf(
                        favorites: favoriteSnapshot.data!,
                        personal: personalSnapshot.data!,
                        onAddSpot: onAddSpot,
                        onOpenFavorite: onOpenFavorite,
                        onOpenPersonal: onOpenPersonal,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

enum _ShelfMode { favorites, personal }

class _MapShelf extends StatefulWidget {
  const _MapShelf({
    required this.favorites,
    required this.personal,
    required this.onAddSpot,
    required this.onOpenFavorite,
    required this.onOpenPersonal,
  });

  final List<Spot> favorites;
  final List<UserSpot> personal;
  final VoidCallback onAddSpot;
  final ValueChanged<Spot> onOpenFavorite;
  final ValueChanged<UserSpot> onOpenPersonal;

  @override
  State<_MapShelf> createState() => _MapShelfState();
}

class _MapShelfState extends State<_MapShelf> {
  final MapController _previewController = FiniteMapController();
  _ShelfMode _mode = _ShelfMode.personal;
  String? _selectedSpotId;
  bool _mapReady = false;

  List<LatLng> get _activePoints => _mode == _ShelfMode.personal
      ? [
          for (final spot in widget.personal)
            if (_isValid(spot.latitude, spot.longitude))
              LatLng(spot.latitude, spot.longitude),
        ]
      : [
          for (final spot in widget.favorites)
            if (_isValid(spot.latitude, spot.longitude))
              LatLng(spot.latitude, spot.longitude),
        ];

  static bool _isValid(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  @override
  void didUpdateWidget(covariant _MapShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePersonal(oldWidget.personal, widget.personal) ||
        !_sameFavorites(oldWidget.favorites, widget.favorites)) {
      if (_selectedSpotId != null && !_selectionStillExists()) {
        _selectedSpotId = null;
      }
      _scheduleFit();
    }
  }

  bool _selectionStillExists() => _mode == _ShelfMode.personal
      ? widget.personal.any((spot) => spot.id == _selectedSpotId)
      : widget.favorites.any((spot) => spot.id == _selectedSpotId);

  bool _samePersonal(List<UserSpot> a, List<UserSpot> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i].id == b[i].id).every((same) => same);

  bool _sameFavorites(List<Spot> a, List<Spot> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i].id == b[i].id).every((same) => same);

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  void _selectMode(_ShelfMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _selectedSpotId = null;
    });
    _scheduleFit();
  }

  void _selectSpot(String spotId) {
    setState(() => _selectedSpotId = spotId);
  }

  void _clearSelection() {
    if (_selectedSpotId == null) return;
    setState(() => _selectedSpotId = null);
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitActivePoints();
    });
  }

  void _fitActivePoints() {
    if (!_mapReady) return;
    final points = _activePoints;
    if (points.isEmpty) {
      _previewController.move(const LatLng(30.5, -9.7), 5.2);
      return;
    }
    if (points.length == 1) {
      _previewController.move(points.first, 12);
      return;
    }
    _previewController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(46, 58, 46, 54),
        maxZoom: 11.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    final count = _mode == _ShelfMode.personal
        ? widget.personal.length
        : widget.favorites.length;
    final maximum = _mode == _ShelfMode.personal
        ? UserSpot.maximumPersonalSpots
        : FavoriteSpotService.maximumFavorites;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight =
            (constraints.maxHeight * 0.43).clamp(225.0, 380.0).toDouble();
        final shelfTop = _selectedSpotId == null
            ? mapHeight - 22
            : (mapHeight - 92).clamp(130.0, mapHeight - 22).toDouble();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeSelector(
                      mode: _mode,
                      onChanged: _selectMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    key: const ValueKey<String>('my-spots-capacity'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: palette.borderStrong),
                    ),
                    child: Text(
                      '$count/$maximum',
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: mapHeight,
                    child: _buildPreviewMap(palette),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    top: shelfTop,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CollectionShelf(
                      mode: _mode,
                      favorites: widget.favorites,
                      personal: widget.personal,
                      onAddSpot: widget.onAddSpot,
                      onOpenFavorite: widget.onOpenFavorite,
                      onOpenPersonal: widget.onOpenPersonal,
                      selectedSpotId: _selectedSpotId,
                      onSelectSpot: _selectSpot,
                      onClearSelection: _clearSelection,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewMap(_ShelfPalette palette) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _previewController,
            options: MapOptions(
              initialCenter: const LatLng(30.5, -9.7),
              initialZoom: 5.2,
              minZoom: 3,
              maxZoom: 16,
              onTap: (_, __) => _clearSelection(),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.doubleTapDragZoom,
              ),
              onMapReady: () {
                _mapReady = true;
                _scheduleFit();
              },
            ),
            children: [
              const AppTileLayer(style: MapStyle.satellite),
              if (palette.isDark)
                IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFF001329).withValues(alpha: 0.36),
                  ),
                ),
              AppMapAttribution(style: MapStyle.satellite),
              FiniteMarkerLayer(markers: _previewMarkers(palette)),
            ],
          ),
          Positioned(
            right: 14,
            bottom: 31,
            child: Material(
              color: palette.surface.withValues(alpha: 0.96),
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: palette.shadow,
              child: IconButton(
                key: const ValueKey<String>('fit-my-spots-preview'),
                tooltip: context.tr('mySpots.fitAll'),
                onPressed: _fitActivePoints,
                icon: Icon(Icons.my_location_rounded, color: palette.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _previewMarkers(_ShelfPalette palette) {
    if (_mode == _ShelfMode.personal) {
      return [
        for (final spot in widget.personal)
          if (_isValid(spot.latitude, spot.longitude))
            Marker(
              width: 116,
              height: 58,
              point: LatLng(spot.latitude, spot.longitude),
              alignment: Alignment.topCenter,
              child: _ShelfMapMarker(
                name: spot.name,
                privateSpot: true,
                palette: palette,
                onTap: () => _selectSpot(spot.id),
              ),
            ),
      ];
    }
    return [
      for (final spot in widget.favorites)
        if (_isValid(spot.latitude, spot.longitude))
          Marker(
            width: 116,
            height: 58,
            point: LatLng(spot.latitude, spot.longitude),
            alignment: Alignment.topCenter,
            child: _ShelfMapMarker(
              name: spot.name,
              privateSpot: false,
              palette: palette,
              onTap: () => _selectSpot(spot.id),
            ),
          ),
    ];
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _ShelfMode mode;
  final ValueChanged<_ShelfMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _segment(
            context,
            label: context.tr('mySpots.favoritesTab'),
            selected: mode == _ShelfMode.favorites,
            onTap: () => onChanged(_ShelfMode.favorites),
          ),
          _segment(
            context,
            label: context.tr('mySpots.personalTab'),
            selected: mode == _ShelfMode.personal,
            onTap: () => onChanged(_ShelfMode.personal),
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = _ShelfPalette.of(context);
    return Expanded(
      child: Material(
        color: selected ? palette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? (palette.isDark ? const Color(0xFF001523) : Colors.white)
                    : palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfMapMarker extends StatelessWidget {
  const _ShelfMapMarker({
    required this.name,
    required this.privateSpot,
    required this.palette,
    required this.onTap,
  });

  final String name;
  final bool privateSpot;
  final _ShelfPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markerAccent = privateSpot ? personalSpotMarkerNavy : palette.accent;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: markerAccent),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  privateSpot ? Icons.lock_rounded : Icons.favorite_rounded,
                  color: markerAccent,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.location_on_rounded,
            color: markerAccent,
            size: 31,
            shadows: [Shadow(color: palette.shadow, blurRadius: 5)],
          ),
        ],
      ),
    );
  }
}

class _CollectionShelf extends StatelessWidget {
  const _CollectionShelf({
    required this.mode,
    required this.favorites,
    required this.personal,
    required this.onAddSpot,
    required this.onOpenFavorite,
    required this.onOpenPersonal,
    required this.selectedSpotId,
    required this.onSelectSpot,
    required this.onClearSelection,
  });

  final _ShelfMode mode;
  final List<Spot> favorites;
  final List<UserSpot> personal;
  final VoidCallback onAddSpot;
  final ValueChanged<Spot> onOpenFavorite;
  final ValueChanged<UserSpot> onOpenPersonal;
  final String? selectedSpotId;
  final ValueChanged<String> onSelectSpot;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    final isPersonal = mode == _ShelfMode.personal;
    final isEmpty = isPersonal ? personal.isEmpty : favorites.isEmpty;
    final atLimit =
        isPersonal && personal.length >= UserSpot.maximumPersonalSpots;
    final selectedPersonal = isPersonal
        ? personal.where((spot) => spot.id == selectedSpotId).firstOrNull
        : null;
    final selectedFavorite = !isPersonal
        ? favorites.where((spot) => spot.id == selectedSpotId).firstOrNull
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClearSelection,
      child: Container(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(27),
            topRight: Radius.circular(27),
          ),
          border: Border(
            top: BorderSide(color: palette.borderStrong, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 22,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.borderStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  isPersonal
                      ? 'mySpots.personalTitle'
                      : 'mySpots.favoritesTitle',
                ),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    isPersonal
                        ? Icons.lock_outline_rounded
                        : Icons.favorite_border_rounded,
                    size: 14,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr(
                        isPersonal
                            ? 'mySpots.coordinatesPrivate'
                            : 'mySpots.favoriteShelfNotice',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: isEmpty
                    ? _ShelfEmptyState(
                        personal: isPersonal,
                        onAddSpot: onAddSpot,
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 112,
                            child: ListView.separated(
                              key: ValueKey<String>(
                                isPersonal
                                    ? 'personal-spots-shelf'
                                    : 'favorite-spots-shelf',
                              ),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: isPersonal
                                  ? personal.length
                                  : favorites.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                if (isPersonal) {
                                  final spot = personal[index];
                                  return _SpotPreviewTile(
                                    id: spot.id,
                                    name: spot.name,
                                    photoUrl: spot.photoUrl,
                                    selected: spot.id == selectedSpotId,
                                    onTap: () => onSelectSpot(spot.id),
                                    onOpenMap: () => onOpenPersonal(spot),
                                  );
                                }
                                final spot = favorites[index];
                                return _SpotPreviewTile(
                                  id: spot.id,
                                  name: spot.name,
                                  selected: spot.id == selectedSpotId,
                                  onTap: () => onSelectSpot(spot.id),
                                  onOpenMap: () => onOpenFavorite(spot),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 7),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: selectedPersonal != null
                                  ? _PersonalShelfCard(
                                      key: ValueKey<String>(
                                        'personal-details-${selectedPersonal.id}',
                                      ),
                                      spot: selectedPersonal,
                                      onOpen: () =>
                                          onOpenPersonal(selectedPersonal),
                                    )
                                  : selectedFavorite != null
                                      ? _FavoriteShelfCard(
                                          key: ValueKey<String>(
                                            'favorite-details-${selectedFavorite.id}',
                                          ),
                                          spot: selectedFavorite,
                                          onOpen: () =>
                                              onOpenFavorite(selectedFavorite),
                                        )
                                      : const _SelectionHint(),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 43,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('add-personal-spot-from-shelf'),
                  onPressed: atLimit ? null : onAddSpot,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.accent,
                    side: BorderSide(
                      color: atLimit
                          ? palette.border
                          : palette.accent.withValues(alpha: 0.78),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    atLimit
                        ? Icons.lock_rounded
                        : Icons.add_circle_outline_rounded,
                  ),
                  label: Text(
                    context.tr(
                      atLimit
                          ? 'mySpots.personalLimitReached'
                          : 'mySpots.addTitle',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotPreviewTile extends StatelessWidget {
  const _SpotPreviewTile({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.selected,
    required this.onTap,
    required this.onOpenMap,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Material(
      key: ValueKey<String>('select-shelf-spot-$id'),
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.accent : palette.borderStrong,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: palette.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SpotVisual(id: id, photoUrl: photoUrl),
                    const _PhotoScrim(),
                    if (selected)
                      Positioned(
                        left: 7,
                        top: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 39,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 9, right: 3),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                selected ? palette.accent : palette.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: context.tr('mySpots.openOnMap'),
                      child: InkWell(
                        key: ValueKey<String>('open-shelf-map-$id'),
                        onTap: onOpenMap,
                        borderRadius: BorderRadius.circular(11),
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Icon(
                            Icons.navigation_rounded,
                            color: palette.accent,
                            size: 18,
                          ),
                        ),
                      ),
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

class _SelectionHint extends StatelessWidget {
  const _SelectionHint();

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Center(
      child: Text(
        context.tr('mySpots.selectSpotHint'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonalShelfCard extends StatelessWidget {
  const _PersonalShelfCard({
    super.key,
    required this.spot,
    required this.onOpen,
  });

  final UserSpot spot;
  final VoidCallback onOpen;

  Future<void> _edit(BuildContext context) async {
    final updated = await showUserSpotFormSheet(
      context: context,
      latitude: spot.latitude,
      longitude: spot.longitude,
      existingSpot: spot,
      onSubmit: (draft) => UserSpotService.instance.updateSpot(spot, draft),
    );
    if (updated && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('mySpots.updated'))),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('mySpots.deleteTitle')),
            content: Text(context.tr('mySpots.deleteConfirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.tr('common.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.tr('common.delete')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await UserSpotService.instance.deleteSpot(spot);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.deleted'))),
        );
      }
    } on UserSpotException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.deleteError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        key: ValueKey<String>('personal-spot-popup-${spot.id}'),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: palette.borderStrong),
          boxShadow: palette.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 84,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SpotVisual(id: spot.id, photoUrl: spot.photoUrl),
                      const _PhotoScrim(),
                      Positioned(
                        left: 5,
                        top: 5,
                        child: _PrivateChip(palette: palette),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        radius: const Radius.circular(3),
                        thickness: 3,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 16,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${spot.latitude.toStringAsFixed(5)}, '
                                '${spot.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (spot.notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _DetailLine(
                                  icon: Icons.notes_rounded,
                                  text: spot.notes,
                                  color: palette.textSecondary,
                                ),
                              ],
                              if (spot.dangerNotes.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _DetailLine(
                                  icon: Icons.warning_amber_rounded,
                                  text: spot.dangerNotes,
                                  color: palette.error,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 9, color: palette.border),
                    SizedBox(
                      height: 38,
                      child: Row(
                        children: [
                          Expanded(
                            child: _CardAction(
                              key: ValueKey<String>(
                                'open-personal-map-${spot.id}',
                              ),
                              label: context.tr('mySpots.openOnMap'),
                              icon: Icons.navigation_rounded,
                              color: palette.accent,
                              onTap: onOpen,
                            ),
                          ),
                          Container(
                              width: 1, height: 17, color: palette.border),
                          SizedBox(
                            width: 42,
                            child: _CardAction(
                              key: ValueKey<String>(
                                'edit-personal-spot-${spot.id}',
                              ),
                              label: context.tr('common.edit'),
                              icon: Icons.edit_outlined,
                              color: palette.textSecondary,
                              onTap: () => _edit(context),
                              iconOnly: true,
                            ),
                          ),
                          Container(
                              width: 1, height: 17, color: palette.border),
                          SizedBox(
                            width: 42,
                            child: _CardAction(
                              key: ValueKey<String>(
                                'delete-personal-spot-${spot.id}',
                              ),
                              label: context.tr('common.delete'),
                              icon: Icons.delete_outline_rounded,
                              color: palette.error,
                              onTap: () => _delete(context),
                              iconOnly: true,
                            ),
                          ),
                        ],
                      ),
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

class _FavoriteShelfCard extends StatelessWidget {
  const _FavoriteShelfCard({
    super.key,
    required this.spot,
    required this.onOpen,
  });

  final Spot spot;
  final VoidCallback onOpen;

  Future<void> _remove(BuildContext context) async {
    try {
      await FavoriteSpotService.instance.remove(spot.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.favoriteRemoved'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('mySpots.favoriteError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Container(
      key: ValueKey<String>('favorite-spot-popup-${spot.id}'),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.borderStrong),
        boxShadow: palette.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 76,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SpotVisual(id: spot.id),
                    const _PhotoScrim(),
                    const Positioned(
                      left: 6,
                      top: 6,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF7F8A),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spot.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${spot.latitude.toStringAsFixed(5)}, '
                            '${spot.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (spot.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _DetailLine(
                              icon: Icons.notes_rounded,
                              text: spot.notes,
                              color: palette.textSecondary,
                            ),
                          ],
                          if (spot.fishTypes.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _DetailLine(
                              icon: Icons.set_meal_rounded,
                              text: spot.fishTypes.join(', '),
                              color: palette.textSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 5, color: palette.border),
                  SizedBox(
                    height: 27,
                    child: Row(
                      children: [
                        Expanded(
                          child: _CardAction(
                            key: ValueKey<String>(
                              'open-favorite-map-${spot.id}',
                            ),
                            label: context.tr('mySpots.openOnMap'),
                            icon: Icons.navigation_rounded,
                            color: palette.accent,
                            onTap: onOpen,
                          ),
                        ),
                        Container(width: 1, height: 17, color: palette.border),
                        SizedBox(
                          width: 48,
                          child: _CardAction(
                            key: ValueKey<String>(
                              'delete-favorite-spot-${spot.id}',
                            ),
                            label: context.tr('common.delete'),
                            tooltip: context.tr('mySpots.removeFavorite'),
                            icon: Icons.delete_outline_rounded,
                            color: palette.error,
                            onTap: () => _remove(context),
                            iconOnly: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotVisual extends StatelessWidget {
  const _SpotVisual({required this.id, this.photoUrl});

  final String id;
  final String? photoUrl;

  static const _fallbacks = [
    'assets/home_cards/tides_portrait_light.webp',
    'assets/home_cards/advanced_tides_portrait_light.webp',
    'assets/home_cards/fish_species_portrait_light.webp',
  ];

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      _fallbacks[id.hashCode.abs() % _fallbacks.length],
      fit: BoxFit.cover,
    );
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) return fallback;
    return AuthenticatedSpotPhoto(
      url: url,
      fit: BoxFit.cover,
      placeholder: fallback,
    );
  }
}

class _PhotoScrim extends StatelessWidget {
  const _PhotoScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x18000000), Color(0x52000000)],
        ),
      ),
    );
  }
}

class _PrivateChip extends StatelessWidget {
  const _PrivateChip({required this.palette});

  final _ShelfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: palette.accent, size: 10),
          const SizedBox(width: 3),
          Text(
            context.tr('mySpots.privateLabel'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    super.key,
    required this.label,
    this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconOnly = false,
  });

  final String label;
  final String? tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: iconOnly
              ? Center(child: Icon(icon, color: color, size: 20))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 17),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ShelfEmptyState extends StatelessWidget {
  const _ShelfEmptyState({
    required this.personal,
    required this.onAddSpot,
  });

  final bool personal;
  final VoidCallback onAddSpot;

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              personal
                  ? Icons.add_location_alt_outlined
                  : Icons.favorite_border_rounded,
              color: palette.accent,
              size: 34,
            ),
            const SizedBox(height: 7),
            Text(
              context.tr(
                personal ? 'mySpots.emptySubtitle' : 'mySpots.noFavorites',
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
            if (personal) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAddSpot,
                icon: const Icon(Icons.map_outlined),
                label: Text(context.tr('mySpots.chooseOnMap')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView({required this.auth});

  final AuthService auth;

  Future<void> _signIn(BuildContext context) async {
    final success = await auth.signInWithGoogle();
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('mySpots.signInError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: palette.accent),
              ),
              child: Icon(
                Icons.lock_person_outlined,
                color: palette.accent,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('mySpots.signInTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('mySpots.signInSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed:
                  kIsWeb || auth.isLoading ? null : () => _signIn(context),
              icon: auth.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(context.tr('settings.signInGoogle')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    final palette = _ShelfPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: palette.error, size: 48),
            const SizedBox(height: 12),
            Text(
              context.tr('mySpots.loadError'),
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfPalette {
  const _ShelfPalette(this.isDark);

  factory _ShelfPalette.of(BuildContext context) =>
      _ShelfPalette(ThemeController.instance.isDark);

  final bool isDark;

  Color get background =>
      isDark ? const Color(0xFF020817) : const Color(0xFFF7FAFE);
  Color get surface =>
      isDark ? const Color(0xFF07172C) : const Color(0xFFFFFFFF);
  Color get accent =>
      isDark ? const Color(0xFF19D7FF) : const Color(0xFF078FF0);
  Color get textPrimary =>
      isDark ? const Color(0xFFF4F8FF) : const Color(0xFF071A3F);
  Color get textSecondary =>
      isDark ? const Color(0xFFA8B9D2) : const Color(0xFF526786);
  Color get border =>
      isDark ? const Color(0xFF17395C) : const Color(0xFFD1E1F2);
  Color get borderStrong =>
      isDark ? const Color(0xFF3C8CBF) : const Color(0xFFB8D6F1);
  Color get shadow => isDark
      ? Colors.black.withValues(alpha: 0.36)
      : const Color(0xFF0C4F86).withValues(alpha: 0.12);
  Color get error => isDark ? const Color(0xFFFF7F8A) : const Color(0xFFCE3344);

  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: shadow,
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ];
}
