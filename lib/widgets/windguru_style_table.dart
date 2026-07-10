// ============================================================================
// windguru_style_table.dart
//
// Widget Flutter qui reproduit un tableau de prevalence style "Windguru" :
// - Colonnes = creneaux horaires (scroll horizontal synchronise)
// - Lignes = vent, rafales, direction (fleche), houle, periode, temperature,
//   couverture nuageuse, probabilite de pluie, notation en etoiles
// - Cellules colorees selon des seuils (comme sur la capture d'ecran)
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// Sous-objets modeles (additifs, nulles si absents)
// ============================================================================

/// Modele vent/haute-resolution (GFS ou ECMWF IFS-HRES).
class WindModelSlot {
  final double? windSpeedKt;
  final double? windGustKt;
  final double? windDirDeg;
  final double? tempC;
  final double? cloudLowPct;
  final double? cloudMidPct;
  final double? cloudHighPct;
  final double? precipProbPct;
  final double? pressureMsl;
  final double? relHumidityPct;

  const WindModelSlot({
    this.windSpeedKt,
    this.windGustKt,
    this.windDirDeg,
    this.tempC,
    this.cloudLowPct,
    this.cloudMidPct,
    this.cloudHighPct,
    this.precipProbPct,
    this.pressureMsl,
    this.relHumidityPct,
  });

  factory WindModelSlot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const WindModelSlot();
    double? n(String k) => (json[k] as num?)?.toDouble();
    // Verifier qu'au moins un champ essentiel est present
    final hasData = json.containsKey('wind_speed_kt') || json.containsKey('temp_c');
    if (!hasData) return const WindModelSlot();
    return WindModelSlot(
      windSpeedKt: n('wind_speed_kt'),
      windGustKt: n('wind_gust_kt'),
      windDirDeg: n('wind_dir_deg'),
      tempC: n('temp_c'),
      cloudLowPct: n('cloud_low_pct'),
      cloudMidPct: n('cloud_mid_pct'),
      cloudHighPct: n('cloud_high_pct'),
      precipProbPct: n('precip_prob_pct'),
      pressureMsl: n('pressure_msl'),
      relHumidityPct: n('rel_humidity_pct'),
    );
  }

  /// True si ce slot contient au moins une donnee reelle (pas juste des null).
  bool get hasData => windSpeedKt != null || tempC != null;
}

/// Modele vagues (GFS-Wave).
class WaveModelSlot {
  final double? waveHeightM;
  final double? wavePeriodS;
  final double? waveDirDeg;
  final double? swellHeightM;
  final double? swellPeriodS;
  final double? swellDirDeg;
  final double? swell2HeightM;
  final double? swell2PeriodS;
  final double? swell2DirDeg;
  final double? windwaveHeightM;
  final double? windwavePeriodS;
  final double? windwaveDirDeg;
  final double? sstC;

  const WaveModelSlot({
    this.waveHeightM,
    this.wavePeriodS,
    this.waveDirDeg,
    this.swellHeightM,
    this.swellPeriodS,
    this.swellDirDeg,
    this.swell2HeightM,
    this.swell2PeriodS,
    this.swell2DirDeg,
    this.windwaveHeightM,
    this.windwavePeriodS,
    this.windwaveDirDeg,
    this.sstC,
  });

  factory WaveModelSlot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const WaveModelSlot();
    double? n(String k) => (json[k] as num?)?.toDouble();
    final hasData = json.containsKey('wave_height_m') || json.containsKey('swell_wave_height');
    if (!hasData) return const WaveModelSlot();
    return WaveModelSlot(
      waveHeightM: n('wave_height_m'),
      wavePeriodS: n('wave_period_s'),
      waveDirDeg: n('wave_dir_deg'),
      swellHeightM: n('swell_height_m'),
      swellPeriodS: n('swell_period_s'),
      swellDirDeg: n('swell_dir_deg'),
      swell2HeightM: n('swell2_height_m'),
      swell2PeriodS: n('swell2_period_s'),
      swell2DirDeg: n('swell2_dir_deg'),
      windwaveHeightM: n('windwave_height_m'),
      windwavePeriodS: n('windwave_period_s'),
      windwaveDirDeg: n('windwave_dir_deg'),
      sstC: n('sst_c'),
    );
  }

  /// True si ce slot contient au moins une donnee reelle.
  bool get hasData => waveHeightM != null || swellHeightM != null;
}

