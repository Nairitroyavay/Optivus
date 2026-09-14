import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/routine_state.dart';
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

  /// Total actionable tasks for this day (excludes hard schedule blocks).
  final int actionableTotal;

  /// Completed actionable tasks on this day.
  final int completed;

  /// Missed actionable tasks on this day.
  final int missed;

  /// Skipped actionable tasks on this day.
  final int skipped;

  /// Scheduled base/anchor blocks (e.g., classes, work, fixed routine).
  final int baseBlockCount;

  /// Actionable flexible tasks scheduled on this day.
  final int flexibleTaskCount;

  /// Free minutes within the canonical 06:00–23:00 planning window.
  final int freeMinutes;

  /// Occupied minutes within the canonical 06:00–23:00 planning window.
  final int occupiedMinutes;

  /// The largest contiguous free gap within the planning window.
  final RoutineTimeInterval? largestFreeInterval;

  /// Category keys present on this day.
  final Set<String> availableCategoryKeys;

  const RoutineWeekDaySummary({
    required this.day,
    required this.entries,
    required this.availability,
    required this.actionableTotal,
    required this.completed,
    required this.missed,
    required this.skipped,
    required this.baseBlockCount,
    required this.flexibleTaskCount,
    required this.freeMinutes,
    required this.occupiedMinutes,
    this.largestFreeInterval,
    required this.availableCategoryKeys,
  });

  /// Whether there is at least one actionable task on this day.
  bool get hasActionableTasks => actionableTotal > 0;

  /// Completion progress between 0.0 and 1.0. Returns 0.0 if there are no tasks.
  double get progress =>
      actionableTotal > 0 ? (completed / actionableTotal).clamp(0.0, 1.0) : 0.0;

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

    // 2. Filter out continuation segments for task identity and completion counts.
    // A continuation is schedule occupancy, not an independent task to complete.
    final nonContinuation = entries
        .where((e) => e.kind != RoutineDayEntryKind.continuation)
        .toList(growable: false);

    // 3. Exclude hard blocks from the actionable completion denominator.
    // Hard blocks represent schedule anchors, not to-do tasks.
    final actionable = nonContinuation
        .where(
          (e) =>
              e.item.blockType != RoutineBlockType.hardBlock &&
              !e.item.isHardBlock,
        )
        .toList(growable: false);

    final actionableTotal = actionable.length;
    final completed = actionable
        .where(
          (e) => e.item.isCompleted || e.item.status == RoutineStatus.completed,
        )
        .length;
    final missed = actionable
        .where((e) => e.item.isMissed || e.item.status == RoutineStatus.missed)
        .length;
    final skipped = actionable
        .where((e) => e.item.status == RoutineStatus.skipped)
        .length;

    // 4. Count base blocks and flexible tasks accurately without conflating with "habits".
    final baseBlockCount = nonContinuation
        .where(
          (e) =>
              e.item.isHardBlock ||
              e.item.blockType == RoutineBlockType.hardBlock ||
              e.item.source == RoutineSource.baseTimeline,
        )
        .length;

    final flexibleTaskCount = nonContinuation
        .where((e) => e.item.blockType == RoutineBlockType.flexibleTask)
        .length;

    // 5. Gather category keys present on this day
    final categoryKeys = <String>{};
    for (final opt in categoryFilters) {
      if (opt.key == 'all') continue;
      if (entries.any(
        (e) => RoutineEntryFilter.matchesCategory(e.item, opt.key),
      )) {
        categoryKeys.add(opt.key);
      }
    }

    return RoutineWeekDaySummary(
      day: day,
      entries: entries,
      availability: availability,
      actionableTotal: actionableTotal,
      completed: completed,
      missed: missed,
      skipped: skipped,
      baseBlockCount: baseBlockCount,
      flexibleTaskCount: flexibleTaskCount,
      freeMinutes: availability.freeMinutes,
      occupiedMinutes: availability.occupiedMinutes,
      largestFreeInterval: availability.largestFreeInterval,
      availableCategoryKeys: categoryKeys,
    );
  }
}
