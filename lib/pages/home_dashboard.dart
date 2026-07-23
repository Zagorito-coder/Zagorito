// ============================================================
//  home_dashboard.dart — Présentation premium de l'accueil
//  Ce fichier ne charge aucune donnée et ne connaît aucun provider métier.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../models/tide_data.dart';
import '../theme_controller.dart';
import '../widgets/language_selector.dart';
import 'settings_page.dart';

class HomeDashboard extends StatefulWidget {
  final TideData tideData;
  final bool isLoading;
  final List<Spot> spots;
  final Future<void> Function() onRefresh;
  final VoidCallback? onNavigateToSpots;
  final VoidCallback? onNavigateToSpecies;
  final VoidCallback? onNavigateToTechniques;
  final VoidCallback? onNavigateToCommunity;
  final VoidCallback? onNavigateToShops;
  final VoidCallback? onNavigateToTides;
  final VoidCallback? onNavigateToTidesV2;

  const HomeDashboard({
    super.key,
    required this.tideData,
    required this.isLoading,
    required this.spots,
    required this.onRefresh,
    this.onNavigateToSpots,
    this.onNavigateToSpecies,
    this.onNavigateToTechniques,
    this.onNavigateToCommunity,
    this.onNavigateToShops,
    this.onNavigateToTides,
    this.onNavigateToTidesV2,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final palette = _HomePalette.of(context);
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.background,
          drawer: _HomeDrawer(
            onNavigateToSpots: widget.onNavigateToSpots,
            onNavigateToSpecies: widget.onNavigateToSpecies,
            onNavigateToTechniques: widget.onNavigateToTechniques,
            onNavigateToCommunity: widget.onNavigateToCommunity,
            onNavigateToShops: widget.onNavigateToShops,
            onNavigateToTides: widget.onNavigateToTides,
            onNavigateToTidesV2: widget.onNavigateToTidesV2,
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _OceanBackgroundPainter(palette),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final headerHeight = (height * 0.09).clamp(50.0, 60.0);
                    final heroHeight = (height * 0.36).clamp(190.0, 240.0);
                    final headingHeight = (height * 0.072).clamp(39.0, 49.0);

                    final cards = [
                      _ExpeditionCard(
                        title: context.tr('drawer.tides'),
                        subtitle: context.tr('home.tidesSubtitle'),
                        accent: palette.cyan,
                        motif: _ExpeditionMotif.tides,
                        onTap: widget.onNavigateToTides,
                      ),
                      _ExpeditionCard(
                        title: context.tr('drawer.tidesPro'),
                        subtitle: context.tr('home.tidesProSubtitle'),
                        accent: palette.blue,
                        motif: _ExpeditionMotif.forecast,
                        onTap: widget.onNavigateToTidesV2,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.fishSpecies'),
                        subtitle: context.tr('home.fishSpeciesSubtitle'),
                        accent: palette.cyan,
                        motif: _ExpeditionMotif.fish,
                        onTap: widget.onNavigateToSpecies,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.fishingTechniques'),
                        subtitle: context.tr('home.fishingTechniquesSubtitle'),
                        accent: palette.blue,
                        motif: _ExpeditionMotif.techniques,
                        onTap: widget.onNavigateToTechniques,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.community'),
                        subtitle: context.tr('home.communitySubtitle'),
                        accent: palette.cyan,
                        motif: _ExpeditionMotif.community,
                        onTap: widget.onNavigateToCommunity,
                      ),
                      _ExpeditionCard(
                        title: context.tr('home.tackleShops'),
                        subtitle: context.tr('home.tackleShopsSubtitle'),
                        accent: palette.blue,
                        motif: _ExpeditionMotif.shops,
                        onTap: widget.onNavigateToShops,
                      ),
                    ];

                    return RefreshIndicator(
                      color: palette.accent,
                      backgroundColor: palette.surface,
                      onRefresh: widget.onRefresh,
                      child: CustomScrollView(
                        key: const PageStorageKey<String>(
                          'premium-home-static',
                        ),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: height,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: headerHeight,
                                    child: _HomeHeader(
                                      onMenuTap: () => _scaffoldKey.currentState
                                          ?.openDrawer(),
                                    ),
                                  ),
                                  SizedBox(
                                    height: heroHeight,
                                    child: _ConditionsHero(
                                      height: heroHeight,
                                      tideData: widget.tideData,
                                      isLoading: widget.isLoading,
                                      spotsCount: widget.spots.length,
                                      onOpenMap: widget.onNavigateToSpots,
                                    ),
                                  ),
                                  SizedBox(
                                    height: headingHeight,
                                    child: _ExpeditionHeading(palette: palette),
                                  ),
                                  Expanded(
                                    child: _ExpeditionGrid(cards: cards),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const _HomeHeader({required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 5),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).openAppDrawerTooltip,
            child: _PremiumIconButton(
              icon: Icons.menu_rounded,
              onTap: onMenuTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.24),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.phishing_rounded,
                      color: palette.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.tr('home.appName'),
                      maxLines: 1,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        shadows: palette.isDark
                            ? [
                                Shadow(
                                  color: palette.accent.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: context.tr('home.member'),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.8),
                ),
                boxShadow: palette.glowShadow(0.17),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: palette.accent,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 62),
                    child: Text(
                      context.tr('home.memberShort'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PremiumIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.borderStrong),
            boxShadow: palette.softShadow,
          ),
          child: Icon(icon, color: palette.textPrimary, size: 25),
        ),
      ),
    );
  }
}

