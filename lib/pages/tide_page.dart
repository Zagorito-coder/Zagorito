// ============================================================
//  tide_page.dart — Page Marées complète, animée, haute perf
//  Branchée sur les conditions marines publiées par TideService
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tide_page_models.dart' as tm;
import '../models/tide_data.dart' as tide_data;
import '../services/tide_service.dart' as tide_svc;
import '../theme_controller.dart';
import '../widgets/app_back_button.dart';
import '../widgets/open_meteo_attribution.dart';
import '../l10n/app_localizations.dart';

// ── Palette adaptative ──────────────────────────────────────
bool get _isDark => ThemeController.instance.isDark;

Color get _bg   => _isDark ? const Color(0xFF050D1A) : const Color(0xFFF0F4F8);
Color get _card => _isDark ? const Color(0xFF0D1F38) : const Color(0xFFFFFFFF);

const Color _accent = Color(0xFF00D4FF);
const Color _green  = Color(0xFF00FF88);
const Color _amber  = Color(0xFFFFB800);
const Color _red    = Color(0xFFFF6B6B);

Color _txt(double opacity) => _isDark ? Colors.white.withValues(alpha: opacity) : Colors.black.withValues(alpha: opacity);

// ── Conversion TideService → modèle TidePage ─────────────────
tm.TideData _fromTideService(tide_data.TideData src) {
  final now = DateTime.now();
  final currentHour = now.hour;

  final today = DateTime.now();
  final todayOnly = src.hourlyPoints.where((p) =>
    p.time.year == today.year &&
    p.time.month == today.month &&
    p.time.day == today.day
  ).toList();

  final tidePoints = (todayOnly.isNotEmpty ? todayOnly : src.hourlyPoints).map((p) {
    final t = p.time.hour + p.time.minute / 60.0;
    return tm.TidePoint(time: t, height: p.height);
  }).toList();

  final hourlyCards = <tm.HourlyCard>[];
  for (int h = 0; h < 24; h++) {
    final hourPoint = tidePoints.where((p) => p.time >= h && p.time < h + 1).firstOrNull;
    final nearestPoint = tidePoints.isEmpty
        ? null
        : tidePoints.reduce((a, b) =>
            (a.time - h).abs() <= (b.time - h).abs() ? a : b);
    final selectedTidePoint = hourPoint ?? nearestPoint;
    final hh = selectedTidePoint?.height ?? src.next;

    final prevH = h > 0 ? tidePoints.where((p) => p.time >= h - 1 && p.time < h).toList() : <tm.TidePoint>[];
    double prev = prevH.isNotEmpty ? prevH.last.height : hh;
    final trend = hh >= prev ? 'montante' : 'descendante';

    final isNow = h == currentHour;
    final activity = ((hh - src.low) / (src.high - src.low).clamp(0.01, 10)).clamp(0.0, 1.0);
    final score = (activity * 100).round();
    String level;
    String label;
    if (activity > 0.7) { level = 'high'; label = 'Activité Élevée'; }
    else if (activity > 0.4) { level = 'mid'; label = 'Activité Moyenne'; }
    else { level = 'low'; label = 'Activité Faible'; }

    final matchPoint = src.hourlyPoints.where((p) =>
      p.time.year == today.year &&
      p.time.month == today.month &&
      p.time.day == today.day &&
      p.time.hour == h,
    ).firstOrNull ?? (src.hourlyPoints.isEmpty
        ? null
        : src.hourlyPoints.reduce((a, b) =>
            (a.time.hour - h).abs() <= (b.time.hour - h).abs() ? a : b));

    final windDir = matchPoint != null
        ? _degToCompass(matchPoint.windDirectionDeg)
        : 'N';
    final wavePeriodH = matchPoint?.wavePeriod ?? 0.0;
    final windWaveH = matchPoint?.windWaveHeight ?? 0.0;
    final windSpeed = matchPoint?.windSpeedKmh?.round().clamp(0, 200) ?? 0;
    final temperature = matchPoint?.temperatureC?.round() ?? 0;

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
        events.add(tm.TideEvent(type: 'low', time: tidePoints[i].time, height: b, label: 'Basse Mer'));
      } else if (b > a && b > c) {
        events.add(tm.TideEvent(type: 'high', time: tidePoints[i].time, height: b, label: 'Haute Mer'));
      }
    }
  }
  if (events.isEmpty) {
    events.add(tm.TideEvent(type: 'low', time: src.low, height: src.low, label: 'Basse Mer'));
    events.add(tm.TideEvent(type: 'high', time: src.high, height: src.high, label: 'Haute Mer'));
  }

  final astro = src.astro;
  final moon = astro.moonPhaseName;
  final influence = astro.activityLabel;
  final overallScore = (astro.fishActivity * 100).round();
  final overallLevel = astro.fishActivity > 0.7 ? 'high' : astro.fishActivity > 0.4 ? 'mid' : 'low';
  final overallLabel = astro.activityLabel;

  final bestHours = <String>[];
  if (astro.lunarTransit.isNotEmpty) bestHours.add(astro.lunarTransit);
  if (astro.lunarUnder.isNotEmpty) bestHours.add(astro.lunarUnder);

  return tm.TideData(
    location: src.location,
    hourlyCards: hourlyCards,
    tidePoints: tidePoints,
    tideEvents: events,
    currentHour: currentHour,
    moonInfo: tm.MoonInfo(phaseName: moon, influence: influence),
    sunTimes: tm.SunTimes(sunrise: astro.sunRise, sunset: astro.sunSet, goldenHour: ''),
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
  const TidePage({super.key});
  @override State<TidePage> createState() => _TidePageState();
}

