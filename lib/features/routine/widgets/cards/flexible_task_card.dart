import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for flexible tasks: Reading, Study, Skill practice, Journaling.
class FlexibleTaskCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final VoidCallback? onTap;

  const FlexibleTaskCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
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
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
                      maxLines: 1,
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
                      '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${TimelineUtils.formatDuration(item.durationMinutes)} • ${item.priorityLabel}',
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
            ],
          ),
          // Subtask preview
          if (item.subtasks != null && item.subtasks!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${item.subtasks!.length} subtasks',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            ...item.subtasks!.take(2).indexed.map((entry) {
              final idx = entry.$1;
              final task = entry.$2;
              final done =
                  item.subtasksCompleted != null &&
                  idx < item.subtasksCompleted!.length &&
                  item.subtasksCompleted![idx];
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 13,
                      color: done
                          ? OptivusColors.success
                          : OptivusColors.sub.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        task,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: done ? OptivusColors.sub : OptivusColors.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: OptivusColors.sub,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (item.subtasks!.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '+${item.subtasks!.length - 2} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: OptivusColors.sub.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              CardActionButton(
                label: 'Start',
                color: color,
                icon: Icons.play_arrow_rounded,
                onTap: () => ref
                    .read(routineNotifierProvider.notifier)
                    .startFlexibleTask(item.id),
              ),
              CardActionButton(
                label: 'Done',
                color: OptivusColors.success,
                icon: Icons.check_rounded,
                onTap: () => ref
                    .read(routineNotifierProvider.notifier)
                    .markCompleted(item.id),
              ),
              CardActionButton(
                label: 'Move',
                color: OptivusColors.textSecondary,
                icon: Icons.schedule_rounded,
                onTap: () => showRoutineMoveSheet(context, ref, item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
