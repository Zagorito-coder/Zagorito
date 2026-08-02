// ============================================================
//  tide_page.dart — Page Marées complète, animée, haute perf
//  Branchée sur les conditions marines publiées par TideService
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/tide_page_models.dart' as tm;
import '../models/tide_data.dart' as tide_data;
import '../services/forecast_firestore_service.dart';
import '../services/tide_service.dart' as tide_svc;
import '../theme_controller.dart';
import '../widgets/app_back_button.dart';
import '../widgets/open_meteo_attribution.dart';
import '../l10n/app_localizations.dart';

// ── Palette adaptative ──────────────────────────────────────
bool get _isDark => ThemeController.instance.isDark;

Color get _bg => _isDark ? const Color(0xFF03101F) : const Color(0xFFEAF7FC);
Color get _card => _isDark ? const Color(0xD90A1C30) : const Color(0xE8F8FCFF);
Color get _glassBorder =>
    _isDark ? const Color(0x805AC9F4) : const Color(0x993F9ED3);

const Color _accent = Color(0xFF00D4FF);
const Color _green = Color(0xFF00FF88);
const Color _amber = Color(0xFFFFB800);
const Color _red = Color(0xFFFF6B6B);

Color _txt(double opacity) => _isDark
    ? Colors.white.withValues(alpha: opacity)
    : Colors.black.withValues(alpha: opacity);

