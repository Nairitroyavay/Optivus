import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/sheets/add_routine_sheet.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_base.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_factory.dart';

/// Card for tracker-linked tasks: Meditation, Workout, Focus timer.
class TrackerTaskCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final VoidCallback? onTap;

  const TrackerTaskCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = RoutineCardFactory.colorForType(RoutineBlockType.trackerTask);
    final isInTracker = item.status == RoutineStatus.inTracker;
    final isComplete =
        item.isCompleted || item.status == RoutineStatus.completed;

    return RoutineCardBase(
      railColor: color,
      railHeight: railHeight,
      isCompleted: isComplete,
      hasConflict: item.hasConflict,
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
                  child: Text('⏱️', style: TextStyle(fontSize: 20)),
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
                        color: isComplete
                            ? OptivusColors.success
                            : OptivusColors.ink,
                        letterSpacing: -0.2,
                        decoration: isComplete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)} • ${item.blockTypeLabel}',
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
          if (isInTracker) ...[
            const SizedBox(height: 6),
            Text(
              'In progress in Tracker',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (isInTracker)
                CardActionButton(
                  label: 'Open Tracker',
                  color: color,
                  icon: Icons.open_in_new,
                  onTap: () =>
                      ref.read(appNavigationProvider.notifier).goToTracker(),
                )
              else if (!isComplete) ...[
                CardActionButton(
                  label: 'Start',
                  color: color,
                  icon: Icons.play_arrow,
                  onTap: () => ref
                      .read(routineNotifierProvider.notifier)
                      .startTrackerTask(item),
                ),
                CardActionButton(
                  label: 'Edit',
                  color: OptivusColors.textSecondary,
                  icon: Icons.edit_rounded,
                  onTap: () =>
                      showAddRoutineSheet(context, ref, editItem: item),
                ),
              ],
              if (isComplete)
                CardActionButton(
                  label: 'Completed',
                  color: OptivusColors.success,
                  icon: Icons.check,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
