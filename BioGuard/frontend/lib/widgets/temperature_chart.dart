import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/reading.dart';
import 'glass.dart';

/// Plots numeric readings (temperature) over time as a line chart.
/// Anomalous points are highlighted in the danger color.
/// Not intended for lock-type readings — see LockHistoryList for those.
class TemperatureChart extends StatelessWidget {
  const TemperatureChart({super.key, required this.readings});

  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    // Chart expects chronological order; API returns most-recent-first.
    final chronological = readings.reversed
        .where((r) => r.numericValue != null)
        .toList();

    if (chronological.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.thermostat_rounded,
          title: 'No temperature data to plot',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomPaint(
        painter: _TemperatureChartPainter(
          readings: chronological,
          gridColor: Colors.white.withValues(alpha: 0.07),
          labelColor: AppColors.textMuted,
          lineColor: AppColors.skyMint,
          anomalyColor: AppColors.danger,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TemperatureChartPainter extends CustomPainter {
  _TemperatureChartPainter({
    required this.readings,
    required this.gridColor,
    required this.labelColor,
    required this.lineColor,
    required this.anomalyColor,
  });

  final List<Reading> readings;
  final Color gridColor;
  final Color labelColor;
  final Color lineColor;
  final Color anomalyColor;

  static const double _leftPadding = 44;
  static const double _bottomPadding = 16;
  static const double _topPadding = 12;
  static const double _rightPadding = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final values = readings.map((r) => r.numericValue!).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    // Avoid a zero-height range when all readings are identical.
    final range = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;

    final plotWidth = size.width - _leftPadding - _rightPadding;
    final plotHeight = size.height - _topPadding - _bottomPadding;
    final plotBottom = _topPadding + plotHeight;

    double yFor(double v) =>
        _topPadding + plotHeight - ((v - minValue) / range) * plotHeight;

    // Horizontal gridlines + labels at max / mid / min.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 11);
    for (final v in [maxValue, minValue + range / 2, minValue]) {
      final y = yFor(v);
      canvas.drawLine(
        Offset(_leftPadding, y),
        Offset(size.width - _rightPadding, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: '${v.toStringAsFixed(1)}°', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPadding - tp.width - 8, y - tp.height / 2));
    }

    if (readings.length < 2) {
      // Single point — draw a dot, skip the line.
      final r = readings.first;
      _drawPoint(
        canvas,
        Offset(_leftPadding + plotWidth / 2, yFor(r.numericValue!)),
        r.anomalous,
      );
      return;
    }

    final points = <Offset>[
      for (var i = 0; i < readings.length; i++)
        Offset(
          _leftPadding + (i / (readings.length - 1)) * plotWidth,
          yFor(readings[i].numericValue!),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    // Soft mint fill beneath the line.
    final fill = Path.from(line)
      ..lineTo(points.last.dx, plotBottom)
      ..lineTo(points.first.dx, plotBottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(0, _topPadding, size.width, plotBottom)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < points.length; i++) {
      if (readings[i].anomalous) {
        _drawPoint(canvas, points[i], true);
      }
    }
    // Emphasize the latest reading.
    if (!readings.last.anomalous) {
      _drawPoint(canvas, points.last, false);
    }
  }

  void _drawPoint(Canvas canvas, Offset at, bool anomalous) {
    final color = anomalous ? anomalyColor : lineColor;
    canvas.drawCircle(at, 9, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawCircle(at, 4.5, Paint()..color = color);
    canvas.drawCircle(at, 1.8, Paint()..color = AppColors.graphite);
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) {
    return oldDelegate.readings != readings;
  }
}
