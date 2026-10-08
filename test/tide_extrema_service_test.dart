import 'package:flutter_test/flutter_test.dart';
import 'package:spots_app/models/tide_data.dart';
import 'package:spots_app/services/casablanca_tide_reference.dart';
import 'package:spots_app/services/tide_extrema_service.dart';

void main() {
  test('détecte le milieu des plateaux de haute et basse mer', () {
    final start = DateTime.utc(2026, 10, 6);
    final points = <TidePoint>[
      for (var hour = 0; hour < 7; hour++)
        TidePoint(
          time: start.add(Duration(hours: hour)),
          instantUtc: start.add(Duration(hours: hour)),
          height: <double>[0, 1, 1, 0, -1, -1, 0][hour],
        ),
    ];

    final extrema = TideExtremaService.detect(
      points,
      instantOf: (point) => point.instantUtc!,
      civilAt: (instant) => instant,
    );

    expect(extrema, hasLength(2));
    expect(extrema[0].isHigh, isTrue);
    expect(extrema[0].instantUtc, DateTime.utc(2026, 10, 6, 1, 30));
    expect(extrema[0].height, 1);
    expect(extrema[1].isHigh, isFalse);
    expect(extrema[1].instantUtc, DateTime.utc(2026, 10, 6, 4, 30));
    expect(extrema[1].height, -1);
  });

  test('ne transforme pas une borne ou une série monotone en extrême', () {
    final start = DateTime.utc(2026, 10, 6);
    final points = <TidePoint>[
      for (var hour = 0; hour < 4; hour++)
        TidePoint(
          time: start.add(Duration(hours: hour)),
          instantUtc: start.add(Duration(hours: hour)),
          height: hour.toDouble(),
        ),
    ];

    final extrema = TideExtremaService.detect(
      points,
      instantOf: (point) => point.instantUtc!,
      civilAt: (instant) => instant,
    );

    expect(extrema, isEmpty);
  });

  test('détecte les plateaux même lorsque toutes les hauteurs sont négatives',
      () {
    final start = DateTime.utc(2026, 10, 6);
    final heights = <double>[
      -0.60,
      -0.58,
      -0.57,
      -0.57,
      -0.58,
      -0.61,
      -0.63,
      -0.63,
      -0.61,
    ];
    final points = <TidePoint>[
      for (var hour = 0; hour < heights.length; hour++)
        TidePoint(
          time: start.add(Duration(hours: hour)),
          instantUtc: start.add(Duration(hours: hour)),
          height: heights[hour],
        ),
    ];

    final extrema = TideExtremaService.detect(
      points,
      instantOf: (point) => point.instantUtc!,
      civilAt: (instant) => instant,
    );

    expect(extrema, hasLength(2));
    expect(extrema[0].instantUtc, DateTime.utc(2026, 10, 6, 2, 30));
    expect(extrema[0].isHigh, isTrue);
    expect(extrema[1].instantUtc, DateTime.utc(2026, 10, 6, 6, 30));
    expect(extrema[1].isHigh, isFalse);
  });

  test('préserve les quatre extrema de la courbe harmonique Casablanca', () {
    final start = DateTime.utc(2026, 10, 6);
    final points = <TidePoint>[
      for (var minute = 0; minute <= 24 * 60; minute++)
        TidePoint(
          time: start.add(Duration(minutes: minute)),
          instantUtc: start.add(Duration(minutes: minute)),
          height: CasablancaTideReference.heightAtUtc(
            start.add(Duration(minutes: minute)),
          ),
        ),
    ];

    final extrema = TideExtremaService.detect(
      points,
      instantOf: (point) => point.instantUtc!,
      civilAt: (instant) => instant,
    );

    expect(extrema, hasLength(4));
    expect(
      extrema.map((event) => event.instantUtc),
      <DateTime>[
        DateTime.utc(2026, 10, 6, 4, 25),
        DateTime.utc(2026, 10, 6, 10, 41),
        DateTime.utc(2026, 10, 6, 17, 9),
        DateTime.utc(2026, 10, 6, 23, 18),
      ],
    );
    expect(extrema.map((event) => event.isHigh), <bool>[
      false,
      true,
      false,
      true,
    ]);
  });
}