class _TidePageState extends State<TidePage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  bool _isLoading = true;
  tm.TideData _data = _emptyData();
  final _scrollController = ScrollController();
  final _clockNotifier = ValueNotifier<String>('');
  Timer? _clockTimer;
  int _selectedHourIndex = 0;

  static tm.TideData _emptyData([String location = '...']) {
    return tm.TideData(
      location: location,
      hourlyCards: const [],
      tidePoints: const [],
      tideEvents: const [],
      currentHour: 0,
      moonInfo: const tm.MoonInfo(phaseName: '...', influence: '...'),
      sunTimes: const tm.SunTimes(sunrise: '--:--', sunset: '--:--', goldenHour: ''),
      overallScore: 0, overallLevel: 'mid', overallLabel: '...',
      bestHours: const [],
      waveInfo: const tm.WaveInfo(height: 0, period: 0, swell: ''),
      windInfo: const tm.WindInfo(speed: 0, direction: '', gust: 0),
    );
  }

  Future<void> _loadTideData() async {
    try {
      final d = await tide_svc.TideService.fetchTides();
      if (!mounted) return;
      setState(() {
        _data = d.hourlyPoints.isEmpty ? _emptyData(d.location) : _fromTideService(d);
        _isLoading = false;
        _selectedHourIndex = _data.hourlyCards.indexWhere((c) => c.isNow);
        if (_selectedHourIndex < 0) _selectedHourIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
    }
  }

  @override void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _loadTideData();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    const items = 12;
    _fadeAnims = List.generate(items, (i) {
      final start = i * 0.06;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0), curve: Curves.easeOut)),
      );
    });
    _slideAnims = List.generate(items, (i) {
      final start = i * 0.06;
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0), curve: Curves.easeOut)),
      );
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      _clockNotifier.value = '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
    });
    _clockNotifier.value = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) { _ctrl.forward(); _autoScroll(); });
  }

  void _autoScroll() {
    if (_scrollController.hasClients) {
      final offset = _selectedHourIndex * 118.0 - 40;
      _scrollController.animateTo(offset.clamp(0, _scrollController.position.maxScrollExtent), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
    }
  }

  void _onThemeChanged() => setState(() {});
  @override void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _ctrl.dispose(); _clockTimer?.cancel(); _clockNotifier.dispose(); _scrollController.dispose();
    super.dispose();
  }

  void _onCardTap(int index) => setState(() => _selectedHourIndex = index);

  @override Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: _bg, body: const Center(child: CircularProgressIndicator()));
    if (_data.hourlyCards.isEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
              const Spacer(),
              Icon(Icons.cloud_off_outlined, color: _txt(0.55), size: 48),
              const SizedBox(height: 16),
              Text(
                'Données marines indisponibles',
                style: GoogleFonts.inter(color: _txt(0.85), fontSize: 17, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Réessayez lorsque la connexion aux conditions publiées sera rétablie.',
                style: GoogleFonts.inter(color: _txt(0.55), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _data = _emptyData();
                  });
                  _loadTideData();
                },
                child: const Text('Réessayer'),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    }
    return Scaffold(backgroundColor: _bg, body: SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _buildHeader()),
      SliverToBoxAdapter(child: _buildScoreCard()),
      SliverToBoxAdapter(child: _buildCurveCard()),
      SliverToBoxAdapter(child: _buildHourlyTitle()),
      SliverToBoxAdapter(child: _buildHourlyScroller()),
      SliverToBoxAdapter(child: _buildSelectedBanner()),
      SliverToBoxAdapter(child: _buildConditionsTitle()),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.45, crossAxisSpacing: 12, mainAxisSpacing: 12),
        delegate: SliverChildListDelegate([
          _buildConditionMoon(_data.moonInfo), _buildConditionWind(_data.windInfo),
          _buildConditionWaves(_data.waveInfo), _buildConditionSun(_data.sunTimes),
        ]),
      )),
      SliverToBoxAdapter(child: _buildEventsTitle()),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
        delegate: SliverChildListDelegate(_data.tideEvents.map((e) => _buildTideEventCard(e)).toList()),
      )),
      const SliverToBoxAdapter(child: OpenMeteoAttribution()),
      const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
    ])));
  }

  Widget _buildHeader() {
    return FadeTransition(opacity: _fadeAnims[0], child: SlideTransition(position: _slideAnims[0], child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        const AppBackButton(), const SizedBox(width: 8),
        Row(children: [_AnimatedDot(), const SizedBox(width: 8), Text(_data.location, style: GoogleFonts.inter(color: _txt(0.7), fontSize: 13, fontWeight: FontWeight.w400))]),
        const Spacer(),
        ValueListenableBuilder<String>(valueListenable: _clockNotifier, builder: (context, time, _) => Text(time, style: GoogleFonts.inter(color: _txt(0.6), fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    )));
  }

  Widget _buildScoreCard() {
    return FadeTransition(opacity: _fadeAnims[1], child: SlideTransition(position: _slideAnims[1], child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_card, _card.withValues(alpha: 0.8)]), boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 2)]),
        child: Row(children: [
          SizedBox(width: 120, height: 120, child: RepaintBoundary(child: _CircularGauge(score: _data.overallScore, level: _data.overallLevel, animation: _ctrl))),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: _levelColor(_data.overallLevel).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _levelColor(_data.overallLevel).withValues(alpha: 0.3), width: 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.info_outline, size: 12, color: _levelColor(_data.overallLevel)), const SizedBox(width: 4), Text(_tideLabel(context, _data.overallLevel), style: GoogleFonts.inter(color: _levelColor(_data.overallLevel), fontSize: 12, fontWeight: FontWeight.w600))]),
            ),
            const SizedBox(height: 6),
            Text(context.tr('tide.scoreDescription'), style: GoogleFonts.inter(color: _txt(0.5), fontSize: 11, height: 1.4)),
            const SizedBox(height: 8),
            Text(context.tr('tide.bestHours'), style: GoogleFonts.inter(color: _txt(0.35), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: _data.bestHours.map((h) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: _accent.withValues(alpha: 0.25), width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.access_time, size: 11, color: _accent), const SizedBox(width: 4), Text(h, style: GoogleFonts.inter(color: _accent, fontSize: 11, fontWeight: FontWeight.w600))]))).toList()),
          ])),
        ]),
      ),
    )));
  }

  Widget _buildCurveCard() {
    return FadeTransition(opacity: _fadeAnims[2], child: SlideTransition(position: _slideAnims[2], child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(padding: const EdgeInsets.fromLTRB(12, 16, 12, 0), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.06), blurRadius: 20, spreadRadius: 1)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(context.tr('tide.tideCurveTitle'), style: GoogleFonts.inter(color: _txt(0.85), fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _legend(context.tr('tide.now'), _green), const SizedBox(width: 8),
              _legend(context.tr('tide.highTide'), _accent), const SizedBox(width: 8),
              _legend(context.tr('tide.lowTide'), _red),
            ]),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 300, child: RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: _PillCurvePainter(
            points: _data.tidePoints, events: _data.tideEvents,
            currentHour: _data.currentHour + DateTime.now().minute / 60,
            nowLabel: context.tr('tide.nowShort'), isDark: _isDark,
          )))),
          const SizedBox(height: 4),
          SizedBox(height: 90, child: _WindWaveBandeau(cards: _data.hourlyCards, selectedIndex: _selectedHourIndex, onTap: _onCardTap)),
          const SizedBox(height: 12),
        ]),
      ),
    )));
  }

  Widget _legend(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(color: _txt(0.5), fontSize: 10)),
    ]);
  }

  Widget _buildHourlyTitle() {
    return FadeTransition(opacity: _fadeAnims[3], child: SlideTransition(position: _slideAnims[3], child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(context.tr('tide.hourlyActivity'), style: GoogleFonts.inter(color: _txt(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(), Text(context.tr('tide.swipeToExplore'), style: GoogleFonts.inter(color: _txt(0.35), fontSize: 11)),
      ]),
    )));
  }

  Widget _buildHourlyScroller() {
    return FadeTransition(opacity: _fadeAnims[4], child: SlideTransition(position: _slideAnims[4], child: SizedBox(height: 220, child: ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent], stops: [0.0, 0.05, 0.95, 1.0]).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(controller: _scrollController, scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _data.hourlyCards.length, itemBuilder: (context, index) {
        final card = _data.hourlyCards[index];
        return Padding(padding: const EdgeInsets.only(right: 8), child: _HourlyCardWidget(card: card, isSelected: index == _selectedHourIndex, onTap: () => _onCardTap(index), animation: _ctrl));
      }),
    ))));
  }

  Widget _buildSelectedBanner() {
    final selected = _data.hourlyCards[_selectedHourIndex];
    final windText = selected.windSpeed > 0 ? '${selected.windSpeed}km/h' : '--';
    return AnimatedSwitcher(duration: const Duration(milliseconds: 400), transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: child)),
      child: Container(key: ValueKey(_selectedHourIndex), margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _levelColor(selected.activityLevel).withValues(alpha: 0.3), width: 1), boxShadow: [BoxShadow(color: _levelColor(selected.activityLevel).withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 2)]),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('tide.selectedHour'), style: GoogleFonts.inter(color: _txt(0.4), fontSize: 11)), const SizedBox(height: 4),
            Text(selected.label, style: GoogleFonts.inter(color: _txt(1.0), fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 2),
            Text('Marée ${selected.tideTrend} · ${selected.tideHeight.toStringAsFixed(2)}m · $windText ${selected.windDirection}', style: GoogleFonts.inter(color: _txt(0.5), fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${selected.activityScore}', style: GoogleFonts.inter(color: _levelColor(selected.activityLevel), fontSize: 28, fontWeight: FontWeight.w800)),
            Text(context.tr('tide.activityScore'), style: GoogleFonts.inter(color: _txt(0.4), fontSize: 10)), const SizedBox(height: 4),
            Text(_tideLabel(context, selected.activityLevel), style: GoogleFonts.inter(color: _levelColor(selected.activityLevel), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildConditionsTitle() {
    return FadeTransition(opacity: _fadeAnims[6], child: SlideTransition(position: _slideAnims[6], child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(context.tr('tide.conditions'), style: GoogleFonts.inter(color: _txt(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(_data.hourlyCards[_selectedHourIndex].label, style: GoogleFonts.inter(color: _accent.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    )));
  }

  Widget _buildConditionMoon(tm.MoonInfo info) => _ConditionCard(animation: _ctrl, delayIndex: 7, icon: '🌙', title: context.tr('tide.moonPhase'), value: info.phaseName, subtitle: info.influence, child: RepaintBoundary(child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _MoonPainter(phase: 0.0)))));
  Widget _buildConditionWind(tm.WindInfo info) => _ConditionCard(animation: _ctrl, delayIndex: 8, icon: '💨', title: context.tr('tide.wind'), value: info.speed > 0 ? '${info.speed} km/h ${info.direction}' : '--', subtitle: info.gust > 0 ? 'Rafales ±${info.gust} km/h' : 'Données indisponibles', child: RepaintBoundary(child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _WindLinesPainter(animation: _ctrl)))));
  Widget _buildConditionWaves(tm.WaveInfo info) => _ConditionCard(animation: _ctrl, delayIndex: 9, icon: '🌊', title: context.tr('tide.waves'), value: info.height > 0 ? '${info.height.toStringAsFixed(1)}m / ${info.period}s' : '--', subtitle: info.swell, child: RepaintBoundary(child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _WaveSinePainter(animation: _ctrl)))));
  Widget _buildConditionSun(tm.SunTimes info) => _ConditionCard(animation: _ctrl, delayIndex: 10, icon: '☀️', title: context.tr('tide.sun'), value: '${info.sunrise} — ${info.sunset}', subtitle: 'Or ${info.goldenHour}', child: RepaintBoundary(child: SizedBox(width: 40, height: 40, child: CustomPaint(painter: _SunArcPainter(animation: _ctrl)))));

  Widget _buildEventsTitle() {
    return FadeTransition(opacity: _fadeAnims[8], child: SlideTransition(position: _slideAnims[8], child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(children: [Container(width: 4, height: 18, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Text(context.tr('tide.tideEvents'), style: GoogleFonts.inter(color: _txt(0.9), fontSize: 14, fontWeight: FontWeight.w600))]),
    )));
  }

  Widget _buildTideEventCard(tm.TideEvent event) {
    final isHigh = event.type == 'high';
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: isHigh ? _accent.withValues(alpha: 0.2) : _red.withValues(alpha: 0.2), width: 1), boxShadow: [BoxShadow(color: (isHigh ? _accent : _red).withValues(alpha: 0.05), blurRadius: 15, spreadRadius: 1)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [Icon(isHigh ? Icons.water : Icons.water_drop_outlined, color: isHigh ? _accent : _red, size: 14), const SizedBox(width: 4), Flexible(child: Text(context.tr(event.type == 'high' ? 'tide.highTideLabel' : 'tide.lowTideLabel').toUpperCase(), style: GoogleFonts.inter(color: isHigh ? _accent : _red, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5), overflow: TextOverflow.ellipsis, maxLines: 1))]),
        const SizedBox(height: 4),
        Text(_formatDecimalTime(event.time), style: GoogleFonts.inter(color: _txt(1.0), fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 1), Text('${event.height.toStringAsFixed(2)}m NGF', style: GoogleFonts.inter(color: _txt(0.5), fontSize: 10)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
Color _levelColor(String level) {
  switch (level) { case 'high': return _green; case 'mid': return _amber; case 'low': return _red; default: return _accent; }
}
String _formatDecimalTime(double time) {
  final h = time.floor(), m = ((time - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
String _tideLabel(BuildContext context, String level) {
  switch (level) { case 'high': return context.tr('tide.activityHigh'); case 'mid': return context.tr('tide.activityMid'); case 'low': return context.tr('tide.activityLow'); default: return context.tr('tide.activityMid'); }
}
String _degToCompass(double deg) {
  const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  return dirs[((deg % 360) / 22.5).round() % 16];
}

// ── AnimatedDot ────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  @override State<_AnimatedDot> createState() => _AnimatedDotState();
}
class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (context, child) => Container(width: 8, height: 8, decoration: BoxDecoration(color: _green.withValues(alpha: 0.6 + 0.4 * _c.value), shape: BoxShape.circle, boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.3 * _c.value), blurRadius: 6, spreadRadius: 2)])));
  }
}

// ── CircularGauge ──────────────────────────────────────────
class _CircularGauge extends StatelessWidget {
  final int score; final String level; final Animation<double> animation;
  const _CircularGauge({required this.score, required this.level, required this.animation});
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: animation, builder: (context, child) {
      final progress = (score / 100 * animation.value).clamp(0.0, 1.0);
      return CustomPaint(painter: _GaugePainter(progress: progress, color: _levelColor(level)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${(score * animation.value).round()}', style: GoogleFonts.inter(color: _levelColor(level), fontSize: 32, fontWeight: FontWeight.w800)),
        Text('/100', style: GoogleFonts.inter(color: _txt(0.3), fontSize: 11, fontWeight: FontWeight.w400)),
        const SizedBox(height: 4),
        if (level == 'high') ScaleTransition(scale: Tween(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: animation, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut))), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: _green.withValues(alpha: 0.8), shape: BoxShape.circle))),
      ])));
    });
  }
}
class _GaugePainter extends CustomPainter {
  final double progress; final Color color;
  _GaugePainter({required this.progress, required this.color});
  @override void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 6;
    const stroke = 10.0;
    final bg = Paint()..color = _txt(0.06)..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi * 0.75, math.pi * 1.5, false, bg);
    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi * 0.75, math.pi * 1.5 * progress, false, fg);
  }
  @override bool shouldRepaint(covariant _GaugePainter old) => old.progress != progress;
}

