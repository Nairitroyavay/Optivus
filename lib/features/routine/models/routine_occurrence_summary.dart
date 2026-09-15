import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/models/routine_item.dart';

/// Pure occurrence-aware completion and routine counts for a single day.
///
/// Derived exclusively from [RoutineDayEntry] occurrences where
/// `kind != RoutineDayEntryKind.continuation`.
///
/// Invariant: Occurrence identity determines routine counts. Block type does
/// not decide whether a visible routine is counted.
@immutable
class RoutineOccurrenceSummary {
  final int total;
  final int completed;
  final int missed;
  final int skipped;
  final int continuationCount;

  const RoutineOccurrenceSummary({
    required this.total,
    required this.completed,
    required this.missed,
    required this.skipped,
    required this.continuationCount,
  });

  /// Whether there is at least one routine occurrence starting/landing on this day.
  bool get hasRoutines => total > 0;

  /// Completion progress between 0.0 and 1.0. Returns 0.0 if total is 0.
  double get progress => total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

  /// Computes canonical occurrence counts from projected day entries.
  factory RoutineOccurrenceSummary.fromEntries(List<RoutineDayEntry> entries) {
    var total = 0;
    var completed = 0;
    var missed = 0;
    var skipped = 0;
    var continuationCount = 0;

    for (final entry in entries) {
      if (entry.kind == RoutineDayEntryKind.continuation) {
        continuationCount++;
        continue;
      }

      total++;
      final item = entry.item;
      if (item.isCompleted || item.status == RoutineStatus.completed) {
        completed++;
      } else if (item.isMissed || item.status == RoutineStatus.missed) {
        missed++;
      } else if (item.status == RoutineStatus.skipped) {
        skipped++;
      }
    }

    return RoutineOccurrenceSummary(
      total: total,
      completed: completed,
      missed: missed,
      skipped: skipped,
      continuationCount: continuationCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineOccurrenceSummary &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          completed == other.completed &&
          missed == other.missed &&
          skipped == other.skipped &&
          continuationCount == other.continuationCount;

  @override
  int get hashCode =>
      Object.hash(total, completed, missed, skipped, continuationCount);

  @override
  String toString() =>
      'RoutineOccurrenceSummary(total: $total, completed: $completed, missed: $missed, skipped: $skipped, continuationCount: $continuationCount)';
}