/// Une "colonne" du tableau = un creneau horaire avec toutes ses valeurs.
class ForecastSlot {
  final DateTime dateTime;

  // Champs racine (compat arriere)
  final double windSpeedKnots;
  final double windGustKnots;
  final double windDirectionDeg;
  final double waveHeightM;
  final double wavePeriodS;
  final double waveDirectionDeg;
  final int temperatureC;
  final int? cloudCoverPct;
  final int? precipProbPct;
  final int ratingStars;
  final bool isNewDay;

  // Nouveaux sous-objets modeles (additifs, null si absents)
  final WindModelSlot? modelWind;
  final WindModelSlot? modelHires;
  final WaveModelSlot? modelWave;

  const ForecastSlot({
    required this.dateTime,
    required this.windSpeedKnots,
    required this.windGustKnots,
    required this.windDirectionDeg,
    required this.waveHeightM,
    required this.wavePeriodS,
    required this.waveDirectionDeg,
    required this.temperatureC,
    this.cloudCoverPct,
    this.precipProbPct,
    required this.ratingStars,
    this.isNewDay = false,
    this.modelWind,
    this.modelHires,
    this.modelWave,
  });
}

// ---------------------------------------------------------------------------
// Palette de couleurs (approximation du rendu Windguru)
// ---------------------------------------------------------------------------
class _Palette {
  static Color wind(double knots) {
    if (knots < 6) return const Color(0xFF9FE7D8);
    if (knots < 9) return const Color(0xFF7FE0A3);
    if (knots < 12) return const Color(0xFF57D25A);
    if (knots < 16) return const Color(0xFFF2E24A);
    if (knots < 20) return const Color(0xFFF2B23C);
    if (knots < 25) return const Color(0xFFF08A3C);
    if (knots < 30) return const Color(0xFFE8613C);
    return const Color(0xFFD8334A);
  }

  static Color wave(double meters) {
    if (meters < 1.0) return const Color(0xFFDDE3F5);
    if (meters < 1.8) return const Color(0xFFB9C6F0);
    if (meters < 2.5) return const Color(0xFF95A9EA);
    return const Color(0xFF7C90E0);
  }

  static Color temperature(int celsius) {
    if (celsius < 18) return const Color(0xFFCDEBFF);
    if (celsius < 22) return const Color(0xFFFCE79A);
    if (celsius < 26) return const Color(0xFFF7B85C);
    if (celsius < 29) return const Color(0xFFF08A3C);
    return const Color(0xFFE05A4A);
  }

  static Color cloud(int pct) {
    final v = (255 - (pct * 1.6)).clamp(140, 255).toDouble();
    return Color.fromARGB(255, v.toInt(), v.toInt(), v.toInt());
  }

  static Color precip(int pct) {
    if (pct < 10) return const Color(0xFFFFFDE7);
    if (pct < 40) return const Color(0xFFFFF59D);
    if (pct < 70) return const Color(0xFFFFE082);
    return const Color(0xFFFFCC80);
  }

  static const headerDay = Color(0xFFEDEDED);
  static const border = Color(0xFFE0E0E0);
}

// ---------------------------------------------------------------------------
// Widget principal
// ---------------------------------------------------------------------------
/// Callback expose par ForecastTable pour permettre a un widget parent
/// (ex: une barre de dates) de faire defiler le tableau jusqu'a un index
/// de creneau precis (utilise l'index dans `slots`).
typedef ScrollToSlotFn = void Function(int slotIndex, {bool animate});

/// Modele de donnees affiche par le tableau.
enum TableModel {
  /// Tableau racine historique (vent GFS + houle).
  root,

  /// Modele vent GFS ~13km.
  wind,

  /// Modele haute resolution ECMWF IFS-HRES ~9km.
  hires,

  /// Modele vagues GFS-Wave.
  wave,
}

class ForecastTable extends StatefulWidget {
  final String modelName;
  final String runLabel;
  final List<ForecastSlot> slots;
  final double columnWidth;
  final double labelColumnWidth;

  /// Modele de donnees a afficher. [TableModel.root] par defaut.
  final TableModel model;

  /// Appele une fois le widget monte, avec une fonction que le parent peut
  /// garder de cote et appeler plus tard.
  final void Function(ScrollToSlotFn scrollToSlot)? onReady;

  /// Notifie le parent du premier slot visible apres chaque scroll
  /// (permet de synchroniser la barre de dates).
  final void Function(int slotIndex)? onSlotScrolled;