// ── HourlyCardWidget ───────────────────────────────────────
class _HourlyCardWidget extends StatelessWidget {
  final tm.HourlyCard card; final bool isSelected; final VoidCallback onTap; final Animation<double> animation;
  const _HourlyCardWidget({required this.card, required this.isSelected, required this.onTap, required this.animation});
  @override Widget build(BuildContext context) {
    final color = _levelColor(card.activityLevel);
    final windText = card.windSpeed > 0 ? '~${card.windSpeed}km/h' : '--';
    final tempText = card.temp != 0 ? '${card.temp}°C' : '--';
    final waveText = card.waveHeight > 0 ? '~${card.waveHeight.toStringAsFixed(1)}m' : '--';
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, width: 110, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isSelected ? color.withValues(alpha: 0.12) : _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent, width: 1.5), boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)] : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(height: 16, child: Stack(alignment: Alignment.center, children: [
          if (card.isNow) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: _green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: _green.withValues(alpha: 0.4), width: 0.5)), child: Text(context.tr('tide.nowShort'), style: GoogleFonts.inter(color: _green, fontSize: 7, fontWeight: FontWeight.w800))),
          if (card.isIdeal && !card.isNow) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: _accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: _accent.withValues(alpha: 0.4), width: 0.5)), child: Text(context.tr('tide.ideal'), style: GoogleFonts.inter(color: _accent, fontSize: 7, fontWeight: FontWeight.w800))),
        ])),
        const SizedBox(height: 6), Text(card.label, style: GoogleFonts.inter(color: _txt(0.9), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), _FishIcon(level: card.activityLevel, size: 24), const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${card.activityScore}', style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text('/100', style: GoogleFonts.inter(color: _txt(0.3), fontSize: 8)),
        ]), const SizedBox(height: 3),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: card.activityScore / 100, backgroundColor: _txt(0.08), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 2)),
        const SizedBox(height: 6),
        Text('${card.tideTrend == 'montante' ? '↑' : '↓'} ${card.tideHeight.toStringAsFixed(1)}m  $windText', style: GoogleFonts.inter(color: _txt(0.5), fontSize: 9), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('$waveText  $tempText', style: GoogleFonts.inter(color: _txt(0.35), fontSize: 9), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}

// ── FishIcon ───────────────────────────────────────────────
class _FishIcon extends StatefulWidget {
  final String level; final double size;
  const _FishIcon({required this.level, required this.size});
  @override State<_FishIcon> createState() => _FishIconState();
}
class _FishIconState extends State<_FishIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl; late final Animation<double> _swim, _pulse, _glow;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true); _swim = Tween<double>(begin: -0.12, end: 0.12).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)); _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut))); _glow = Tween<double>(begin: 0.2, end: 0.6).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut))); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final color = _levelColor(widget.level);
    final baseScale = widget.level == 'high' ? 1.0 : (widget.level == 'mid' ? 0.7 : 0.45);
    return AnimatedBuilder(animation: _ctrl, builder: (context, child) {
      final swimValue = _swim.value * (widget.level == 'high' ? 1.0 : 0.5);
      final pulseValue = _pulse.value;
      final glowOpacity = widget.level == 'high' ? _glow.value : (widget.level == 'mid' ? _glow.value * 0.6 : _glow.value * 0.3);
      return Transform.scale(scale: baseScale * pulseValue, child: Transform.rotate(angle: swimValue, child: Container(
        width: widget.size, height: widget.size * 0.65,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)]), borderRadius: BorderRadius.circular(widget.size * 0.35), border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5), boxShadow: [BoxShadow(color: color.withValues(alpha: glowOpacity), blurRadius: 12, spreadRadius: 2)]),
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(widget.size * 0.7, widget.size * 0.45), painter: _FishBodyPainter(color: color)),
          Positioned(left: widget.size * 0.55, top: widget.size * 0.22, child: Container(width: widget.size * 0.1, height: widget.size * 0.1, decoration: BoxDecoration(color: _txt(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)]), child: Center(child: Container(width: widget.size * 0.05, height: widget.size * 0.05, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle))))),
        ]),
      )));
    });
  }
}
class _FishBodyPainter extends CustomPainter {
  final Color color; _FishBodyPainter({required this.color});
  @override void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawPath(Path()..moveTo(w * 0.15, h * 0.5)..quadraticBezierTo(w * 0.15, h * 0.15, w * 0.5, h * 0.15)..quadraticBezierTo(w * 0.85, h * 0.15, w * 0.85, h * 0.5)..quadraticBezierTo(w * 0.85, h * 0.85, w * 0.5, h * 0.85)..quadraticBezierTo(w * 0.15, h * 0.85, w * 0.15, h * 0.5)..close(), Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(Path()..moveTo(w * 0.15, h * 0.5)..lineTo(0, h * 0.25)..lineTo(0, h * 0.75)..close(), Paint()..color = color.withValues(alpha: 0.8)..style = PaintingStyle.fill);
    final fin = Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.fill;
    canvas.drawPath(Path()..moveTo(w * 0.4, h * 0.15)..lineTo(w * 0.5, 0)..lineTo(w * 0.6, h * 0.15)..close(), fin);
    canvas.drawPath(Path()..moveTo(w * 0.5, h * 0.85)..lineTo(w * 0.45, h)..lineTo(w * 0.55, h)..close(), fin);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── ConditionCard ──────────────────────────────────────────
class _ConditionCard extends StatelessWidget {
  final Animation<double> animation; final int delayIndex; final String icon, title, value, subtitle; final Widget child;
  const _ConditionCard({required this.animation, required this.delayIndex, required this.icon, required this.title, required this.value, required this.subtitle, required this.child});
  @override Widget build(BuildContext context) {
    final start = delayIndex * 0.06;
    final anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: animation, curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0), curve: Curves.easeOut)));
    return FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.05), blurRadius: 15, spreadRadius: 1)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(icon, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6), Text(title, style: GoogleFonts.inter(color: _txt(0.5), fontSize: 11, fontWeight: FontWeight.w600)), const Spacer(),
          if (subtitle.contains('Influence')) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(subtitle.split(' ').last, style: GoogleFonts.inter(color: _accent, fontSize: 9, fontWeight: FontWeight.w600))),
          if (subtitle.contains('Rafales')) Text(subtitle, style: GoogleFonts.inter(color: _txt(0.35), fontSize: 9)),
          if (subtitle.contains('Or')) Text(subtitle, style: GoogleFonts.inter(color: _amber.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600)),
        ]), const Spacer(),
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.inter(color: _txt(1.0), fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (!subtitle.contains('Influence') && !subtitle.contains('Rafales') && !subtitle.contains('Or')) Text(subtitle, style: GoogleFonts.inter(color: _txt(0.4), fontSize: 10)),
        ])), child]),
      ]),
    )));
  }
}

