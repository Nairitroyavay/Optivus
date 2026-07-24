import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/timeline_visual_layout.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/timeline_layout.dart';
import 'package:optivus/features/routine/widgets/routine_time_ruler.dart';

/// Current time indicator — dot + dotted line at the current minute.
///
/// Uses `OptivusColors.roseAccent` (orange, old `OptivusColors.roseAccent`) — NOT green.
/// Matches old Optivus `_CurrentTimeLineAtY` exactly.
class RoutineCurrentTimeLine extends StatefulWidget {
  final TimelineLayout layout;
  final TimelineVisualScale? visualScale;

  const RoutineCurrentTimeLine({
    super.key,
    required this.layout,
    this.visualScale,
  });

  @override
  State<RoutineCurrentTimeLine> createState() => _RoutineCurrentTimeLineState();
}

class _RoutineCurrentTimeLineState extends State<RoutineCurrentTimeLine> {
  Timer? _timer;
  int _currentMinute = 0;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentMinute = now.hour * 60 + now.minute;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show if current time is within visible range
    if (!widget.layout.isMinuteVisible(_currentMinute)) {
      return const SizedBox.shrink();
    }

    if (widget.layout.totalMinutes <= 0) return const SizedBox.shrink();

    final topOffset =
        widget.visualScale?.yForMinute(_currentMinute) ??
        widget.layout.topForMinute(_currentMinute);
    const dotSize = 8.0;

    final displayTimeStr =
        'Now — ${TimelineUtils.formatMinute(_currentMinute)}';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: topOffset - dotSize / 2,
          left: 0,
          right: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: kTimelineTimeRailWidth),
              Container(
                width: dotSize,
                height: dotSize,
                margin: EdgeInsets.only(
                  left: (kTimelineRailDotColumnWidth - dotSize) / 2,
                  right: kTimelineContentGap,
                ),
                decoration: BoxDecoration(
                  color: OptivusColors.roseAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  displayTimeStr,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.roseAccent,
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _DottedLinePainter(color: OptivusColors.roseAccent),
                  size: const Size.fromHeight(1),
                ),
              ),
              const SizedBox(width: 16),
            ],
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