class _ConditionsHero extends StatelessWidget {
  final double height;
  final TideData tideData;
  final bool isLoading;
  final int spotsCount;
  final VoidCallback? onOpenMap;

  const _ConditionsHero({
    required this.height,
    required this.tideData,
    required this.isLoading,
    required this.spotsCount,
    required this.onOpenMap,
  });

  bool get _hasData => tideData.hourlyPoints.isNotEmpty;

  TidePoint? get _currentPoint {
    if (!_hasData) return null;
    final now = DateTime.now();
    return tideData.hourlyPoints.reduce(
      (a, b) =>
          a.time.difference(now).abs() <= b.time.difference(now).abs() ? a : b,
    );
  }

  String get _nextTime {
    if (!_hasData) return '--:--';
    final now = DateTime.now();
    final upcoming = tideData.hourlyPoints.where((p) => p.time.isAfter(now));
    final point =
        upcoming.isEmpty ? tideData.hourlyPoints.last : upcoming.first;
    return '${point.time.hour.toString().padLeft(2, '0')}:'
        '${point.time.minute.toString().padLeft(2, '0')}';
  }

  String get _windDirection {
    final degrees = _currentPoint?.windDirectionDeg;
    if (degrees == null) return '--';
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    return labels[((degrees % 360) / 45).round() % 8];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    final compactTextScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
    final current = _currentPoint;
    final activity =
        _hasData ? tideData.astro.fishActivity.clamp(0.0, 1.0) : 0.0;
    final activityValue = _hasData ? '${(activity * 100).round()}%' : '--';
    final tideValue = _hasData ? '${tideData.next.toStringAsFixed(1)} m' : '--';
    final windValue = current?.windSpeedKmh == null
        ? '--'
        : '${current!.windSpeedKmh!.round()} km/h';
    final waveValue =
        _hasData ? '${tideData.waveHeight.toStringAsFixed(1)} m' : '--';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.accent, width: 1.1),
            boxShadow: [
              ...palette.softShadow,
              if (palette.isDark) ...palette.glowShadow(0.22),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/home_hero_v3.webp',
                fit: BoxFit.cover,
                alignment: Alignment.centerLeft,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.44, 0.76, 1.0],
                    colors: palette.heroOverlay,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CircuitPainter(
                    palette.accent.withValues(
                      alpha: palette.isDark ? 0.14 : 0.11,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('home.greeting'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: compactTextScaler,
                              style: TextStyle(
                                color: palette.heroText,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.tr('home.prepareTrip'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: compactTextScaler,
                              style: TextStyle(
                                color: palette.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isLoading)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: palette.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: palette.heroPanel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.heroPanelBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroMetric(
                              icon: Icons.waves_rounded,
                              label: context.tr('home.tidesTitle'),
                              value: tideValue,
                              detail: _nextTime,
                            ),
                          ),
                          _HeroDivider(color: palette.heroPanelBorder),
                          Expanded(
                            child: _HeroMetric(
                              icon: Icons.air_rounded,
                              label: context.tr('home.wind'),
                              value: windValue,
                              detail: _windDirection,
                            ),
                          ),
                          _HeroDivider(color: palette.heroPanelBorder),
                          Expanded(
                            child: _HeroMetric(
                              icon: Icons.water_rounded,
                              label: context.tr('home.sea'),
                              value: waveValue,
                              detail: _hasData
                                  ? '${current?.wavePeriod.round() ?? 0} s'
                                  : '--',
                            ),
                          ),
                          _HeroDivider(color: palette.heroPanelBorder),
                          Expanded(
                            child: _ActivityGauge(
                              progress: activity,
                              value: activityValue,
                              label: context.tr('home.activity'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: palette.heroPanel,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: palette.heroPanelBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: palette.accent,
                            size: 21,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$spotsCount ${context.tr('drawer.spots')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: compactTextScaler,
                              style: TextStyle(
                                color: palette.heroText,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            button: true,
                            label: context.tr('home.openFullMap'),
                            child: OutlinedButton.icon(
                              onPressed: onOpenMap,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: Text(
                                context.tr('bottomNav.map'),
                                textScaler: compactTextScaler,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.accent,
                                side: BorderSide(color: palette.accent),
                                backgroundColor:
                                    palette.surface.withValues(alpha: 0.72),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: palette.accent, size: 13),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.heroText.withValues(alpha: 0.82),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: palette.heroText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.heroText.withValues(alpha: 0.72),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  final Color color;

  const _HeroDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 60, color: color);
  }
}

class _ActivityGauge extends StatelessWidget {
  final double progress;
  final String value;
  final String label;

  const _ActivityGauge({
    required this.progress,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: _GaugePainter(
          progress: progress,
          color: palette.accent,
          trackColor: palette.accent.withValues(alpha: 0.18),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.heroText.withValues(alpha: 0.76),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: palette.heroText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _GaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    const start = math.pi * 0.72;
    const sweep = math.pi * 1.56;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final active = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    canvas.drawArc(rect, start, sweep, false, track);
    if (progress > 0) {
      canvas.drawArc(rect, start, sweep * progress, false, active);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class _ExpeditionHeading extends StatelessWidget {
  final _HomePalette palette;

  const _ExpeditionHeading({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.72),
                  ),
                ),
                child: Icon(
                  Icons.explore_outlined,
                  color: palette.accent,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 225),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.tr('home.expeditionTitle'),
                    maxLines: 1,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.accent,
                        palette.accent.withValues(alpha: 0),
                      ],
                    ),
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

class _ExpeditionGrid extends StatelessWidget {
  final List<Widget> cards;

  const _ExpeditionGrid({required this.cards}) : assert(cards.length == 6);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        children: [
          for (var row = 0; row < 3; row++) ...[
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cards[row * 2]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[row * 2 + 1]),
                ],
              ),
            ),
            if (row < 2) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

enum _ExpeditionMotif {
  tides,
  forecast,
  fish,
  techniques,
  community,
  shops,
}

extension on _ExpeditionMotif {
  String get assetStem => switch (this) {
        _ExpeditionMotif.tides => 'tides',
        _ExpeditionMotif.forecast => 'advanced_tides',
        _ExpeditionMotif.fish => 'fish_species',
        _ExpeditionMotif.techniques => 'techniques',
        _ExpeditionMotif.community => 'community',
        _ExpeditionMotif.shops => 'shops',
      };
}

class _ExpeditionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final _ExpeditionMotif motif;
  final VoidCallback? onTap;

  const _ExpeditionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.motif,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    final asset =
        'assets/home_cards/${motif.assetStem}_${palette.isDark ? 'dark' : 'light'}.webp';
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);

    return Semantics(
      key: ValueKey<String>('home-expedition-${motif.name}'),
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.isDark
                    ? palette.accent.withValues(alpha: 0.58)
                    : palette.borderStrong,
              ),
              boxShadow: [
                ...palette.softShadow,
                if (palette.isDark)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 12,
                  ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth * 0.36;
                final textStart = constraints.maxWidth * 0.37;
                final textWidth = constraints.maxWidth - textStart - 6;
                return Stack(
                  children: [
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: imageWidth,
                      child: ClipRRect(
                        borderRadius: const BorderRadiusDirectional.only(
                          topStart: Radius.circular(17),
                          bottomStart: Radius.circular(17),
                        ),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: accent.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.phishing_rounded,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CustomPaint(
                            painter: _CardMotifPainter(
                              motif: motif,
                              color: accent,
                              isDark: palette.isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: textStart,
                      end: 6,
                      top: 6,
                      bottom: 6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: textWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                textScaler: textScaler,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 10,
                                  height: 1.04,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                textScaler: textScaler,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 7.4,
                                  height: 1.18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      end: 6,
                      bottom: 6,
                      child: Container(
                        width: 22,
                        height: 24,
                        decoration: BoxDecoration(
                          color: palette.surface.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.55),
                          ),
                          boxShadow: palette.isDark
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.22),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          color: accent,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CardMotifPainter extends CustomPainter {
  final _ExpeditionMotif motif;
  final Color color;
  final bool isDark;

  const _CardMotifPainter({
    required this.motif,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: isDark ? 0.13 : 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final glow = Paint()
      ..color = color.withValues(alpha: isDark ? 0.09 : 0.055)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.13, size.height * 0.2),
      size.shortestSide * 0.27,
      glow,
    );

    switch (motif) {
      case _ExpeditionMotif.tides:
      case _ExpeditionMotif.forecast:
        for (var i = 0; i < 3; i++) {
          final path = Path()..moveTo(0, size.height * (0.35 + i * 0.08));
          for (var x = 0.0; x <= size.width; x += 8) {
            final y =
                size.height * (0.35 + i * 0.08) + math.sin(x / 18 + i) * 5;
            path.lineTo(x, y);
          }
          canvas.drawPath(path, line);
        }
        break;
      case _ExpeditionMotif.fish:
        final body = Rect.fromCenter(
          center: Offset(size.width * 0.28, size.height * 0.3),
          width: size.width * 0.32,
          height: size.height * 0.13,
        );
        canvas.drawOval(body, line);
        final tail = Path()
          ..moveTo(body.left, body.center.dy)
          ..lineTo(body.left - 18, body.top - 4)
          ..lineTo(body.left - 18, body.bottom + 4)
          ..close();
        canvas.drawPath(tail, line);
        break;
      case _ExpeditionMotif.techniques:
        final path = Path()
          ..moveTo(size.width * 0.05, size.height * 0.45)
          ..quadraticBezierTo(
            size.width * 0.35,
            size.height * 0.03,
            size.width * 0.73,
            size.height * 0.18,
          );
        canvas.drawPath(path, line..strokeWidth = 2);
        break;
      case _ExpeditionMotif.community:
        for (final point in [
          Offset(size.width * 0.16, size.height * 0.3),
          Offset(size.width * 0.3, size.height * 0.24),
          Offset(size.width * 0.43, size.height * 0.31),
        ]) {
          canvas.drawCircle(point, 8, line);
          canvas.drawArc(
            Rect.fromCenter(
              center: point.translate(0, 19),
              width: 27,
              height: 24,
            ),
            math.pi,
            math.pi,
            false,
            line,
          );
        }
        break;
      case _ExpeditionMotif.shops:
        final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.1,
            size.height * 0.22,
            size.width * 0.36,
            size.height * 0.2,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(box, line);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.28, size.height * 0.22),
            width: 28,
            height: 22,
          ),
          math.pi,
          math.pi,
          false,
          line,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CardMotifPainter oldDelegate) =>
      oldDelegate.motif != motif ||
      oldDelegate.color != color ||
      oldDelegate.isDark != isDark;
}

class _HomeDrawer extends StatelessWidget {
  final VoidCallback? onNavigateToSpots;
  final VoidCallback? onNavigateToSpecies;
  final VoidCallback? onNavigateToTechniques;
  final VoidCallback? onNavigateToCommunity;
  final VoidCallback? onNavigateToShops;
  final VoidCallback? onNavigateToTides;
  final VoidCallback? onNavigateToTidesV2;

  const _HomeDrawer({
    this.onNavigateToSpots,
    this.onNavigateToSpecies,
    this.onNavigateToTechniques,
    this.onNavigateToCommunity,
    this.onNavigateToShops,
    this.onNavigateToTides,
    this.onNavigateToTidesV2,
  });

  void _closeAndRun(BuildContext context, VoidCallback? callback) {
    Navigator.pop(context);
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Drawer(
      backgroundColor: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.navy, palette.blue],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: palette.accent),
                boxShadow: palette.glowShadow(0.18),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BoosterFish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('app.tagline'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_rounded, color: palette.accent, size: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: _DrawerUtilityButton(
                      icon: ThemeController.instance.isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: ThemeController.instance.isDark
                          ? context.tr('theme.dark')
                          : context.tr('theme.light'),
                      onTap: ThemeController.instance.toggle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const CuteLanguageSelector(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _DrawerNavigationItem(
                    icon: Icons.home_rounded,
                    label: context.tr('drawer.home'),
                    selected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.waves_rounded,
                    label: context.tr('drawer.tides'),
                    onTap: () => _closeAndRun(context, onNavigateToTides),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.show_chart_rounded,
                    label: context.tr('drawer.tidesPro'),
                    onTap: () => _closeAndRun(context, onNavigateToTidesV2),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.location_on_rounded,
                    label: context.tr('drawer.spots'),
                    onTap: () => _closeAndRun(context, onNavigateToSpots),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.set_meal_rounded,
                    label: context.tr('drawer.fish'),
                    onTap: () => _closeAndRun(context, onNavigateToSpecies),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.phishing_rounded,
                    label: context.tr('drawer.techniques'),
                    onTap: () => _closeAndRun(context, onNavigateToTechniques),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.storefront_rounded,
                    label: context.tr('drawer.shops'),
                    onTap: () => _closeAndRun(context, onNavigateToShops),
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.groups_rounded,
                    label: context.tr('drawer.community'),
                    onTap: () => _closeAndRun(context, onNavigateToCommunity),
                  ),
                  Divider(color: palette.border),
                  _DrawerNavigationItem(
                    icon: Icons.settings_rounded,
                    label: context.tr('drawer.settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  _DrawerNavigationItem(
                    icon: Icons.help_outline_rounded,
                    label: context.tr('drawer.help'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(context.tr('drawer.help')),
                          content: Text(context.tr('drawer.helpContent')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(context.tr('common.ok')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.anchor_rounded,
                      color: palette.textSecondary, size: 18),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.tr('home.member'),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

class _DrawerUtilityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerUtilityButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: palette.accent, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _DrawerNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerNavigationItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _HomePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        selectedTileColor: palette.accent.withValues(alpha: 0.12),
        leading: Icon(
          icon,
          color: selected ? palette.accent : palette.textSecondary,
          size: 21,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? palette.accent : palette.textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? Icon(Icons.circle, color: palette.accent, size: 7)
            : null,
      ),
    );
  }
}

class _OceanBackgroundPainter extends CustomPainter {
  final _HomePalette palette;

  const _OceanBackgroundPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: palette.backgroundGradient,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.accent.withValues(alpha: palette.isDark ? 0.12 : 0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.05),
          radius: size.width * 0.85,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final wave = Paint()
      ..color = palette.accent.withValues(alpha: palette.isDark ? 0.045 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < 5; row++) {
      final yBase = size.height * (0.56 + row * 0.07);
      final path = Path()..moveTo(0, yBase);
      for (var x = 0.0; x <= size.width; x += 12) {
        path.lineTo(x, yBase + math.sin(x / 38 + row) * 9);
      }
      canvas.drawPath(path, wave);
    }
  }

  @override
  bool shouldRepaint(covariant _OceanBackgroundPainter oldDelegate) =>
      oldDelegate.palette.isDark != palette.isDark;
}

class _CircuitPainter extends CustomPainter {
  final Color color;

  const _CircuitPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final origin = Offset(size.width * 0.54, size.height * 0.17);
    for (var i = 0; i < 5; i++) {
      final y = origin.dy + i * 14;
      final path = Path()
        ..moveTo(origin.dx, y)
        ..lineTo(size.width * (0.7 + i * 0.025), y)
        ..lineTo(size.width * (0.76 + i * 0.02), y - 8)
        ..lineTo(size.width * 0.96, y - 8);
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        Offset(size.width * 0.96, y - 8),
        1.6,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HomePalette {
  final bool isDark;

  const _HomePalette(this.isDark);

  factory _HomePalette.of(BuildContext context) =>
      _HomePalette(ThemeController.instance.isDark);

  Color get background =>
      isDark ? const Color(0xFF020817) : const Color(0xFFF7FAFE);
  Color get surface =>
      isDark ? const Color(0xFF07172C) : const Color(0xFFFFFFFF);
  Color get navy => isDark ? const Color(0xFF03142B) : const Color(0xFF0B2852);
  Color get blue => isDark ? const Color(0xFF075C92) : const Color(0xFF087ED7);
  Color get cyan => isDark ? const Color(0xFF19D7FF) : const Color(0xFF079BF2);
  Color get accent => isDark ? cyan : const Color(0xFF078FF0);
  Color get textPrimary =>
      isDark ? const Color(0xFFF4F8FF) : const Color(0xFF071A3F);
  Color get textSecondary =>
      isDark ? const Color(0xFFA8B9D2) : const Color(0xFF526786);
  Color get border =>
      isDark ? const Color(0xFF17395C) : const Color(0xFFD1E1F2);
  Color get borderStrong =>
      isDark ? const Color(0xFF3C8CBF) : const Color(0xFFB8D6F1);
  Color get heroText =>
      isDark ? const Color(0xFFF7FAFF) : const Color(0xFF071A3F);
  Color get heroPanel =>
      isDark ? const Color(0xD9071A31) : const Color(0xEAF8FBFF);
  Color get heroPanelBorder =>
      isDark ? const Color(0x6649CBFF) : const Color(0x667ABDEB);

  List<Color> get backgroundGradient => isDark
      ? const [Color(0xFF020817), Color(0xFF041226), Color(0xFF020817)]
      : const [Color(0xFFF9FCFF), Color(0xFFF2F8FE), Color(0xFFFFFFFF)];

  List<Color> get heroOverlay => isDark
      ? const [
          Color(0x05020817),
          Color(0x4D020817),
          Color(0xE8071830),
          Color(0xFF07182E),
        ]
      : const [
          Color(0x08000000),
          Color(0x33FFFFFF),
          Color(0xEAF8FBFF),
          Color(0xFFF8FBFF),
        ];

  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.34)
              : const Color(0xFF0C4F86).withValues(alpha: 0.11),
          blurRadius: 22,
          offset: const Offset(0, 9),
        ),
      ];

  List<BoxShadow> glowShadow(double alpha) => [
        BoxShadow(
          color: accent.withValues(alpha: alpha),
          blurRadius: 22,
          spreadRadius: isDark ? 0.5 : 0,
        ),
      ];
}