// ── Mini Painters ──────────────────────────────────────────
class _MoonPainter extends CustomPainter {
  final double phase; _MoonPainter({required this.phase});
  @override void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2); final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A3A55));
    canvas.clipPath(Path.combine(PathOperation.difference, Path()..addOval(Rect.fromCircle(center: c, radius: r)), Path()..addOval(Rect.fromCircle(center: Offset(c.dx + r * 0.4, c.dy), radius: r))));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFE4B5));
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}
class _WindLinesPainter extends CustomPainter {
  final Animation<double> animation; _WindLinesPainter({required this.animation}) : super(repaint: animation);
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _accent.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) { final y = size.height * [0.25, 0.5, 0.75][i]; canvas.drawLine(Offset(size.width * 0.1, y), Offset(size.width * 0.1 + (size.width * 0.3 + i * size.width * 0.15) * animation.value, y), p); }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

// ── PillCurvePainter ────────────────────────────────────────
class _PillCurvePainter extends CustomPainter {
  final List<tm.TidePoint> points; final List<tm.TideEvent> events; final double currentHour; final String nowLabel; final bool isDark;
  _PillCurvePainter({required this.points, required this.events, required this.currentHour, required this.nowLabel, required this.isDark});

  static const double _padL = 20.0, _padR = 56.0, _pillZoneH = 58.0, _hourZoneH = 30.0, _topMargin = 8.0;

