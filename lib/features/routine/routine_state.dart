import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected day for the routine timeline.
final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Active primary filter.
final routineFilterProvider = StateProvider<String>((ref) => 'all');

/// Whether to show the full 24-hour timeline.
final showFullDayProvider = StateProvider<bool>((ref) => false);

/// Whether to show minute ticks on the ruler.
final showMinuteTicksProvider = StateProvider<bool>((ref) => true);

/// Whether to use compact card mode.
final compactModeProvider = StateProvider<bool>((ref) => false);

/// Primary filter options with labels and emojis.
class RoutineFilterOption {
  final String key;
  final String label;
  final String emoji;

  const RoutineFilterOption(this.key, this.label, this.emoji);
}

const List<RoutineFilterOption> primaryFilters = [
  RoutineFilterOption('all', 'All', '🗓️'),
  RoutineFilterOption('base_timeline', 'Base Timeline', '📅'),
  RoutineFilterOption('flexible_tasks', 'Flexible Tasks', '🎯'),
  RoutineFilterOption('tracker_tasks', 'Tracker Tasks', '⏱️'),
  RoutineFilterOption('check_ins', 'Check-ins', '✅'),
  RoutineFilterOption('conflicts', 'Conflicts', '⚠️'),
  RoutineFilterOption('completed', 'Completed', '✓'),
  RoutineFilterOption('missed', 'Missed', '✗'),
];
