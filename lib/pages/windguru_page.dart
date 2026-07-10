// ============================================================================
// windguru_page.dart
//
// Page complete "marees" style Windguru avec geolocalisation automatique :
// - Detecte la position GPS de l'utilisateur
// - Cherche le spot cotier le plus proche dans Firestore
// - Affiche le tableau Windguru pour ce spot
// - Permet de changer manuellement de spot via un dropdown
//
// Donnees : lues depuis Firestore (remplies chaque nuit par
// harvest_forecast.py + GitHub Actions)
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/widgets/windguru_style_table.dart';
import 'package:spots_app/widgets/app_back_button.dart';

class WindguruPage extends StatefulWidget {
  /// Si null, utilise la geolocalisation pour trouver le spot le plus proche.
  /// Sinon, utilise le spotId fourni directement.
  final String? spotId;

  const WindguruPage({super.key, this.spotId});

  @override
  State<WindguruPage> createState() => _WindguruPageState();
}

class _WindguruPageState extends State<WindguruPage> {
  ScrollToSlotFn? _scrollToSlot;
  Future<SpotForecast>? _future;
  bool _isLoading = true;
  String? _error;

  /// Index du jour selectionne dans `dayStarts`
  int? _selectedDayIndex;

  /// Liste des spots disponibles (charges depuis Firestore)
  List<Map<String, dynamic>> _availableSpots = [];
  String? _currentSpotId;

  static const _joursFr = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      // 1. Charger la liste des spots disponibles depuis Firestore
      _availableSpots = await ForecastFirestoreService.listAvailableSpots();

      if (_availableSpots.isEmpty) {
        setState(() {
          _error = 'Aucun spot disponible dans Firestore.\n'
              'Lancez harvest_forecast.py d\'abord.';
          _isLoading = false;
        });
        return;
      }

      // 2. Determiner quel spot utiliser
      String spotId;
      if (widget.spotId != null) {
        spotId = widget.spotId!;
      } else {
        spotId = await _findNearestSpot();
      }

