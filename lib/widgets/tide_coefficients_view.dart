import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/tide_coefficient_service.dart';

const _coefficientCyan = Color(0xFF27E5F4);
const _coefficientBlue = Color(0xFF119EEA);
const _coefficientAmber = Color(0xFFFFB43C);
const _coefficientOrange = Color(0xFFFF6B3D);
const _coefficientGreen = Color(0xFF2DD3B5);

class TideCoefficientsView extends StatelessWidget {
  const TideCoefficientsView({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onSelectedDayChanged,
    required this.isDark,
  });

  final LocalTideCoefficientMonth month;
  final int selectedDay;
  final ValueChanged<int> onSelectedDayChanged;
  final bool isDark;

  Color get _panel =>
      isDark ? const Color(0xE6081A2C) : const Color(0xF7F4FBFF);
  Color get _border => isDark
      ? const Color(0xFF35536A).withValues(alpha: 0.75)
      : const Color(0xFF79B8D7).withValues(alpha: 0.72);
  Color _text(double opacity) =>
      (isDark ? Colors.white : const Color(0xFF061B33))
          .withValues(alpha: opacity);

  @override
  Widget build(BuildContext context) {
    final day = month.day(selectedDay);
    final tradition = MoroccanTideTradition.forDate(day.date);
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _buildIndexAndDailyCurve(context, day),
            const SizedBox(height: 10),
            _buildMonthlyCycle(context),
            const SizedBox(height: 10),
            _buildTraditionalReading(context, tradition),
            const SizedBox(height: 10),
            _buildCulturalNotice(context),
            const SizedBox(height: 12),
            _buildSourceFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexAndDailyCurve(
    BuildContext context,
    LocalTideCoefficientDay day,
  ) {
    final category = _categoryFor(day.localIndex);
    return Semantics(
      container: true,
      label: context.trArgs(
        'tide.coefficientSummarySemantics',
        args: {
          'index': '${day.localIndex}',
          'range': day.tidalRangeMeters.toStringAsFixed(2),
        },
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: _panelDecoration(),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 11,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: _IndexGaugePainter(
                        index: day.localIndex,
                        isDark: isDark,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${day.localIndex}',
                              style: TextStyle(
                                color: _text(1),
                                fontSize: 52,
                                height: 0.98,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              '/120',
                              style: TextStyle(
                                color: _coefficientCyan.withValues(alpha: 0.72),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.tr('tide.localIndex').toUpperCase(),
                              style: const TextStyle(
                                color: _coefficientCyan,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      _summaryLine(
                        icon: Icons.waves_rounded,
                        label: context.tr('tide.tidalRange'),
                        value: '${day.tidalRangeMeters.toStringAsFixed(2)} m',
                        emphasize: true,
                      ),
                      const SizedBox(height: 11),
                      _summaryLine(
                        icon: Icons.water_drop_outlined,
                        label: _categoryLabel(context, category),
                      ),
                      const SizedBox(height: 11),
                      _summaryLine(
                        icon: Icons.functions_rounded,
                        label: context.tr('tide.localHarmonicCalculation'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 168,
              width: double.infinity,
              child: CustomPaint(
                painter: _DailyTideCurvePainter(
                  day: day,
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine({
    required IconData icon,
    required String label,
    String? value,
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _border),
            color: isDark ? const Color(0xFF071627) : const Color(0xFFE8F7FD),
          ),
          child: Icon(icon, color: _coefficientCyan, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: emphasize ? _text(0.9) : _coefficientCyan,
                  fontSize: emphasize ? 13 : 12.5,
                  height: 1.15,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
              if (value != null)
                Text(
                  value,
                  style: const TextStyle(
                    color: _coefficientCyan,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCycle(BuildContext context) {
    final selected = month.day(selectedDay);
    final monthName = _monthName(context, month.month.month).toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 8, 10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: _text(0.94), size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${context.tr('tide.monthlyCycle').toUpperCase()} · $monthName',
                  style: TextStyle(
                    color: _text(0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Semantics(
            slider: true,
            value: context.trArgs(
              'tide.selectedCoefficientDaySemantics',
              args: {
                'day': '$selectedDay',
                'index': '${selected.localIndex}',
              },
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    const chartLeft = 40.0;
                    const chartRight = 10.0;
                    final chartWidth = math.max(
                      1.0,
                      constraints.maxWidth - chartLeft - chartRight,
                    );
                    final x = (details.localPosition.dx - chartLeft)
                        .clamp(0.0, chartWidth);
                    final day = 1 +
                        ((x / chartWidth) * (month.days.length - 1)).round();
                    onSelectedDayChanged(day.clamp(1, month.days.length));
                  },
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MonthlyCoefficientPainter(
                        month: month,
                        selectedDay: selectedDay,
                        isDark: isDark,
                        selectedLabel:
                            '$selectedDay $monthName · ${selected.localIndex}',
                        axisLabel: context.tr('tide.localIndex').toUpperCase(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              _legend(context.tr('tide.neapTideRange'), _coefficientBlue),
              _legend(context.tr('tide.transitionRange'), _coefficientGreen),
              _legend(context.tr('tide.springTideRange'), _coefficientOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _text(0.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  Widget _buildTraditionalReading(
    BuildContext context,
    MoroccanTideTradition tradition,
  ) {
    final period = _traditionalPeriodData(context, tradition.period);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_mosaic_outlined,
                  color: _coefficientAmber, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr('tide.moroccanTraditionalReading').toUpperCase(),
                  style: TextStyle(
                    color: _text(0.95),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.75,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _text(0.9), size: 24),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // La roue occupe la même proportion visuelle que la maquette de
              // référence, sans comprimer le panneau d'interprétation à droite.
              final wheelSize = math.min(224.0, constraints.maxWidth * 0.60);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: wheelSize,
                    height: wheelSize,
                    child: CustomPaint(
                      painter: _TraditionalWheelPainter(
                        selected: tradition.period,
                        isDark: isDark,
                        labels: [
                          context.tr('tide.alKsourLatin'),
                          context.tr('tide.elMaSghirLatin'),
                          context.tr('tide.alQamrayerLatin'),
                          context.tr('tide.alHamzLatin'),
                          context.tr('tide.elMaLkbirLatin'),
                        ],
                        centerLabel: context.tr('tide.hijriDay'),
                        lunarDay: tradition.lunarDay,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: wheelSize * 0.86,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: _border.withValues(alpha: 0.42),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          period.arabicName,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD085),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const _TraditionalDivider(),
                        const SizedBox(height: 7),
                        Text(
                          context.tr('tide.traditionalIndex'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _text(0.82),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${tradition.activityScore}',
                                style: const TextStyle(
                                  color: _coefficientAmber,
                                  fontSize: 37,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: ' / 5',
                                style: TextStyle(
                                  color: _text(0.8),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                child: CustomPaint(
                                  size: const Size(25, 16),
                                  painter: _ActivityFishPainter(
                                    color: index < tradition.activityScore
                                        ? _coefficientAmber
                                        : _text(0.24),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          period.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _text(0.88),
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCulturalNotice(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _panelDecoration(radius: 14),
        child: Row(
          children: [
            const Icon(Icons.grid_goldenratio_rounded,
                color: _coefficientCyan, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('tide.culturalReadingDisclaimer'),
                style: TextStyle(
                  color: _text(0.86),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildSourceFooter(BuildContext context) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.waves_rounded,
                color: _coefficientCyan, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('tide.localHarmonicIndicative'),
              style: TextStyle(
                color: _text(0.55),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );

  BoxDecoration _panelDecoration({double radius = 18}) => BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: _coefficientCyan.withValues(alpha: isDark ? 0.06 : 0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );

  _CoefficientCategory _categoryFor(int index) {
    if (index <= 50) return _CoefficientCategory.neap;
    if (index <= 79) return _CoefficientCategory.transition;
    return _CoefficientCategory.spring;
  }

  String _categoryLabel(BuildContext context, _CoefficientCategory category) {
    switch (category) {
      case _CoefficientCategory.neap:
        return context.tr('tide.neapTide');
      case _CoefficientCategory.transition:
        return context.tr('tide.transition');
      case _CoefficientCategory.spring:
        return context.tr('tide.springTide');
    }
  }

  _TraditionalPeriodData _traditionalPeriodData(
    BuildContext context,
    MoroccanTidePeriod period,
  ) {
    switch (period) {
      case MoroccanTidePeriod.alKsour:
        return _TraditionalPeriodData(
          arabicName: 'الكسور',
          description: context.tr('tide.alKsourDescription'),
        );
      case MoroccanTidePeriod.elMaSghir:
        return _TraditionalPeriodData(
          arabicName: 'الماء الصغير',
          description: context.tr('tide.elMaSghirDescription'),
        );
      case MoroccanTidePeriod.alQamrayer:
        return _TraditionalPeriodData(
          arabicName: 'القصاير / الحصران',
          description: context.tr('tide.alQamrayerDescription'),
        );
      case MoroccanTidePeriod.alHamz:
        return _TraditionalPeriodData(
          arabicName: 'الهمز',
          description: context.tr('tide.alHamzDescription'),
        );
      case MoroccanTidePeriod.elMaLkbir:
        return _TraditionalPeriodData(
          arabicName: 'الماء الكبير',
          description: context.tr('tide.elMaLkbirDescription'),
        );
    }
  }

  String _monthName(BuildContext context, int month) {
    const keys = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    return context.tr('tide.months.${keys[month - 1]}');
  }
}

enum _CoefficientCategory { neap, transition, spring }

class _TraditionalPeriodData {
  const _TraditionalPeriodData({
    required this.arabicName,
    required this.description,
  });

  final String arabicName;
  final String description;
}

class _TraditionalDivider extends StatelessWidget {
  const _TraditionalDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0x55FFB43C), height: 1),
        ),
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          transform: Matrix4.rotationZ(math.pi / 4),
          decoration: BoxDecoration(
            border: Border.all(color: _coefficientAmber, width: 1.2),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0x55FFB43C), height: 1),
        ),
      ],
    );
  }
}

class _ActivityFishPainter extends CustomPainter {
  const _ActivityFishPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromCenter(
      center: Offset(size.width * 0.47, size.height * 0.5),
      width: size.width * 0.62,
      height: size.height * 0.68,
    );
    final path = Path()
      ..addOval(body)
      ..moveTo(size.width * 0.76, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.13)
      ..lineTo(size.width, size.height * 0.87)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      Offset(size.width * 0.27, size.height * 0.42),
      1.15,
      Paint()..color = const Color(0xFF071827),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.43, size.height * 0.22)
        ..quadraticBezierTo(
          size.width * 0.55,
          -1,
          size.width * 0.61,
          size.height * 0.25,
        ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityFishPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _IndexGaugePainter extends CustomPainter {
  const _IndexGaugePainter({required this.index, required this.isDark});

  final int index;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi * 0.72;
    const sweep = math.pi * 1.56;
    final progress = ((index - 20) / 100).clamp(0.0, 1.0);

    final wave = Path();
    for (var i = 0; i <= 160; i++) {
      final angle = math.pi * 2 * i / 160;
      final waveRadius = radius * 1.18 +
          math.sin(angle * 9) * radius * 0.035 +
          math.sin(angle * 17) * radius * 0.016;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * waveRadius;
      if (i == 0) {
        wave.moveTo(point.dx, point.dy);
      } else {
        wave.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      wave,
      Paint()
        ..color = _coefficientCyan.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      wave,
      Paint()
        ..color = _coefficientCyan.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = (isDark ? Colors.white : const Color(0xFF173A55))
            .withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 18,
    );
    canvas.drawArc(
      rect,
      start,
      sweep * progress,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [_coefficientBlue, _coefficientCyan, Color(0xFF74F6F1)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = 18,
    );

    for (var i = 0; i <= 48; i++) {
      final angle = start + sweep * i / 48;
      final inside =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 17);
      final outside =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 10);
      canvas.drawLine(
        inside,
        outside,
        Paint()
          ..color = (isDark ? Colors.white : const Color(0xFF173A55))
              .withValues(alpha: 0.28)
          ..strokeWidth = i % 4 == 0 ? 1.3 : 0.65,
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.69,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF10324A).withValues(alpha: isDark ? 0.8 : 0.18),
            const Color(0xFF03101E).withValues(alpha: isDark ? 1 : 0.06),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _IndexGaugePainter oldDelegate) =>
      index != oldDelegate.index || isDark != oldDelegate.isDark;
}

class _DailyTideCurvePainter extends CustomPainter {
  const _DailyTideCurvePainter({required this.day, required this.isDark});

  final LocalTideCoefficientDay day;
  final bool isDark;

  Color _text(double alpha) => (isDark ? Colors.white : const Color(0xFF061B33))
      .withValues(alpha: alpha);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const right = 8.0;
    const top = 35.0;
    const bottom = 25.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final maxHeight = math.max(0.5, (day.highMeters * 2).ceil() / 2);
    final minHeight = math.min(0.0, (day.lowMeters * 2).floor() / 2);
    final range = math.max(0.1, maxHeight - minHeight);
    double x(DateTime time) =>
        chart.left +
        (time.difference(day.date).inMinutes / (24 * 60)) * chart.width;
    double y(double height) =>
        chart.bottom - ((height - minHeight) / range) * chart.height;

    for (var i = 0; i <= 2; i++) {
      final value = minHeight + range * i / 2;
      final yy = chart.bottom - chart.height * i / 2;
      canvas.drawLine(
        Offset(chart.left, yy),
        Offset(chart.right, yy),
        Paint()
          ..color = _text(0.10)
          ..strokeWidth = 0.7,
      );
      _paintText(
        canvas,
        '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} m',
        Offset(0, yy - 7),
        color: _text(0.58),
        size: 9.5,
      );
    }

    final path = Path();
    for (var i = 0; i < day.samples.length; i++) {
      final sample = day.samples[i];
      final point = Offset(x(sample.time), y(sample.height));
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _coefficientCyan.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _coefficientCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    for (final extremum in day.extrema.take(4)) {
      final xx = x(extremum.time);
      final yy = y(extremum.height);
      _dashedLine(
          canvas, Offset(xx, yy + 5), Offset(xx, chart.bottom), _text(0.45));
      canvas.drawCircle(Offset(xx, yy), 4.3, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(xx, yy),
        7,
        Paint()
          ..color = _coefficientCyan.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final time =
          '${extremum.time.hour.toString().padLeft(2, '0')}:${extremum.time.minute.toString().padLeft(2, '0')}';
      final label = '$time\n${extremum.height.toStringAsFixed(2)} m';
      final labelWidth = 65.0;
      final labelX = (xx - labelWidth / 2).clamp(0.0, size.width - labelWidth);
      _paintText(
        canvas,
        label,
        Offset(labelX, math.max(0, yy - 31)),
        color: _coefficientCyan,
        size: 9.5,
        width: labelWidth,
        align: TextAlign.center,
        weight: FontWeight.w700,
      );
    }

    for (final hour in [0, 6, 12, 18, 24]) {
      final xx = chart.left + chart.width * hour / 24;
      final label = '${hour.toString().padLeft(2, '0')}h';
      _paintText(
        canvas,
        label,
        Offset((xx - 12).clamp(0.0, size.width - 25), chart.bottom + 7),
        color: _text(0.62),
        size: 10,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DailyTideCurvePainter oldDelegate) =>
      day != oldDelegate.day || isDark != oldDelegate.isDark;
}

class _MonthlyCoefficientPainter extends CustomPainter {
  const _MonthlyCoefficientPainter({
    required this.month,
    required this.selectedDay,
    required this.isDark,
    required this.selectedLabel,
    required this.axisLabel,
  });

  final LocalTideCoefficientMonth month;
  final int selectedDay;
  final bool isDark;
  final String selectedLabel;
  final String axisLabel;

  Color _text(double alpha) => (isDark ? Colors.white : const Color(0xFF061B33))
      .withValues(alpha: alpha);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const right = 10.0;
    const top = 45.0;
    const bottom = 27.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    double x(int day) =>
        chart.left +
        ((day - 1) / math.max(1, month.days.length - 1)) * chart.width;
    double y(int index) => chart.bottom - ((index - 20) / 100) * chart.height;

    for (final value in [20, 40, 60, 80, 100, 120]) {
      final yy = y(value);
      canvas.drawLine(
        Offset(chart.left, yy),
        Offset(chart.right, yy),
        Paint()
          ..color = _text(0.09)
          ..strokeWidth = 0.7,
      );
      _paintText(canvas, '$value', Offset(4, yy - 7),
          color: _text(0.67), size: 9.5);
    }

    canvas.save();
    canvas.translate(10, chart.center.dy + 28);
    canvas.rotate(-math.pi / 2);
    _paintText(
      canvas,
      axisLabel,
      Offset.zero,
      color: _text(0.56),
      size: 8.5,
      width: chart.height,
      align: TextAlign.center,
      weight: FontWeight.w600,
    );
    canvas.restore();

    final points = month.days
        .map((day) => Offset(x(day.date.day), y(day.localIndex)))
        .toList(growable: false);
    final curve = _smoothPath(points);
    final fill = Path.from(curve)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x70FF7C43),
            Color(0x4435D4AF),
            Color(0x22119EEA),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      curve,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            _coefficientBlue,
            _coefficientGreen,
            Color(0xFFFFDB54),
            _coefficientOrange,
          ],
        ).createShader(chart)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    final selected = month.day(selectedDay);
    final sx = x(selectedDay);
    final sy = y(selected.localIndex);
    _dashedLine(canvas, Offset(sx, top - 5), Offset(sx, chart.bottom),
        _coefficientCyan);
    canvas.drawCircle(Offset(sx, sy), 7,
        Paint()..color = _coefficientCyan.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(sx, sy), 4, Paint()..color = Colors.white);

    final labelPainter = TextPainter(
      text: const TextSpan(),
      textDirection: TextDirection.ltr,
    );
    labelPainter.text = TextSpan(
      text: selectedLabel,
      style: const TextStyle(
        color: _coefficientCyan,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
    labelPainter.layout();
    final pillWidth = labelPainter.width + 22;
    final pillLeft = (sx - pillWidth / 2).clamp(0.0, size.width - pillWidth);
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillLeft, 4, pillWidth, 30),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = const Color(0xFF09324A)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = _coefficientCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    labelPainter.paint(
      canvas,
      Offset(pillLeft + 11, 4 + (30 - labelPainter.height) / 2),
    );

    final tickDays = <int>{
      1,
      4,
      7,
      10,
      13,
      16,
      19,
      22,
      25,
      28,
      month.days.length
    };
    for (final day in tickDays) {
      _paintText(
        canvas,
        '$day',
        Offset((x(day) - 7).clamp(0.0, size.width - 15), chart.bottom + 8),
        color: _text(0.7),
        size: 9.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyCoefficientPainter oldDelegate) =>
      month != oldDelegate.month ||
      selectedDay != oldDelegate.selectedDay ||
      isDark != oldDelegate.isDark ||
      selectedLabel != oldDelegate.selectedLabel ||
      axisLabel != oldDelegate.axisLabel;
}

class _TraditionalWheelPainter extends CustomPainter {
  const _TraditionalWheelPainter({
    required this.selected,
    required this.isDark,
    required this.labels,
    required this.centerLabel,
    required this.lunarDay,
  });

  final MoroccanTidePeriod selected;
  final bool isDark;
  final List<String> labels;
  final String centerLabel;
  final int lunarDay;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2 - 7;
    // La maquette de référence utilise un médaillon central large (environ
    // 46 % du rayon). Les libellés restent dans l'anneau grâce à des ancrages
    // indépendants et sont peints après le centre.
    final innerRadius = outerRadius * 0.46;
    const gap = 0.025;
    const start = -math.pi / 2 - math.pi / 5;
    final selectedIndex = MoroccanTidePeriod.values.indexOf(selected);
    final textColor = isDark ? Colors.white : const Color(0xFF061B33);
    final wheelRect = Rect.fromCircle(center: center, radius: outerRadius);

    canvas.drawCircle(
      center,
      outerRadius + 3,
      Paint()
        ..color = _coefficientCyan.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      outerRadius + 2,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF7EB6D4),
            Color(0xFF2F617E),
            Color(0xFF87BCD9),
            Color(0xFF2F617E),
            Color(0xFF7EB6D4),
          ],
        ).createShader(wheelRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Couche 1 : secteurs, bordures et pointeur actif. Aucun contenu n'est
    // encore peint afin que le disque central ne puisse jamais le masquer.
    for (var i = 0; i < 5; i++) {
      final segmentStart = start + i * math.pi * 2 / 5 + gap;
      final segmentSweep = math.pi * 2 / 5 - gap * 2;
      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerRadius),
          segmentStart,
          segmentSweep,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          segmentStart + segmentSweep,
          -segmentSweep,
          false,
        )
        ..close();
      final active = i == selectedIndex;
      if (active) {
        canvas.drawPath(
          path,
          Paint()
            ..color = _coefficientAmber.withValues(alpha: 0.42)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: active
                ? const [Color(0x99FFB43C), Color(0xFFFF9F24)]
                : [
                    const Color(0xFF18354B)
                        .withValues(alpha: isDark ? 0.82 : 0.16),
                    const Color(0xFF071827)
                        .withValues(alpha: isDark ? 0.9 : 0.06),
                  ],
          ).createShader(Rect.fromCircle(center: center, radius: outerRadius)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = active
              ? const Color(0xFFFFC158)
              : _coefficientCyan.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1,
      );

      final angle = segmentStart + segmentSweep / 2;
      if (active) {
        final pointerTip = center +
            Offset(math.cos(angle), math.sin(angle)) * (outerRadius + 8);
        final tangent = Offset(-math.sin(angle), math.cos(angle));
        final baseCenter = center +
            Offset(math.cos(angle), math.sin(angle)) * (outerRadius + 1);
        final pointer = Path()
          ..moveTo(pointerTip.dx, pointerTip.dy)
          ..lineTo(
            baseCenter.dx + tangent.dx * 5,
            baseCenter.dy + tangent.dy * 5,
          )
          ..lineTo(
            baseCenter.dx - tangent.dx * 5,
            baseCenter.dy - tangent.dy * 5,
          )
          ..close();
        canvas.drawPath(pointer, Paint()..color = const Color(0xFFFFC158));
      }
    }

    // Couche 2 : médaillon central.
    canvas.drawCircle(
      center,
      innerRadius - 4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF16334A).withValues(alpha: isDark ? 0.95 : 0.22),
            const Color(0xFF041321).withValues(alpha: isDark ? 1 : 0.08),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: innerRadius)),
    );
    canvas.drawCircle(
      center,
      innerRadius - 4,
      Paint()
        ..color = _coefficientAmber.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final centerLabelSize = outerRadius * 0.088;
    final lunarDaySize = outerRadius * 0.17;
    _paintCrescent(canvas, center.translate(0, -16), 10.5);
    _paintStar(canvas, center.translate(13, -22), 1.8);
    _paintStar(canvas, center.translate(16, -16), 1.1);
    _paintText(
      canvas,
      centerLabel,
      Offset(center.dx - 34, center.dy - 1),
      color: textColor.withValues(alpha: 0.78),
      size: centerLabelSize,
      width: 68,
      align: TextAlign.center,
      weight: FontWeight.w600,
    );
    _paintText(
      canvas,
      '$lunarDay',
      Offset(center.dx - 22, center.dy + 12),
      color: textColor,
      size: lunarDaySize,
      width: 44,
      align: TextAlign.center,
      weight: FontWeight.w800,
    );

    // Couche 3 : pictogrammes et libellés. Ils sont peints en dernier pour
    // rester parfaitement lisibles et utilisent des ancrages indépendants,
    // reproduisant la composition du modèle de référence.
    const iconAnchors = <Offset>[
      Offset(0, -0.82),
      Offset(0.75, -0.36),
      Offset(0.43, 0.52),
      Offset(-0.43, 0.52),
      Offset(-0.75, -0.36),
    ];
    const labelAnchors = <Offset>[
      Offset(0, -0.63),
      Offset(0.76, -0.08),
      Offset(0.42, 0.72),
      Offset(-0.42, 0.72),
      Offset(-0.76, -0.08),
    ];
    for (var i = 0; i < 5; i++) {
      final active = i == selectedIndex;
      final iconCenter = center + iconAnchors[i] * outerRadius;
      _paintTraditionalIcon(
        canvas,
        iconCenter,
        i,
        active ? const Color(0xFFFFF0C9) : textColor.withValues(alpha: 0.66),
      );

      final sideSector = i == 1 || i == 4;
      final labelCenter = center + labelAnchors[i] * outerRadius;
      final labelWidth = outerRadius * (sideSector ? 0.68 : 0.82);
      final label = sideSector ? _wrapSideWheelLabel(labels[i]) : labels[i];
      _paintWheelLabel(
        canvas,
        label,
        labelCenter,
        color: active ? Colors.white : textColor.withValues(alpha: 0.84),
        fontSize: outerRadius * (sideSector ? 0.118 : 0.108),
        width: labelWidth,
        weight: active ? FontWeight.w800 : FontWeight.w600,
        canvasSize: size,
      );
    }
  }

  void _paintWheelLabel(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
    required double width,
    required FontWeight weight,
    required Size canvasSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.04,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: width);
    final left = (center.dx - painter.width / 2)
        .clamp(2.0, canvasSize.width - painter.width - 2);
    final top = (center.dy - painter.height / 2)
        .clamp(2.0, canvasSize.height - painter.height - 2);
    painter.paint(canvas, Offset(left, top));
  }

  String _wrapSideWheelLabel(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length < 3) return value;
    return '${words.take(2).join(' ')}\n${words.skip(2).join(' ')}';
  }

  void _paintTraditionalIcon(
    Canvas canvas,
    Offset center,
    int index,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round;
    if (index == 0) {
      final body = Rect.fromCenter(
        center: center.translate(0, 1),
        width: 13,
        height: 10.5,
      );
      canvas.drawRect(body, paint);
      for (final dx in [-5.3, 0.0, 5.3]) {
        canvas.drawRect(
          Rect.fromCenter(
            center: center.translate(dx, -5.8),
            width: 3.2,
            height: 4,
          ),
          paint,
        );
      }
      canvas.drawLine(
        center.translate(-8, 6.7),
        center.translate(8, 6.7),
        paint,
      );
      return;
    }
    if (index == 1 || index == 4) {
      for (var row = -1; row <= 1; row++) {
        final y = center.dy + row * 4;
        final wave = Path()..moveTo(center.dx - 9.5, y);
        for (var step = 0; step < 4; step++) {
          final x = center.dx - 9.5 + step * 4.75;
          wave.quadraticBezierTo(x + 2.375, y - 2.3, x + 4.75, y);
        }
        canvas.drawPath(wave, paint);
      }
      return;
    }
    if (index == 2) {
      _paintCrescent(
        canvas,
        center.translate(-2, 0),
        7,
        foreground: color,
      );
      _paintStar(canvas, center.translate(7, -6), 2, color: color);
      _paintStar(canvas, center.translate(8, 3.5), 1.3, color: color);
      return;
    }

    canvas.drawCircle(center.translate(-2, -2), 5.2, paint);
    canvas.drawLine(
      center.translate(2, 2),
      center.translate(8, 8),
      paint,
    );
    canvas.drawCircle(center.translate(8, 8), 2, paint);
    canvas.drawLine(
      center.translate(-8, 8),
      center.translate(6, 8),
      paint,
    );
  }

  void _paintCrescent(
    Canvas canvas,
    Offset center,
    double radius, {
    Color foreground = const Color(0xFFFFD789),
  }) {
    canvas.drawCircle(center, radius, Paint()..color = foreground);
    canvas.drawCircle(
      center.translate(radius * 0.45, -radius * 0.18),
      radius * 0.92,
      Paint()
        ..color = isDark ? const Color(0xFF0B2133) : const Color(0xFFEAF7FC),
    );
  }

  void _paintStar(
    Canvas canvas,
    Offset center,
    double radius, {
    Color color = const Color(0xFFFFD789),
  }) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? radius : radius * 0.33;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TraditionalWheelPainter oldDelegate) =>
      selected != oldDelegate.selected ||
      isDark != oldDelegate.isDark ||
      lunarDay != oldDelegate.lunarDay ||
      labels != oldDelegate.labels ||
      centerLabel != oldDelegate.centerLabel;
}

Path _smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length - 1; i++) {
    final current = points[i];
    final next = points[i + 1];
    final midpoint = Offset(
      (current.dx + next.dx) / 2,
      (current.dy + next.dy) / 2,
    );
    path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

void _dashedLine(Canvas canvas, Offset start, Offset end, Color color) {
  const dash = 4.0;
  const gap = 4.0;
  final distance = (end - start).distance;
  final direction = (end - start) / math.max(distance, 0.001);
  for (var progress = 0.0; progress < distance; progress += dash + gap) {
    canvas.drawLine(
      start + direction * progress,
      start + direction * math.min(progress + dash, distance),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  required Color color,
  required double size,
  double? width,
  TextAlign align = TextAlign.left,
  FontWeight weight = FontWeight.w500,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        height: 1.08,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 2,
  )..layout(maxWidth: width ?? double.infinity);
  painter.paint(canvas, offset);
}
