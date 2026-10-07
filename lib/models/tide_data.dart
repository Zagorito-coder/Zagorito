// ============================================================
//  tide_data.dart — Modèle de données de marées
// ============================================================

import '../services/astronomy_service.dart';
import '../utils/station_time_zone.dart';

/// Référence verticale utilisée pour exprimer les hauteurs de marée.
///
/// Une valeur n'est comparable à une table hydrographique locale que si son
/// référentiel est identifié explicitement. Les documents Open-Meteo sont
/// relatifs au niveau moyen mondial de la mer, tandis que Casablanca dispose
/// d'une calibration locale BMI propre à cette station. Les stations
/// marocaines sans marégraphe local peuvent utiliser le même repère vertical
/// indicatif que Casablanca tout en conservant leur propre courbe Open-Meteo.
enum TideHeightDatum {
  globalMeanSeaLevel,
  casablancaBmi,
  moroccoCasablancaModel,
  unknown,
}

/// Représente un point de données de marée (heure + hauteur)
class TidePoint {
  final DateTime time;
  final DateTime? instantUtc;
  final double height; // en mètres
  final double? windDirectionDeg; // degrés météo (direction d'où vient le vent)
  final double? wavePeriod; // secondes
  final double? windWaveHeight; // mètres
  final double? temperatureC;
  final double? windSpeedKmh;
  final double? pressureHpa;
  final double? precipitationProbabilityPct;
  final double? relativeHumidityPct;
  final double? windGustKmh;
  final double? visibilityKm;
  final double? cloudCoverPct;
  final double? precipitationMm;
  final double? swellHeightM;
  final double? swellPeriodS;
  final double? swellDirectionDeg;
  final double? secondarySwellHeightM;
  final double? secondarySwellPeriodS;
  final double? secondarySwellDirectionDeg;
  final double? seaSurfaceTemperatureC;
  final double? oceanCurrentSpeedKmh;
  final double? oceanCurrentDirectionDeg;

  const TidePoint({
    required this.time,
    this.instantUtc,
    required this.height,
    this.windDirectionDeg,
    this.wavePeriod,
    this.windWaveHeight,
    this.temperatureC,
    this.windSpeedKmh,
    this.pressureHpa,
    this.precipitationProbabilityPct,
    this.relativeHumidityPct,
    this.windGustKmh,
    this.visibilityKm,
    this.cloudCoverPct,
    this.precipitationMm,
    this.swellHeightM,
    this.swellPeriodS,
    this.swellDirectionDeg,
    this.secondarySwellHeightM,
    this.secondarySwellPeriodS,
    this.secondarySwellDirectionDeg,
    this.seaSurfaceTemperatureC,
    this.oceanCurrentSpeedKmh,
    this.oceanCurrentDirectionDeg,
  });
}

/// Prévision météo/marine légère à trois heures, destinée uniquement au
/// tableau vertical de la page Marées. Elle est publiée dans le même document
/// Firestore que les marées afin de ne pas ajouter de lecture côté mobile.
class HourlyForecastPoint {
  final DateTime time;
  final DateTime? instantUtc;
  final double? windSpeedKmh;
  final double? windGustKmh;
  final double? windDirectionDeg;
  final int? weatherCode;
  final bool? isDay;
  final double? temperatureC;
  final double? pressureHpa;
  final double? waveHeightM;
  final double? wavePeriodS;
  final double? waveDirectionDeg;
  final double? precipitationProbabilityPct;
  final double? cloudCoverPct;
  final int? activityScore;

  const HourlyForecastPoint({
    required this.time,
    this.instantUtc,
    this.windSpeedKmh,
    this.windGustKmh,
    this.windDirectionDeg,
    this.weatherCode,
    this.isDay,
    this.temperatureC,
    this.pressureHpa,
    this.waveHeightM,
    this.wavePeriodS,
    this.waveDirectionDeg,
    this.precipitationProbabilityPct,
    this.cloudCoverPct,
    this.activityScore,
  });
}

/// Données de marées complètes pour affichage, enrichies avec données astronomiques
class TideData {
  final List<TidePoint> hourlyPoints;
  final List<HourlyForecastPoint> hourlyForecast;
  final double low; // Marée basse (minimum)
  final double high; // Marée haute (maximum)
  final double next; // Prochaine hauteur prévue
  final double waveHeight; // Hauteur significative des vagues (m)
  final String location;
  final DateTime? generatedAt;
  final int? utcOffsetSeconds;
  final String? timeZoneId;
  final TideHeightDatum tideHeightDatum;
  final AstroData astro; // Phase lune, coef, activité, transit...

  const TideData({
    required this.hourlyPoints,
    this.hourlyForecast = const [],
    required this.low,
    required this.high,
    required this.next,
    required this.waveHeight,
    required this.location,
    this.generatedAt,
    this.utcOffsetSeconds,
    this.timeZoneId,
    this.tideHeightDatum = TideHeightDatum.unknown,
    required this.astro,
  });

  /// Heure civile de la station pour un instant donné.
  ///
  /// Les valeurs horaires affichées par les pages Marées sont des heures
  /// locales de station. Sans ce décalage, une ville choisie manuellement dans
  /// un autre fuseau serait regroupée selon la date du téléphone.
  DateTime stationTimeAt(DateTime instant) {
    return StationTimeZone.civilAt(
      instant,
      timeZoneId: timeZoneId,
      fallbackOffsetSeconds: utcOffsetSeconds,
    );
  }

  /// Convertit une heure civile de station vers l'instant UTC correspondant.
  /// Cette opération est notamment nécessaire au modèle harmonique de
  /// Casablanca, qui travaille exclusivement sur des instants UTC.
  DateTime stationInstantAt(DateTime stationTime) {
    return StationTimeZone.instantAt(
      stationTime,
      timeZoneId: timeZoneId,
      fallbackOffsetSeconds: utcOffsetSeconds,
    );
  }

  /// Valeurs par défaut quand l'API échoue
  factory TideData.fallback({String location = 'Casablanca Morocco'}) {
    return TideData(
      hourlyPoints: const [],
      hourlyForecast: const [],
      low: 0.0,
      high: 0.0,
      next: 0.0,
      waveHeight: 0.0,
      location: location,
      generatedAt: null,
      utcOffsetSeconds: null,
      timeZoneId: null,
      astro: AstroData.fallback(),
    );
  }
}
