import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

// ─── 1. CIRCULAR PROGRESS RING ───
class TrackerProgressRing extends StatelessWidget {
  final double progress;
  final Color ringColor;
  final double strokeWidth;
  final Widget? centerWidget;

  const TrackerProgressRing({
    super.key,
    required this.progress,
    required this.ringColor,
    this.strokeWidth = 10,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(120, 120),
            painter: _RingPainter(
              progress: progress,
              color: ringColor,
              strokeWidth: strokeWidth,
            ),
          ),
          () {
            final w = centerWidget;
            return w ?? const SizedBox.shrink();
          }(),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    // Active progress arc
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

// ─── 2. GRAPH SPARKLINE ───
class TrackerSparkline extends StatelessWidget {
  final List<double> dataPoints;
  final Color lineColor;
  final bool fillGradients;

  const TrackerSparkline({
    super.key,
    required this.dataPoints,
    required this.lineColor,
    this.fillGradients = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        size: const Size(double.infinity, 80),
        painter: _SparklinePainter(
          points: dataPoints,
          color: lineColor,
          fill: fillGradients,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final bool fill;

  _SparklinePainter({
    required this.points,
    required this.color,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double maxVal = points.reduce(math.max);
    final double minVal = points.reduce(math.min);
    final double delta = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final double stepX = width / (points.length - 1);
    final path = Path();
    final fillPath = Path();

    // Mapping function
    Offset getOffset(int index) {
      final double x = index * stepX;
      final double normY = (points[index] - minVal) / delta;
      final double y = height - (normY * height * 0.7) - (height * 0.15);
      return Offset(x, y);
    }

    final start = getOffset(0);
    path.moveTo(start.dx, start.dy);
    fillPath.moveTo(0, height);
    fillPath.lineTo(start.dx, start.dy);

    for (int i = 1; i < points.length; i++) {
      final p = getOffset(i);
      path.lineTo(p.dx, p.dy);
      fillPath.lineTo(p.dx, p.dy);
    }

    fillPath.lineTo(width, height);
    fillPath.close();

    // Fill paint
    if (fill) {
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, width, height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // Line paint
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}

// ─── 3. PHONE HEALTH DATA SOURCE CARD ───
class PhoneDataSourceCard extends StatelessWidget {
  final bool isSynced;
  final VoidCallback onToggle;

  const PhoneDataSourceCard({
    super.key,
    required this.isSynced,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isSynced ? Icons.health_and_safety : Icons.health_and_safety_outlined,
            color: isSynced ? OptivusColors.success : Colors.blueGrey,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wearable Integration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  isSynced ? 'Mock Apple Health Active' : 'Off - Click to Link SDK',
                  style: TextStyle(fontSize: 10, color: isSynced ? OptivusColors.success : OptivusColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSynced ? OptivusColors.success.withValues(alpha: 0.15) : OptivusColors.brandAccent,
              foregroundColor: isSynced ? OptivusColors.success : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onToggle,
            child: Text(
              isSynced ? 'Linked' : 'Link SDK',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. MOCK MAP GPS ROUTE PREVIEW ───
class MockMapPreview extends StatelessWidget {
  const MockMapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5),
        child: CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _MapRoutePainter(),
        ),
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw mock grid/streets
    final streetPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, h * 0.3), Offset(w, h * 0.4), streetPaint);
    canvas.drawLine(Offset(w * 0.2, 0), Offset(w * 0.3, h), streetPaint);
    canvas.drawLine(Offset(w * 0.7, 0), Offset(w * 0.6, h), streetPaint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w, h * 0.7), streetPaint);

    // Draw active GPS running route
    final path = Path()
      ..moveTo(w * 0.25, h * 0.8)
      ..quadraticBezierTo(w * 0.35, h * 0.35, w * 0.5, h * 0.38)
      ..lineTo(w * 0.65, h * 0.72);

    final routePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, routePaint);

    // Start Pin (dot)
    final startPaint = Paint()..color = Colors.green;
    canvas.drawCircle(Offset(w * 0.25, h * 0.8), 6, startPaint);

    // End Pin (dot)
    final endPaint = Paint()..color = Colors.red;
    canvas.drawCircle(Offset(w * 0.65, h * 0.72), 6, endPaint);
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) => false;
}
