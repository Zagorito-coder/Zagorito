// ============================================================================
// forecast_firestore_service.dart
//
// Lit le document Firestore rempli chaque nuit par harvest_forecast.py
// (collection "spots_meteo") et le convertit en List<ForecastSlot>
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spots_app/widgets/windguru_style_table.dart';

class SpotForecast {
  final String locationName;
  final DateTime? lastUpdate;
  final List<ForecastSlot> slots;
  final List<DateTime> dayStarts;
  final List<int> dayStartIndexes;

  SpotForecast({
    required this.locationName,
    required this.lastUpdate,
    required this.slots,
    required this.dayStarts,
    required this.dayStartIndexes,
  });
}

class ForecastFirestoreService {
  static final _db = FirebaseFirestore.instance;

  /// Recupere une seule fois les previsions d'un spot.
  static Future<SpotForecast> fetchSpot(String spotId) async {
    final doc = await _db.collection('spots_meteo').doc(spotId).get();
    if (!doc.exists) {
      throw Exception('Spot "$spotId" introuvable dans Firestore.');
    }
    return _parseDoc(doc.data()!);
  }

  /// Version "temps reel" : stream.
  static Stream<SpotForecast> watchSpot(String spotId) {
    return _db
        .collection('spots_meteo')
        .doc(spotId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) => _parseDoc(doc.data()!));
  }

  static SpotForecast _parseDoc(Map<String, dynamic> data) {
    final days = (data['days'] as List<dynamic>? ?? []);
    final List<ForecastSlot> allSlots = [];
    final List<DateTime> dayStarts = [];
    final List<int> dayStartIndexes = [];

    for (final dayRaw in days) {
      final day = dayRaw as Map<String, dynamic>;
      final slotsRaw = (day['slots'] as List<dynamic>? ?? []);
      if (slotsRaw.isEmpty) continue;

      dayStartIndexes.add(allSlots.length);
      bool first = true;

      for (final slotRaw in slotsRaw) {
        final s = slotRaw as Map<String, dynamic>;
        final dt = DateTime.parse(s['hour'] as String);
        if (first) dayStarts.add(DateTime(dt.year, dt.month, dt.day));

        allSlots.add(ForecastSlot(
          dateTime: dt,
          windSpeedKnots: (s['wind_speed_kt'] as num?)?.toDouble() ?? 0,
          windGustKnots: (s['wind_gust_kt'] as num?)?.toDouble() ?? 0,
          windDirectionDeg: (s['wind_dir_deg'] as num?)?.toDouble() ?? 0,
          waveHeightM: (s['wave_height_m'] as num?)?.toDouble() ?? 0,
          wavePeriodS: (s['wave_period_s'] as num?)?.toDouble() ?? 0,
          waveDirectionDeg: (s['wave_dir_deg'] as num?)?.toDouble() ?? 0,
          temperatureC: (s['temp_c'] as num?)?.toInt() ?? 0,
          cloudCoverPct: (s['cloud_pct'] as num?)?.toInt(),
          precipProbPct: (s['precip_pct'] as num?)?.toInt(),
          ratingStars: (s['rating'] as num?)?.toInt() ?? 0,
          isNewDay: first,
        ));
        first = false;
      }
    }

    final ts = data['last_update'];
    final lastUpdate = ts is Timestamp ? ts.toDate() : null;

    return SpotForecast(
      locationName: data['location_name'] as String? ?? '',
      lastUpdate: lastUpdate,
      slots: allSlots,
      dayStarts: dayStarts,
      dayStartIndexes: dayStartIndexes,
    );
  }
}