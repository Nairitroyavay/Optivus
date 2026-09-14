import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';

/// Current time indicator — dot + dotted line at the current minute.
///
/// Uses `OptivusColors.roseAccent` (orange, old `OptivusColors.roseAccent`) — NOT green.
/// Matches old Optivus `_CurrentTimeLineAtY` exactly.
class RoutineCurrentTimeLine extends StatelessWidget {
  final TimelineLayout layout;
  final TimelineVisualScale? visualScale;
  final int? currentMinute;

  const RoutineCurrentTimeLine({
    super.key,
    required this.layout,
    this.visualScale,
    this.currentMinute,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMinute = currentMinute ??
        () {
          final now = DateTime.now();
          return now.hour * 60 + now.minute;
        }();

    // Only show if current time is within visible range
    if (!layout.isMinuteVisible(effectiveMinute)) {
      return const SizedBox.shrink();
    }

    if (layout.totalMinutes <= 0) return const SizedBox.shrink();

    final topOffset = TimelineUtils.minuteToY(
      effectiveMinute,
      layout: layout,
      visualScale: visualScale,
    );
    const dotSize = kTimelineLiveDotSize;
    final isOnTick = TimelineUtils.isRulerTick(effectiveMinute);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Horizontal dashed line starting at the rail and extending right
        Positioned(
          top: topOffset - 0.7,
          left: kTimelineRailX,
          right: 0,
          height: 1.4,
          child: CustomPaint(
            painter: _DottedLinePainter(color: OptivusColors.roseAccent),
          ),
        ),

        // 2. Small orange live dot aligned with the vertical time rail
        Positioned(
          top: topOffset - dotSize / 2,
          left: kTimelineRailX - dotSize / 2,
          width: dotSize,
          height: dotSize,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: const BoxDecoration(
              color: OptivusColors.roseAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),

        // 3. Current-time label strictly left of the vertical time rail (when between ticks)
        if (!isOnTick)
          Positioned(
            top: topOffset,
            left: 0,
            width: kTimelineLabelRight,
            child: FractionalTranslation(
              translation: const Offset(0.0, -0.5),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  TimelineUtils.formatMinuteShort(effectiveMinute),
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.roseAccent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dotted line painter — exact match of old Optivus
// ─────────────────────────────────────────────────────────────────────────────

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.52)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const dashWidth = 3.5;
    const dashSpace = 5.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
