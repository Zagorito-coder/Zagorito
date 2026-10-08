import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/data/marine_weather_points.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/services/astronomy_service.dart';
import 'package:spots_app/services/casablanca_tide_reference.dart';
import 'package:spots_app/services/tide_service.dart';
import 'package:spots_app/utils/tide_chart_scale.dart';

void main() {
  test('retrouve les quatre extrema de Casablanca au plus près de la table',
      () {
    // Le 07/08/2026, Casablanca est à UTC+1. La journée locale commence donc
    // le 06/08 à 23:00 UTC.
    final startUtc = DateTime.utc(2026, 8, 6, 23);
    final heights = List<double>.generate(
      24 * 60,
      (minute) => CasablancaTideReference.heightAtUtc(
        startUtc.add(Duration(minutes: minute)),
      ),
      growable: false,
    );

    final extrema = <({String type, int minute, double height})>[];
    for (var index = 1; index < heights.length - 1; index++) {
      final previous = heights[index - 1];
      final current = heights[index];
      final next = heights[index + 1];
      if (current < previous && current < next) {
        extrema.add((type: 'low', minute: index, height: current));
      } else if (current > previous && current > next) {
        extrema.add((type: 'high', minute: index, height: current));
      }
    }

    expect(extrema, hasLength(4));
    const expected = [
      (type: 'low', minute: 3 * 60, height: 1.4),
      (type: 'high', minute: 9 * 60 + 24, height: 2.9),
      (type: 'low', minute: 15 * 60 + 47, height: 1.4),
      (type: 'high', minute: 22 * 60 + 6, height: 2.8),
    ];

    for (var index = 0; index < expected.length; index++) {
      expect(extrema[index].type, expected[index].type);
      expect(
        (extrema[index].minute - expected[index].minute).abs(),
        lessThanOrEqualTo(10),
      );
      expect(
        (extrema[index].height - expected[index].height).abs(),
        lessThanOrEqualTo(0.1),
      );
    }
  });

  test('la courbe Casablanca utilise une échelle fixe 0 à 5 sans écrêtage', () {
    final source = File('lib/pages/tide_page.dart').readAsStringSync();
    final scale = TideChartScale.forValues(
      const [1.05, 3.39],
      fixedChartDatumScale: true,
      usesMeanSeaLevelDatum: false,
    );

    expect(scale.min, 0);
    expect(scale.max, 5);
    expect(scale.contains(1.05), isTrue);
    expect(scale.contains(3.39), isTrue);
    expect(source, contains("context.tr('tide.tideCurveJrcSource')"));
    expect(
      source,
      isNot(contains('height.clamp(0.0, 5.0)')),
      reason: 'Écrêter les valeurs fausserait les extrema de marée.',
    );
  });

  test('calibre le niveau Casablanca sans altérer les conditions marines', () {
    final now = DateTime.utc(2026, 8, 8, 12);
    final source = TideData(
      hourlyPoints: [
        TidePoint(
          time: now.subtract(const Duration(hours: 1)),
          height: -0.9,
          windDirectionDeg: 315,
          wavePeriod: 8,
          windWaveHeight: 1.2,
          windSpeedKmh: 22,
          pressureHpa: 1014,
        ),
        TidePoint(
          time: now.add(const Duration(hours: 1)),
          height: -0.8,
          windDirectionDeg: 320,
          wavePeriod: 9,
          windWaveHeight: 1.3,
          windSpeedKmh: 24,
          pressureHpa: 1015,
        ),
      ],
      low: -0.9,
      high: -0.8,
      next: -0.8,
      waveHeight: 1.3,
      location: 'Casablanca, Maroc',
      astro: AstroData.fallback(),
    );

    final calibrated = CasablancaTideReference.calibrateForecast(
      source,
      now: now,
    );

    expect(calibrated.tideHeightDatum, TideHeightDatum.casablancaBmi);
    expect(calibrated.next, greaterThan(0));
    expect(calibrated.low, greaterThanOrEqualTo(0));
    expect(calibrated.hourlyPoints.first.windWaveHeight, 1.2);
    expect(calibrated.hourlyPoints.first.windSpeedKmh, 22);
    expect(calibrated.hourlyPoints.first.pressureHpa, 1014);
    expect(calibrated.waveHeight, source.waveHeight);
    expect(calibrated.astro, same(source.astro));
  });

  test(
      'le modèle de présentation mondial conserve la courbe locale et le marnage',
      () {
    final now = DateTime(2026, 10, 7, 12);
    final source = TideData(
      hourlyPoints: [
        TidePoint(
          time: now.subtract(const Duration(hours: 1)),
          height: -1.48,
          windWaveHeight: 0.7,
        ),
        TidePoint(
          time: now.add(const Duration(hours: 1)),
          height: 0.96,
          windWaveHeight: 0.8,
        ),
      ],
      low: -1.48,
      high: 0.96,
      next: 0.96,
      waveHeight: 0.8,
      location: 'Dakar, Sénégal',
      tideHeightDatum: TideHeightDatum.globalMeanSeaLevel,
      astro: AstroData.fallback(),
    );

    final calibrated = CasablancaTideReference.calibratePublishedForecast(
      source,
      now: now,
    );

    expect(
      calibrated.tideHeightDatum,
      TideHeightDatum.casablancaPresentationModel,
    );
    expect(calibrated.low, closeTo(0.626, 0.002));
    expect(calibrated.high, closeTo(3.066, 0.002));
    expect(
      calibrated.high - calibrated.low,
      closeTo(source.high - source.low, 1e-9),
      reason: 'Le décalage vertical ne doit jamais modifier le marnage local.',
    );
    expect(calibrated.next, closeTo(calibrated.high, 1e-9));
    expect(calibrated.hourlyPoints.first.time, source.hourlyPoints.first.time);
    expect(calibrated.hourlyPoints.first.windWaveHeight, 0.7);
    expect(calibrated.waveHeight, source.waveHeight);
    expect(calibrated.astro, same(source.astro));
  });

  test('une station à fort marnage étend son axe sans écrêtage', () {
    final offset = CasablancaTideReference.presentationOffsetForMeanSeaLevel(
      sourceLow: -4,
      sourceHigh: 2,
    );
    final values = [-4 + offset, 2 + offset];
    final scale = TideChartScale.forValues(
      values,
      fixedChartDatumScale: true,
      usesMeanSeaLevelDatum: false,
    );

    expect(values, [0, 6]);
    expect(scale.min, 0);
    expect(scale.max, 6);
    expect(values.every(scale.contains), isTrue);
  });

  test('le service applique le bon repère aux 143 lieux du sélecteur manuel',
      () {
    final now = DateTime.utc(2026, 10, 7, 12);
    final source = TideData(
      hourlyPoints: [
        TidePoint(time: now.subtract(const Duration(hours: 1)), height: -0.8),
        TidePoint(time: now.add(const Duration(hours: 1)), height: 0.6),
      ],
      low: -0.8,
      high: 0.6,
      next: 0.6,
      waveHeight: 1,
      location: 'Station',
      tideHeightDatum: TideHeightDatum.globalMeanSeaLevel,
      astro: AstroData.fallback(),
    );

    expect(marineWeatherPoints, hasLength(143));
    for (final point in marineWeatherPoints) {
      final station = TideStation(
        id: point.id,
        name: point.name,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      final result = TideService.applyPresentationReference(
        station,
        source,
        now: now,
      );
      expect(
        result.tideHeightDatum,
        station.id == 'casablanca_maroc'
            ? TideHeightDatum.casablancaBmi
            : TideHeightDatum.casablancaPresentationModel,
        reason: station.id,
      );
      expect(result.low, greaterThanOrEqualTo(0), reason: station.id);
      if (station.id != 'casablanca_maroc') {
        expect(
          result.high - result.low,
          closeTo(1.4, 1e-12),
          reason: station.id,
        );
      }
    }
  });

  test('le repli hors ligne Casablanca conserve le référentiel BMI', () {
    final fallback = TideService.casablancaOfflineFallback(
      now: DateTime.utc(2026, 8, 8, 12),
    );

    expect(fallback.tideHeightDatum, TideHeightDatum.casablancaBmi);
  });

  test('qualifie aussi une prévision Casablanca vide sans inventer de points',
      () {
    final source = TideData.fallback(location: 'Casablanca, Maroc');

    final calibrated = CasablancaTideReference.calibrateForecast(source);

    expect(calibrated.tideHeightDatum, TideHeightDatum.casablancaBmi);
    expect(calibrated.hourlyPoints, isEmpty);
    expect(calibrated.low, source.low);
    expect(calibrated.high, source.high);
  });
}
