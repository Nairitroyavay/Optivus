import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

void showRoutineWeekPlannerSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _WeekPlannerSheet(),
  );
}

class _WeekPlannerSheet extends ConsumerWidget {
  const _WeekPlannerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routineNotifierProvider);
    final allItems = state.items;
    final selected = state.selectedDay;
    final startOfWeek = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(
      7,
      (index) => DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + index,
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OptivusColors.routineSheetTop,
                OptivusColors.routineSheetBottom,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
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
              const Text(
                'Week Planner',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monday to Sunday • ${_dateLabel(days.first)} - ${_dateLabel(days.last)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...days.map((day) {
                final items = RoutineMaterializer.itemsForDay(allItems, day);
                final hardBlocks = items
                    .where((item) => item.isHardBlock)
                    .length;
                final habits = items
                    .where(
                      (item) =>
                          item.blockType == RoutineBlockType.flexibleTask ||
                          item.category == RoutineCategory.habit,
                    )
                    .length;
                final freeMinutes = _freeMinutes(items);
                final completed = items
                    .where(
                      (item) =>
                          item.status == RoutineStatus.completed ||
                          item.isCompleted,
                    )
                    .length;
                return _WeekDayCard(
                  day: day,
                  selected: DateUtils.isSameDay(day, selected),
                  total: items.length,
                  completed: completed,
                  hardBlocks: hardBlocks,
                  habits: habits,
                  freeMinutes: freeMinutes,
                  onTap: () {
                    ref
                        .read(routineNotifierProvider.notifier)
                        .updateSelectedDay(day);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  int _freeMinutes(List<RoutineItem> items) {
    final busy = items.fold<int>(0, (sum, item) {
      return sum + item.durationMinutes.clamp(0, 24 * 60).toInt();
    });
    return (24 * 60 - busy).clamp(0, 24 * 60).toInt();
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _WeekDayCard extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final int total;
  final int completed;
  final int hardBlocks;
  final int habits;
  final int freeMinutes;
  final VoidCallback onTap;

  const _WeekDayCard({
    required this.day,
    required this.selected,
    required this.total,
    required this.completed,
    required this.hardBlocks,
    required this.habits,
    required this.freeMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = OptivusColors.routineAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? OptivusColors.ink.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.78),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${TimelineUtils.getShortDayName(day.weekday)} ${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : OptivusColors.ink,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: selected ? Colors.white : color,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('$completed/$total done', selected),
                  _chip('$hardBlocks base blocks', selected),
                  _chip('$habits habits', selected),
                  _chip(
                    '${TimelineUtils.formatDuration(freeMinutes)} free',
                    selected,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, bool inverted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: inverted
            ? Colors.white.withValues(alpha: 0.12)
            : OptivusColors.routineAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: inverted ? Colors.white : OptivusColors.textSecondary,
        ),
      ),
    );
  }
}
