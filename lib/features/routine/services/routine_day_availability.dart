import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

/// Canonical Routine planning window boundaries.
///
/// Routine free-slot placement and day availability are measured
/// between 06:00 (360) and 23:00 (1380), giving a 17-hour (1020-minute) day.
const int kRoutinePlanningWindowStartMinute = 360; // 06:00
const int kRoutinePlanningWindowEndMinute = 1380; // 23:00

/// Represents a half-open time interval [startMinute, endMinute).
@immutable
class RoutineTimeInterval {
  final int startMinute;
  final int endMinute;

  const RoutineTimeInterval({
    required this.startMinute,
    required this.endMinute,
  }) : assert(startMinute <= endMinute, 'startMinute must be <= endMinute');

  int get durationMinutes => endMinute - startMinute;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineTimeInterval &&
          runtimeType == other.runtimeType &&
          startMinute == other.startMinute &&
          endMinute == other.endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);

  @override
  String toString() => '[$startMinute, $endMinute] (${durationMinutes}m)';
}

/// Immutable availability calculation for a routine day.
///
/// Encapsulates occupied and free time within a canonical planning window,
/// unioning overlapping and touching intervals to guarantee that overlapping
/// blocks are never double-counted.
@immutable
class RoutineDayAvailability {
  final int windowStartMinute;
  final int windowEndMinute;
  final List<RoutineTimeInterval> occupiedIntervals;
  final List<RoutineTimeInterval> freeIntervals;
  final int occupiedMinutes;
  final int freeMinutes;

  const RoutineDayAvailability({
    required this.windowStartMinute,
    required this.windowEndMinute,
    required this.occupiedIntervals,
    required this.freeIntervals,
    required this.occupiedMinutes,
    required this.freeMinutes,
  });

  /// The single largest contiguous free interval in the planning window,
  /// or null if the window is completely occupied.
  RoutineTimeInterval? get largestFreeInterval {
    if (freeIntervals.isEmpty) return null;
    RoutineTimeInterval? largest;
    for (final interval in freeIntervals) {
      if (largest == null ||
          interval.durationMinutes > largest.durationMinutes) {
        largest = interval;
      }
    }
    return largest;
  }

  /// Computes availability from occurrence-aware [RoutineDayEntry] items.
  ///
  /// This is the authoritative engine entry point for the Routine tab,
  /// Week Planner, and slot placement.
  factory RoutineDayAvailability.computeFromEntries(
    List<RoutineDayEntry> entries, {
    int windowStartMinute = kRoutinePlanningWindowStartMinute,
    int windowEndMinute = kRoutinePlanningWindowEndMinute,
  }) {
    final rawIntervals = <RoutineTimeInterval>[];

    for (final entry in entries) {
      final item = entry.item;
      int startMinute;
      int endMinute;

      if (entry.kind == RoutineDayEntryKind.continuation) {
        startMinute = 0;
        endMinute = item.endMinute;
      } else if (item.crossesMidnight ||
          item.endsNextDay ||
          item.endMinute <= item.startMinute) {
        startMinute = item.startMinute;
        endMinute = TimelineUtils.normalizedEndMinute(item);
      } else {
        startMinute = item.startMinute;
        endMinute = item.endMinute;
      }

      final clippedStart = max(windowStartMinute, startMinute);
      final clippedEnd = min(windowEndMinute, endMinute);

      if (clippedEnd > clippedStart) {
        rawIntervals.add(
          RoutineTimeInterval(
            startMinute: clippedStart,
            endMinute: clippedEnd,
          ),
        );
      }
    }

    return RoutineDayAvailability.computeFromIntervals(
      rawIntervals,
      windowStartMinute: windowStartMinute,
      windowEndMinute: windowEndMinute,
    );
  }

