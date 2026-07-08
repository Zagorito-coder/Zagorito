// ============================================================================
// windguru_page.dart
//
// Page complete "marees" style Windguru :
// - Barre de dates cliquables en haut (15 jours)
// - Tableau complet en dessous (vent, rafales, direction, houle, periode,
//   temperature, nuages, pluie, etoiles)
// - Cliquer sur une date fait defiler automatiquement le tableau
//
// Donnees : lues depuis Firestore (remplies chaque nuit par
// harvest_forecast.py + GitHub Actions)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/widgets/windguru_style_table.dart';
import 'package:spots_app/widgets/app_back_button.dart';

class WindguruPage extends StatefulWidget {
  final String spotId;

  const WindguruPage({super.key, required this.spotId});

  @override
  State<WindguruPage> createState() => _WindguruPageState();
}

class _WindguruPageState extends State<WindguruPage> {
  ScrollToSlotFn? _scrollToSlot;
  Future<SpotForecast>? _future;
  bool _isLoading = true;
  String? _error;

  static const _joursFr = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final forecast = await ForecastFirestoreService.fetchSpot(widget.spotId);
      if (!mounted) return;
      setState(() { _future = Future.value(forecast); _isLoading = false; });
    } catch (e) {
      debugPrint('[WindguruPage] Erreur: $e');
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsions Météo/Marée'),
        leading: const AppBackButton(),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Aucune donnée disponible',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Le spot "${widget.spotId}" n\'a pas encore de prévisions.\n'
                'Exécutez harvest_forecast.py pour remplir les données.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadForecast,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<SpotForecast>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final forecast = snapshot.data!;
        if (forecast.slots.isEmpty) {
          return const Center(
              child: Text('Aucune donnee disponible pour ce spot'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(forecast),
            _buildDateBar(forecast),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: ForecastTable(
                  modelName: forecast.locationName,
                  runLabel: forecast.lastUpdate != null
                      ? 'Maj : ${forecast.lastUpdate!.day}/${forecast.lastUpdate!.month} '
                          '${forecast.lastUpdate!.hour}h${forecast.lastUpdate!.minute.toString().padLeft(2, '0')}'
                      : '',
                  slots: forecast.slots,
                  onReady: (fn) => _scrollToSlot = fn,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(SpotForecast forecast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(forecast.locationName,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDateBar(SpotForecast forecast) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: forecast.dayStarts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final day = forecast.dayStarts[i];
          final slotIndex = forecast.dayStartIndexes[i];
          final isToday = _isSameDay(day, DateTime.now());

          return GestureDetector(
            onTap: () => _scrollToSlot?.call(slotIndex),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_joursFr[day.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          color: isToday ? Colors.white : Colors.grey[700])),
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}