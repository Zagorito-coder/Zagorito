// ============================================================
//  tide_page.dart — Page Marées complète, animée, haute perf
//  Données fictives hardcodées, prête pour branchement API
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tide_page_models.dart';
import '../theme_controller.dart';

// ── Palette adaptative ──────────────────────────────────────
bool get _isDark => ThemeController.instance.isDark;

Color get _bg   => _isDark ? const Color(0xFF050D1A) : const Color(0xFFF0F4F8);
Color get _card => _isDark ? const Color(0xFF0D1F38) : const Color(0xFFFFFFFF);

const Color _accent = Color(0xFF00D4FF);
const Color _green  = Color(0xFF00FF88);
const Color _amber  = Color(0xFFFFB800);
const Color _red    = Color(0xFFFF6B6B);

// Texte adaptatif : blanc en sombre, noir en clair
Color _txt(double opacity) => _isDark ? Colors.white.withValues(alpha: opacity) : Colors.black.withValues(alpha: opacity);

// ── Données mock ────────────────────────────────────────────
TideData _mockData() {
  final now = DateTime.now();
  final currentHour = now.hour;

  final hourlyCards = <HourlyCard>[
    const HourlyCard(hour: 3, label: '03:00', tideHeight: 0.1, tideTrend: 'montante', activityScore: 38, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 14, windDirection: 'N', waveHeight: 0.58, temp: 14, isIdeal: false, isNow: false),
    const HourlyCard(hour: 4, label: '04:00', tideHeight: 0.3, tideTrend: 'montante', activityScore: 50, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 14, windDirection: 'N', waveHeight: 0.77, temp: 15, isIdeal: false, isNow: false),
    const HourlyCard(hour: 5, label: '05:00', tideHeight: 0.8, tideTrend: 'montante', activityScore: 95, activityLevel: 'high', activityLabel: 'Activité Élevée', windSpeed: 15, windDirection: 'NE', waveHeight: 0.9, temp: 16, isIdeal: false, isNow: false),
    const HourlyCard(hour: 6, label: '06:00', tideHeight: 1.5, tideTrend: 'montante', activityScore: 89, activityLevel: 'high', activityLabel: 'Activité Élevée', windSpeed: 16, windDirection: 'NE', waveHeight: 1.3, temp: 18, isIdeal: true, isNow: false),
    const HourlyCard(hour: 7, label: '07:00', tideHeight: 2.1, tideTrend: 'montante', activityScore: 68, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 16, windDirection: 'E', waveHeight: 1.3, temp: 20, isIdeal: false, isNow: true),
    const HourlyCard(hour: 8, label: '08:00', tideHeight: 2.5, tideTrend: 'descendante', activityScore: 57, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 17, windDirection: 'E', waveHeight: 1.4, temp: 22, isIdeal: false, isNow: false),
    const HourlyCard(hour: 9, label: '09:00', tideHeight: 2.3, tideTrend: 'descendante', activityScore: 42, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 15, windDirection: 'E', waveHeight: 1.2, temp: 23, isIdeal: false, isNow: false),
    const HourlyCard(hour: 10, label: '10:00', tideHeight: 1.8, tideTrend: 'descendante', activityScore: 35, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 14, windDirection: 'SE', waveHeight: 1.0, temp: 24, isIdeal: false, isNow: false),
    const HourlyCard(hour: 11, label: '11:00', tideHeight: 1.2, tideTrend: 'descendante', activityScore: 48, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 13, windDirection: 'SE', waveHeight: 0.8, temp: 25, isIdeal: false, isNow: false),
    const HourlyCard(hour: 12, label: '12:00', tideHeight: 0.6, tideTrend: 'descendante', activityScore: 55, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 12, windDirection: 'S', waveHeight: 0.6, temp: 26, isIdeal: false, isNow: false),
    const HourlyCard(hour: 13, label: '13:00', tideHeight: 0.2, tideTrend: 'montante', activityScore: 62, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 11, windDirection: 'S', waveHeight: 0.5, temp: 27, isIdeal: false, isNow: false),
    const HourlyCard(hour: 14, label: '14:00', tideHeight: 0.5, tideTrend: 'montante', activityScore: 75, activityLevel: 'high', activityLabel: 'Activité Élevée', windSpeed: 12, windDirection: 'SW', waveHeight: 0.7, temp: 26, isIdeal: false, isNow: false),
    const HourlyCard(hour: 15, label: '15:00', tideHeight: 1.1, tideTrend: 'montante', activityScore: 82, activityLevel: 'high', activityLabel: 'Activité Élevée', windSpeed: 13, windDirection: 'SW', waveHeight: 0.9, temp: 25, isIdeal: false, isNow: false),
    const HourlyCard(hour: 16, label: '16:00', tideHeight: 1.8, tideTrend: 'montante', activityScore: 78, activityLevel: 'high', activityLabel: 'Activité Élevée', windSpeed: 14, windDirection: 'W', waveHeight: 1.1, temp: 24, isIdeal: false, isNow: false),
    const HourlyCard(hour: 17, label: '17:00', tideHeight: 2.4, tideTrend: 'montante', activityScore: 65, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 15, windDirection: 'W', waveHeight: 1.2, temp: 23, isIdeal: false, isNow: false),
    const HourlyCard(hour: 18, label: '18:00', tideHeight: 2.7, tideTrend: 'descendante', activityScore: 45, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 14, windDirection: 'NW', waveHeight: 1.1, temp: 22, isIdeal: false, isNow: false),
    const HourlyCard(hour: 19, label: '19:00', tideHeight: 2.5, tideTrend: 'descendante', activityScore: 30, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 13, windDirection: 'NW', waveHeight: 1.0, temp: 21, isIdeal: false, isNow: false),
    const HourlyCard(hour: 20, label: '20:00', tideHeight: 2.0, tideTrend: 'descendante', activityScore: 25, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 12, windDirection: 'N', waveHeight: 0.9, temp: 20, isIdeal: false, isNow: false),
    const HourlyCard(hour: 21, label: '21:00', tideHeight: 1.4, tideTrend: 'descendante', activityScore: 35, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 11, windDirection: 'N', waveHeight: 0.8, temp: 19, isIdeal: false, isNow: false),
    const HourlyCard(hour: 22, label: '22:00', tideHeight: 0.9, tideTrend: 'descendante', activityScore: 40, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 10, windDirection: 'N', waveHeight: 0.6, temp: 18, isIdeal: false, isNow: false),
    const HourlyCard(hour: 23, label: '23:00', tideHeight: 0.5, tideTrend: 'montante', activityScore: 48, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 10, windDirection: 'NE', waveHeight: 0.5, temp: 17, isIdeal: false, isNow: false),
    const HourlyCard(hour: 0, label: '00:00', tideHeight: 0.3, tideTrend: 'montante', activityScore: 52, activityLevel: 'mid', activityLabel: 'Activité Moyenne', windSpeed: 11, windDirection: 'NE', waveHeight: 0.4, temp: 16, isIdeal: false, isNow: false),
    const HourlyCard(hour: 1, label: '01:00', tideHeight: 0.2, tideTrend: 'montante', activityScore: 45, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 12, windDirection: 'NE', waveHeight: 0.4, temp: 15, isIdeal: false, isNow: false),
    const HourlyCard(hour: 2, label: '02:00', tideHeight: 0.15, tideTrend: 'montante', activityScore: 40, activityLevel: 'low', activityLabel: 'Activité Faible', windSpeed: 13, windDirection: 'N', waveHeight: 0.5, temp: 14, isIdeal: false, isNow: false),
  ];

  final tidePoints = <TidePoint>[
    const TidePoint(time: 0.0, height: 0.3),
    const TidePoint(time: 0.5, height: 0.25),
    const TidePoint(time: 1.0, height: 0.2),
    const TidePoint(time: 1.5, height: 0.15),
    const TidePoint(time: 2.0, height: 0.15),
    const TidePoint(time: 2.5, height: 0.2),
    const TidePoint(time: 3.0, height: 0.1),
    const TidePoint(time: 3.5, height: 0.05),
    const TidePoint(time: 4.0, height: 0.0),
    const TidePoint(time: 4.5, height: 0.1),
    const TidePoint(time: 5.0, height: 0.3),
    const TidePoint(time: 5.5, height: 0.6),
    const TidePoint(time: 6.0, height: 1.0),
    const TidePoint(time: 6.5, height: 1.5),
    const TidePoint(time: 7.0, height: 2.1),
    const TidePoint(time: 7.5, height: 2.5),
    const TidePoint(time: 8.0, height: 2.7),
    const TidePoint(time: 8.5, height: 2.6),
    const TidePoint(time: 9.0, height: 2.4),
    const TidePoint(time: 9.5, height: 2.1),
    const TidePoint(time: 10.0, height: 1.8),
    const TidePoint(time: 10.5, height: 1.5),
    const TidePoint(time: 11.0, height: 1.2),
    const TidePoint(time: 11.5, height: 0.9),
    const TidePoint(time: 12.0, height: 0.6),
    const TidePoint(time: 12.5, height: 0.4),
    const TidePoint(time: 13.0, height: 0.2),
    const TidePoint(time: 13.5, height: 0.15),
    const TidePoint(time: 14.0, height: 0.3),
    const TidePoint(time: 14.5, height: 0.6),
    const TidePoint(time: 15.0, height: 1.0),
    const TidePoint(time: 15.5, height: 1.4),
    const TidePoint(time: 16.0, height: 1.9),
    const TidePoint(time: 16.5, height: 2.3),
    const TidePoint(time: 17.0, height: 2.6),
    const TidePoint(time: 17.5, height: 2.8),
    const TidePoint(time: 18.0, height: 2.9),
    const TidePoint(time: 18.5, height: 2.8),
    const TidePoint(time: 19.0, height: 2.6),
    const TidePoint(time: 19.5, height: 2.3),
    const TidePoint(time: 20.0, height: 2.0),
    const TidePoint(time: 20.5, height: 1.7),
    const TidePoint(time: 21.0, height: 1.4),
    const TidePoint(time: 21.5, height: 1.1),
    const TidePoint(time: 22.0, height: 0.9),
    const TidePoint(time: 22.5, height: 0.7),
    const TidePoint(time: 23.0, height: 0.5),
    const TidePoint(time: 23.5, height: 0.4),
    const TidePoint(time: 24.0, height: 0.3),
  ];

  return TideData(
    location: 'Agadir, Maroc',
    hourlyCards: hourlyCards,
    tidePoints: tidePoints,
    tideEvents: const [
      TideEvent(type: 'low', time: 5.0, height: -0.77, label: 'Basse Mer'),
      TideEvent(type: 'high', time: 11.0, height: 3.27, label: 'Haute Mer'),
      TideEvent(type: 'low', time: 17.0, height: -0.47, label: 'Basse Mer'),
      TideEvent(type: 'high', time: 23.0, height: 3.58, label: 'Haute Mer'),
    ],
    currentHour: currentHour,
    moonInfo: const MoonInfo(phaseName: 'Nouvelle Lune', influence: 'Influence Très haute'),
    sunTimes: const SunTimes(sunrise: '05:52', sunset: '19:48', goldenHour: '05:22'),
    overallScore: 68,
    overallLevel: 'mid',
    overallLabel: 'Activité Moyenne',
    bestHours: const ['07:00 - 09:00', '10:00 - 18:00'],
    waveInfo: const WaveInfo(height: 1.3, period: 9, swell: 'Houle Atlantique'),
    windInfo: const WindInfo(speed: 16, direction: 'SE', gust: 4),
  );
}

