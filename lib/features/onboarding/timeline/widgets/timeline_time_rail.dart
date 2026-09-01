import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../routine/utils/timeline_utils.dart';
import '../models/timeline_geometry.dart';

/// Shared time rail components for rendering the vertical timeline axis.
class TimelineTimeRailBackground extends StatelessWidget {
  final TimelineScale scale;
  final List<int> boundaryMinutes;
  final Color accent;
  final String keyPrefix;
  final double minimumBoundaryLabelSpacing;

  const TimelineTimeRailBackground({
    super.key,
    required this.scale,
    required this.boundaryMinutes,
    this.accent = OptivusColors.brandAccent,
    this.keyPrefix = 'timeline',
    this.minimumBoundaryLabelSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final startHour = scale.startMinute ~/ 60;
    final endHour = (scale.endMinute + 59) ~/ 60;
    final hourCount = endHour - startHour;
    var lastBoundaryLabelY = double.negativeInfinity;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Vertical Rail Line ──
        Positioned(
          top: 0,
          bottom: 0,
          left: 48,
          width: 8,
          child: Container(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: accent.withValues(alpha: 0.36),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),

        // ── Non-Hour Boundary Minute Indicators ──
        for (final minute in boundaryMinutes)
          Builder(
            builder: (context) {
              final top = scale.yForMinute(minute);
              final showLabel =
                  top - lastBoundaryLabelY >= minimumBoundaryLabelSpacing;
              if (showLabel) lastBoundaryLabelY = top;
              return _BoundaryMinuteIndicator(
                minute: minute,
                top: top,
                accent: accent,
                keyPrefix: keyPrefix,
                showLabel: showLabel,
              );
            },
          ),

        // ── Hour Marks & Labels ──
        for (var i = 0; i <= hourCount; i++) ...[
          _HourMarkLabel(
            minute: (startHour + i) * 60,
            top: scale.yForMinute((startHour + i) * 60),
            accent: accent,
          ),
        ],
      ],
    );
  }
}

class _HourMarkLabel extends StatelessWidget {
  final int minute;
  final double top;
  final Color accent;

  const _HourMarkLabel({
    required this.minute,
    required this.top,
    required this.accent,
  });

  String _formatHourLabel(int min) {
    final hour24 = (min ~/ 60) % 24;
    final displayHour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final ampm = hour24 < 12 ? 'AM' : 'PM';
    return '$displayHour $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top - 8,
      left: 0,
      width: 56,
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            width: 42,
            child: Text(
              _formatHourLabel(minute),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          Positioned(
            left: 48,
            top: 7.5,
            width: 4,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundaryMinuteIndicator extends StatelessWidget {
  final int minute;
  final double top;
  final Color accent;
  final String keyPrefix;
  final bool showLabel;

  const _BoundaryMinuteIndicator({
    required this.minute,
    required this.top,
    required this.accent,
    required this.keyPrefix,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showLabel)
          Positioned(
            top: top - 7,
            left: 0,
            width: 40,
            height: 14,
            child: Text(
              TimelineUtils.formatMinuteShort(minute),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: accent.withValues(alpha: 0.85),
              ),
            ),
          ),
        Positioned(
          top: top,
          left: 60,
          right: 16,
          height: 1,
          child: DecoratedBox(
            key: ValueKey('$keyPrefix-minute-line-$minute'),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: top - 0.5,
          left: 44,
          width: 16,
          height: 1.5,
          child: DecoratedBox(
            key: ValueKey('$keyPrefix-minute-tick-$minute'),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
    );
  }
}
