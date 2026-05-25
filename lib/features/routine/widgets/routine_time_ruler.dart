import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Timeline constants matching old Optivus exactly.
const double kTimelineTimeRailWidth = 64.0;
const double kTimelineHourHeight = 112.0;
const double kTimelinePixelsPerMinute = kTimelineHourHeight / 60.0;
const double kTimelineMinimumTaskCardHeight = 118.0;
const double kTimelineActiveTaskCardHeight = 204.0;
const double kTimelineBottomNavigationPadding = 132.0;
const double kTimelineRailDotColumnWidth = 12.0;
const double kTimelineContentGap = 12.0;

/// Time ruler — draws hour labels and hour-marker dots on the left rail.
///
/// Matches old Optivus timeline rail styling exactly:
/// - Hour labels: 10.8px, w900, kSub@0.62
/// - Hour dots: 8px, kSub@0.16
/// - Horizontal lines: 1px, kSub@0.055
class RoutineTimeRuler extends StatelessWidget {
  final int startMinute;
  final int endMinute;

  const RoutineTimeRuler({
    super.key,
    required this.startMinute,
    required this.endMinute,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimeRulerPainter(
        startMinute: startMinute,
        endMinute: endMinute,
      ),
      size: Size(
        kTimelineTimeRailWidth,
        ((endMinute - startMinute) / 60.0) * kTimelineHourHeight,
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final int startMinute;
  final int endMinute;

  _TimeRulerPainter({
    required this.startMinute,
    required this.endMinute,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalMinutes = endMinute - startMinute;
    if (totalMinutes <= 0) return;

    final pxPerMinute = size.height / totalMinutes;

    // Draw hour markers
    final startHour = startMinute ~/ 60;
    final endHour = (endMinute + 59) ~/ 60;

    for (int hour = startHour; hour <= endHour && hour < 24; hour++) {
      final minuteOffset = hour * 60 - startMinute;
      final y = minuteOffset * pxPerMinute;

      if (y < -20 || y > size.height + 20) continue;

      // Hour dot (8px)
      canvas.drawCircle(
        Offset(kTimelineTimeRailWidth - 7 + kTimelineRailDotColumnWidth / 2, y),
        4,
        Paint()..color = OptivusColors.sub.withValues(alpha: 0.16),
      );

      // Horizontal line across content area
      canvas.drawLine(
        Offset(kTimelineTimeRailWidth + kTimelineRailDotColumnWidth, y),
        Offset(size.width > 0 ? size.width : 400, y),
        Paint()
          ..color = OptivusColors.sub.withValues(alpha: 0.055)
          ..strokeWidth = 1.0,
      );

      // Hour label (right-aligned within rail)
      final label = '${hour.toString().padLeft(2, '0')}:00';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w900,
            color: OptivusColors.sub.withValues(alpha: 0.62),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          kTimelineTimeRailWidth - 7 - textPainter.width,
          y - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return startMinute != oldDelegate.startMinute ||
        endMinute != oldDelegate.endMinute;
  }
}
