import 'package:flutter/material.dart';
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

// Shared rail layout constants
const double kTimelineRailX =
    kTimelineTimeRailWidth + kTimelineRailDotColumnWidth / 2;
const double kTimelineLabelRailGap = 7.0;
const double kTimelineLabelRight =
    kTimelineTimeRailWidth - kTimelineLabelRailGap;
const double kTimelineLiveDotSize = 8.0;

/// Time ruler — draws hour labels and hour-marker dots on the left rail.
///
/// Matches old Optivus timeline rail styling exactly:
/// - Hour labels: bold and larger
/// - Hour dots: 8px, OptivusColors.sub@0.16
/// - Horizontal lines: 1px, OptivusColors.sub@0.055
class RoutineTimeRuler extends StatelessWidget {
  final TimelineLayout layout;
  final TimelineVisualScale? visualScale;
  final int? currentMinute;

  const RoutineTimeRuler({
    super.key,
    required this.layout,
    this.visualScale,
    this.currentMinute,
  });

  @visibleForTesting
  static bool shouldSuppressTickLabel({
    required int tickMinute,
    required int? currentMinute,
    required TimelineLayout layout,
    TimelineVisualScale? visualScale,
    double tickLabelHeight = 11.0,
    double liveLabelHeight = 13.0,
    double padding = 2.0,
  }) {
    if (currentMinute == null) return false;
    if (!layout.isMinuteVisible(currentMinute)) return false;
    if (TimelineUtils.isRulerTick(currentMinute)) return false;
    final yCurrent = TimelineUtils.minuteToY(
      currentMinute,
      layout: layout,
      visualScale: visualScale,
    );
    final yTick = TimelineUtils.minuteToY(
      tickMinute,
      layout: layout,
      visualScale: visualScale,
    );
    final distance = (yCurrent - yTick).abs();
    final minDist = (tickLabelHeight / 2) + (liveLabelHeight / 2) + padding;
    return distance < minDist;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimeRulerPainter(
        layout: layout,
        visualScale: visualScale,
        currentMinute: currentMinute,
      ),
      size: Size(
        kTimelineTimeRailWidth +
            kTimelineRailDotColumnWidth +
            kTimelineContentGap,
        TimelineUtils.minuteToY(
          layout.visibleEndMinute,
          layout: layout,
          visualScale: visualScale,
        ),
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final TimelineLayout layout;
  final TimelineVisualScale? visualScale;
  final int? currentMinute;

  _TimeRulerPainter({
    required this.layout,
    this.visualScale,
    this.currentMinute,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.totalMinutes <= 0) return;

    final startMinute = layout.visibleStartMinute;
    final endMinute = layout.visibleEndMinute;
    final showTicks = layout.showMinuteTicks;

    final hasCurrentMinute =
        currentMinute != null && layout.isMinuteVisible(currentMinute!);
    final currentIsOnTick =
        hasCurrentMinute && TimelineUtils.isRulerTick(currentMinute!);
    final double? currentY = hasCurrentMinute
        ? TimelineUtils.minuteToY(
            currentMinute!,
            layout: layout,
            visualScale: visualScale,
          )
        : null;

    double? liveLabelHeight;
    if (hasCurrentMinute && !currentIsOnTick) {
      final livePainter = TextPainter(
        text: TextSpan(
          text: TimelineUtils.formatMinuteShort(currentMinute!),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: OptivusColors.roseAccent,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      liveLabelHeight = livePainter.height;
    }

    for (int m = startMinute; m <= endMinute; m++) {
      final y = TimelineUtils.minuteToY(m, layout: layout, visualScale: visualScale);

      if (y < -20 || y > size.height + 20) continue;

      final isLiveTick = currentMinute != null && m == currentMinute;

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
              color: isLiveTick
                  ? OptivusColors.roseAccent
                  : OptivusColors.sub.withValues(alpha: 0.62),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Check collision if current time is between ticks
        var suppress = false;
        if (!isLiveTick &&
            hasCurrentMinute &&
            !currentIsOnTick &&
            liveLabelHeight != null &&
            currentY != null) {
          final distance = (y - currentY).abs();
          final minDist =
              (textPainter.height / 2) + (liveLabelHeight / 2) + 2.0;
          if (distance < minDist) {
            suppress = true;
          }
        }

        if (!suppress) {
          textPainter.paint(
            canvas,
            Offset(
              kTimelineLabelRight - textPainter.width,
              y - textPainter.height / 2,
            ),
          );
        }
      } else if (TimelineUtils.isRulerTick(m)) {
        // 10-minute marker
        canvas.drawLine(
          Offset(kTimelineTimeRailWidth - 4, y),
          Offset(kTimelineTimeRailWidth, y),
          Paint()
            ..color = isLiveTick
                ? OptivusColors.roseAccent
                : OptivusColors.sub.withValues(alpha: 0.3)
            ..strokeWidth = isLiveTick ? 1.6 : 1.2,
        );
        final label = TimelineUtils.formatMinuteShort(m);
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: isLiveTick ? 10.5 : 9.2,
              fontWeight: isLiveTick ? FontWeight.w900 : FontWeight.w700,
              color: isLiveTick
                  ? OptivusColors.roseAccent
                  : OptivusColors.sub.withValues(alpha: 0.4),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Check collision if current time is between ticks
        var suppress = false;
        if (!isLiveTick &&
            hasCurrentMinute &&
            !currentIsOnTick &&
            liveLabelHeight != null &&
            currentY != null) {
          final distance = (y - currentY).abs();
          final minDist =
              (textPainter.height / 2) + (liveLabelHeight / 2) + 2.0;
          if (distance < minDist) {
            suppress = true;
          }
        }

        if (!suppress) {
          textPainter.paint(
            canvas,
            Offset(
              kTimelineLabelRight - textPainter.width,
              y - textPainter.height / 2,
            ),
          );
        }
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
        visualScale != oldDelegate.visualScale ||
        currentMinute != oldDelegate.currentMinute;
  }
}
