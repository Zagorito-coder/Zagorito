// ============================================================
//  tide_service.dart — Service Open-Meteo Marine API
//  Récupère les hauteurs de mer en temps réel + données astro
// ============================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/tide_data.dart';
import 'astronomy_service.dart';

class TideService {
  static const String _baseUrl = 'marine-api.open-meteo.com';

  /// Récupère les données de marées pour une position donnée.
  /// Par défaut : Casablanca (33.57, -7.59)
  /// Retry 1x si timeout.
  static Future<TideData> fetchTides({
    double latitude = 33.57,
    double longitude = -7.59,
    String locationName = 'Casablanca Morocco',
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = Uri.https(_baseUrl, '/v1/marine', {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'hourly': 'wave_height',
          'timezone': 'auto',
        });

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
        final heights = (hourly['wave_height'] as List<dynamic>?)
                ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [];

        if (times.isEmpty || heights.isEmpty) {
          if (attempt == 0) continue;
          return TideData.fallback();
        }

        // Construire les points horaires
        final List<TidePoint> points = [];
        for (int i = 0; i < math.min(times.length, heights.length); i++) {
          final t = DateTime.tryParse(times[i]);
          if (t != null) {
            points.add(TidePoint(time: t, height: heights[i]));
          }
        }

        if (points.isEmpty) {
          if (attempt == 0) continue;
          return TideData.fallback();
        }

        // Calculer LOW, HIGH, NEXT
        double minH = double.infinity;
        double maxH = -double.infinity;
        for (final p in points) {
          if (p.height < minH) minH = p.height;
          if (p.height > maxH) maxH = p.height;
        }

        // Prochaine valeur = première heure future
        final now = DateTime.now();
        TidePoint? nextPoint;
        for (final p in points) {
          if (p.time.isAfter(now)) {
            nextPoint = p;
            break;
          }
        }
        final next = nextPoint?.height ?? points.last.height;

        final low = minH == double.infinity ? 0.4 : minH;
        final high = maxH == -double.infinity ? 3.9 : maxH;
        final waveHeight = (high - low) / 2;

        // Données astronomiques
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
        // Petit délai avant retry
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return TideData.fallback();
  }
}