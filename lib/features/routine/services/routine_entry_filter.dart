import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_filter_definitions.dart';
import 'package:optivus/models/routine_item.dart';

/// Authoritative filtering engine for Routine day entries.
///
/// Provides single-source filtering across:
/// 1. View (all, base_timeline, flexible_tasks, tracker_tasks, check_ins)
/// 2. Status (any, todo, done, missed)
/// 3. Category (all, or matching dynamic category key)
@immutable
class RoutineEntryFilter {
  const RoutineEntryFilter._();

  /// Whether an item belongs to the Base Timeline (anchor/foundation blocks).
  ///
  /// This is the canonical Base Timeline classifier used across both
  /// Routine timeline filtering and Week Planner base block counting.
  static bool isBaseTimeline(RoutineItem item) {
    if (item.baseTimelineSection != null &&
        item.baseTimelineSection!.trim().isNotEmpty) {
      return true;
    }
    if (item.source == RoutineSource.baseTimeline) {
      return true;
    }
    if (item.source == RoutineSource.onboarding) {
      return item.category == RoutineCategory.classBlock ||
          item.category == RoutineCategory.job ||
          item.category == RoutineCategory.eating ||
          item.category == RoutineCategory.fixed ||
          item.category == RoutineCategory.sleep ||
          item.category == RoutineCategory.skinCare;
    }
    return false;
  }

  /// Whether an item is a flexible task.
  static bool isFlexible(RoutineItem item) =>
      item.blockType == RoutineBlockType.flexibleTask;

  /// Whether an item is a tracker task.
  static bool isTracker(RoutineItem item) =>
      item.blockType == RoutineBlockType.trackerTask;

  /// Whether an item is a check-in item.
  static bool isCheckIn(RoutineItem item) =>
      item.blockType == RoutineBlockType.checkIn;

  /// Evaluates the view axis.
  static bool matchesView(RoutineDayEntry entry, String view) {
    return switch (view) {
      'base_timeline' => isBaseTimeline(entry.item),
      'flexible_tasks' => isFlexible(entry.item),
      'tracker_tasks' => isTracker(entry.item),
      'check_ins' => isCheckIn(entry.item),
      _ => true, // 'all' or fallback
    };
  }

  /// Evaluates the status axis.
  ///
  /// - `any`: all items match.
  /// - `todo`: planned, active, or in-tracker tasks that are NOT completed, missed, or skipped.
  /// - `done`: completed items.
  /// - `missed`: missed items.
  static bool matchesStatus(RoutineDayEntry entry, String status) {
    final item = entry.item;
    return switch (status) {
      'todo' =>
        !item.isCompleted &&
            !item.isMissed &&
            item.status != RoutineStatus.completed &&
            item.status != RoutineStatus.missed &&
            item.status != RoutineStatus.skipped,
      'done' => item.isCompleted || item.status == RoutineStatus.completed,
      'missed' => item.isMissed || item.status == RoutineStatus.missed,
      _ => true, // 'any' or fallback
    };
  }

  /// Evaluates the category axis against the canonical Routine category rules.
  ///
  /// Complete taxonomy covering all [RoutineCategory] enum values:
  /// - classes: classBlock
  /// - job: job
  /// - eating: eating
  /// - fixed: fixed, sleep
  /// - skin_care: skinCare
  /// - good_habits: habit, identity
  /// - bad_habits: badHabit, or keyword
  /// - money: finance, moneyTask
  /// - health: health (Option A explicit category)
  /// - focus: focus, or focus tracker (Option A explicit category)
  /// - meditation: meditation, or meditation tracker
  /// - hydration: hydration, or hydration tracker
  /// - screen_time: screenTime
  static bool matchesCategory(RoutineItem item, String category) {
    if (category == 'all') return true;
    final title = item.title.toLowerCase();
    return switch (category) {
      'classes' => item.category == RoutineCategory.classBlock,
      'job' => item.category == RoutineCategory.job,
      'eating' => item.category == RoutineCategory.eating,
      'fixed' =>
        item.category == RoutineCategory.fixed ||
            item.category == RoutineCategory.sleep,
      'skin_care' => item.category == RoutineCategory.skinCare,
      'good_habits' =>
        item.category == RoutineCategory.habit ||
            item.category == RoutineCategory.identity,
      'bad_habits' =>
        item.category == RoutineCategory.badHabit ||
            title.contains('smok') ||
            title.contains('alcohol') ||
            title.contains('junk'),
      'money' =>
        item.category == RoutineCategory.finance ||
            item.blockType == RoutineBlockType.moneyTask,
      'health' => item.category == RoutineCategory.health,
      'focus' =>
        item.category == RoutineCategory.focus ||
            item.trackerType == TrackerType.focus,
      'meditation' =>
        item.category == RoutineCategory.meditation ||
            item.trackerType == TrackerType.meditation ||
            title.contains('meditat'),
      'hydration' =>
        item.category == RoutineCategory.hydration ||
            item.trackerType == TrackerType.hydration ||
            title.contains('water'),
      'screen_time' => item.category == RoutineCategory.screenTime,
      _ => true,
    };
  }

  /// Applies all active filters to [entries].
  static List<RoutineDayEntry> apply(
    List<RoutineDayEntry> entries, {
    String view = 'all',
    String status = 'any',
    String category = 'all',
  }) {
    return entries
        .where((entry) {
          if (!matchesView(entry, view)) return false;
          if (!matchesStatus(entry, status)) return false;
          if (category != 'all' && !matchesCategory(entry.item, category)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Returns the subset of [categoryFilters] (excluding 'all') that match at least
  /// one entry in [entries].
  static List<RoutineFilterOption> dynamicCategoryOptions(
    List<RoutineDayEntry> entries,
  ) {
    final result = <RoutineFilterOption>[];
    for (final option in categoryFilters) {
      if (option.key == 'all') continue;
      final exists = entries.any(
        (entry) => matchesCategory(entry.item, option.key),
      );
      if (exists) {
        result.add(option);
      }
    }
    return result;
  }
}
