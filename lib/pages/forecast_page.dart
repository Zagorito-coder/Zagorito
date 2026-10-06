import 'dart:async';
// ============================================================================
// forecast_page.dart
//
// Page complete "marees" style Forecast avec geolocalisation automatique :
// - Partage la sélection GPS ou manuelle avec la page Marées
// - Cherche le point météo existant le plus proche dans le catalogue local
// - Affiche le tableau Forecast pour ce spot
// - Permet de rechercher et sélectionner une ville
//
// Donnees : lues depuis Firestore (publiées par
// harvest_forecast.py + GitHub Actions)
// ============================================================================

import 'package:flutter/material.dart';
import '../services/marine_location_controller.dart';
import '../widgets/marine_location_selector.dart';
import '../data/marine_weather_points.dart';
import '../l10n/app_localizations.dart';
import 'package:spots_app/services/forecast_firestore_service.dart';
import 'package:spots_app/widgets/forecast_table.dart';
import 'package:spots_app/widgets/app_back_button.dart';
import 'package:spots_app/widgets/open_meteo_attribution.dart';
import 'package:spots_app/theme.dart';

@visibleForTesting
String? forecastSpotIdForPosition({
  required List<Map<String, dynamic>> spots,
  required double? latitude,
  required double? longitude,
}) {
  if (latitude == null || longitude == null) {
    return null;
  }
  return ForecastFirestoreService.nearestWeatherStationIdWithinRadius(
    stations: spots,
    latitude: latitude,
    longitude: longitude,
  );
}

class ForecastPage extends StatefulWidget {
  /// Si null, utilise la geolocalisation pour trouver le spot le plus proche.
  /// Sinon, utilise le spotId fourni directement.
  final String? spotId;

  final MarineLocationController? locationController;
  final Future<SpotForecast?> Function(String)? forecastLoader;
  const ForecastPage(
      {super.key, this.spotId, this.locationController, this.forecastLoader});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  ScrollToSlotFn? _scrollToSlot;
  Future<SpotForecast>? _future;
  bool _isLoading = true;
  String? _error;

  /// Index du jour selectionne dans `dayStarts`
  int? _selectedDayIndex;

  late final _location =
      widget.locationController ?? MarineLocationController.instance;
  int _locationRevision = -1;
  int _loadRequest = 0;

  static const _joursFr = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

  @override
  void initState() {
    super.initState();
    _location.addListener(_onLocationChanged);
    unawaited(_init());
  }

  @override
  void dispose() {
    _loadRequest++;
    _location.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _init() async {
    await _location.initialize();
    if (!mounted) return;
    if (widget.spotId != null) {
      final point =
          marineWeatherPoints.where((p) => p.id == widget.spotId).firstOrNull;
      if (point != null) await _location.selectManual(point);
    }
    if (mounted) _onLocationChanged();
  }

  void _onLocationChanged({bool force = false}) {
    if (!mounted || (!force && _locationRevision == _location.revision)) return;
    _locationRevision = _location.revision;
    final point = _location.weatherPoint;
    _loadRequest++;
    if (point == null) {
      setState(() {
        _future = null;
        _isLoading = false;
        _error = context.tr(_location.coordinates == null
            ? 'marineLocation.choose'
            : 'marineLocation.noWeather');
      });
      return;
    }
    unawaited(_loadForecast(point.id));
  }

  Future<void> _loadForecast(String spotId) async {
    final request = ++_loadRequest;
    setState(() {
      _isLoading = true;
      _error = null;
      _future = null;
    });
    try {
      final forecast = await (widget.forecastLoader ??
              ForecastFirestoreService.fetchSpot)(spotId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || request != _loadRequest) return;
      if (forecast == null) {
        setState(() {
          _error = 'Connectez-vous pour voir les prévisions météo.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _future = Future.value(forecast);
        _isLoading = false;
        _selectedDayIndex = _findDayIndexForToday(forecast);
      });
    } catch (e) {
      debugPrint('[ForecastPage] Erreur chargement $spotId: $e');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _error = 'Prévisions temporairement indisponibles pour ce lieu.';
        _isLoading = false;
      });
    }
  }

  int _findDayIndexForToday(SpotForecast forecast) {
    final now = forecast.stationTimeAt(DateTime.now());
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
      setState(() {
        _selectedDayIndex = dayIdx;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsions Météo/Marée'),
        leading: const AppBackButton(),
      ),
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
                child: MarineLocationSelector(controller: _location))
          ],
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final tc = ThemeColors.of(context);
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: tc.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Aucune donnée disponible',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: tc.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _onLocationChanged(force: true),
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

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(forecast),
                    _buildHeaderBandeau(forecast),
                    _buildDateBar(forecast),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          _buildLegacyTable(forecast),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          _buildMultiModelTables(forecast),
                          const OpenMeteoAttribution(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

  Widget _buildHeaderBandeau(SpotForecast forecast) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white70 : Colors.black87;
    final subColor = dark ? Colors.white54 : Colors.grey;

    String formatCoord(double? v) {
      if (v == null) return '-';
      return '${v.toStringAsFixed(2)}°';
    }

    String formatTime(String? iso) {
      if (iso == null || iso.trim().isEmpty) return '-';
      final parsed = DateTime.tryParse(iso.trim());
      if (parsed == null) return '-';
      return '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}';
    }

    String waterTempStr() {
      if (forecast.waterTempC == null) return '-';
      return '${forecast.waterTempC!.toStringAsFixed(1)}°C';
    }

    final selectedIndex = _selectedDayIndex ?? 0;
    final selectedSunrise = forecast.sunriseForDay(selectedIndex) ??
        (selectedIndex == 0 ? forecast.sunrise : null);
    final selectedSunset = forecast.sunsetForDay(selectedIndex) ??
        (selectedIndex == 0 ? forecast.sunset : null);

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
            formatTime(selectedSunrise),
            style: TextStyle(fontSize: 11, color: textColor),
          ),
          const SizedBox(width: 12),
          // Sunset
          Icon(Icons.nights_stay, size: 14, color: Colors.indigo),
          const SizedBox(width: 2),
          Text(
            formatTime(selectedSunset),
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
    final tc = ThemeColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                    ? tc.oceanMedium
                    : (dark ? tc.surfaceLight : const Color(0xFFF1F3F6)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? tc.oceanDeep : tc.glassBorder,
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
                          color: isSelected ? Colors.white : tc.textSecondary)),
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : tc.textPrimary)),
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
