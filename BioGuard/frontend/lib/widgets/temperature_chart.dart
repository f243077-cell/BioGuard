import 'package:flutter/material.dart';

import '../models/reading.dart';

/// Plots numeric readings (temperature) over time as a line chart.
/// Anomalous points are highlighted in red.
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
      return const Center(child: Text('No temperature data to plot'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        painter: _TemperatureChartPainter(
          readings: chronological,
          axisColor: Theme.of(context).dividerColor,
          lineColor: Theme.of(context).colorScheme.primary,
          anomalyColor: Theme.of(context).colorScheme.error,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TemperatureChartPainter extends CustomPainter {
  _TemperatureChartPainter({
    required this.readings,
    required this.axisColor,
    required this.lineColor,
    required this.anomalyColor,
  });

  final List<Reading> readings;
  final Color axisColor;
  final Color lineColor;
  final Color anomalyColor;

  static const double _leftPadding = 44;
  static const double _bottomPadding = 24;
  static const double _topPadding = 12;
  static const double _rightPadding = 12;

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

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    // Y axis
    canvas.drawLine(
      Offset(_leftPadding, _topPadding),
      Offset(_leftPadding, size.height - _bottomPadding),
      axisPaint,
    );
    // X axis
    canvas.drawLine(
      Offset(_leftPadding, size.height - _bottomPadding),
      Offset(size.width - _rightPadding, size.height - _bottomPadding),
      axisPaint,
    );

    // Y axis labels: min / mid / max
    final labelStyle = TextStyle(color: axisColor, fontSize: 10);
    for (final v in [maxValue, minValue + range / 2, minValue]) {
      final y =
          _topPadding + plotHeight - ((v - minValue) / range) * plotHeight;
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(1), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPadding - tp.width - 6, y - tp.height / 2));
    }

    if (readings.length < 2) {
      // Single point — draw a dot, skip the line.
      final r = readings.first;
      final dx = _leftPadding + plotWidth / 2;
      final dy =
          _topPadding +
          plotHeight -
          ((r.numericValue! - minValue) / range) * plotHeight;
      canvas.drawCircle(Offset(dx, dy), 4, Paint()..color = lineColor);
      return;
    }

    final points = <Offset>[];
    for (var i = 0; i < readings.length; i++) {
      final dx = _leftPadding + (i / (readings.length - 1)) * plotWidth;
      final dy =
          _topPadding +
          plotHeight -
          ((readings[i].numericValue! - minValue) / range) * plotHeight;
      points.add(Offset(dx, dy));
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // Points — anomalous readings highlighted in the error color.
    for (var i = 0; i < points.length; i++) {
      final isAnomalous = readings[i].anomalous;
      canvas.drawCircle(
        points[i],
        isAnomalous ? 4.5 : 2.5,
        Paint()..color = isAnomalous ? anomalyColor : lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) {
    return oldDelegate.readings != readings;
  }
}
