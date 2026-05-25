import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

/// Shows the expanded detail sheet for a routine item.
void showRoutineDetailSheet(
  BuildContext context,
  WidgetRef ref,
  RoutineItem item,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoutineDetailSheetBody(item: item, parentRef: ref),
  );
}

class _RoutineDetailSheetBody extends StatelessWidget {
  final RoutineItem item;
  final WidgetRef parentRef;

  const _RoutineDetailSheetBody({
    required this.item,
    required this.parentRef,
  });

  @override
  Widget build(BuildContext context) {
    final steps = item.displaySteps;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0FFF0), Color(0xFFDCFFCC)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title + close
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info rows
              _InfoRow(
                'Time',
                TimelineUtils.formatTimeRange(item.startMinute, item.endMinute),
              ),
              _InfoRow(
                'Duration',
                TimelineUtils.formatDuration(item.durationMinutes),
              ),
              _InfoRow('Type', item.blockTypeLabel),
              _InfoRow('Priority', item.priorityLabel),
              _InfoRow('Status', item.statusLabel),
              if (item.location != null)
                _InfoRow('Location', item.location!),
              if (item.mealCategory != null)
                _InfoRow('Meal', item.mealCategory!),

              // Notes
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.textBody,
                    ),
                  ),
                ),
              ],

              // Subtasks
              if (item.subtasks != null && item.subtasks!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Subtasks (${item.subtasks!.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ...item.subtasks!.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final task = entry.value;
                  final done = item.subtasksCompleted != null &&
                      idx < item.subtasksCompleted!.length &&
                      item.subtasksCompleted![idx];
                  return GestureDetector(
                    onTap: () {
                      parentRef
                          .read(mockRoutineProvider.notifier)
                          .toggleSubtask(item.id, idx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 20,
                            color: done
                                ? OptivusColors.success
                                : OptivusColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: done
                                    ? OptivusColors.textMuted
                                    : OptivusColors.textBody,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              // Dishes
              if (item.dishes != null && item.dishes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Dishes (${item.dishes!.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.dishes!.map((dish) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dish,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OptivusColors.textBody,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (item.caloriesEstimate != null ||
                    item.proteinEstimate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${item.caloriesEstimate?.toInt() ?? 0} kcal • ${item.proteinEstimate?.toInt() ?? 0}g protein',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ],

              // Steps
              if (steps != null && steps.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Steps (${steps.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ...steps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: OptivusColors.routineAccent.withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: OptivusColors.routineAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: OptivusColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Action buttons
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      label: 'Edit',
                      icon: Icons.edit,
                      color: OptivusColors.textSecondary,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TODO: Edit routine item'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      color: OptivusColors.danger,
                      onTap: () {
                        parentRef
                            .read(mockRoutineProvider.notifier)
                            .deleteRoutineItem(item.id);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetButton(
                      label: 'Move',
                      icon: Icons.schedule,
                      color: OptivusColors.routineAccent,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TODO: Move routine item'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SheetButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
