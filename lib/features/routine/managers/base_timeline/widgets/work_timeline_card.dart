import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
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
  static double minimumHeight(TimelineBlockDraft block) {
    final hasLoc = block.location?.trim().isNotEmpty == true;
    final hasSection = block.sectionLabel?.trim().isNotEmpty == true;
    final notes = block.notes?.trim() ?? '';
    final notesExtra = notes.isEmpty ? 0.0 : (notes.length > 50 ? 50.0 : 32.0);
    return 94.0 +
        (hasLoc ? 20.0 : 0.0) +
        (hasSection ? 20.0 : 0.0) +
        notesExtra;
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
        '${isEditable ? ", tap to edit" : ", tap for details"}';

    final card = Semantics(
      button: true,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
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
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.work_rounded, size: 12, color: accent),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ),
            if (isEditable)
              Icon(
                Icons.edit_rounded,
                size: 13,
                color: accent.withValues(alpha: 0.7),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: accent.withValues(alpha: 0.90),
          ),
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 3),
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
                    fontSize: 10,
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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

    final semanticLabel = 'Show $title in front, $timeFull';

    final card = Semantics(
      button: true,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
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
