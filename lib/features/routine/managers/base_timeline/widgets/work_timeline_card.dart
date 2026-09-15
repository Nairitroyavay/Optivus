import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Responsive card renderer for Work / Business schedule items on the timeline.
///
/// Follows the visual hierarchy of the modern Base Timeline card family:
/// - Rich / normal (height >= 96): Role/title, time, workplace/location,
///   business/section badge or label, and notes/details.
/// - Medium (68 <= height < 96): Role/title, time, workplace, business/notes.
/// - Compact / narrow: Role/title, time and workplace.
/// - Tiny: Single-line summary.
///
/// Overlapping back card: compact exposed banner (icon, title, time).
/// Deletion belongs in the edit sheet, not on the card face.
class WorkTimelineCard extends StatelessWidget {
  final PositionedTimelineEntry positioned;
  final TimelineBlockDraft? block;
  final bool isEditable;
  final Color accent;
  final VoidCallback? onTap;

  const WorkTimelineCard({
    super.key,
    required this.positioned,
    required this.block,
    required this.isEditable,
    this.accent = OptivusColors.warning,
    this.onTap,
  });

  /// Single authoritative content-adaptive minimum height calculation
  /// shared across adapter and renderer.
  static double minimumHeight(
    TimelineBlockDraft block, {
    double contentWidth = 220.0,
    double textScale = 1.0,
    bool isEditable = true,
  }) {
    final title = block.title.trim();
    final location = block.location?.trim() ?? '';
    final sectionLabel = block.sectionLabel?.trim() ?? '';
    final notes = block.notes?.trim() ?? '';

    // Card chrome & padding:
    // Horizontal padding in rich card: 12 left + 12 right = 24 (or 16 if narrow < 120), plus 2px for border
    final isNarrow = contentWidth < 120.0;
    final horizontalPadding = isNarrow ? 18.0 : 26.0;
    final innerWidth = (contentWidth - horizontalPadding).clamp(
      30.0,
      double.infinity,
    );

    // Vertical padding: 6 top + 6 bottom = 12.0
    // Border / margin: 2.0
    double totalHeight = 14.0;

    // 1. Header row: work icon (20px) + spacing (6px) + edit icon allowance (17px if editable)
    final editAllowance = isEditable ? 17.0 : 0.0;
    final titleWidth = (innerWidth - 20.0 - 6.0 - editAllowance).clamp(
      30.0,
      double.infinity,
    );
    final titleHeight = _measureTextHeight(
      text: title.isNotEmpty ? title : 'Work',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      maxWidth: titleWidth,
      textScale: textScale,
    );
    totalHeight += titleHeight > 21.0 ? titleHeight : 21.0;

    // 2. Section badge / label
    if (sectionLabel.isNotEmpty) {
      totalHeight += 3.0;
      final badgeInnerWidth = (innerWidth - 12.0).clamp(30.0, double.infinity);
      final badgeTextHeight = _measureTextHeight(
        text: sectionLabel,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0.2,
        ),
        maxWidth: badgeInnerWidth,
        textScale: textScale,
      );
      totalHeight += badgeTextHeight + 5.0; // 1.5 top + 1.5 bottom + 2 border
    }

    // 3. Time label
    totalHeight += 3.0;
    final timeHeight = _measureTextHeight(
      text: TimelineUtils.formatTimeRange(block.startMinute, block.endMinute),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      maxWidth: innerWidth,
      textScale: textScale,
    );
    totalHeight += timeHeight;

    // 4. Location
    if (location.isNotEmpty) {
      totalHeight += 3.0;
      final locWidth = (innerWidth - 13.0).clamp(30.0, double.infinity);
      final locHeight = _measureTextHeight(
        text: location,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
        maxWidth: locWidth,
        textScale: textScale,
      );
      totalHeight += locHeight > 12.5 ? locHeight : 12.5;
    }

