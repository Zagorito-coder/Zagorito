import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/utils/tide_height_formatter.dart';

void main() {
  test('un niveau MSL négatif devient une magnitude sous la référence', () {
    final reading = TideHeightFormatter.reading(
      -1.32,
      TideHeightDatum.globalMeanSeaLevel,
    );

    expect(reading.meters, 1.32);
    expect(reading.relation, TideHeightRelation.belowMeanSeaLevel);
    expect(
      TideHeightFormatter.value(
        -1.32,
        TideHeightDatum.globalMeanSeaLevel,
      ),
      '1.32 m',
    );
  });

  test('un niveau MSL positif et le zéro conservent leur position', () {
    expect(
      TideHeightFormatter.reading(
        0.75,
        TideHeightDatum.globalMeanSeaLevel,
      ).relation,
      TideHeightRelation.aboveMeanSeaLevel,
    );
    expect(
      TideHeightFormatter.reading(
        0,
        TideHeightDatum.globalMeanSeaLevel,
      ).relation,
      TideHeightRelation.atMeanSeaLevel,
    );
  });

  test('la coordonnée compacte MSL conserve un signe mathématique explicite',
      () {
    expect(
      TideHeightFormatter.coordinateValue(
        -1.32,
        TideHeightDatum.globalMeanSeaLevel,
      ),
      '−1.32 m',
    );
    expect(
      TideHeightFormatter.coordinateValue(
        0.75,
        TideHeightDatum.globalMeanSeaLevel,
      ),
      '+0.75 m',
    );
    expect(
      TideHeightFormatter.coordinateValue(
        -0.004,
        TideHeightDatum.globalMeanSeaLevel,
      ),
      '0.00 m',
    );
  });

  test('Casablanca et une référence inconnue ne sont jamais recalibrées', () {
    expect(
      TideHeightFormatter.value(-0.4, TideHeightDatum.casablancaBmi),
      '-0.40 m',
    );
    expect(
      TideHeightFormatter.value(-0.4, TideHeightDatum.unknown),
      '-0.40 m',
    );
  });

  testWidgets('la formulation française explicite le niveau moyen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('full-msl-format'),
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(
                TideHeightFormatter.full(
                  context,
                  -1.32,
                  TideHeightDatum.globalMeanSeaLevel,
                ),
              ),
              Text(
                TideHeightFormatter.compactFull(
                  context,
                  -1.32,
                  TideHeightDatum.globalMeanSeaLevel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.32 m sous le NMM'), findsOneWidget);
    expect(find.text('−1.32 m NMM'), findsOneWidget);
    expect(find.textContaining('↓ NMM'), findsNothing);
  });

  test('identifie les deux versions du repère de présentation', () {
    expect(
      TideHeightFormatter.isPresentationDatum(
        TideHeightDatum.casablancaPresentationModel,
      ),
      isTrue,
    );
    expect(
      TideHeightFormatter.isPresentationDatum(
        TideHeightDatum.moroccoCasablancaModel,
      ),
      isTrue,
    );
    expect(
      TideHeightFormatter.isPresentationDatum(TideHeightDatum.casablancaBmi),
      isFalse,
    );
  });
}
