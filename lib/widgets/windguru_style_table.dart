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

/// Une "colonne" du tableau = un creneau horaire avec toutes ses valeurs.
class ForecastSlot {
  final DateTime dateTime;
  final double windSpeedKnots;
  final double windGustKnots;
  final double windDirectionDeg; // direction d'ou vient le vent, 0 = Nord
  final double waveHeightM;
  final double wavePeriodS;
  final double waveDirectionDeg;
  final int temperatureC;
  final int? cloudCoverPct; // null => cellule vide "-"
  final int? precipProbPct; // null => cellule vide "-"
  final int ratingStars; // 0 a 5
  final bool isNewDay; // true si c'est le premier creneau d'un nouveau jour

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

class ForecastTable extends StatefulWidget {
  final String modelName;
  final String runLabel;
  final List<ForecastSlot> slots;
  final double columnWidth;
  final double labelColumnWidth;

  /// Appele une fois le widget monte, avec une fonction que le parent peut
  /// garder de cote et appeler plus tard.
  final void Function(ScrollToSlotFn scrollToSlot)? onReady;

  const ForecastTable({
    super.key,
    required this.modelName,
    required this.runLabel,
    required this.slots,
    this.columnWidth = 46,
    this.labelColumnWidth = 46,
    this.onReady,
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
  }

  @override
  void dispose() {
    _headerController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre du modele
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Text(
                widget.modelName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Text(
                widget.runLabel,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne fixe des labels
            SizedBox(
              width: widget.labelColumnWidth,
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _labelCell('kts'),
                  _labelCell('rafales'),
                  _labelCell(''),
                  _labelCell('houle m'),
                  _labelCell('periode s'),
                  _labelCell(''),
                  _labelCell('temp C'),
                  _labelCell('nuages %'),
                  _labelCell('pluie %'),
                  _labelCell('note'),
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
                    height: _rowHeight * 10,
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

  Widget _labelCell(String text) => Container(
        height: _rowHeight,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 4),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: _Palette.border)),
        ),
        child:
            Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      );

  Widget _headerCell(ForecastSlot s) {
    final day =
        '${_weekday(s.dateTime)}\n${s.dateTime.day.toString().padLeft(2, '0')}.';
    final hour = '${s.dateTime.hour.toString().padLeft(2, '0')}h';
    return Container(
      width: widget.columnWidth,
      decoration: BoxDecoration(
        color: s.isNewDay ? _Palette.headerDay : Colors.white,
        border: const Border(
          left: BorderSide(color: _Palette.border),
          bottom: BorderSide(color: _Palette.border),
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold)),
          Text(hour,
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _dataColumn(ForecastSlot s) {
    return Container(
      width: widget.columnWidth,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _Palette.border)),
      ),
      child: Column(
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
          _valueCell('${s.temperatureC}',
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
      ),
    );
  }

  Widget _valueCell(String text, Color color) => Container(
        height: _rowHeight,
        color: color,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _emptyCell() => SizedBox(
        height: _rowHeight,
        child:
            const Center(child: Text('-', style: TextStyle(color: Colors.grey))),
      );

  Widget _arrowCell(double directionDeg) => SizedBox(
        height: _rowHeight,
        child: Center(
          child: Transform.rotate(
            angle: (directionDeg + 180) * 3.14159265 / 180,
            child: const Icon(Icons.arrow_upward,
                size: 16, color: Colors.black87),
          ),
        ),
      );

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