// ── Conversion TideService → modèle TidePage ─────────────────
tm.TideData _fromTideService(
  tide_data.TideData src, {
  GfsWeatherTimeline? gfsWeather,
}) {
  final now = DateTime.now();
  final currentHour = now.hour;

  final today = DateTime.now();
  final todayOnly = src.hourlyPoints
      .where((p) =>
          p.time.year == today.year &&
          p.time.month == today.month &&
          p.time.day == today.day)
      .toList();

  final tidePoints =
      (todayOnly.isNotEmpty ? todayOnly : src.hourlyPoints).map((p) {
    final t = p.time.hour + p.time.minute / 60.0;
    return tm.TidePoint(time: t, height: p.height);
  }).toList();

  final hourlyCards = <tm.HourlyCard>[];
  for (int h = 0; h < 24; h++) {
    final hourPoint =
        tidePoints.where((p) => p.time >= h && p.time < h + 1).firstOrNull;
    final nearestPoint = tidePoints.isEmpty
        ? null
        : tidePoints
            .reduce((a, b) => (a.time - h).abs() <= (b.time - h).abs() ? a : b);
    final selectedTidePoint = hourPoint ?? nearestPoint;
    final hh = selectedTidePoint?.height ?? src.next;

    final prevH = h > 0
        ? tidePoints.where((p) => p.time >= h - 1 && p.time < h).toList()
        : <tm.TidePoint>[];
    double prev = prevH.isNotEmpty ? prevH.last.height : hh;
    final trend = hh >= prev ? 'montante' : 'descendante';

    final isNow = h == currentHour;
    final activity =
        ((hh - src.low) / (src.high - src.low).clamp(0.01, 10)).clamp(0.0, 1.0);
    final score = (activity * 100).round();
    String level;
    String label;
    if (activity > 0.7) {
      level = 'high';
      label = 'Activité Élevée';
    } else if (activity > 0.4) {
      level = 'mid';
      label = 'Activité Moyenne';
    } else {
      level = 'low';
      label = 'Activité Faible';
    }

    final matchPoint = src.hourlyPoints
            .where(
              (p) =>
                  p.time.year == today.year &&
                  p.time.month == today.month &&
                  p.time.day == today.day &&
                  p.time.hour == h,
            )
            .firstOrNull ??
        (src.hourlyPoints.isEmpty
            ? null
            : src.hourlyPoints.reduce((a, b) =>
                (a.time.hour - h).abs() <= (b.time.hour - h).abs() ? a : b));

    final windDir =
        matchPoint != null ? _degToCompass(matchPoint.windDirectionDeg) : 'N';
    final wavePeriodH = matchPoint?.wavePeriod ?? 0.0;
    final windWaveH = matchPoint?.windWaveHeight ?? 0.0;
    final windSpeed = matchPoint?.windSpeedKmh?.round().clamp(0, 200) ?? 0;
    final temperature = matchPoint?.temperatureC?.round() ?? 0;
    final requestedTime = DateTime(today.year, today.month, today.day, h);
    final gfsPoint = gfsWeather?.nearestTo(requestedTime);

    hourlyCards.add(tm.HourlyCard(
      hour: h,
      label: '${h.toString().padLeft(2, '0')}:00',
      tideHeight: hh,
      tideTrend: trend,
      activityScore: score,
      activityLevel: level,
      activityLabel: label,
      windSpeed: windSpeed,
      windDirection: windDir,
      waveHeight: windWaveH,
      temp: temperature,
      pressureHpa: matchPoint?.pressureHpa ?? gfsPoint?.pressureHpa,
      precipitationProbabilityPct: matchPoint?.precipitationProbabilityPct ??
          gfsPoint?.precipitationProbabilityPct,
      relativeHumidityPct:
          matchPoint?.relativeHumidityPct ?? gfsPoint?.relativeHumidityPct,
      isIdeal: activity > 0.7,
      isNow: isNow,
      wavePeriod: wavePeriodH.round(),
    ));
  }

  final events = <tm.TideEvent>[];
  if (tidePoints.length >= 3) {
    for (int i = 1; i < tidePoints.length - 1; i++) {
      final a = tidePoints[i - 1].height;
      final b = tidePoints[i].height;
      final c = tidePoints[i + 1].height;
      if (b < a && b < c) {
        events.add(tm.TideEvent(
            type: 'low',
            time: tidePoints[i].time,
            height: b,
            label: 'Basse Mer',
            dateTime: DateTime(today.year, today.month, today.day)
                .add(Duration(minutes: (tidePoints[i].time * 60).round()))));
      } else if (b > a && b > c) {
        events.add(tm.TideEvent(
            type: 'high',
            time: tidePoints[i].time,
            height: b,
            label: 'Haute Mer',
            dateTime: DateTime(today.year, today.month, today.day)
                .add(Duration(minutes: (tidePoints[i].time * 60).round()))));
      }
    }
  }
  if (events.isEmpty) {
    final lowPoint = tidePoints.reduce((a, b) => a.height <= b.height ? a : b);
    final highPoint = tidePoints.reduce((a, b) => a.height >= b.height ? a : b);
    events.add(tm.TideEvent(
        type: 'low',
        time: lowPoint.time,
        height: lowPoint.height,
        label: 'Basse Mer',
        dateTime: DateTime(today.year, today.month, today.day)
            .add(Duration(minutes: (lowPoint.time * 60).round()))));
    events.add(tm.TideEvent(
        type: 'high',
        time: highPoint.time,
        height: highPoint.height,
        label: 'Haute Mer',
        dateTime: DateTime(today.year, today.month, today.day)
            .add(Duration(minutes: (highPoint.time * 60).round()))));
  }

  final upcomingEvents = <tm.TideEvent>[];
  final sourcePoints = src.hourlyPoints;
  for (int i = 1; i < sourcePoints.length - 1; i++) {
    final previous = sourcePoints[i - 1].height;
    final current = sourcePoints[i].height;
    final next = sourcePoints[i + 1].height;
    final point = sourcePoints[i];
    if (point.time.isBefore(now.subtract(const Duration(minutes: 30)))) {
      continue;
    }
    if (current > previous && current > next) {
      upcomingEvents.add(tm.TideEvent(
        type: 'high',
        time: point.time.hour + point.time.minute / 60,
        height: current,
        label: 'Haute Mer',
        dateTime: point.time,
      ));
    } else if (current < previous && current < next) {
      upcomingEvents.add(tm.TideEvent(
        type: 'low',
        time: point.time.hour + point.time.minute / 60,
        height: current,
        label: 'Basse Mer',
        dateTime: point.time,
      ));
    }
    if (upcomingEvents.length == 4) break;
  }

  final astro = src.astro;
  final moon = astro.moonPhaseName;
  final influence = astro.activityLabel;
  final overallScore = (astro.fishActivity * 100).round();
  final overallLevel = astro.fishActivity > 0.7
      ? 'high'
      : astro.fishActivity > 0.4
          ? 'mid'
          : 'low';
  final overallLabel = astro.activityLabel;

  final bestHours = <String>[];
  if (astro.lunarTransit.isNotEmpty) bestHours.add(astro.lunarTransit);
  if (astro.lunarUnder.isNotEmpty) bestHours.add(astro.lunarUnder);

  return tm.TideData(
    location: src.location,
    generatedAt: src.generatedAt,
    hourlyCards: hourlyCards,
    tidePoints: tidePoints,
    tideEvents: events,
    upcomingEvents: upcomingEvents.isEmpty ? events : upcomingEvents,
    currentHour: currentHour,
    moonInfo: tm.MoonInfo(phaseName: moon, influence: influence),
    sunTimes: tm.SunTimes(
        sunrise: astro.sunRise, sunset: astro.sunSet, goldenHour: ''),
    overallScore: overallScore,
    overallLevel: overallLevel,
    overallLabel: overallLabel,
    bestHours: bestHours,
    waveInfo: tm.WaveInfo(
      height: src.waveHeight,
      period: src.hourlyPoints.isNotEmpty
          ? src.hourlyPoints.first.wavePeriod.round()
          : 0,
      swell: src.waveHeight > 0 ? 'Houle disponible' : 'Données indisponibles',
    ),
    windInfo: tm.WindInfo(
      speed: src.hourlyPoints.isNotEmpty
          ? (src.hourlyPoints.first.windSpeedKmh?.round() ?? 0)
          : 0,
      direction: src.hourlyPoints.isNotEmpty
          ? _degToCompass(src.hourlyPoints.first.windDirectionDeg)
          : '--',
      gust: 0,
    ),
  );
}

// ═════════════════════════════════════════════════════════════
class TidePage extends StatefulWidget {
  const TidePage({
    super.key,
    this.embeddedInBottomNavigation = false,
  });