  @override void paint(Canvas canvas, Size size) {
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
      canvas.drawLine(Offset(_padL, gy), Offset(_padL + w, gy), Paint()..color = _txt(0.06)..strokeWidth = 0.6);
      final tp = TextPainter(text: TextSpan(text: '${v.toStringAsFixed(decimals)}m', style: GoogleFonts.inter(color: _txt(0.45), fontSize: 10, fontWeight: FontWeight.w500)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(_padL + w + 8, gy - tp.height / 2));
    }

    final surface = Path()..moveTo(xFor(sampled.first.time), yFor(sampled.first.height));
    for (int i = 1; i < sampled.length; i++) { surface.lineTo(xFor(sampled[i].time), yFor(sampled[i].height)); }

    final fillPath = Path.from(surface)..lineTo(xFor(sampled.last.time), chartBottom)..lineTo(xFor(sampled.first.time), chartBottom)..close();
    canvas.drawPath(fillPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_accent.withValues(alpha: 0.35), _accent.withValues(alpha: 0.02)]).createShader(Rect.fromLTWH(_padL, chartTop, w, h)));

    canvas.drawPath(surface, Paint()..color = _accent.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 4..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(surface, Paint()..color = _accent..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round);

    for (final p in sampled) { final pt = Offset(xFor(p.time), yFor(p.height)); canvas.drawCircle(pt, 5, Paint()..color = _accent.withValues(alpha: 0.25)); canvas.drawCircle(pt, 3, Paint()..color = _accent); }

    final hourLabelY = chartBottom + 10;
    for (final hh in [0, 3, 6, 9, 12, 15, 18, 21, 24]) {
      final hx = xFor(hh.toDouble());
      final label = hh == 24 ? '24h' : '${hh}h';
      final tp = TextPainter(text: TextSpan(text: label, style: GoogleFonts.inter(color: _txt(0.55), fontSize: 11, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((hx - tp.width / 2).clamp(0.0, size.width - tp.width), hourLabelY));
    }

    final nx = xFor(currentHour).clamp(_padL, _padL + w);
    canvas.drawLine(Offset(nx, chartTop), Offset(nx, chartBottom), Paint()..color = _green.withValues(alpha: 0.7)..strokeWidth = 2);

    final placedPills = <Rect>[];
    void drawPill(double targetX, String text, Color color, String symbol, {bool isNow = false}) {
      final tp = TextPainter(text: TextSpan(text: text, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      const hPad = 10.0; final pillW = tp.width + hPad * 2 + 8; const pillH = 24.0;
      double px = (targetX - pillW / 2).clamp(0.0, size.width - pillW);
      double py = _topMargin; var rect = Rect.fromLTWH(px, py, pillW, pillH); int guard = 0;
      while (placedPills.any((r) => r.overlaps(rect.inflate(4))) && guard < 3) { py += pillH + 4; rect = Rect.fromLTWH(px, py, pillW, pillH); guard++; }
      placedPills.add(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = color);
      tp.paint(canvas, Offset(rect.left + hPad + 8, rect.top + (pillH - tp.height) / 2));
      final symTp = TextPainter(text: TextSpan(text: symbol, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      symTp.paint(canvas, Offset(rect.left + hPad, rect.top + (pillH - symTp.height) / 2));
    }

    drawPill(nx, nowLabel.toUpperCase(), _green, '●', isNow: true);
    for (final e in events) {
      final isHigh = e.type == 'high'; final ex = xFor(e.time);
      drawPill(ex, '${e.height.toStringAsFixed(2)}m ${isHigh ? 'HM' : 'BM'}', isHigh ? _accent : _red, isHigh ? '▲' : '▼');
      canvas.drawCircle(Offset(ex, yFor(e.height)), 5, Paint()..color = isHigh ? _accent : _red);
      canvas.drawCircle(Offset(ex, yFor(e.height)), 8, Paint()..color = (isHigh ? _accent : _red).withValues(alpha: 0.25));
    }
  }

  List<tm.TidePoint> _hourlySample(List<tm.TidePoint> src) { if (src.length <= 25) return src; final step = src.length / 24; return List.generate(25, (i) => src[(i * step).round().clamp(0, src.length - 1)]); }
  @override bool shouldRepaint(covariant _PillCurvePainter old) => old.currentHour != currentHour || old.points.length != points.length || old.events.length != events.length;
}

// ── WindWaveBandeau ─────────────────────────────────────────
class _WindWaveBandeau extends StatelessWidget {
  final List<tm.HourlyCard> cards; final int selectedIndex; final ValueChanged<int> onTap;
  const _WindWaveBandeau({required this.cards, required this.selectedIndex, required this.onTap});

  double _dirToRad(String dir) { const map = {'N':0.0,'NNE':22.5,'NE':45.0,'ENE':67.5,'E':90.0,'ESE':112.5,'SE':135.0,'SSE':157.5,'S':180.0,'SSW':202.5,'SW':225.0,'WSW':247.5,'W':270.0,'WNW':292.5,'NW':315.0,'NNW':337.5}; return (map[dir] ?? 0.0) * math.pi / 180; }

  @override Widget build(BuildContext context) {
    return ListView.builder(scrollDirection: Axis.horizontal, itemCount: cards.length, itemBuilder: (context, i) {
      final c = cards[i]; final selected = i == selectedIndex;
      return GestureDetector(onTap: () => onTap(i), child: Container(width: 46, margin: const EdgeInsets.only(right: 1), color: selected ? _accent.withValues(alpha: 0.25) : Colors.black, padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(c.windDirection, style: GoogleFonts.inter(color: _accent, fontSize: 9, fontWeight: FontWeight.w700)), const SizedBox(height: 4),
          Transform.rotate(angle: _dirToRad(c.windDirection), child: const Icon(Icons.arrow_downward, size: 13, color: _accent)), const SizedBox(height: 6),
          Text(c.waveHeight.toStringAsFixed(1), style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
          Text('${c.wavePeriod}s', style: GoogleFonts.inter(color: _amber, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ));
    });
  }
}
class _WaveSinePainter extends CustomPainter {
  final Animation<double> animation; _WaveSinePainter({required this.animation}) : super(repaint: animation);
  @override void paint(Canvas canvas, Size size) { final p = Paint()..color = _accent.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 2; final path = Path()..moveTo(0, size.height / 2); for (double x = 0; x <= size.width; x += 1) { path.lineTo(x, size.height / 2 + size.height * 0.25 * math.sin(2 * math.pi / size.width * x + animation.value * math.pi * 2)); } canvas.drawPath(path, p); }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
class _SunArcPainter extends CustomPainter {
  final Animation<double> animation; _SunArcPainter({required this.animation}) : super(repaint: animation);
  @override void paint(Canvas canvas, Size size) { final c = Offset(size.width / 2, size.height); final r = size.width * 0.45; canvas.drawPath(Path()..addArc(Rect.fromCircle(center: c, radius: r), -math.pi, math.pi), Paint()..color = _amber.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 2); final sp = 0.3 + animation.value * 0.4; final a = math.pi * (1 - sp); final sun = Offset(c.dx + r * math.cos(a), c.dy - r * math.sin(a)); canvas.drawCircle(sun, 4, Paint()..color = _amber); canvas.drawCircle(sun, 8, Paint()..color = _amber.withValues(alpha: 0.3)..style = PaintingStyle.fill); }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
