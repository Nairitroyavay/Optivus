import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../routine/utils/timeline_utils.dart';
import '../models/timeline_geometry.dart';

/// Shared time rail components for rendering the vertical timeline axis.
///
/// Matches the golden Step 4 ribbon rail visual reference: 8px ribbon at
/// left: 48, double-edge border, soft shadow, hour markers, half-hour markers,
/// subtle 10-minute ticks, and boundary connectors.
class TimelineTimeRailBackground extends StatelessWidget {
  final TimelineScale scale;
  final List<int> boundaryMinutes;
  final Color accent;
  final String keyPrefix;
  final double minimumBoundaryLabelSpacing;
  final double? cardLeftOffset;
  final double? labelWidth;
  final double? labelHeight;
  final Map<int, double>? cardLeftOffsetByMinute;

  const TimelineTimeRailBackground({
    super.key,
    required this.scale,
    required this.boundaryMinutes,
    this.accent = OptivusColors.brandAccent,
    this.keyPrefix = 'timeline',
    this.minimumBoundaryLabelSpacing = 0,
    this.cardLeftOffset,
    this.labelWidth,
    this.labelHeight,
    this.cardLeftOffsetByMinute,
  });

  @override
  Widget build(BuildContext context) {
    final startHour = scale.startMinute ~/ 60;
    final endHour = (scale.endMinute + 59) ~/ 60;
    final hourCount = endHour - startHour;
    var lastBoundaryLabelY = double.negativeInfinity;

    final first10 = (scale.startMinute ~/ 10) * 10;
    final last10 = ((scale.endMinute + 9) ~/ 10) * 10;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Vertical Rail Line (Step 4 Golden Ribbon Rail) ──
        Positioned(
          top: 0,
          bottom: 0,
          left: 48,
          width: 8,
          child: Container(
            key: ValueKey('$keyPrefix-spine'),
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

        // ── Minor 10-Minute Ticks on Rail ──
        for (var minute = first10; minute <= last10; minute += 10)
          if (minute >= scale.startMinute &&
              minute <= scale.endMinute &&
              minute % 60 != 0 &&
              minute % 30 != 0)
            Positioned(
              key: ValueKey('$keyPrefix-minor-$minute'),
              top: scale.yForMinute(minute) - 0.5,
              left: 50,
              width: 4,
              height: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),

        // ── Half-Hour Ticks on Rail ──
        for (var i = 0; i <= hourCount; i++)
          if ((startHour + i) * 60 + 30 >= scale.startMinute &&
              (startHour + i) * 60 + 30 <= scale.endMinute)
            Positioned(
              key: ValueKey('$keyPrefix-half-${(startHour + i) * 60 + 30}'),
              top: scale.yForMinute((startHour + i) * 60 + 30) - 0.6,
              left: 49,
              width: 6,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),

        // ── Boundary Minute Connectors & Indicators ──
        for (final minute in boundaryMinutes)
          Builder(
            builder: (context) {
              final top = scale.yForMinute(minute);
              final showLabel = minute % 60 != 0 &&
                  top - lastBoundaryLabelY >= minimumBoundaryLabelSpacing;
              if (showLabel) lastBoundaryLabelY = top;
              return _BoundaryMinuteIndicator(
                minute: minute,
                top: top,
                accent: accent,
                keyPrefix: keyPrefix,
                showLabel: showLabel,
                cardLeftOffset:
                    cardLeftOffsetByMinute?[minute] ?? cardLeftOffset,
              );
            },
          ),

        // ── Hour Marks & Labels ──
        for (var i = 0; i <= hourCount; i++) ...[
          _HourMarkLabel(
            keyPrefix: keyPrefix,
            minute: (startHour + i) * 60,
            top: scale.yForMinute((startHour + i) * 60),
            accent: accent,
            labelWidth: labelWidth,
            labelHeight: labelHeight,
          ),
        ],
      ],
    );
  }
}

class _HourMarkLabel extends StatelessWidget {
  final String keyPrefix;
  final int minute;
  final double top;
  final Color accent;
  final double? labelWidth;
  final double? labelHeight;

  const _HourMarkLabel({
    required this.keyPrefix,
    required this.minute,
    required this.top,
    required this.accent,
    this.labelWidth,
    this.labelHeight,
  });

  String _formatHourLabel(int min) {
    final hour24 = (min ~/ 60) % 24;
    final displayHour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final ampm = hour24 < 12 ? 'AM' : 'PM';
    return '$displayHour $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = labelWidth ?? 42.0;
    final effectiveHeight = labelHeight ?? 18.0;

    return Positioned(
      key: ValueKey('$keyPrefix-hour-$minute'),
      top: top - effectiveHeight / 2,
      left: 0,
      width: (effectiveWidth + 14.0).clamp(56.0, 120.0),
      height: effectiveHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            width: effectiveWidth,
            child: Text(
              _formatHourLabel(minute),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          Positioned(
            left: 48,
            top: (effectiveHeight - 1.5) / 2,
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
  final double? cardLeftOffset;

  const _BoundaryMinuteIndicator({
    required this.minute,
    required this.top,
    required this.accent,
    required this.keyPrefix,
    required this.showLabel,
    this.cardLeftOffset,
  });

  @override
  Widget build(BuildContext context) {
    final connectorRight = cardLeftOffset != null ? null : 16.0;
    final connectorWidth = cardLeftOffset != null
        ? (cardLeftOffset! - 56.0).clamp(0.0, 200.0)
        : null;

    return Stack(
      key: ValueKey('$keyPrefix-connector-$minute'),
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
          left: 56,
          right: connectorRight,
          width: connectorWidth,
          height: 1,
          child: DecoratedBox(
            key: ValueKey('$keyPrefix-minute-line-$minute'),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: top - 0.5,
          left: 48,
          width: 8,
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