  /// Masque la navigation de retour et suspend les tâches périodiques lorsque
  /// la page est conservée hors écran par la barre de navigation principale.
  final bool embeddedInBottomNavigation;

  @override
  State<TidePage> createState() => _TidePageState();
}

class _TidePageState extends State<TidePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _clockInterval = Duration(minutes: 1);
  static const _refreshAfter = Duration(minutes: 15);
  static const _retryAfter = Duration(minutes: 2);

  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  bool _isLoading = true;
  tm.TideData _data = _emptyData();
  final _scrollController = ScrollController();
  final _clockNotifier = ValueNotifier<DateTime>(DateTime.now());
  Timer? _clockTimer;
  int _selectedHourIndex = 0;
  bool _followsCurrentHour = true;
  bool _loadInProgress = false;
  bool _isVisible = false;
  bool _appIsResumed = true;
  DateTime? _lastLoadedAt;
  DateTime? _lastLoadAttemptAt;

  static tm.TideData _emptyData([String location = '...']) {
    return tm.TideData(
      location: location,
      generatedAt: null,
      hourlyCards: const [],
      tidePoints: const [],
      tideEvents: const [],
      upcomingEvents: const [],
      currentHour: 0,
      moonInfo: const tm.MoonInfo(phaseName: '...', influence: '...'),
      sunTimes:
          const tm.SunTimes(sunrise: '--:--', sunset: '--:--', goldenHour: ''),
      overallScore: 0,
      overallLevel: 'mid',
      overallLabel: '...',
      bestHours: const [],
      waveInfo: const tm.WaveInfo(height: 0, period: 0, swell: ''),
      windInfo: const tm.WindInfo(speed: 0, direction: '', gust: 0),
    );
  }

  Future<void> _loadTideData() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    _lastLoadAttemptAt = DateTime.now();
    final hadUsableData = _data.hourlyCards.isNotEmpty;
    final gfsFuture = ForecastFirestoreService.fetchGfsWeather(
      'casablanca_maroc',
    )
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => null,
        )
        .catchError((_) => null);
    try {
      final d = await tide_svc.TideService.fetchTides();
      if (!mounted) return;
      final hasUsableData = d.hourlyPoints.isNotEmpty;
      setState(() {
        if (hasUsableData || !hadUsableData) {
          _data = hasUsableData ? _fromTideService(d) : _emptyData(d.location);
          if (!hadUsableData) {
            _selectedHourIndex = _data.hourlyCards.indexWhere((c) => c.isNow);
            if (_selectedHourIndex < 0) _selectedHourIndex = 0;
            _followsCurrentHour = true;
          } else if (_selectedHourIndex >= _data.hourlyCards.length) {
            _selectedHourIndex = 0;
          }
        }
        _isLoading = false;
      });
      if (!hasUsableData) return;
      _lastLoadedAt = DateTime.now();
      if (!hadUsableData) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _autoScroll();
        });
      }

      final gfsWeather = await gfsFuture;
      if (!mounted || gfsWeather == null || d.hourlyPoints.isEmpty) return;
      setState(() {
        _data = _fromTideService(d, gfsWeather: gfsWeather);
        if (_selectedHourIndex >= _data.hourlyCards.length) {
          _selectedHourIndex = 0;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } finally {
      _loadInProgress = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsResumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    ThemeController.instance.addListener(_onThemeChanged);
    unawaited(_loadTideData());
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    const items = 12;
    _fadeAnims = List.generate(items, (i) {
      final start = i * 0.06;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0),
                curve: Curves.easeOut)),
      );
    });
    _slideAnims = List.generate(items, (i) {
      final start = i * 0.06;
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0),
                curve: Curves.easeOut)),
      );
    });
    _updateClock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    _synchronizeActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    if (_appIsResumed == isResumed) return;
    _appIsResumed = isResumed;
    _synchronizeActivity();
  }

  void _synchronizeActivity() {
    if (_isVisible && _appIsResumed) {
      _startClock();
      _maybeRefreshData();
    } else {
      _stopClock();
    }
  }

  void _updateClock() {
    final now = DateTime.now();
    final previousHour = _clockNotifier.value.hour;
    _clockNotifier.value = now;
    if (!mounted ||
        !_followsCurrentHour ||
        previousHour == now.hour ||
        _data.hourlyCards.isEmpty) {
      return;
    }
    final currentIndex =
        _data.hourlyCards.indexWhere((card) => card.hour == now.hour);
    if (currentIndex < 0 || currentIndex == _selectedHourIndex) return;
    setState(() => _selectedHourIndex = currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isVisible) _autoScroll();
    });
  }

  void _startClock() {
    if (_clockTimer != null) return;
    _updateClock();
    _scheduleNextClockTick();
  }

  void _scheduleNextClockTick() {
    if (_clockTimer != null) return;
    final now = DateTime.now();
    final elapsedInMinute = now.second * 1000 + now.millisecond;
    _clockTimer = Timer(
      Duration(
        milliseconds: _clockInterval.inMilliseconds - elapsedInMinute,
      ),
      () {
        _clockTimer = null;
        if (!mounted || !_isVisible || !_appIsResumed) return;
        _updateClock();
        _maybeRefreshData();
        _scheduleNextClockTick();
      },
    );
  }

  void _maybeRefreshData() {
    if (!_isVisible || !_appIsResumed || _loadInProgress) return;
    final now = DateTime.now();
    final lastLoadedAt = _lastLoadedAt;
    final needsRefresh =
        lastLoadedAt == null || now.difference(lastLoadedAt) >= _refreshAfter;
    final lastAttemptAt = _lastLoadAttemptAt;
    final canRetry =
        lastAttemptAt == null || now.difference(lastAttemptAt) >= _retryAfter;
    if (needsRefresh && canRetry) unawaited(_loadTideData());
  }

  void _stopClock() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  void _autoScroll() {
    if (_scrollController.hasClients) {
      final offset = _selectedHourIndex * 47.0 - 80;
      _scrollController.animateTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic);
    }
  }

  void _onThemeChanged() => setState(() {});
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeController.instance.removeListener(_onThemeChanged);
    _ctrl.dispose();
    _stopClock();
    _clockNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCardTap(int index) {
    setState(() {
      _selectedHourIndex = index;
      _followsCurrentHour =
          _data.hourlyCards[index].hour == DateTime.now().hour;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPageShell(
        SafeArea(
          child: Stack(
            children: [
              if (!widget.embeddedInBottomNavigation)
                const Align(
                  alignment: Alignment.topLeft,
                  child: AppBackButton(),
                ),
              const Center(
                child: CircularProgressIndicator(
                  color: _accent,
                  semanticsLabel: 'Chargement des prévisions marines',
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_data.hourlyCards.isEmpty) {
      return _buildPageShell(
        SafeArea(
          child: Column(
            children: [
              if (!widget.embeddedInBottomNavigation)
                const Align(
                    alignment: Alignment.centerLeft, child: AppBackButton()),
              const Spacer(),
              Icon(Icons.cloud_off_outlined, color: _txt(0.55), size: 48),
              const SizedBox(height: 16),
              Text(
                'Données marines indisponibles',
                style: TextStyle(
                    color: _txt(0.85),
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Réessayez lorsque la connexion aux conditions publiées sera rétablie.',
                style: TextStyle(color: _txt(0.55), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _data = _emptyData();
                  });
                  unawaited(_loadTideData());
                },
                child: const Text('Réessayer'),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }
    return _buildPageShell(
      SafeArea(
        child: CustomScrollView(
          key: const Key('tide-page-scroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildScoreCard()),
            SliverToBoxAdapter(child: _buildCurrentTideRibbon()),
            SliverToBoxAdapter(child: _buildCurveCard()),
            SliverToBoxAdapter(child: _buildHourlyActivitySection()),
            SliverToBoxAdapter(child: _buildConditionsPanel()),
            SliverToBoxAdapter(child: _buildEventsPanel()),
            const SliverToBoxAdapter(
              child: OpenMeteoAttribution(
                padding: EdgeInsets.fromLTRB(16, 3, 16, 2),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 6)),
          ],
        ),
      ),
    );
  }

  Widget _buildPageShell(Widget child) {
    final backgroundAsset = _isDark
        ? 'assets/page_heroes/tides_marine_dark.webp'
        : 'assets/page_heroes/tides_marine_light.webp';
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isDark
                    ? const [
                        Color(0x52020B16),
                        Color(0x1A020B16),
                        Color(0x8A020B16),
                      ]
                    : const [
                        Color(0x20FFFFFF),
                        Color(0x08FFFFFF),
                        Color(0x52EAF7FC),
                      ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor ?? _glassBorder,
              width: _isDark ? 0.8 : 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isDark ? _accent : const Color(0xFF126AA4))
                    .withValues(alpha: _isDark ? 0.10 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnims[0],
      child: SlideTransition(
        position: _slideAnims[0],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
          child: Column(
            children: [
              Row(
                children: [
                  if (!widget.embeddedInBottomNavigation) ...[
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Material(
                        color: _card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _glassBorder, width: 0.7),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _txt(0.86),
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      semanticLabel: 'BoosterFish',
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BOOSTERFISH',
                          style: TextStyle(
                            color: _txt(0.68),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.7,
                          ),
                        ),
                        Text(
                          'MARÉES',
                          style: TextStyle(
                            color: _txt(1),
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _clockNotifier,
                    builder: (context, time, _) => Text(
                      '${time.hour.toString().padLeft(2, '0')}:'
                      '${time.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: _txt(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedDot(),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      _data.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _txt(0.78),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_data.generatedAt != null) ...[
                    const SizedBox(width: 9),
                    Text(
                      '• mise à jour ${_formatUpdateTime(_data.generatedAt!)}',
                      style: TextStyle(
                        color: _txt(0.52),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return FadeTransition(
      opacity: _fadeAnims[1],
      child: SlideTransition(
        position: _slideAnims[1],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _glassPanel(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: RepaintBoundary(
                    child: _CircularGauge(
                      score: _data.overallScore,
                      level: _data.overallLevel,
                      animation: _ctrl,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'ACTIVITÉ ${_data.overallLabel.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _levelColor(_data.overallLevel),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          PositionedSafetyInfo(
                            color: _levelColor(_data.overallLevel),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Indice pêche indicatif basé sur la marée et les paramètres solunaires.',
                        style: TextStyle(
                          color: _txt(0.64),
                          fontSize: 8,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('tide.bestHours').toUpperCase(),
                        style: TextStyle(
                          color: _txt(0.48),
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: _data.bestHours
                            .map(
                              (hour) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.42),
                                    width: 0.7,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 11,
                                      color: _accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hour,
                                      style: TextStyle(
                                        color: _accent,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTideRibbon() {
    final selected = _data.hourlyCards[_selectedHourIndex];
    final rising = selected.tideTrend == 'montante';
    final nextHigh = _nextEvent('high');
    final nextLow = _nextEvent('low');
    return FadeTransition(
      opacity: _fadeAnims[2],
      child: SlideTransition(
        position: _slideAnims[2],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Semantics(
            container: true,
            label:
                'Marée ${selected.tideTrend}, ${selected.tideHeight.toStringAsFixed(2)} mètres à ${selected.label}',
            child: _glassPanel(
              borderColor: _accent.withValues(alpha: 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    flex: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _clockNotifier,
                          builder: (context, now, _) => Text(
                            selected.hour == now.hour
                                ? 'MARÉE ACTUELLE'
                                : 'MARÉE À ${selected.label}',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${selected.tideHeight.toStringAsFixed(2)} m',
                          style: TextStyle(
                            color: _txt(1),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        Text(
                          'Marée ${selected.tideTrend}',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withValues(alpha: 0.10),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.60),
                      ),
                    ),
                    child: Icon(
                      rising
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: _accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROCHAINS EXTRÊMES',
                          style: TextStyle(
                            color: _txt(0.52),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        _compactEventLine(nextHigh, true),
                        const SizedBox(height: 7),
                        _compactEventLine(nextLow, false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  tm.TideEvent? _nextEvent(String type) {
    final currentDecimalHour =
        DateTime.now().hour + DateTime.now().minute / 60.0;
    final futureEvents = _data.tideEvents
        .where(
            (event) => event.type == type && event.time >= currentDecimalHour)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (futureEvents.isNotEmpty) return futureEvents.first;
    return _data.tideEvents.where((event) => event.type == type).firstOrNull;
  }

  Widget _compactEventLine(tm.TideEvent? event, bool isHigh) {
    final color = isHigh ? _accent : _red;
    return Row(
      children: [
        Icon(
          isHigh ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            event == null
                ? (isHigh ? 'Haute mer —' : 'Basse mer —')
                : '${isHigh ? 'Haute' : 'Basse'} ${_formatDecimalTime(event.time)} · ${event.height.toStringAsFixed(2)} m',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: event == null ? _txt(0.46) : color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurveCard() {
    return FadeTransition(
      opacity: _fadeAnims[2],
      child: SlideTransition(
        position: _slideAnims[2],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _glassPanel(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('tide.tideCurveTitle').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _txt(0.88),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _legend(context.tr('tide.highTide'), _accent),
                    const SizedBox(width: 7),
                    _legend(context.tr('tide.lowTide'), _red),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 140,
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: _clockNotifier,
                    builder: (context, now, _) => RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _PillCurvePainter(
                          points: _data.tidePoints,
                          events: _data.tideEvents,
                          currentHour: now.hour + now.minute / 60,
                          nowLabel: context.tr('tide.nowShort'),
                          isDark: _isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: _txt(0.5), fontSize: 10)),
    ]);
  }

  Widget _buildHourlyActivitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDark
                ? const [Color(0xFF071A2B), Color(0xFF0A2638)]
                : const [Color(0xFFF9FDFF), Color(0xFFE4F5FB)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDark
                ? _accent.withValues(alpha: 0.46)
                : const Color(0xFF3F9ED3).withValues(alpha: 0.68),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isDark ? _accent : const Color(0xFF126AA4))
                  .withValues(alpha: _isDark ? 0.15 : 0.13),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHourlyTitle(),
            _buildHourlyScroller(),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyTitle() {
    return FadeTransition(
        opacity: _fadeAnims[3],
        child: SlideTransition(
            position: _slideAnims[3],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 4),
              child: Row(children: [
                Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('ACTIVITÉ PAR HEURE',
                    style: TextStyle(
                        color: _txt(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4)),
                const Spacer(),
                Text(context.tr('tide.swipeToExplore'),
                    style: TextStyle(color: _txt(0.45), fontSize: 8.5)),
              ]),
            )));
  }

  Widget _buildHourlyScroller() {
    return FadeTransition(
        opacity: _fadeAnims[4],
        child: SlideTransition(
            position: _slideAnims[4],
            child: SizedBox(
                height: 82,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent
                      ],
                      stops: [
                        0.0,
                        0.05,
                        0.95,
                        1.0
                      ]).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _data.hourlyCards.length,
                      itemBuilder: (context, index) {
                        final card = _data.hourlyCards[index];
                        return Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: _HourlyCardWidget(
                                card: card,
                                isSelected: index == _selectedHourIndex,
                                onTap: () => _onCardTap(index),
                                animation: _ctrl));
                      }),
                ))));
  }

  Widget _buildConditionsPanel() {
    final selected = _data.hourlyCards[_selectedHourIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
      child: _glassPanel(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONDITIONS ACTUELLES',
              style: TextStyle(
                color: _txt(0.64),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  Expanded(
                    child: _compactConditionCell(
                      icon: Icon(
                        Icons.nightlight_round,
                        color: _isDark
                            ? const Color(0xFFDDE7F3)
                            : const Color(0xFF284668),
                        size: 20,
                      ),
                      label: 'LUNE',
                      value: _data.moonInfo.phaseName,
                    ),
                  ),
                  _conditionDivider(),
                  Expanded(
                    child: _compactConditionCell(
                      icon: const Icon(
                        Icons.air_rounded,
                        color: _accent,
                        size: 20,
                      ),
                      label: 'VENT',
                      value: selected.windSpeed > 0
                          ? '${selected.windSpeed} km/h\n${selected.windDirection}'
                          : 'Indisponible',
                    ),
                  ),
                  _conditionDivider(),
                  Expanded(
                    child: _compactConditionCell(
                      icon: const Icon(
                        Icons.waves_rounded,
                        color: _accent,
                        size: 20,
                      ),
                      label: 'VAGUES',
                      value: selected.waveHeight > 0
                          ? '${selected.waveHeight.toStringAsFixed(1)} m / ${selected.wavePeriod} s'
                          : 'Indisponible',
                    ),
                  ),
                  _conditionDivider(),
                  Expanded(
                    child: _compactConditionCell(
                      icon: const Icon(
                        Icons.wb_sunny_rounded,
                        color: _amber,
                        size: 20,
                      ),
                      label: 'SOLEIL',
                      value:
                          '${_data.sunTimes.sunrise}\n${_data.sunTimes.sunset}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 0.7,
              color: _glassBorder.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: _compactConditionCell(
                      icon: const Icon(
                        Icons.speed_rounded,
                        color: _accent,
                        size: 18,
                      ),
                      label: 'PRESSION',
                      value: selected.pressureHpa == null
                          ? 'Indisponible'
                          : '${selected.pressureHpa!.round()} hPa',
                    ),
                  ),
                  _conditionDivider(height: 47),
                  Expanded(
                    child: _compactConditionCell(
                      icon: const Icon(
                        Icons.umbrella_rounded,
                        color: Color(0xFF77C7FF),
                        size: 18,
                      ),
                      label: 'PLUIE',
                      value: selected.precipitationProbabilityPct == null
                          ? 'Indisponible'
                          : '${selected.precipitationProbabilityPct!.round()} %',
                    ),
                  ),
                  _conditionDivider(height: 47),
                  Expanded(
                    child: _compactConditionCell(
                      icon: const Icon(
                        Icons.water_drop_outlined,
                        color: Color(0xFF6FE7D2),
                        size: 18,
                      ),
                      label: 'HUMIDITÉ',
                      value: selected.relativeHumidityPct == null
                          ? 'Indisponible'
                          : '${selected.relativeHumidityPct!.round()} %',
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

  Widget _conditionDivider({double height = 53}) => Container(
        width: 0.7,
        height: height,
        color: _glassBorder.withValues(alpha: 0.65),
      );

  Widget _compactConditionCell({
    required Widget icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _txt(0.50),
            fontSize: 7,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 2),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _txt(0.92),
              fontSize: 8.5,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventsPanel() {
    final events = _data.upcomingEvents.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 4),
      child: _glassPanel(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROCHAINS ÉVÉNEMENTS DE MARÉE',
              style: TextStyle(
                color: _txt(0.64),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 55,
              child: Row(
                children: [
                  for (var index = 0; index < events.length; index++) ...[
                    Expanded(child: _compactEventCard(events[index])),
                    if (index != events.length - 1) const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactEventCard(tm.TideEvent event) {
    final isHigh = event.type == 'high';
    final color = isHigh ? _accent : _red;
    final dateTime = event.dateTime;
    final tomorrow = dateTime != null && dateTime.day != DateTime.now().day;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.62), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHigh
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                color: color,
                size: 13,
              ),
              Expanded(
                child: Text(
                  isHigh ? 'HAUTE MER' : 'BASSE MER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 6.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _formatDecimalTime(event.time),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${event.height.toStringAsFixed(2)} m${tomorrow ? ' · J+1' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _txt(0.78),
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PositionedSafetyInfo extends StatelessWidget {
  final Color color;

  const PositionedSafetyInfo({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Informations importantes sur les prévisions',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Prévisions marines'),
            content: const Text(
              'Ces prévisions sont indicatives et issues d’un modèle marin. '
              'La précision est limitée près des côtes. Ne les utilisez pas '
              'pour la navigation et vérifiez toujours les bulletins et '
              'horaires officiels locaux.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Compris'),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            Icons.info_outline_rounded,
            color: color,
            size: 14,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
Color _levelColor(String level) {
  switch (level) {
    case 'high':
      return _green;
    case 'mid':
      return _amber;
    case 'low':
      return _red;
    default:
      return _accent;
  }
}

String _formatDecimalTime(double time) {
  final h = time.floor(), m = ((time - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _formatUpdateTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _degToCompass(double deg) {
  const dirs = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW'
  ];
  return dirs[((deg % 360) / 22.5).round() % 16];
}

double _compassToRadians(String direction) {
  const degrees = {
    'N': 0.0,
    'NNE': 22.5,
    'NE': 45.0,
    'ENE': 67.5,
    'E': 90.0,
    'ESE': 112.5,
    'SE': 135.0,
    'SSE': 157.5,
    'S': 180.0,
    'SSW': 202.5,
    'SW': 225.0,
    'WSW': 247.5,
    'W': 270.0,
    'WNW': 292.5,
    'NW': 315.0,
    'NNW': 337.5,
  };
  return (degrees[direction] ?? 0) * math.pi / 180;
}

// ── AnimatedDot ────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.6 + 0.4 * _c.value),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _green.withValues(alpha: 0.3 * _c.value),
                      blurRadius: 6,
                      spreadRadius: 2)
                ])));
  }
}

// ── CircularGauge ──────────────────────────────────────────
class _CircularGauge extends StatelessWidget {
  final int score;
  final String level;
  final Animation<double> animation;
  const _CircularGauge(
      {required this.score, required this.level, required this.animation});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = (score / 100 * animation.value).clamp(0.0, 1.0);
          return CustomPaint(
              painter:
                  _GaugePainter(progress: progress, color: _levelColor(level)),
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(score * animation.value).round()}',
                    style: TextStyle(
                        color: _levelColor(level),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text('/100',
                    style: TextStyle(
                        color: _txt(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 4),
                if (level == 'high')
                  ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.2).animate(
                          CurvedAnimation(
                              parent: animation,
                              curve: const Interval(0.5, 1.0,
                                  curve: Curves.easeInOut))),
                      child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.8),
                              shape: BoxShape.circle))),
              ])));
        });
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  _GaugePainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 7;
    const stroke = 6.0;
    final bg = Paint()
      ..color = _txt(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi * 0.75,
        math.pi * 1.5, false, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi * 0.75,
        math.pi * 1.5 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ── HourlyCardWidget ───────────────────────────────────────
class _HourlyCardWidget extends StatelessWidget {
  final tm.HourlyCard card;
  final bool isSelected;
  final VoidCallback onTap;
  final Animation<double> animation;
  const _HourlyCardWidget(
      {required this.card,
      required this.isSelected,
      required this.onTap,
      required this.animation});
  @override
  Widget build(BuildContext context) {
    final selectedText = _isDark ? Colors.white : const Color(0xFF07364A);
    final accentText = _isDark ? _accent : const Color(0xFF007C9E);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${card.hour} heures',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: isSelected ? 1.035 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 44,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? null
                  : (_isDark
                      ? const Color(0xFF0C2134)
                      : const Color(0xFFF8FCFE)),
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _isDark
                          ? const [Color(0xFF10607A), Color(0xFF0B4058)]
                          : const [Color(0xFFDDF6FC), Color(0xFFBFEAF5)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected
                    ? (_isDark ? _accent : const Color(0xFF087FA1))
                    : _glassBorder,
                width: isSelected ? 1.35 : 0.65,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (_isDark ? _accent : const Color(0xFF087FA1))
                            .withValues(alpha: 0.28),
                        blurRadius: 11,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${card.hour}h',
                  style: TextStyle(
                    color: isSelected ? selectedText : _txt(0.76),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  card.windDirection,
                  style: TextStyle(
                    color: isSelected ? selectedText : accentText,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Transform.rotate(
                  angle: _compassToRadians(card.windDirection),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: isSelected ? selectedText : accentText,
                  ),
                ),
                Text(
                  card.waveHeight > 0
                      ? card.waveHeight.toStringAsFixed(1)
                      : 'N/D',
                  style: TextStyle(
                    color: isSelected ? selectedText : _txt(0.94),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  card.wavePeriod > 0 ? '${card.wavePeriod}s' : 'N/D',
                  style: TextStyle(
                    color: isSelected
                        ? (_isDark
                            ? const Color(0xFFFFCC4D)
                            : const Color(0xFF8A5200))
                        : _amber,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── PillCurvePainter ────────────────────────────────────────
class _PillCurvePainter extends CustomPainter {
  final List<tm.TidePoint> points;
  final List<tm.TideEvent> events;
  final double currentHour;
  final String nowLabel;
  final bool isDark;
  _PillCurvePainter(
      {required this.points,
      required this.events,
      required this.currentHour,
      required this.nowLabel,
      required this.isDark});

  static const double _padL = 14.0,
      _padR = 38.0,
      _pillZoneH = 46.0,
      _hourZoneH = 22.0,
      _topMargin = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final sampled = _hourlySample(points);
    if (sampled.length < 2) return;

    final chartTop = _topMargin + _pillZoneH;
    final chartBottom = size.height - _hourZoneH;
    final w = size.width - _padL - _padR;
    final h = chartBottom - chartTop;
    if (h <= 0 || w <= 0) return;

    final maxH = sampled.map((p) => p.height).reduce(math.max);
    final minH = sampled.map((p) => p.height).reduce(math.min);
    final range = (maxH - minH).clamp(0.02, 100.0);
    final paddedMin = minH - range * 0.1;
    final paddedRange = range * 1.2;

    double xFor(double t) => _padL + (t / 24.0) * w;
    double yFor(double v) => chartTop + h - ((v - paddedMin) / paddedRange) * h;

    final decimals = range < 0.5 ? 2 : 1;
    for (int i = 0; i <= 4; i++) {
      final v = paddedMin + paddedRange * i / 4;
      final gy = chartTop + h - h * i / 4;
      canvas.drawLine(
          Offset(_padL, gy),
          Offset(_padL + w, gy),
          Paint()
            ..color = _txt(0.06)
            ..strokeWidth = 0.6);
      final tp = TextPainter(
          text: TextSpan(
              text: '${v.toStringAsFixed(decimals)}m',
              style: TextStyle(
                  color: _txt(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(_padL + w + 8, gy - tp.height / 2));
    }

    final surface = Path()
      ..moveTo(xFor(sampled.first.time), yFor(sampled.first.height));
    for (int i = 1; i < sampled.length; i++) {
      surface.lineTo(xFor(sampled[i].time), yFor(sampled[i].height));
    }

    final fillPath = Path.from(surface)
      ..lineTo(xFor(sampled.last.time), chartBottom)
      ..lineTo(xFor(sampled.first.time), chartBottom)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _accent.withValues(alpha: 0.35),
                _accent.withValues(alpha: 0.02)
              ]).createShader(Rect.fromLTWH(_padL, chartTop, w, h)));

    canvas.drawPath(
        surface,
        Paint()
          ..color = _accent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(
        surface,
        Paint()
          ..color = _accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);

    for (final p in sampled) {
      final pt = Offset(xFor(p.time), yFor(p.height));
      canvas.drawCircle(
          pt, 5, Paint()..color = _accent.withValues(alpha: 0.25));
      canvas.drawCircle(pt, 3, Paint()..color = _accent);
    }

    final hourLabelY = chartBottom + 10;
    for (final hh in [0, 3, 6, 9, 12, 15, 18, 21, 24]) {
      final hx = xFor(hh.toDouble());
      final label = hh == 24 ? '24h' : '${hh}h';
      final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  color: _txt(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset((hx - tp.width / 2).clamp(0.0, size.width - tp.width),
              hourLabelY));
    }

    final nx = xFor(currentHour).clamp(_padL, _padL + w);
    canvas.drawLine(
        Offset(nx, chartTop),
        Offset(nx, chartBottom),
        Paint()
          ..color = _green.withValues(alpha: 0.7)
          ..strokeWidth = 2);

    final placedPills = <Rect>[];
    void drawPill(double targetX, String text, Color color, String symbol,
        {bool isNow = false}) {
      final tp = TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)
        ..layout();
      const hPad = 10.0;
      final pillW = tp.width + hPad * 2 + 8;
      const pillH = 24.0;
      double px = (targetX - pillW / 2).clamp(0.0, size.width - pillW);
      double py = _topMargin;
      var rect = Rect.fromLTWH(px, py, pillW, pillH);
      int guard = 0;
      while (placedPills.any((r) => r.overlaps(rect.inflate(4))) && guard < 3) {
        py += pillH + 4;
        rect = Rect.fromLTWH(px, py, pillW, pillH);
        guard++;
      }
      placedPills.add(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()..color = color);
      tp.paint(canvas,
          Offset(rect.left + hPad + 8, rect.top + (pillH - tp.height) / 2));
      final symTp = TextPainter(
          text: TextSpan(
              text: symbol,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)
        ..layout();
      symTp.paint(canvas,
          Offset(rect.left + hPad, rect.top + (pillH - symTp.height) / 2));
    }

    drawPill(nx, nowLabel.toUpperCase(), _green, '●', isNow: true);
    for (final e in events) {
      final isHigh = e.type == 'high';
      final ex = xFor(e.time);
      drawPill(ex, '${e.height.toStringAsFixed(2)}m ${isHigh ? 'HM' : 'BM'}',
          isHigh ? _accent : _red, isHigh ? '▲' : '▼');
      canvas.drawCircle(Offset(ex, yFor(e.height)), 5,
          Paint()..color = isHigh ? _accent : _red);
      canvas.drawCircle(Offset(ex, yFor(e.height)), 8,
          Paint()..color = (isHigh ? _accent : _red).withValues(alpha: 0.25));
    }
  }

  List<tm.TidePoint> _hourlySample(List<tm.TidePoint> src) {
    if (src.length <= 25) return src;
    final step = src.length / 24;
    return List.generate(
        25, (i) => src[(i * step).round().clamp(0, src.length - 1)]);
  }

  @override
  bool shouldRepaint(covariant _PillCurvePainter old) =>
      old.currentHour != currentHour ||
      old.points != points ||
      old.events != events ||
      old.nowLabel != nowLabel ||
      old.isDark != isDark;
}
