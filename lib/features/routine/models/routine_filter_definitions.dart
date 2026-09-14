import 'package:flutter/foundation.dart';

/// Primary filter options with labels and emojis.
@immutable
class RoutineFilterOption {
  final String key;
  final String label;
  final String emoji;

  const RoutineFilterOption(this.key, this.label, this.emoji);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineFilterOption &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'RoutineFilterOption($key, $label)';
}

/// Canonical view-axis filters.
const List<RoutineFilterOption> primaryFilters = [
  RoutineFilterOption('all', 'All', 'All'),
  RoutineFilterOption('base_timeline', 'Base Timeline', 'Base'),
  RoutineFilterOption('flexible_tasks', 'Flexible Tasks', 'Flex'),
  RoutineFilterOption('tracker_tasks', 'Tracker Tasks', 'Track'),
  RoutineFilterOption('check_ins', 'Check-ins', 'Check'),
];

/// Canonical status-axis filters.
const List<RoutineFilterOption> statusFilters = [
  RoutineFilterOption('any', 'Any', 'Any'),
  RoutineFilterOption('todo', 'To do', 'To do'),
  RoutineFilterOption('done', 'Done', 'Done'),
  RoutineFilterOption('missed', 'Missed', 'Missed'),
];

/// Canonical category-axis filters.
///
/// Every [RoutineCategory] enum value is intentionally and explicitly mapped:
/// - classBlock  -> 'classes'
/// - job         -> 'job'
/// - eating      -> 'eating'
/// - fixed       -> 'fixed'
/// - skinCare    -> 'skin_care'
/// - sleep       -> 'fixed' (anchor / fixed schedule)
/// - habit       -> 'good_habits'
/// - badHabit    -> 'bad_habits'
/// - identity    -> 'good_habits'
/// - finance     -> 'money'
/// - health      -> 'health' (explicit category chip)
/// - focus       -> 'focus'  (explicit category chip)
/// - meditation  -> 'meditation'
/// - hydration   -> 'hydration'
/// - screenTime  -> 'screen_time'
const List<RoutineFilterOption> categoryFilters = [
  RoutineFilterOption('all', 'All Categories', 'All'),
  RoutineFilterOption('classes', 'Classes', 'Class'),
  RoutineFilterOption('job', 'Job / Work', 'Work'),
  RoutineFilterOption('eating', 'Eating', 'Food'),
  RoutineFilterOption('fixed', 'Fixed', 'Fixed'),
  RoutineFilterOption('skin_care', 'Skin Care', 'Skin'),
  RoutineFilterOption('good_habits', 'Good Habits', 'Good'),
  RoutineFilterOption('bad_habits', 'Bad Habits', 'Bad'),
  RoutineFilterOption('money', 'Money System', 'Money'),
  RoutineFilterOption('health', 'Health', 'Health'),
  RoutineFilterOption('focus', 'Focus', 'Focus'),
  RoutineFilterOption('meditation', 'Meditation', 'Mind'),
  RoutineFilterOption('hydration', 'Hydration', 'Water'),
  RoutineFilterOption('screen_time', 'Screen Time', 'Screen'),
];