  /// Computes availability from [RoutineItem]s for backwards compatibility.
  factory RoutineDayAvailability.computeFromItems(
    List<RoutineItem> items, {
    int windowStartMinute = kRoutinePlanningWindowStartMinute,
    int windowEndMinute = kRoutinePlanningWindowEndMinute,
  }) {
    final rawIntervals = <RoutineTimeInterval>[];

    for (final item in items) {
      int startMinute;
      int endMinute;

      if (item.isContinuation) {
        startMinute = 0;
        endMinute = item.endMinute;
      } else if (item.crossesMidnight ||
          item.endsNextDay ||
          item.endMinute <= item.startMinute) {
        startMinute = item.startMinute;
        endMinute = TimelineUtils.normalizedEndMinute(item);
      } else {
        startMinute = item.startMinute;
        endMinute = item.endMinute;
      }

      final clippedStart = max(windowStartMinute, startMinute);
      final clippedEnd = min(windowEndMinute, endMinute);

      if (clippedEnd > clippedStart) {
        rawIntervals.add(
          RoutineTimeInterval(
            startMinute: clippedStart,
            endMinute: clippedEnd,
          ),
        );
      }
    }

    return RoutineDayAvailability.computeFromIntervals(
      rawIntervals,
      windowStartMinute: windowStartMinute,
      windowEndMinute: windowEndMinute,
    );
  }

  /// Pure interval merging and complementary gap computation.
  factory RoutineDayAvailability.computeFromIntervals(
    List<RoutineTimeInterval> rawIntervals, {
    int windowStartMinute = kRoutinePlanningWindowStartMinute,
    int windowEndMinute = kRoutinePlanningWindowEndMinute,
  }) {
    // 1. Sort intervals by startMinute, then endMinute
    final sorted = List<RoutineTimeInterval>.from(rawIntervals)
      ..sort((a, b) {
        final cmp = a.startMinute.compareTo(b.startMinute);
        return cmp != 0 ? cmp : a.endMinute.compareTo(b.endMinute);
      });

    // 2. Merge overlapping and touching intervals
    final mergedOccupied = <RoutineTimeInterval>[];
    for (final interval in sorted) {
      if (mergedOccupied.isEmpty) {
        mergedOccupied.add(interval);
      } else {
        final last = mergedOccupied.last;
        if (interval.startMinute <= last.endMinute) {
          mergedOccupied[mergedOccupied.length - 1] = RoutineTimeInterval(
            startMinute: last.startMinute,
            endMinute: max(last.endMinute, interval.endMinute),
          );
        } else {
          mergedOccupied.add(interval);
        }
      }
    }

    // 3. Calculate complementary free intervals
    final freeIntervals = <RoutineTimeInterval>[];
    var cursor = windowStartMinute;
    for (final occ in mergedOccupied) {
      if (occ.startMinute > cursor) {
        freeIntervals.add(
          RoutineTimeInterval(
            startMinute: cursor,
            endMinute: occ.startMinute,
          ),
        );
      }
      cursor = max(cursor, occ.endMinute);
    }
    if (cursor < windowEndMinute) {
      freeIntervals.add(
        RoutineTimeInterval(
          startMinute: cursor,
          endMinute: windowEndMinute,
        ),
      );
    }

    // 4. Sum up minutes
    final occupiedMinutes = mergedOccupied.fold<int>(
      0,
      (sum, interval) => sum + interval.durationMinutes,
    );
    final freeMinutes = freeIntervals.fold<int>(
      0,
      (sum, interval) => sum + interval.durationMinutes,
    );

    return RoutineDayAvailability(
      windowStartMinute: windowStartMinute,
      windowEndMinute: windowEndMinute,
      occupiedIntervals: List.unmodifiable(mergedOccupied),
      freeIntervals: List.unmodifiable(freeIntervals),
      occupiedMinutes: occupiedMinutes,
      freeMinutes: freeMinutes,
    );
  }

  /// Finds the earliest free slot within [freeIntervals] that can accommodate
  /// [durationMinutes], adhering to [snapMinutes] ceiling alignment.
  ///
  /// For example, if a free gap begins at 07:03 and [snapMinutes] is 5,
  /// the earliest aligned candidate is 07:05. If [snapMinutes] is 1, it is 07:03.
  int? findFirstFreeSlot({
    required int durationMinutes,
    int snapMinutes = 5,
  }) {
    if (durationMinutes <= 0) return windowStartMinute;

    for (final free in freeIntervals) {
      if (free.durationMinutes < durationMinutes) continue;

      // Align free.startMinute upwards to snapMinutes
      final candidateStart = snapMinutes <= 1
          ? free.startMinute
          : ((free.startMinute + snapMinutes - 1) ~/ snapMinutes) * snapMinutes;

      if (candidateStart + durationMinutes <= free.endMinute) {
        return candidateStart;
      }
    }
    return null;
  }
}
