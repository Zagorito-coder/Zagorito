import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../models/tide_data.dart';

/// Position d'un niveau marin par rapport à sa référence verticale.
enum TideHeightRelation {
  localReference,
  aboveMeanSeaLevel,
  belowMeanSeaLevel,
  atMeanSeaLevel,
}

/// Présentation d'une hauteur sans modifier la donnée scientifique source.
///
/// Open-Meteo publie un niveau signé par rapport au niveau moyen global de la
/// mer. Une valeur négative est donc affichée comme une distance *sous* le NMM
/// plutôt que comme une « hauteur de marée négative » ambiguë.
class TideHeightReading {
  const TideHeightReading({
    required this.meters,
    required this.relation,
  });

  factory TideHeightReading.fromMeters(
    double meters,
    TideHeightDatum datum,
  ) {
    if (datum != TideHeightDatum.globalMeanSeaLevel) {
      return TideHeightReading(
        meters: meters,
        relation: TideHeightRelation.localReference,
      );
    }
    if (meters > 0) {
      return TideHeightReading(
        meters: meters,
        relation: TideHeightRelation.aboveMeanSeaLevel,
      );
    }
    if (meters < 0) {
      return TideHeightReading(
        meters: meters.abs(),
        relation: TideHeightRelation.belowMeanSeaLevel,
      );
    }
    return const TideHeightReading(
      meters: 0,
      relation: TideHeightRelation.atMeanSeaLevel,
    );
  }

  final double meters;
  final TideHeightRelation relation;
}

class TideHeightFormatter {
  const TideHeightFormatter._();

  static TideHeightReading reading(
    double meters,
    TideHeightDatum datum,
  ) =>
      TideHeightReading.fromMeters(meters, datum);

  static String number(
    double meters,
    TideHeightDatum datum, {
    int fractionDigits = 2,
    bool trimTrailingZeros = false,
  }) {
    final value = reading(meters, datum).meters;
    var formatted = value.toStringAsFixed(fractionDigits);
    if (formatted.startsWith('-') && double.tryParse(formatted) == 0) {
      formatted = formatted.substring(1);
    }
    if (trimTrailingZeros && formatted.contains('.')) {
      formatted = formatted.replaceFirst(RegExp(r'0+$'), '');
      formatted = formatted.replaceFirst(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  static String value(
    double meters,
    TideHeightDatum datum, {
    int fractionDigits = 2,
    bool trimTrailingZeros = false,
  }) =>
      '${number(
        meters,
        datum,
        fractionDigits: fractionDigits,
        trimTrailingZeros: trimTrailingZeros,
      )} m';

  static String qualifier(
    BuildContext context,
    double meters,
    TideHeightDatum datum,
  ) {
    return switch (reading(meters, datum).relation) {
      TideHeightRelation.aboveMeanSeaLevel =>
        context.tr('tide.aboveMeanSeaLevelShort'),
      TideHeightRelation.belowMeanSeaLevel =>
        context.tr('tide.belowMeanSeaLevelShort'),
      TideHeightRelation.atMeanSeaLevel =>
        context.tr('tide.atMeanSeaLevelShort'),
      TideHeightRelation.localReference => '',
    };
  }

  /// Libellé court réservé aux cellules étroites. La légende complète reste
  /// visible dans la page et le lecteur d'écran reçoit toujours [full].
  static String compactQualifier(
    BuildContext context,
    double meters,
    TideHeightDatum datum,
  ) {
    return switch (reading(meters, datum).relation) {
      TideHeightRelation.aboveMeanSeaLevel =>
        context.tr('tide.aboveMeanSeaLevelCompact'),
      TideHeightRelation.belowMeanSeaLevel =>
        context.tr('tide.belowMeanSeaLevelCompact'),
      TideHeightRelation.atMeanSeaLevel =>
        context.tr('tide.atMeanSeaLevelCompact'),
      TideHeightRelation.localReference => '',
    };
  }

  static String full(
    BuildContext context,
    double meters,
    TideHeightDatum datum, {
    int fractionDigits = 2,
    bool trimTrailingZeros = false,
  }) {
    final formatted = value(
      meters,
      datum,
      fractionDigits: fractionDigits,
      trimTrailingZeros: trimTrailingZeros,
    );
    final reference = qualifier(context, meters, datum);
    return reference.isEmpty ? formatted : '$formatted $reference';
  }

  static String compactFull(
    BuildContext context,
    double meters,
    TideHeightDatum datum, {
    int fractionDigits = 2,
    bool trimTrailingZeros = false,
  }) {
    final formatted = value(
      meters,
      datum,
      fractionDigits: fractionDigits,
      trimTrailingZeros: trimTrailingZeros,
    );
    final reference = compactQualifier(context, meters, datum);
    return reference.isEmpty ? formatted : '$formatted $reference';
  }
}
