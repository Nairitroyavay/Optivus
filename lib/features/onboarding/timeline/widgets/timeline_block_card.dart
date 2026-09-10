import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../routine/utils/timeline_utils.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_geometry.dart';
import '../models/timeline_style.dart';

/// Shared block card widget for displaying a single event in the timeline.
class TimelineBlockCard extends StatelessWidget {
  final PositionedTimelineEntry positioned;
  final TimelineEntryStyle style;
  final VoidCallback? onTap;

  const TimelineBlockCard({
    super.key,
    required this.positioned,
    required this.style,
    this.onTap,
  });

  TimelineEntry get entry => positioned.entry;

  @override
  Widget build(BuildContext context) {
    final height = positioned.height;
    final width = positioned.width;
    final tiny = height < 42;
    final compact = height < 85;
    final isNarrow = width < 110;

    final timeLabel =
        style.timeRangeLabel ??
        TimelineUtils.formatTimeRange(entry.startMinute, entry.endMinute);

    final semanticLabel =
        '${entry.title}, $timeLabel'
        '${entry.subtitle != null ? ", ${entry.subtitle}" : ""}'
        '${entry.isEditable ? ", double tap to edit" : ""}';

    return Semantics(
      button: entry.isEditable,
      label: semanticLabel,
      child: GestureDetector(
        key: ValueKey('timeline-block-${entry.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: entry.isEditable ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.78),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                style.accentColor.withValues(alpha: 0.22),
                style.accentColor.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: OptivusColors.borderNeutral.withValues(alpha: 0.45),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: style.accentColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tiny ? 8 : (isNarrow ? 8 : 12),
                vertical: tiny ? 3 : (compact ? 6 : 10),
              ),
              child: _buildContent(context, tiny, compact, isNarrow, timeLabel),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool tiny,
    bool compact,
    bool isNarrow,
    String timeLabel,
  ) {
    if (tiny) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: style.accentColor.withValues(alpha: 0.95),
              height: 1.1,
            ),
          ),
        ),
      );
    }

    if (compact) {
      return ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (style.icon != null && !isNarrow) ...[
                    Icon(style.icon, size: 13, color: style.accentColor),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                timeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: style.accentColor.withValues(alpha: 0.90),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Standard / Large event block
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row with icon and edit indicator
            Row(
              children: [
                if (style.icon != null) ...[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(style.icon, size: 13, color: style.accentColor),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                ),
                if (entry.isEditable && !isNarrow)
                  Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: style.accentColor.withValues(alpha: 0.6),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // Time Range
            Text(
              timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: style.accentColor.withValues(alpha: 0.90),
              ),
            ),

            // Subtitle (if available)
            if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                entry.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],

            // Tags / Dishes / Products (if available)
            if (style.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: style.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: OptivusColors.borderNeutral.withValues(
                          alpha: 0.40,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