    // 5. Notes
    if (notes.isNotEmpty) {
      totalHeight += 3.0;
      final notesWidth = (innerWidth - 14.0).clamp(30.0, double.infinity);
      final notesHeight = _measureTextHeight(
        text: notes,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.25,
          fontStyle: FontStyle.italic,
        ),
        maxWidth: notesWidth,
        textScale: textScale,
      );
      totalHeight += notesHeight > 12.5 ? notesHeight : 12.5;
    }

    // Bottom safety buffer scaled with text scaling
    totalHeight += (14.0 * textScale).clamp(14.0, 32.0);

    return totalHeight < 96.0 ? 96.0 : totalHeight.ceilToDouble();
  }

  static double _measureTextHeight({
    required String text,
    required TextStyle style,
    required double maxWidth,
    double textScale = 1.0,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
    )..layout(maxWidth: maxWidth);
    final h = painter.size.height;
    painter.dispose();
    return h;
  }

  @override
  Widget build(BuildContext context) {
    if (positioned.hasOverlap && !positioned.isFront) {
      return _buildExposedBackCard(context);
    }

    final height = positioned.height;
    final width = positioned.width;
    final entry = positioned.entry;

    final isTiny = height < 44;
    final isNarrow = width < 120;
    final isCompact = (height < 68 || isNarrow) && !isTiny;
    final isMedium = height >= 68 && height < 96 && !isNarrow;
    final isRich = height >= 96 && !isNarrow;

    final title = block?.title.isNotEmpty == true ? block!.title : entry.title;
    final location = block?.location?.trim() ?? (entry.subtitle?.trim() ?? '');
    final sectionLabel = block?.sectionLabel?.trim() ?? '';
    final notes = block?.notes?.trim() ?? '';

    final timeLabel = TimelineUtils.formatTimeRange(
      entry.startMinute,
      entry.endMinute,
    );

    final semanticLabel =
        '$title, $timeLabel'
        '${location.isNotEmpty ? ", Workplace: $location" : ""}'
        '${sectionLabel.isNotEmpty ? ", Section: $sectionLabel" : ""}'
        '${notes.isNotEmpty ? ", Details: $notes" : ""}'
        '${isEditable ? ", tap to edit" : ""}';

    final card = Semantics(
      button: isEditable,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: OptivusMotion.duration(context, OptivusMotion.fastDuration),
        curve: OptivusMotion.enterCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.88),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.0),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.16),
              accent.withValues(alpha: 0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 12,
              vertical: isTiny ? 2 : (isCompact ? 4 : 6),
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: _buildBody(
                isTiny: isTiny,
                isCompact: isCompact,
                isMedium: isMedium,
                isRich: isRich,
                isNarrow: isNarrow,
                title: title,
                location: location,
                sectionLabel: sectionLabel,
                notes: notes,
                timeLabel: timeLabel,
              ),
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: card,
            )
          : card,
    );
  }

  Widget _buildBody({
    required bool isTiny,
    required bool isCompact,
    required bool isMedium,
    required bool isRich,
    required bool isNarrow,
    required String title,
    required String location,
    required String sectionLabel,
    required String notes,
    required String timeLabel,
  }) {
    if (isTiny) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          sectionLabel.isNotEmpty ? '$sectionLabel · $title' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent.withValues(alpha: 0.95),
          ),
        ),
      );
    }

    if (isCompact) {
      final secondary = location.isNotEmpty
          ? location
          : (sectionLabel.isNotEmpty ? sectionLabel : notes);
      final detailText = secondary.isNotEmpty
          ? '$timeLabel · $secondary'
          : timeLabel;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              if (isEditable && !isNarrow)
                Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: accent.withValues(alpha: 0.7),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            detailText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.90),
            ),
          ),
        ],
      );
    }

    if (isMedium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.work_rounded, size: 11, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              if (isEditable)
                Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: accent.withValues(alpha: 0.7),
                ),
            ],
          ),
          if (sectionLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            _buildBadge(sectionLabel, accent),
          ],
          const SizedBox(height: 2),
          Text(
            timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.90),
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 11,
                  color: OptivusColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: OptivusColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (notes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              notes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontStyle: FontStyle.italic,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ],
      );
    }

    // Rich card (height >= 96)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.work_rounded, size: 12, color: accent),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ),
            if (isEditable)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(
                  Icons.edit_rounded,
                  size: 13,
                  color: accent.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        if (sectionLabel.isNotEmpty) ...[
          _buildBadge(sectionLabel, accent),
          const SizedBox(height: 3),
        ],
        Text(
          timeLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: accent.withValues(alpha: 0.90),
          ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1.5),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 11,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: OptivusColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1.5),
                child: Icon(
                  Icons.notes_rounded,
                  size: 11,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.25,
                    fontStyle: FontStyle.italic,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildExposedBackCard(BuildContext context) {
    final entry = positioned.entry;
    final title = block?.title.isNotEmpty == true ? block!.title : entry.title;
    final timeShort = TimelineUtils.formatMinuteShort(entry.startMinute);
    final timeFull = TimelineUtils.formatTimeRange(
      entry.startMinute,
      entry.endMinute,
    );

    final semanticLabel = '$title, $timeFull. Tap to bring to front.';

    final card = Semantics(
      button: true,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: OptivusMotion.duration(context, OptivusMotion.fastDuration),
        curve: OptivusMotion.enterCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.88),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.0),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.16),
              accent.withValues(alpha: 0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.work_rounded,
                            size: 9,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeShort,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: accent.withValues(alpha: 0.90),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: card,
            )
          : card,
    );
  }
}
