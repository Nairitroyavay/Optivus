import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for hard blocks: Class, Job, Work, Sleep, Travel, Exam, Shift.
class HardBlockCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final VoidCallback? onTap;

  const HardBlockCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = RoutineCardFactory.colorForType(RoutineBlockType.hardBlock);
    return RoutineCardBase(
      railColor: color,
      railHeight: railHeight,
      isCompleted: item.isCompleted,
      hasConflict: item.hasConflict,
      isNow: isNow,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                    _isSleepItem(item) ? '🌙' : '🔒',
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          if (item.conflictMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              item.conflictMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OptivusColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              CardActionButton(
                label: 'View',
                color: color,
                icon: Icons.visibility_rounded,
                onTap: onTap,
              ),
              if (!item.isContinuation)
                CardActionButton(
                  label: 'Edit base',
                  color: OptivusColors.textSecondary,
                  icon: Icons.edit_calendar_rounded,
                  onTap: () => showAddRoutineSheet(context, ref, editItem: item),
                ),
              if (item.hasConflict && !item.isContinuation)
                CardActionButton(
                  label: 'Allow overlap',
                  color: OptivusColors.warning,
                  icon: Icons.layers_rounded,
                  onTap: () => ref
                      .read(routineNotifierProvider.notifier)
                      .updateItem(item.copyWith(allowOverlap: true)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _isSleepItem(RoutineItem item) =>
      item.category == RoutineCategory.sleep ||
      item.title.toLowerCase().contains('sleep');
}
