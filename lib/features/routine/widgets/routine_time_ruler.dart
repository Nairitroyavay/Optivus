import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

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
/// - Hour labels: bold and larger
/// - Hour dots: 8px, OptivusColors.sub@0.16
/// - Horizontal lines: 1px, OptivusColors.sub@0.055
class RoutineTimeRuler extends StatelessWidget {
  final TimelineLayout layout;
  final TimelineVisualScale? visualScale;

  const RoutineTimeRuler({super.key, required this.layout, this.visualScale});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimeRulerPainter(layout: layout, visualScale: visualScale),
      size: Size(
        kTimelineTimeRailWidth +
            kTimelineRailDotColumnWidth +
            kTimelineContentGap,
        visualScale?.yForMinute(layout.visibleEndMinute) ?? layout.totalHeight,
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final TimelineLayout layout;
  final TimelineVisualScale? visualScale;

  _TimeRulerPainter({required this.layout, this.visualScale});

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.totalMinutes <= 0) return;

    final startMinute = layout.visibleStartMinute;
    final endMinute = layout.visibleEndMinute;
    final showTicks = layout.showMinuteTicks;

    for (int m = startMinute; m <= endMinute; m++) {
      final y = visualScale?.yForMinute(m) ?? layout.topForMinute(m);

      if (y < -20 || y > size.height + 20) continue;

      if (m % 60 == 0) {
        // Hour dot (8px)
        canvas.drawCircle(
          Offset(
            kTimelineTimeRailWidth - 7 + kTimelineRailDotColumnWidth / 2,
            y,
          ),
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

        // Hour label
        final label = TimelineUtils.formatMinuteShort(m);
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 12.4,
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
      } else if (m % 10 == 0) {
        // 10-minute marker
        canvas.drawLine(
          Offset(kTimelineTimeRailWidth - 4, y),
          Offset(kTimelineTimeRailWidth, y),
          Paint()
            ..color = OptivusColors.sub.withValues(alpha: 0.3)
            ..strokeWidth = 1.2,
        );
        final label = TimelineUtils.formatMinuteShort(m);
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 9.2,
              fontWeight: FontWeight.w700,
              color: OptivusColors.sub.withValues(alpha: 0.4),
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
      } else if (m % 5 == 0) {
        // 5-minute marker
        canvas.drawLine(
          Offset(kTimelineTimeRailWidth - 3, y),
          Offset(kTimelineTimeRailWidth, y),
          Paint()
            ..color = OptivusColors.sub.withValues(alpha: 0.2)
            ..strokeWidth = 1.0,
        );
      } else if (showTicks) {
        // 1-minute marker
        canvas.drawLine(
          Offset(kTimelineTimeRailWidth - 1.5, y),
          Offset(kTimelineTimeRailWidth, y),
          Paint()
            ..color = OptivusColors.sub.withValues(alpha: 0.1)
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return layout != oldDelegate.layout ||
        visualScale != oldDelegate.visualScale;
  }
}