      // 3. Charger les previsions
      await _loadForecast(spotId);
    } catch (e) {
      debugPrint('[WindguruPage] Erreur init: $e');
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  /// Trouve le spot le plus proche de la position GPS actuelle
  Future<String> _findNearestSpot() async {
    // Verifier les permissions
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      // GPS refuse → fallback sur le premier spot de la liste
      return _availableSpots.first['id'] as String;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // Trouver le spot le plus proche
      String nearestId = _availableSpots.first['id'] as String;
      double minDist = double.infinity;

      for (final spot in _availableSpots) {
        final dist = _haversine(
          pos.latitude, pos.longitude,
          spot['latitude'] as double, spot['longitude'] as double,
        );
        if (dist < minDist) {
          minDist = dist;
          nearestId = spot['id'] as String;
        }
      }
      return nearestId;
    } catch (_) {
      return _availableSpots.first['id'] as String;
    }
  }

  /// Distance Haversine en km
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Future<void> _loadForecast(String spotId) async {
    setState(() { _isLoading = true; _error = null; _currentSpotId = spotId; });
    try {
      final forecast = await ForecastFirestoreService.fetchSpot(spotId);
      if (!mounted) return;
      if (forecast == null) {
        setState(() { _error = 'Connectez-vous pour voir les prévisions météo.'; _isLoading = false; });
        return;
      }
      setState(() {
        _future = Future.value(forecast);
        _isLoading = false;
        _selectedDayIndex = _findDayIndexForToday(forecast);
      });
    } catch (e) {
      debugPrint('[WindguruPage] Erreur chargement $spotId: $e');
      if (!mounted) return;
      setState(() { _error = 'Spot "$spotId": ${e.toString()}'; _isLoading = false; });
    }
  }

  int _findDayIndexForToday(SpotForecast forecast) {
    final now = DateTime.now();
    for (int i = 0; i < forecast.dayStarts.length; i++) {
      if (_isSameDay(forecast.dayStarts[i], now)) return i;
    }
    return 0;
  }

  void _updateSelectedDayFromSlot(int slotIndex, SpotForecast forecast) {
    if (forecast.dayStartIndexes.isEmpty) return;
    int dayIdx = 0;
    for (int i = 0; i < forecast.dayStartIndexes.length; i++) {
      if (forecast.dayStartIndexes[i] <= slotIndex) {
        dayIdx = i;
      } else {
        break;
      }
    }
    if (dayIdx != _selectedDayIndex) {
      setState(() { _selectedDayIndex = dayIdx; });
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
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _init,
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

        // Verifier si on a des donnees multi-modeles
        final hasMultiModel = forecast.slots.any(
          (s) => s.modelWind != null || s.modelHires != null || s.modelWave != null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSpotSelector(forecast),
            _buildHeaderBandeau(forecast),
            _buildDateBar(forecast),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: hasMultiModel
                    ? _buildMultiModelTables(forecast)
                    : _buildLegacyTable(forecast),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpotSelector(SpotForecast forecast) {
    if (_availableSpots.length <= 1) {
      return _buildHeader(forecast);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentSpotId,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                items: _availableSpots.map((spot) {
                  return DropdownMenuItem<String>(
                    value: spot['id'] as String,
                    child: Text(
                      spot['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null && id != _currentSpotId) {
                    _loadForecast(id);
                  }
                },
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildHeaderBandeau(SpotForecast forecast) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white70 : Colors.black87;
    final subColor = dark ? Colors.white54 : Colors.grey;

    String formatCoord(double? v) {
      if (v == null) return '-';
      return '${v.toStringAsFixed(2)}°';
    }

    String formatTime(String? iso) {
      if (iso == null) return '-';
      // Extraire HH:MM de "2026-07-10T06:28"
      final parts = iso.split('T');
      if (parts.length == 2) return parts[1].substring(0, 5);
      return iso;
    }

    String waterTempStr() {
      if (forecast.waterTempC == null) return '-';
      return '${forecast.waterTempC!.toStringAsFixed(1)}°C';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: dark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Row(
        children: [
          // Lat / Lon
          Icon(Icons.public, size: 14, color: subColor),
          const SizedBox(width: 2),
          Text(
            '${formatCoord(forecast.latitude)} ${formatCoord(forecast.longitude)}',
            style: TextStyle(fontSize: 11, color: textColor),
          ),
          const SizedBox(width: 12),
          // Sunrise
          Icon(Icons.wb_sunny, size: 14, color: Colors.orange),
          const SizedBox(width: 2),
          Text(
            formatTime(forecast.sunrise),
            style: TextStyle(fontSize: 11, color: textColor),
          ),
          const SizedBox(width: 12),
          // Sunset
          Icon(Icons.nights_stay, size: 14, color: Colors.indigo),
          const SizedBox(width: 2),
          Text(
            formatTime(forecast.sunset),
            style: TextStyle(fontSize: 11, color: textColor),
          ),
          const SizedBox(width: 12),
          // Water temp
          Icon(Icons.water_drop, size: 14, color: Colors.blue),
          const SizedBox(width: 2),
          Text(
            'Eau ${waterTempStr()}',
            style: TextStyle(fontSize: 11, color: textColor),
          ),
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
          final isSelected = i == _selectedDayIndex;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDayIndex = i);
              _scrollToSlot?.call(slotIndex);
            },
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFE0E0E0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_joursFr[day.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : Colors.grey[700])),
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegacyTable(SpotForecast forecast) {
    return ForecastTable(
      modelName: forecast.locationName,
      runLabel: forecast.lastUpdate != null
          ? 'Maj : ${forecast.lastUpdate!.day}/${forecast.lastUpdate!.month} '
              '${forecast.lastUpdate!.hour}h${forecast.lastUpdate!.minute.toString().padLeft(2, '0')}'
          : '',
      slots: forecast.slots,
      model: TableModel.root,
      onReady: (fn) => _scrollToSlot = fn,
      onSlotScrolled: (slotIndex) {
        _updateSelectedDayFromSlot(slotIndex, forecast);
      },
    );
  }

  Widget _buildMultiModelTables(SpotForecast forecast) {
    return Column(
      children: [
        ForecastTable(
          modelName: '${forecast.locationName} — Vent GFS ~13km',
          runLabel: forecast.lastUpdate != null
              ? 'Maj : ${forecast.lastUpdate!.day}/${forecast.lastUpdate!.month} '
                  '${forecast.lastUpdate!.hour}h${forecast.lastUpdate!.minute.toString().padLeft(2, '0')}'
              : '',
          slots: forecast.slots,
          model: TableModel.wind,
          onReady: (fn) => _scrollToSlot = fn,
          onSlotScrolled: (slotIndex) {
            _updateSelectedDayFromSlot(slotIndex, forecast);
          },
        ),
        const SizedBox(height: 12),
        ForecastTable(
          modelName: '${forecast.locationName} — ECMWF IFS-HRES ~9km',
          runLabel: '',
          slots: forecast.slots,
          model: TableModel.hires,
        ),
        const SizedBox(height: 12),
        ForecastTable(
          modelName: '${forecast.locationName} — Vagues GFS-Wave',
          runLabel: '',
          slots: forecast.slots,
          model: TableModel.wave,
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
