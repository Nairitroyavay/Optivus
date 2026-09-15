import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_occurrence_summary.dart';
import 'package:optivus/features/routine/services/routine_day_availability.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

/// Comprehensive summary for a single day in the Week Planner.
///
/// Built exclusively from occurrence-aware [RoutineDayEntry] items and the
/// canonical [RoutineDayAvailability] engine.
@immutable
class RoutineWeekDaySummary {
  final DateTime day;
  final List<RoutineDayEntry> entries;
  final RoutineDayAvailability availability;

  /// Total routine occurrences starting/landing on this day
  /// (excludes continuation segments).
  final int routineTotal;

  /// Completed routines on this day.
  final int completed;

  /// Missed routines on this day.
  final int missed;

  /// Skipped routines on this day.
  final int skipped;

  /// Overnight continuation segments continuing into this day.
  final int continuationCount;

  /// Scheduled base/anchor blocks (e.g., classes, work, fixed routine).
  final int baseBlockCount;

  /// Actionable flexible tasks scheduled on this day.
  final int flexibleTaskCount;

  /// Free minutes within the canonical 06:00–23:00 planning window.
  final int freeMinutes;

  /// Occupied minutes within the canonical 06:00–23:00 planning window.
  final int occupiedMinutes;

  /// The largest contiguous free interval within the planning window.
  final RoutineTimeInterval? largestFreeInterval;

  const RoutineWeekDaySummary({
    required this.day,
    required this.entries,
    required this.availability,
    required this.routineTotal,
    required this.completed,
    required this.missed,
    required this.skipped,
    required this.continuationCount,
    required this.baseBlockCount,
    required this.flexibleTaskCount,
    required this.freeMinutes,
    required this.occupiedMinutes,
    this.largestFreeInterval,
  });

  /// Deprecated alias for backwards compatibility during migration.
  @Deprecated('Use routineTotal instead')
  int get actionableTotal => routineTotal;

  /// Deprecated alias for backwards compatibility during migration.
  @Deprecated('Use hasRoutines instead')
  bool get hasActionableTasks => hasRoutines;

  /// Whether there is at least one routine occurrence starting/landing on this day.
  bool get hasRoutines => routineTotal > 0;

  /// Completion progress between 0.0 and 1.0. Returns 0.0 if there are no routines.
  double get progress =>
      routineTotal > 0 ? (completed / routineTotal).clamp(0.0, 1.0) : 0.0;

  /// Formatted free time string from availability engine.
  String get freeTimeFormatted => availability.freeTimeFormatted;

  /// Computes the summary from raw templates and occurrences using the authoritative projector.
  factory RoutineWeekDaySummary.compute({
    required DateTime day,
    required List<RoutineItem> templates,
    required List<RoutineOccurrenceRecord> occurrences,
  }) {
    final entries = RoutineOccurrenceProjector.entriesForDay(
      templates,
      occurrences,
      day,
    );
    return RoutineWeekDaySummary.fromEntries(day: day, entries: entries);
  }

  /// Computes the summary from projected [RoutineDayEntry] instances.
  factory RoutineWeekDaySummary.fromEntries({
    required DateTime day,
    required List<RoutineDayEntry> entries,
  }) {
    // 1. Availability engine calculates occupancy and free time.
    // Continuation segments are intentionally included here so that overnight
    // sleep or routines accurately occupy time on the continuation day.
    final availability = RoutineDayAvailability.computeFromEntries(entries);

    // 2. Compute canonical occurrence summary.
    // All non-continuation entries count toward routineTotal and completion metrics.
    final occurrenceSummary = RoutineOccurrenceSummary.fromEntries(entries);

    // 3. Count base blocks and flexible tasks using canonical predicates on non-continuation entries.
    final nonContinuation = entries
        .where((e) => e.kind != RoutineDayEntryKind.continuation)
        .toList(growable: false);

    final baseBlockCount = nonContinuation
        .where((e) => RoutineEntryFilter.isBaseTimeline(e.item))
        .length;

    final flexibleTaskCount = nonContinuation
        .where((e) => RoutineEntryFilter.isFlexible(e.item))
        .length;

    return RoutineWeekDaySummary(
      day: day,
      entries: entries,
      availability: availability,
      routineTotal: occurrenceSummary.total,
      completed: occurrenceSummary.completed,
      missed: occurrenceSummary.missed,
      skipped: occurrenceSummary.skipped,
      continuationCount: occurrenceSummary.continuationCount,
      baseBlockCount: baseBlockCount,
      flexibleTaskCount: flexibleTaskCount,
      freeMinutes: availability.freeMinutes,
      occupiedMinutes: availability.occupiedMinutes,
      largestFreeInterval: availability.largestFreeInterval,
    );
  }
}