// ═════════════════════════════════════════════════════════════
//  PAGE PRINCIPALE
// ═════════════════════════════════════════════════════════════
class TidePage extends StatefulWidget {
  const TidePage({super.key});

  @override
  State<TidePage> createState() => _TidePageState();
}

class _TidePageState extends State<TidePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  late final TideData _data;
  final _scrollController = ScrollController();
  final _clockNotifier = ValueNotifier<String>('');
  Timer? _clockTimer;
  int _selectedHourIndex = 0;

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
    _data = _mockData();
    _selectedHourIndex = _data.hourlyCards.indexWhere((c) => c.isNow);
    if (_selectedHourIndex < 0) _selectedHourIndex = 0;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    const items = 12;
    _fadeAnims = List.generate(items, (i) {
      final start = i * 0.06;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0),
              curve: Curves.easeOut),
        ),
      );
    });
    _slideAnims = List.generate(items, (i) {
      final start = i * 0.06;
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0),
              curve: Curves.easeOut),
        ),
      );
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      _clockNotifier.value =
          '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
    });
    _clockNotifier.value =
        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.forward();
      _autoScroll();
    });
  }

  void _autoScroll() {
    if (_scrollController.hasClients) {
      final offset = _selectedHourIndex * 118.0 - 40;
      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    _ctrl.dispose();
    _clockTimer?.cancel();
    _clockNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCardTap(int index) {
    setState(() => _selectedHourIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── HEADER ──
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            // ── SCORE + COURBE ──
            SliverToBoxAdapter(
              child: _buildScoreCard(),
            ),
            SliverToBoxAdapter(
              child: _buildCurveCard(),
            ),
            // ── ACTIVITÉ PAR HEURE ──
            SliverToBoxAdapter(
              child: _buildHourlyTitle(),
            ),
            SliverToBoxAdapter(
              child: _buildHourlyScroller(),
            ),
            // ── BANNER SÉLECTIONNÉE ──
            SliverToBoxAdapter(
              child: _buildSelectedBanner(),
            ),
            // ── CONDITIONS ──
            SliverToBoxAdapter(
              child: _buildConditionsTitle(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.45,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildListDelegate([
                  _buildConditionMoon(_data.moonInfo),
                  _buildConditionWind(_data.windInfo),
                  _buildConditionWaves(_data.waveInfo),
                  _buildConditionSun(_data.sunTimes),
                ]),
              ),
            ),
            // ── ÉVÉNEMENTS MARÉE ──
            SliverToBoxAdapter(
              child: _buildEventsTitle(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildListDelegate(
                  _data.tideEvents.map((e) => _buildTideEventCard(e)).toList(),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnims[0],
      child: SlideTransition(
        position: _slideAnims[0],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // Point vert animé + lieu
              Row(
                children: [
                  _AnimatedDot(),
                  const SizedBox(width: 8),
                  Text(
                    _data.location,
                    style: GoogleFonts.inter(
                      color: _txt(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Horloge live
              ValueListenableBuilder<String>(
                valueListenable: _clockNotifier,
                builder: (context, time, _) => Text(
                  time,
                  style: GoogleFonts.inter(
                    color: _txt(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CARTE SCORE PRINCIPAL
  // ═══════════════════════════════════════════════════════════
  Widget _buildScoreCard() {
    return FadeTransition(
      opacity: _fadeAnims[1],
      child: SlideTransition(
        position: _slideAnims[1],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _card,
                  _card.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                // Gauge
                SizedBox(
                  width: 120,
                  height: 120,
                  child: RepaintBoundary(
                    child: _CircularGauge(
                      score: _data.overallScore,
                      level: _data.overallLevel,
                      animation: _ctrl,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge level
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _levelColor(_data.overallLevel)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _levelColor(_data.overallLevel)
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: _levelColor(_data.overallLevel),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _data.overallLabel,
                              style: GoogleFonts.inter(
                                color: _levelColor(_data.overallLevel),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Score basé sur marée,\nlune et conditions météo',
                        style: GoogleFonts.inter(
                          color: _txt(0.5),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'MEILLEURES HEURES',
                        style: GoogleFonts.inter(
                          color: _txt(0.35),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _data.bestHours.map((h) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 11,
                                  color: _accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  h,
                                  style: GoogleFonts.inter(
                                    color: _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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

  // ═══════════════════════════════════════════════════════════
  //  COURBE DE MARÉE
  // ═══════════════════════════════════════════════════════════
  Widget _buildCurveCard() {
    return FadeTransition(
      opacity: _fadeAnims[2],
      child: SlideTransition(
        position: _slideAnims[2],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.06),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Courbe des Marées · 24h',
                      style: GoogleFonts.inter(
                        color: _txt(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _legend('Maintenant', _green),
                    const SizedBox(width: 12),
                    _legend('HM', _accent),
                    const SizedBox(width: 12),
                    _legend('BM', _red),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: RepaintBoundary(
                    child: _TideCurvePainter(
                      points: _data.tidePoints,
                      events: _data.tideEvents,
                      currentHour: _data.currentHour + DateTime.now().minute / 60,
                      animation: _ctrl,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: _txt(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TITRE ACTIVITÉ PAR HEURE
  // ═══════════════════════════════════════════════════════════
  Widget _buildHourlyTitle() {
    return FadeTransition(
      opacity: _fadeAnims[3],
      child: SlideTransition(
        position: _slideAnims[3],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Activité par heure',
                style: GoogleFonts.inter(
                  color: _txt(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Glissez pour explorer',
                style: GoogleFonts.inter(
                  color: _txt(0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SCROLLER HORIZONTAL
  // ═══════════════════════════════════════════════════════════
  Widget _buildHourlyScroller() {
    return FadeTransition(
      opacity: _fadeAnims[4],
      child: SlideTransition(
        position: _slideAnims[4],
        child: SizedBox(
          height: 220,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.05, 0.95, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _data.hourlyCards.length,
              itemBuilder: (context, index) {
                final card = _data.hourlyCards[index];
                final isSelected = index == _selectedHourIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _HourlyCardWidget(
                    card: card,
                    isSelected: isSelected,
                    onTap: () => _onCardTap(index),
                    index: index,
                    animation: _ctrl,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BANNER SÉLECTIONNÉE
  // ═══════════════════════════════════════════════════════════
  Widget _buildSelectedBanner() {
    final selected = _data.hourlyCards[_selectedHourIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(_selectedHourIndex),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _levelColor(selected.activityLevel).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _levelColor(selected.activityLevel).withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heure sélectionnée',
                    style: GoogleFonts.inter(
                      color: _txt(0.4),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.label,
                    style: GoogleFonts.inter(
                      color: _txt(1.0),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Marée ${selected.tideTrend} · ${selected.tideHeight.toStringAsFixed(2)}m · ${selected.windSpeed}km/h ${selected.windDirection}',
                    style: GoogleFonts.inter(
                      color: _txt(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${selected.activityScore}',
                  style: GoogleFonts.inter(
                    color: _levelColor(selected.activityLevel),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'score activité',
                  style: GoogleFonts.inter(
                    color: _txt(0.4),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.activityLabel,
                  style: GoogleFonts.inter(
                    color: _levelColor(selected.activityLevel),
                    fontSize: 11,
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

  // ═══════════════════════════════════════════════════════════
  //  TITRE CONDITIONS
  // ═══════════════════════════════════════════════════════════
  Widget _buildConditionsTitle() {
    return FadeTransition(
      opacity: _fadeAnims[6],
      child: SlideTransition(
        position: _slideAnims[6],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Conditions',
                style: GoogleFonts.inter(
                  color: _txt(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _data.hourlyCards[_selectedHourIndex].label,
                style: GoogleFonts.inter(
                  color: _accent.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CONDITION CARDS
  // ═══════════════════════════════════════════════════════════
  Widget _buildConditionMoon(MoonInfo info) {
    return _ConditionCard(
      animation: _ctrl,
      delayIndex: 7,
      icon: '🌙',
      title: 'Phase Lune',
      value: info.phaseName,
      subtitle: info.influence,
      child: RepaintBoundary(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(painter: _MoonPainter(phase: 0.0)),
        ),
      ),
    );
  }

  Widget _buildConditionWind(WindInfo info) {
    return _ConditionCard(
      animation: _ctrl,
      delayIndex: 8,
      icon: '💨',
      title: 'Vent',
      value: '${info.speed} km/h ${info.direction}',
      subtitle: 'Rafales ±${info.gust} km/h',
      child: RepaintBoundary(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _WindLinesPainter(animation: _ctrl),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionWaves(WaveInfo info) {
    return _ConditionCard(
      animation: _ctrl,
      delayIndex: 9,
      icon: '🌊',
      title: 'Vagues',
      value: '${info.height}m / ${info.period}s',
      subtitle: info.swell,
      child: RepaintBoundary(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _WaveSinePainter(animation: _ctrl),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionSun(SunTimes info) {
    return _ConditionCard(
      animation: _ctrl,
      delayIndex: 10,
      icon: '☀️',
      title: 'Soleil',
      value: '${info.sunrise} — ${info.sunset}',
      subtitle: 'Or ${info.goldenHour}',
      child: RepaintBoundary(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _SunArcPainter(animation: _ctrl),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TITRE ÉVÉNEMENTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildEventsTitle() {
    return FadeTransition(
      opacity: _fadeAnims[8],
      child: SlideTransition(
        position: _slideAnims[8],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Événements marée',
                style: GoogleFonts.inter(
                  color: _txt(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CARTE ÉVÉNEMENT
  // ═══════════════════════════════════════════════════════════
  Widget _buildTideEventCard(TideEvent event) {
    final isHigh = event.type == 'high';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHigh ? _accent.withValues(alpha: 0.2) : _red.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHigh ? _accent : _red).withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                isHigh ? Icons.water : Icons.water_drop_outlined,
                color: isHigh ? _accent : _red,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                event.label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: isHigh ? _accent : _red,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatDecimalTime(event.time),
            style: GoogleFonts.inter(
              color: _txt(1.0),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${event.height.toStringAsFixed(2)}m NGF',
            style: GoogleFonts.inter(
              color: _txt(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  WIDGETS PRIVÉS
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
  final h = time.floor();
  final m = ((time - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

// ── Point vert animé ────────────────────────────────────────
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
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.6 + 0.4 * _c.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _green.withValues(alpha: 0.3 * _c.value),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── CircularGauge ───────────────────────────────────────────
class _CircularGauge extends StatelessWidget {
  final int score;
  final String level;
  final Animation<double> animation;

  const _CircularGauge({
    required this.score,
    required this.level,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = (score / 100 * animation.value).clamp(0.0, 1.0);
        return CustomPaint(
          painter: _GaugePainter(
            progress: progress,
            color: _levelColor(level),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(score * animation.value).round()}',
                  style: GoogleFonts.inter(
                    color: _levelColor(level),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '/100',
                  style: GoogleFonts.inter(
                    color: _txt(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                if (level == 'high')
                  ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.2).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
                      ),
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const stroke = 10.0;

    // Background arc
    final bgPaint = Paint()
      ..color = _txt(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.progress != progress;
}

// ── Courbe de marée ─────────────────────────────────────────
class _TideCurvePainter extends StatelessWidget {
  final List<TidePoint> points;
  final List<TideEvent> events;
  final double currentHour;
  final Animation<double> animation;

  const _TideCurvePainter({
    required this.points,
    required this.events,
    required this.currentHour,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _CurvePainter(
            points: points,
            events: events,
            currentHour: currentHour,
            progress: animation.value,
          ),
        );
      },
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<TidePoint> points;
  final List<TideEvent> events;
  final double currentHour;
  final double progress;

  _CurvePainter({
    required this.points,
    required this.events,
    required this.currentHour,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const padding = EdgeInsets.only(left: 30, right: 30, top: 20, bottom: 30);
    final w = size.width - padding.horizontal;
    final h = size.height - padding.vertical;

    final maxH = points.map((p) => p.height).reduce(math.max);
    final minH = points.map((p) => p.height).reduce(math.min);
    final range = (maxH - minH).clamp(0.1, 10.0);

    double xFor(double t) => padding.left + (t / 24.0) * w;
    double yFor(double height) =>
        padding.top + h - ((height - minH) / range) * h;

    // Build smooth path with cubic beziers
    final path = Path();
    path.moveTo(xFor(points.first.time), yFor(points.first.height));

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mx = (xFor(p0.time) + xFor(p1.time)) / 2;
      path.cubicTo(
        mx, yFor(p0.height),
        mx, yFor(p1.height),
        xFor(p1.time), yFor(p1.height),
      );
    }

    // Gradient fill under curve (draw-on effect)
    final fillPath = Path.from(path);
    fillPath.lineTo(xFor(points.last.time), size.height - padding.bottom);
    fillPath.lineTo(xFor(points.first.time), size.height - padding.bottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _accent.withValues(alpha: 0.25 * progress),
          _accent.withValues(alpha: 0.02 * progress),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw line with dash effect based on progress
    final linePaint = Paint()
      ..color = _accent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final m in metrics) {
      final drawLen = m.length * progress;
      final extract = m.extractPath(0, drawLen);
      canvas.drawPath(extract, linePaint);
    }

    // Event markers (HM/BM)
    for (final event in events) {
      final ex = xFor(event.time);
      final ey = yFor(event.height);
      final isHigh = event.type == 'high';
      final color = isHigh ? _accent : _red;

      // Triangle marker
      final markerPath = Path();
      if (isHigh) {
        markerPath.moveTo(ex, ey - 18);
        markerPath.lineTo(ex - 6, ey - 6);
        markerPath.lineTo(ex + 6, ey - 6);
      } else {
        markerPath.moveTo(ex, ey + 18);
        markerPath.lineTo(ex - 6, ey + 6);
        markerPath.lineTo(ex + 6, ey + 6);
      }
      markerPath.close();

      canvas.drawPath(
        markerPath,
        Paint()..color = color..style = PaintingStyle.fill,
      );

      // Label
      final textSpan = TextSpan(
        text: '${event.height.toStringAsFixed(2)}m',
        style: GoogleFonts.inter(
          color: color.withValues(alpha: 0.9),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
        canvas,
        Offset(ex - tp.width / 2,
            isHigh ? ey - 32 : ey + 20),
      );
    }

    // Now line
    if (progress > 0.7) {
      final nx = xFor(currentHour);
      final nowPaint = Paint()
        ..color = _green.withValues(alpha: (progress - 0.7) / 0.3 * 0.8)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(nx, padding.top - 5),
        Offset(nx, size.height - padding.bottom + 5),
        nowPaint,
      );

      // "MAINTENANT" label
      final labelSpan = TextSpan(
        text: 'MAINTENANT',
        style: GoogleFonts.inter(
          color: _green.withValues(alpha: (progress - 0.7) / 0.3),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      );
      final lp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)
        ..layout();
      lp.paint(canvas, Offset(nx - lp.width / 2, padding.top - 18));
    }

    // Hour labels
    for (final h in [0, 6, 12, 18, 24]) {
      final hx = xFor(h.toDouble());
      final label = '${h.toString().padLeft(2, '0')}:00';
      final span = TextSpan(
        text: label,
        style: GoogleFonts.inter(
          color: _txt(0.25 * progress),
          fontSize: 9,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
        canvas,
        Offset(hx - tp.width / 2, size.height - padding.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.progress != progress || old.currentHour != currentHour;
}

// ── Hourly Card Widget ──────────────────────────────────────
class _HourlyCardWidget extends StatelessWidget {
  final HourlyCard card;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;
  final Animation<double> animation;

  const _HourlyCardWidget({
    required this.card,
    required this.isSelected,
    required this.onTap,
    required this.index,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(card.activityLevel);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badges
            SizedBox(
              height: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (card.isNow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _green.withValues(alpha: 0.4), width: 0.5),
                      ),
                      child: Text(
                        'MAINTENANT',
                        style: GoogleFonts.inter(
                          color: _green,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (card.isIdeal && !card.isNow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.4), width: 0.5),
                      ),
                      child: Text(
                        'IDÉAL',
                        style: GoogleFonts.inter(
                          color: _accent,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Heure
            Text(
              card.label,
              style: GoogleFonts.inter(
                color: _txt(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            // Fish icon (simplified)
            _FishIcon(level: card.activityLevel, size: 28),
            const SizedBox(height: 8),
            // Score
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${card.activityScore}',
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '/100',
                  style: GoogleFonts.inter(
                    color: _txt(0.3),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: card.activityScore / 100,
                backgroundColor: _txt(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 10),
            // Marée
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  card.tideTrend == 'montante'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: _txt(0.4),
                  size: 10,
                ),
                const SizedBox(width: 2),
                Text(
                  '${card.tideHeight.toStringAsFixed(1)}m',
                  style: GoogleFonts.inter(
                    color: _txt(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Vent
            Text(
              '~${card.windSpeed}km/h',
              style: GoogleFonts.inter(
                color: _txt(0.35),
                fontSize: 9,
              ),
            ),
            // Vagues + Temp
            Text(
              '~${card.waveHeight.toStringAsFixed(1)}m  ${card.temp}°C',
              style: GoogleFonts.inter(
                color: _txt(0.35),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fish Icon (animé, avec nage + pulsation + glow) ────────
class _FishIcon extends StatefulWidget {
  final String level;
  final double size;

  const _FishIcon({required this.level, required this.size});

  @override
  State<_FishIcon> createState() => _FishIconState();
}

class _FishIconState extends State<_FishIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _swim;
  late final Animation<double> _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _swim = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );
    _glow = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(widget.level);
    final baseScale = widget.level == 'high'
        ? 1.0
        : (widget.level == 'mid' ? 0.7 : 0.45);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final swimValue = _swim.value * (widget.level == 'high' ? 1.0 : 0.5);
        final pulseValue = _pulse.value;
        final glowOpacity = widget.level == 'high'
            ? _glow.value
            : (widget.level == 'mid' ? _glow.value * 0.6 : _glow.value * 0.3);

        return Transform.scale(
          scale: baseScale * pulseValue,
          child: Transform.rotate(
            angle: swimValue,
            child: Container(
              width: widget.size,
              height: widget.size * 0.65,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(widget.size * 0.35),
                border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: glowOpacity),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Corps du poisson
                  CustomPaint(
                    size: Size(widget.size * 0.7, widget.size * 0.45),
                    painter: _FishBodyPainter(color: color),
                  ),
                  // Œil
                  Positioned(
                    left: widget.size * 0.55,
                    top: widget.size * 0.22,
                    child: Container(
                      width: widget.size * 0.1,
                      height: widget.size * 0.1,
                      decoration: BoxDecoration(
                        color: _txt(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: widget.size * 0.05,
                          height: widget.size * 0.05,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Painter du corps du poisson ────────────────────────────
class _FishBodyPainter extends CustomPainter {
  final Color color;

  _FishBodyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bodyPath = Path();
    final w = size.width;
    final h = size.height;

    // Corps ovale
    bodyPath.moveTo(w * 0.15, h * 0.5);
    bodyPath.quadraticBezierTo(w * 0.15, h * 0.15, w * 0.5, h * 0.15);
    bodyPath.quadraticBezierTo(w * 0.85, h * 0.15, w * 0.85, h * 0.5);
    bodyPath.quadraticBezierTo(w * 0.85, h * 0.85, w * 0.5, h * 0.85);
    bodyPath.quadraticBezierTo(w * 0.15, h * 0.85, w * 0.15, h * 0.5);
    bodyPath.close();

    canvas.drawPath(bodyPath, paint);

    // Queue triangulaire
    final tailPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final tailPath = Path();
    tailPath.moveTo(w * 0.15, h * 0.5);
    tailPath.lineTo(0, h * 0.25);
    tailPath.lineTo(0, h * 0.75);
    tailPath.close();
    canvas.drawPath(tailPath, tailPaint);

    // Nageoire dorsale
    final finPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final finPath = Path();
    finPath.moveTo(w * 0.4, h * 0.15);
    finPath.lineTo(w * 0.5, 0);
    finPath.lineTo(w * 0.6, h * 0.15);
    finPath.close();
    canvas.drawPath(finPath, finPaint);

    // Nageoire ventrale
    final finVPath = Path();
    finVPath.moveTo(w * 0.5, h * 0.85);
    finVPath.lineTo(w * 0.45, h);
    finVPath.lineTo(w * 0.55, h);
    finVPath.close();
    canvas.drawPath(finVPath, finPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Condition Card ──────────────────────────────────────────
class _ConditionCard extends StatelessWidget {
  final Animation<double> animation;
  final int delayIndex;
  final String icon;
  final String title;
  final String value;
  final String subtitle;
  final Widget child;

  const _ConditionCard({
    required this.animation,
    required this.delayIndex,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = delayIndex * 0.06;
    final anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(start.clamp(0, 0.8), (start + 0.25).clamp(0, 1.0),
            curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(anim),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _txt(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (subtitle.contains('Influence'))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subtitle.split(' ').last,
                        style: GoogleFonts.inter(
                          color: _accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (subtitle.contains('Rafales'))
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: _txt(0.35),
                        fontSize: 9,
                      ),
                    ),
                  if (subtitle.contains('Or'))
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: _amber.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.inter(
                            color: _txt(1.0),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!subtitle.contains('Influence') &&
                            !subtitle.contains('Rafales') &&
                            !subtitle.contains('Or'))
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              color: _txt(0.4),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  child,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CustomPainters ──────────────────────────────────────────

class _MoonPainter extends CustomPainter {
  final double phase; // 0.0 = nouvelle

  _MoonPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Dark moon
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFF2A3A55),
    );

    // Illuminated crescent
    final illumPaint = Paint()..color = const Color(0xFFFFE4B5);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r));

    // Simple crescent: clip with offset circle
    final clipPath = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(center.dx + r * 0.4, center.dy), radius: r));

    canvas.clipPath(
      Path.combine(PathOperation.difference, path, clipPath),
    );
    canvas.drawCircle(center, r, illumPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _WindLinesPainter extends CustomPainter {
  final Animation<double> animation;

  _WindLinesPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _accent.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final progress = animation.value;
    final yPositions = [0.25, 0.5, 0.75];

    for (int i = 0; i < yPositions.length; i++) {
      final y = size.height * yPositions[i];
      final len = size.width * 0.3 + (i * size.width * 0.15);
      final startX = size.width * 0.1;
      final drawLen = len * progress;

      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + drawLen, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _WaveSinePainter extends CustomPainter {
  final Animation<double> animation;

  _WaveSinePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final amplitude = size.height * 0.25;
    final frequency = 2 * math.pi / size.width;
    final offset = animation.value * math.pi * 2;

    path.moveTo(0, size.height / 2);
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height / 2 +
          amplitude * math.sin(frequency * x + offset);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _SunArcPainter extends CustomPainter {
  final Animation<double> animation;

  _SunArcPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.45;

    // Arc
    final arcPaint = Paint()
      ..color = _amber.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final arcPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi,
        math.pi,
      );
    canvas.drawPath(arcPath, arcPaint);

    // Sun dot moving along arc
    final sunProgress = 0.3 + animation.value * 0.4;
    final angle = math.pi * (1 - sunProgress);
    final sunX = center.dx + radius * math.cos(angle);
    final sunY = center.dy - radius * math.sin(angle);

    canvas.drawCircle(
      Offset(sunX, sunY),
      4,
      Paint()..color = _amber,
    );

    // Glow
    canvas.drawCircle(
      Offset(sunX, sunY),
      8,
      Paint()
        ..color = _amber.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
