import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for hard blocks: Class, Job, Work, Sleep, Travel, Exam, Shift.
class HardBlockCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final bool isFront;
  final bool hasOverlap;
  final VoidCallback? onTap;

  const HardBlockCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
    this.isFront = true,
    this.hasOverlap = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = RoutineCardFactory.colorForType(RoutineBlockType.hardBlock);

    final classDetails = [
      if (item.professor != null && item.professor!.trim().isNotEmpty)
        item.professor!.trim(),
      if (item.courseCode != null && item.courseCode!.trim().isNotEmpty)
        item.courseCode!.trim(),
      if (item.classType != null && item.classType!.trim().isNotEmpty)
        item.classType!.trim(),
      if (item.sectionLabel != null && item.sectionLabel!.trim().isNotEmpty)
        item.sectionLabel!.trim(),
    ].join(' • ');

    return RoutineCardBase(
      railColor: color,
      railHeight: railHeight,
      isCompleted: item.isCompleted,
      isNow: isNow,
      isFront: isFront,
      hasOverlap: hasOverlap,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji icon box
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: color.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _emojiFor(item),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isContinuation
                          ? '${item.title} continues'
                          : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: item.isCompleted
                            ? OptivusColors.success
                            : OptivusColors.ink,
                        letterSpacing: -0.2,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isContinuation
                          ? '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • Continues from yesterday'
                          : '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${TimelineUtils.formatDuration(item.durationMinutes)} • ${item.blockTypeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isOvernight && !item.isContinuation)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OptivusColors.purpleAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: OptivusColors.purpleAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Overnight',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.purpleAccent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),

          // Location
          if (item.location != null && item.location!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: OptivusColors.sub,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.location!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.sub,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Structured Class Details: Professor, Course, Class Type
          if (classDetails.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 13,
                  color: OptivusColors.sub,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    classDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.sub,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Notes
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 13,
                  color: OptivusColors.sub,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.notes!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.sub,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Three Primary Footer Actions: Start, Done, Move
          const SizedBox(height: 8),
          RoutineCardActions(item: item, color: color),
        ],
      ),
    );
  }

  static String _emojiFor(RoutineItem item) {
    if (item.category == RoutineCategory.sleep ||
        item.title.toLowerCase().contains('sleep')) {
      return '🌙';
    }
    if (item.category == RoutineCategory.classBlock) {
      return '🎓';
    }
    if (item.category == RoutineCategory.job ||
        item.title.toLowerCase().contains('work')) {
      return '💼';
    }
    return '🔒';
  }
}
