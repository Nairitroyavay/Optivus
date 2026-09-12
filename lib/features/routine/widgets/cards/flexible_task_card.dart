import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_actions.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for flexible tasks: Reading, Study, Skill practice, Journaling.
class FlexibleTaskCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final bool isFront;
  final bool hasOverlap;
  final VoidCallback? onTap;

  const FlexibleTaskCard({
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
    final color = RoutineCardFactory.colorForType(
      RoutineBlockType.flexibleTask,
    );

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
                child: const Center(
                  child: Text('📋', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.ink,
                        letterSpacing: -0.2,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${TimelineUtils.formatDuration(item.durationMinutes)} • ${item.priorityLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.sub,
                      ),
                    ),
                  ],
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

          // Full subtasks list with interactive checkboxes
          if (item.subtasks != null && item.subtasks!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'SUBTASKS (${item.subtasks!.length})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            ...item.subtasks!.indexed.map((entry) {
              final idx = entry.$1;
              final task = entry.$2;
              final done =
                  item.subtasksCompleted != null &&
                  idx < item.subtasksCompleted!.length &&
                  item.subtasksCompleted![idx];
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(routineNotifierProvider.notifier)
                      .toggleSubtask(item.id, idx),
                  child: Row(
                    children: [
                      Icon(
                        done ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 15,
                        color: done
                            ? OptivusColors.success
                            : OptivusColors.sub.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: done ? OptivusColors.sub : OptivusColors.ink,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: OptivusColors.sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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
}
