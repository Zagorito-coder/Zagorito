// ============================================================
//  tide_service.dart — Service Open-Meteo MARINE API
//  Récupère wave_height (hauteur d'eau) + données vent/vagues
// ============================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/tide_data.dart';
import 'astronomy_service.dart';

class TideService {
  static const String _baseUrl = 'marine-api.open-meteo.com';

  /// Récupère les données marines pour une position donnée.
  /// Par défaut : Casablanca (33.57, -7.59)
  /// /v1/tide n'existe pas → on utilise wave_height de /v1/marine
  /// comme métrique de hauteur d'eau + vent/vagues pour le bandeau.
  static Future<TideData> fetchTides({
    double latitude = 33.57,
    double longitude = -7.59,
    String locationName = 'Casablanca Morocco',
  }) async {
    // Un seul appel : /v1/marine avec tous les champs nécessaires
    final uri = Uri.https(_baseUrl, '/v1/marine', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'hourly': 'wave_height,wind_wave_height,wind_wave_direction,wind_wave_period',
      'forecast_days': '1',
      'timezone': 'auto',
    });

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(uri).timeout(
          const Duration(seconds: 20),
        );

        if (response.statusCode != 200) {
          if (attempt == 0) continue;
          return TideData.fallback();
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final hourly = json['hourly'] as Map<String, dynamic>?;

        if (hourly == null) {
          if (attempt == 0) continue;
          return TideData.fallback();
        }

        final times = (hourly['time'] as List<dynamic>?)?.cast<String>() ?? [];
        // wave_height = hauteur significative des vagues (proxy hauteur d'eau)
        final waveHeights = (hourly['wave_height'] as List<dynamic>?)
                ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [];
        final windWaveHeights = (hourly['wind_wave_height'] as List<dynamic>?)
                ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [];
        final windWaveDirs = (hourly['wind_wave_direction'] as List<dynamic>?)
                ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [];
        final windWavePeriods = (hourly['wind_wave_period'] as List<dynamic>?)
                ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [];

        if (times.isEmpty || waveHeights.isEmpty) {
          if (attempt == 0) continue;
          return TideData.fallback();
        }

        // Construire les points horaires
        final int count = math.min(times.length, waveHeights.length);
        final List<TidePoint> points = [];
        for (int i = 0; i < count; i++) {
          final t = DateTime.tryParse(times[i]);
          if (t != null) {
            points.add(TidePoint(
              time: t,
              height: waveHeights[i],
              windWaveHeight: i < windWaveHeights.length ? windWaveHeights[i] : 0.0,
              windDirectionDeg: i < windWaveDirs.length ? windWaveDirs[i] : 0.0,
              wavePeriod: i < windWavePeriods.length ? windWavePeriods[i] : 7.0,
            ));
          }
        }

        if (points.isEmpty) {
          if (attempt == 0) continue;
          return TideData.fallback();
        }

        // Calculer LOW, HIGH, NEXT
        double minH = double.infinity;
        double maxH = -double.infinity;
        double maxWave = 0.0;
        for (final p in points) {
          if (p.height < minH) minH = p.height;
          if (p.height > maxH) maxH = p.height;
          if (p.windWaveHeight > maxWave) maxWave = p.windWaveHeight;
        }

        final now = DateTime.now();
        TidePoint? nextPoint;
        for (final p in points) {
          if (p.time.isAfter(now)) {
            nextPoint = p;
            break;
          }
        }
        final next = nextPoint?.height ?? points.last.height;

        final low = minH == double.infinity ? 0.3 : minH;
        final high = maxH == -double.infinity ? 2.5 : maxH;
        final waveHeight = maxWave > 0 ? maxWave : (high - low);

        final astro = AstronomyService.calculate(now, low, high);

        return TideData(
          hourlyPoints: points,
          low: low,
          high: high,
          next: next,
          waveHeight: waveHeight,
          location: locationName,
          astro: astro,
        );
      } catch (e, st) {
        debugPrint('[TideService] Erreur (tentative ${attempt + 1}): $e');
        if (attempt == 1) {
          debugPrint('$st');
          return TideData.fallback();
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return TideData.fallback();
  }
}
