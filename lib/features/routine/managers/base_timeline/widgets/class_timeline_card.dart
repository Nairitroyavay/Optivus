import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

/// Responsive card renderer for Class schedule items on the timeline.
///
/// Follows the hierarchy:
/// - Rich / normal: Subject, badges, time, location, faculty, section, notes.
/// - Medium: Subject, course/type badge, time, room & professor.
/// - Compact / narrow: Subject, time & room.
/// - Tiny: Compact single-line summary.
///
/// Tapping any card opens full details.
class ClassTimelineCard extends StatelessWidget {
  final PositionedTimelineEntry positioned;
  final ClassRoutineBlock? block;
  final bool isEditable;
  final Color accent;
  final VoidCallback? onTap;

  const ClassTimelineCard({
    super.key,
    required this.positioned,
    required this.block,
    required this.isEditable,
    this.accent = OptivusColors.blueAccent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final height = positioned.height;
    final width = positioned.width;
    final entry = positioned.entry;

    final isTiny = height < 44;
    final isNarrow = width < 120;
    final isCompact = (height < 68 || isNarrow) && !isTiny;
    final isMedium = height >= 68 && height < 96 && !isNarrow;
    final isRich = height >= 96 && !isNarrow;

    final subject = block?.subject.isNotEmpty == true
        ? block!.subject
        : entry.title;
    final courseCode = block?.courseCode ?? '';
    final classType = block?.classType ?? '';
    final room = block?.room.isNotEmpty == true
        ? block!.room
        : (entry.subtitle ?? '');
    final professor = block?.professor ?? '';
    final section = block?.section ?? '';
    final notes = block?.notes ?? '';

    final timeLabel = TimelineUtils.formatTimeRange(
      entry.startMinute,
      entry.endMinute,
    );

    final semanticLabel =
        '$subject, $timeLabel'
        '${room.isNotEmpty ? ", Room $room" : ""}'
        '${professor.isNotEmpty ? ", $professor" : ""}'
        '${section.isNotEmpty ? ", Section $section" : ""}'
        '${notes.isNotEmpty ? ", Notes: $notes" : ""}'
        '${isEditable ? ", tap to edit" : ", tap for details"}';

    final card = Semantics(
      button: true,
      label: semanticLabel,
      child: Container(
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
              subject: subject,
              courseCode: courseCode,
              classType: classType,
              room: room,
              professor: professor,
              section: section,
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
    required String subject,
    required String courseCode,
    required String classType,
    required String room,
    required String professor,
    required String section,
    required String notes,
    required String timeLabel,
  }) {
    if (isTiny) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          courseCode.isNotEmpty ? '$courseCode · $subject' : subject,
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject,
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
            room.isNotEmpty ? '$timeLabel · $room' : timeLabel,
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
              Expanded(
                child: Text(
                  subject,
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
          if (courseCode.isNotEmpty || classType.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                if (courseCode.isNotEmpty) _buildBadge(courseCode, accent),
                if (classType.isNotEmpty)
                  _buildBadge(classType, OptivusColors.routineAccent),
              ],
            ),
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
          if (room.isNotEmpty || professor.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                if (room.isNotEmpty)
                  Flexible(
                    child: Text(
                      room,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: OptivusColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (room.isNotEmpty && professor.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '·',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                if (professor.isNotEmpty)
                  Flexible(
                    child: Text(
                      professor,
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
              child: Icon(Icons.school_rounded, size: 12, color: accent),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subject,
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
        if (courseCode.isNotEmpty ||
            classType.isNotEmpty ||
            section.isNotEmpty) ...[
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              if (courseCode.isNotEmpty) _buildBadge(courseCode, accent),
              if (classType.isNotEmpty)
                _buildBadge(classType, OptivusColors.routineAccent),
              if (section.isNotEmpty)
                _buildBadge(
                  section.toLowerCase().startsWith('sec')
                      ? section
                      : 'Sec $section',
                  OptivusColors.aquaAccent,
                ),
            ],
          ),
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
        if (room.isNotEmpty || professor.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              if (room.isNotEmpty) ...[
                const Icon(
                  Icons.location_on_outlined,
                  size: 11,
                  color: OptivusColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    room,
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
              if (room.isNotEmpty && professor.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '·',
                    style: TextStyle(
                      fontSize: 10,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ),
              if (professor.isNotEmpty) ...[
                const Icon(
                  Icons.person_outline_rounded,
                  size: 11,
                  color: OptivusColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    professor,
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
            ],
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 11,
                color: OptivusColors.textSecondary,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
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
}
