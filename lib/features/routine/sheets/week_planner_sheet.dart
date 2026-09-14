import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/models/routine_week_day_summary.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

/// Shows the Routine Week Planner sheet.
void showRoutineWeekPlannerSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const WeekPlannerSheet(),
  );
}

class WeekPlannerSheet extends ConsumerStatefulWidget {
  const WeekPlannerSheet({super.key});

  @override
  ConsumerState<WeekPlannerSheet> createState() => _WeekPlannerSheetState();
}

class _WeekPlannerSheetState extends ConsumerState<WeekPlannerSheet> {
  late DateTime _visibleWeekStart;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(routineNotifierProvider).selectedDay;
    _visibleWeekStart = TimelineUtils.weekStart(selected);
  }

  void _goToPreviousWeek() {
    setState(() {
      _visibleWeekStart = _visibleWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _visibleWeekStart = _visibleWeekStart.add(const Duration(days: 7));
    });
  }

  void _goToThisWeek() {
    setState(() {
      _visibleWeekStart = TimelineUtils.weekStart(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routineNotifierProvider);
    final selectedDay = state.selectedDay;
    final isCurrentWeek = DateUtils.isSameDay(
      _visibleWeekStart,
      TimelineUtils.weekStart(DateTime.now()),
    );

    final days = List.generate(
      7,
      (index) => DateTime(
        _visibleWeekStart.year,
        _visibleWeekStart.month,
        _visibleWeekStart.day + index,
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
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
              // Grab handle
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

              // Title and navigation row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Week Planner',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (!isCurrentWeek)
                    GestureDetector(
                      onTap: _goToThisWeek,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: OptivusColors.routineAccent.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: OptivusColors.routineAccent.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: const Text(
                          'This week',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.routineAccent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Week selector bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                      color: OptivusColors.ink,
                      onPressed: _goToPreviousWeek,
                    ),
                    Expanded(
                      child: Text(
                        '${_dateLabel(days.first)} – ${_dateLabel(days.last)}',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                      color: OptivusColors.ink,
                      onPressed: _goToNextWeek,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle describing planning window
              const Text(
                'Actual schedule • Free time uses 6 AM–11 PM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Loading check
              if (state.loading && state.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        OptivusColors.routineAccent,
                      ),
                    ),
                  ),
                )
              else
                ...days.map((day) {
                  final summary = RoutineWeekDaySummary.compute(
                    day: day,
                    templates: state.items,
                    occurrences: state.occurrences,
                  );
                  final isSelected = DateUtils.isSameDay(day, selectedDay);
                  final isToday = TimelineUtils.isToday(day);

                  return _WeekDayCard(
                    summary: summary,
                    isSelected: isSelected,
                    isToday: isToday,
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
  final RoutineWeekDaySummary summary;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _WeekDayCard({
    required this.summary,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final day = summary.day;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? OptivusColors.ink.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.78),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.1 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day row with Today / Selected indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${TimelineUtils.getShortDayName(day.weekday)} ${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : OptivusColors.ink,
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OptivusColors.routineAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SELECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar or neutral status
              if (summary.hasActionableTasks) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${summary.completed}/${summary.actionableTotal} done',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : OptivusColors.ink,
                      ),
                    ),
                    Text(
                      '${(summary.progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.7)
                            : OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.progress,
                    minHeight: 5,
                    backgroundColor: isSelected
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSelected
                          ? OptivusColors.routineAccent
                          : OptivusColors.routineAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Text(
                  'No tasks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.65)
                        : OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Chips row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('${summary.baseBlockCount} base', inverted: isSelected),
                  _chip(
                    '${summary.flexibleTaskCount} flexible',
                    inverted: isSelected,
                  ),
                  _chip(
                    '${TimelineUtils.formatDuration(summary.freeMinutes)} free',
                    inverted: isSelected,
                  ),
                  if (summary.missed > 0)
                    _chip(
                      '${summary.missed} missed',
                      inverted: isSelected,
                      isWarning: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, {required bool inverted, bool isWarning = false}) {
    Color bg;
    Color fg;

    if (isWarning) {
      bg = Colors.red.withValues(alpha: inverted ? 0.25 : 0.12);
      fg = inverted ? const Color(0xFFFF8A80) : Colors.red.shade700;
    } else if (inverted) {
      bg = Colors.white.withValues(alpha: 0.14);
      fg = Colors.white;
    } else {
      bg = OptivusColors.routineAccent.withValues(alpha: 0.1);
      fg = OptivusColors.ink;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