  const ForecastTable({
    super.key,
    required this.modelName,
    required this.runLabel,
    required this.slots,
    this.columnWidth = 46,
    this.labelColumnWidth = 46,
    this.model = TableModel.root,
    this.onReady,
    this.onSlotScrolled,
  });

  @override
  State<ForecastTable> createState() => _ForecastTableState();
}

class _ForecastTableState extends State<ForecastTable> {
  final ScrollController _headerController = ScrollController();
  final ScrollController _bodyController = ScrollController();
  bool _syncing = false;

  static const double _rowHeight = 34;

  @override
  void initState() {
    super.initState();
    _headerController.addListener(() => _sync(_headerController, _bodyController));
    _bodyController.addListener(() => _sync(_bodyController, _headerController));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady?.call(_scrollToSlot);
    });
  }

  void _scrollToSlot(int slotIndex, {bool animate = true}) {
    if (!_bodyController.hasClients) return;
    final target = (slotIndex * widget.columnWidth)
        .clamp(0.0, _bodyController.position.maxScrollExtent);
    for (final c in [_bodyController, _headerController]) {
      if (!c.hasClients) continue;
      if (animate) {
        c.animateTo(target,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      } else {
        c.jumpTo(target);
      }
    }
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients) return;
    _syncing = true;
    to.jumpTo(from.offset);
    _syncing = false;
    // Notifie le parent du 1er slot visible
    _notifyVisibleSlot();
  }

  void _notifyVisibleSlot() {
    if (!_bodyController.hasClients || widget.onSlotScrolled == null) return;
    final offset = _bodyController.offset;
    final idx = (offset / widget.columnWidth).floor().clamp(0, widget.slots.length - 1);
    widget.onSlotScrolled!(idx);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<String> get _labels {
    switch (widget.model) {
      case TableModel.root:
        return ['kts', 'rafales', '', 'houle m', 'periode s', '', 'temp C', 'nuages %', 'pluie %', 'note'];
      case TableModel.wind:
      case TableModel.hires:
        return ['kts', 'rafales', '', 'temp C', 'nuage B', 'nuage M', 'nuage H', 'pluie %', 'hPa', 'humidite'];
      case TableModel.wave:
        return ['tot. m', 'per. s', '', 'S1 m', 'S1 s', '', 'S2 m', 'S2 s', '', 'VV m', 'VV s', ''];
    }
  }

  double get _bodyHeight {
    final n = _labels.length;
    return _rowHeight * n;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre du modele
        Builder(builder: (context) {
          final dark = _isDark(context);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Text(
                  widget.modelName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: dark ? Colors.white : Colors.black87),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.runLabel,
                  style: TextStyle(
                      color: dark ? Colors.white54 : Colors.grey,
                      fontSize: 12),
                ),
              ],
            ),
          );
        }),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne fixe des labels
            SizedBox(
              width: widget.labelColumnWidth,
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  ..._labels.map((l) => _labelCell(l)),
                ],
              ),
            ),
            // Partie scrollable
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      controller: _headerController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      itemCount: widget.slots.length,
                      itemBuilder: (_, i) => _headerCell(widget.slots[i]),
                    ),
                  ),
                  SizedBox(
                    height: _bodyHeight,
                    child: ListView.builder(
                      controller: _bodyController,
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.slots.length,
                      itemBuilder: (_, i) => _dataColumn(widget.slots[i]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Widget _labelCell(String text) => Builder(builder: (context) {
        final dark = _isDark(context);
        return Container(
          height: _rowHeight,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: dark ? Colors.white12 : _Palette.border),
            ),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 10,
                  color: dark ? Colors.white54 : Colors.grey)),
        );
      });

  Widget _headerCell(ForecastSlot s) {
    final day =
        '${_weekday(s.dateTime)}\n${s.dateTime.day.toString().padLeft(2, '0')}.';
    final hour = '${s.dateTime.hour.toString().padLeft(2, '0')}h';
    return Builder(builder: (context) {
      final dark = _isDark(context);
      final bg = s.isNewDay
          ? (dark ? const Color(0xFF2A2A2A) : _Palette.headerDay)
          : (dark ? const Color(0xFF1E1E1E) : Colors.white);
      final borderColor = dark ? Colors.white12 : _Palette.border;
      return Container(
        width: widget.columnWidth,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(day,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white70 : Colors.black87)),
            Text(hour,
                style: TextStyle(
                    fontSize: 9,
                    color: dark ? Colors.white38 : Colors.grey)),
          ],
        ),
      );
    });
  }

  Widget _dataColumn(ForecastSlot s) {
    return Container(
      width: widget.columnWidth,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _Palette.border)),
      ),
      child: _buildRows(s),
    );
  }

  Widget _buildRows(ForecastSlot s) {
    switch (widget.model) {
      case TableModel.root:
        return _buildRootRows(s);
      case TableModel.wind:
        return _buildWindRows(s);
      case TableModel.hires:
        return _buildWindRows(s, useHires: true);
      case TableModel.wave:
        return _buildWaveRows(s);
    }
  }

  Column _buildRootRows(ForecastSlot s) {
    return Column(
      children: [
        _valueCell(s.windSpeedKnots.toStringAsFixed(1),
            _Palette.wind(s.windSpeedKnots)),
        _valueCell(s.windGustKnots.toStringAsFixed(1),
            _Palette.wind(s.windGustKnots)),
        _arrowCell(s.windDirectionDeg),
        _valueCell(
            s.waveHeightM.toStringAsFixed(1), _Palette.wave(s.waveHeightM)),
        _valueCell(s.wavePeriodS.toStringAsFixed(0),
            _Palette.wave(s.wavePeriodS / 2)),
        _arrowCell(s.waveDirectionDeg),
        _valueCell(s.temperatureC.toString(),
            _Palette.temperature(s.temperatureC)),
        s.cloudCoverPct != null
            ? _valueCell('${s.cloudCoverPct}', _Palette.cloud(s.cloudCoverPct!))
            : _emptyCell(),
        s.precipProbPct != null
            ? _valueCell(
                '${s.precipProbPct}', _Palette.precip(s.precipProbPct!))
            : _emptyCell(),
        _starsCell(s.ratingStars),
      ],
    );
  }

  Column _buildWindRows(ForecastSlot s, {bool useHires = false}) {
    final m = useHires ? s.modelHires : s.modelWind;

    String fmt(double? v) => v != null ? v.toStringAsFixed(1) : '-';

    return Column(
      children: [
        _valueCell(
            fmt(m?.windSpeedKt),
            m?.windSpeedKt != null
                ? _Palette.wind(m!.windSpeedKt!)
                : Colors.grey[200]!),
        _valueCell(
            fmt(m?.windGustKt),
            m?.windGustKt != null
                ? _Palette.wind(m!.windGustKt!)
                : Colors.grey[200]!),
        _arrowCell(m?.windDirDeg ?? 0),
        _valueCell(
            m?.tempC != null ? '${m!.tempC!.round()}' : '-',
            m?.tempC != null
                ? _Palette.temperature(m!.tempC!.round())
                : Colors.grey[200]!),
        _valueCell(
            m?.cloudLowPct != null ? '${m!.cloudLowPct!.round()}' : '-',
            Colors.transparent),
        _valueCell(
            m?.cloudMidPct != null ? '${m!.cloudMidPct!.round()}' : '-',
            Colors.transparent),
        _valueCell(
            m?.cloudHighPct != null ? '${m!.cloudHighPct!.round()}' : '-',
            Colors.transparent),
        _valueCell(
            m?.precipProbPct != null ? '${m!.precipProbPct!.round()}' : '-',
            m?.precipProbPct != null
                ? _Palette.precip(m!.precipProbPct!.round())
                : Colors.grey[200]!),
        _valueCell(
            m?.pressureMsl != null
                ? '${m!.pressureMsl!.toStringAsFixed(0)}'
                : '-',
            Colors.transparent),
        _valueCell(
            m?.relHumidityPct != null
                ? '${m!.relHumidityPct!.round()}%'
                : '-',
            Colors.transparent),
      ],
    );
  }

  Column _buildWaveRows(ForecastSlot s) {
    final m = s.modelWave;

    return Column(
      children: [
        // Vague totale (significative)
        _valueCell(
            m?.waveHeightM != null ? m!.waveHeightM!.toStringAsFixed(1) : '-',
            m?.waveHeightM != null
                ? _Palette.wave(m!.waveHeightM!)
                : Colors.grey[200]!),
        _valueCell(
            m?.wavePeriodS != null ? m!.wavePeriodS!.toStringAsFixed(0) : '-',
            Colors.transparent),
        _arrowCell(m?.waveDirDeg ?? 0),
        const SizedBox(height: 6),
        // Houle primaire
        _valueCell(
            m?.swellHeightM != null ? m!.swellHeightM!.toStringAsFixed(1) : '-',
            m?.swellHeightM != null
                ? _Palette.wave(m!.swellHeightM!)
                : Colors.grey[200]!),
        _valueCell(
            m?.swellPeriodS != null
                ? m!.swellPeriodS!.toStringAsFixed(0)
                : '-',
            Colors.transparent),
        _arrowCell(m?.swellDirDeg ?? 0),
        const SizedBox(height: 6),
        // Houle secondaire
        _valueCell(
            m?.swell2HeightM != null
                ? m!.swell2HeightM!.toStringAsFixed(1)
                : '-',
            m?.swell2HeightM != null
                ? _Palette.wave(m!.swell2HeightM!)
                : Colors.grey[200]!),
        _valueCell(
            m?.swell2PeriodS != null
                ? m!.swell2PeriodS!.toStringAsFixed(0)
                : '-',
            Colors.transparent),
        _arrowCell(m?.swell2DirDeg ?? 0),
        const SizedBox(height: 6),
        // Vagues de vent locales
        _valueCell(
            m?.windwaveHeightM != null
                ? m!.windwaveHeightM!.toStringAsFixed(1)
                : '-',
            m?.windwaveHeightM != null
                ? _Palette.wave(m!.windwaveHeightM!)
                : Colors.grey[200]!),
        _valueCell(
            m?.windwavePeriodS != null
                ? m!.windwavePeriodS!.toStringAsFixed(0)
                : '-',
            Colors.transparent),
        _arrowCell(m?.windwaveDirDeg ?? 0),
      ],
    );
  }

  Widget _valueCell(String text, Color color) => Container(
        height: _rowHeight,
        color: color,
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textColorForBg(color)),
        ),
      );

  /// Choisit noir ou blanc selon la luminosite du fond
  Color _textColorForBg(Color bg) {
    final lum = bg.computeLuminance();
    return lum > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _emptyCell() => Builder(builder: (context) {
        final dark = _isDark(context);
        return SizedBox(
          height: _rowHeight,
          child: Center(
              child: Text('-',
                  style: TextStyle(
                      color: dark ? Colors.white30 : Colors.grey))),
        );
      });

  Widget _arrowCell(double directionDeg) => Builder(builder: (context) {
        final dark = _isDark(context);
        return SizedBox(
          height: _rowHeight,
          child: Center(
            child: Transform.rotate(
              angle: (directionDeg + 180) * 3.14159265 / 180,
              child: Icon(Icons.arrow_upward,
                  size: 16, color: dark ? Colors.white70 : Colors.black87),
            ),
          ),
        );
      });

  Widget _starsCell(int count) => SizedBox(
        height: _rowHeight,
        child: Center(
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                count.clamp(0, 5),
                (_) => const Icon(Icons.star,
                    size: 12, color: Color(0xFFF5A623)),
              ),
            ),
          ),
        ),
      );

  String _weekday(DateTime d) {
    const names = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
    return names[d.weekday - 1];
  }
}

// ---------------------------------------------------------------------------
// EXEMPLE D'UTILISATION (demo / debug)
// ---------------------------------------------------------------------------
class ForecastDemoPage extends StatelessWidget {
  const ForecastDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final start = DateTime(2017, 11, 10, 8);
    final slots = List.generate(20, (i) {
      final dt = start.add(Duration(hours: i * 3));
      return ForecastSlot(
        dateTime: dt,
        windSpeedKnots: 5 + (i % 7) * 1.3,
        windGustKnots: 7 + (i % 7) * 1.6,
        windDirectionDeg: (150 + i * 8) % 360,
        waveHeightM: 1.5 + (i % 5) * 0.3,
        wavePeriodS: 12 + (i % 4),
        waveDirectionDeg: (200 + i * 5) % 360,
        temperatureC: 20 + (i % 6),
        cloudCoverPct: i % 3 == 0 ? null : (i * 7) % 100,
        precipProbPct: i % 4 == 0 ? null : (i * 5) % 100,
        ratingStars: (i % 6),
        isNewDay: i % 8 == 0,
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Demo - ForecastTable')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: ForecastTable(
          modelName: 'GFS 27 km',
          runLabel: '10.11.2017 00 UTC',
          slots: slots,
        ),
      ),
    );
  }
}