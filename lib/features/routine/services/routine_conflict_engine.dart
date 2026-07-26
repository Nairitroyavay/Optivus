import 'package:flutter/material.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/models/routine_occurrence.dart';

extension RoutineItemAppliesExt on RoutineItem {
  bool appliesToDate(DateTime day) {
    return RoutineMaterializer.occursOnDay(this, day);
  }
}

class RoutineConflictEngine {
  RoutineConflictEngine._();

  static String scheduleFingerprint(
    RoutineItem a,
    RoutineItem b,
    RoutineConflictType conflictType,
  ) {
    final ordered = [a, b]..sort((left, right) => left.id.compareTo(right.id));
    String part(RoutineItem item) {
      final repeatDays = [...item.repeatDays]..sort();
      return [
        item.id,
        item.startMinute,
        item.endMinute,
        item.crossesMidnight,
        item.endsNextDay,
        item.date == null ? '' : routineLocalDateKey(item.date!),
        item.endDate == null ? '' : routineLocalDateKey(item.endDate!),
        repeatDays.join(','),
        item.repeatRule ?? '',
      ].join(':');
    }

    return [
      'v1',
      conflictType.name,
      part(ordered[0]),
      part(ordered[1]),
    ].join('|');
  }

  static List<RoutineConflict> detect(
    List<RoutineItem> items,
    DateTime day, {
    DateTime? now,
  }) {
    final conflicts = <RoutineConflict>[];
    final targetDay = day;

    for (final item in items) {
      if (item.durationMinutes <= 0) {
        conflicts.add(
          RoutineConflict(
            id: 'invalid-duration-${item.id}',
            type: RoutineConflictType.invalidDuration,
            itemId: item.id,
            title: 'Invalid Duration',
            message: '${item.title} has a zero or negative duration.',
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            blocking: true,
            canKeepBoth: false,
          ),
        );
      }
    }

    final meaningful =
        items.where((item) => item.durationMinutes > 0).toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    for (int i = 0; i < meaningful.length; i++) {
      final a = meaningful[i];
      final aRange = _itemDateRange(a, targetDay);

      for (int j = i + 1; j < meaningful.length; j++) {
        final b = meaningful[j];
        final bRange = _itemDateRange(b, targetDay);

        if (aRange.start.isBefore(bRange.end) &&
            aRange.end.isAfter(bRange.start)) {
          final isAUnavailable = _isUnavailableTime(a);
          final isBUnavailable = _isUnavailableTime(b);
          final isASleep = _isSleep(a);
          final isBSleep = _isSleep(b);

          RoutineConflictType conflictType = RoutineConflictType.timeOverlap;
          bool blocking = false;
          bool canKeepBoth = true;

          if (isAUnavailable && isBUnavailable) {
            conflictType = RoutineConflictType.unavailableTime;
            blocking = true;
            canKeepBoth = false;
          } else if (isASleep || isBSleep) {
            conflictType = RoutineConflictType.sleepConflict;
            blocking = true;
            canKeepBoth = false;
          } else if (a.isHardBlock && b.isHardBlock) {
            conflictType = RoutineConflictType.hardBlockConflict;
            blocking = true;
            canKeepBoth = false; // Two hard blocks cannot be kept together
          }

          if (conflictType == RoutineConflictType.timeOverlap &&
              (a.crossesMidnight ||
                  b.crossesMidnight ||
                  a.endsNextDay ||
                  b.endsNextDay)) {
            conflictType = RoutineConflictType.overnightConflict;
            blocking = true;
            canKeepBoth = false;
          }

          // Evaluate Conflict Allowance Contract AFTER classification
          if (canKeepBoth) {
            final fingerprint = scheduleFingerprint(a, b, conflictType);
            final dateKey = routineLocalDateKey(targetDay);
            final canonicalPairId = ([a.id, b.id]..sort()).join('_');

            final aAllows = a.allowedConflicts.any(
              (c) =>
                  c.canonicalPairId == canonicalPairId &&
                  c.conflictType == conflictType.name &&
                  c.scheduleFingerprint == fingerprint &&
                  c.evaluatedDateKey == dateKey,
            );

            final bAllows = b.allowedConflicts.any(
              (c) =>
                  c.canonicalPairId == canonicalPairId &&
                  c.conflictType == conflictType.name &&
                  c.scheduleFingerprint == fingerprint &&
                  c.evaluatedDateKey == dateKey,
            );

            if (aAllows && bAllows) {
              continue; // Authorized Keep Both
            }
          }

          final overlapStart = aRange.start.isBefore(bRange.start)
              ? bRange.start
              : aRange.start;
          final overlapEnd = aRange.end.isBefore(bRange.end)
              ? aRange.end
              : bRange.end;

          final startMin = overlapStart.hour * 60 + overlapStart.minute;
          var endMin = overlapEnd.hour * 60 + overlapEnd.minute;
          if (overlapEnd.isAfter(
            DateTime(
              overlapStart.year,
              overlapStart.month,
              overlapStart.day,
              23,
              59,
              59,
            ),
          )) {
            endMin += 1440;
          } else if (endMin < startMin) {
            endMin += 1440;
          }

          conflicts.add(
            RoutineConflict(
              id: 'overlap-${a.id}-${b.id}',
              type: conflictType,
              itemId: a.id,
              otherItemId: b.id,
              title: '${a.title} overlaps ${b.title}',
              message: '${a.title} overlaps with ${b.title}',
              startMinute: startMin,
              endMinute: endMin,
              blocking: blocking,
              canKeepBoth: canKeepBoth,
            ),
          );
        }
      }
    }

    conflicts.addAll(_duplicateConflicts(meaningful, targetDay));

    if (meaningful.length > 14) {
      conflicts.add(
        RoutineConflict(
          id: 'too-many-${targetDay.toIso8601String()}',
          type: RoutineConflictType.tooManyTasks,
          itemId: meaningful.first.id,
          title: 'Too many tasks in one day',
          message: '${meaningful.length} scheduled items may be too dense.',
          startMinute: meaningful.first.startMinute,
          endMinute: meaningful.last.endMinute,
          blocking: false,
          canKeepBoth: true,
        ),
      );
    }

    // Tracker-overdue warnings require an injected current time.
    // Skip this check when now is not provided (e.g., validation passes).
    if (now != null && (DateUtils.isSameDay(targetDay, now))) {
      final currentMinute = now.hour * 60 + now.minute;
      for (final item in meaningful) {
        final overdueTracker =
            item.blockType == RoutineBlockType.trackerTask &&
            item.endMinute < currentMinute &&
            item.status != RoutineStatus.completed &&
            item.status != RoutineStatus.inTracker &&
            !item.isCompleted;
        if (overdueTracker) {
          conflicts.add(
            RoutineConflict(
              id: 'tracker-incomplete-${item.id}',
              type: RoutineConflictType.trackerTaskNotCompleted,
              itemId: item.id,
              title: '${item.title} not completed',
              message:
                  '${item.title} was scheduled but not completed in Tracker.',
              startMinute: item.startMinute,
              endMinute: item.endMinute,
              blocking: false,
              canKeepBoth: true,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  static DateTimeRange _itemDateRange(RoutineItem item, DateTime day) {
    final startMinute = item.startMinute;
    final endMinute = item.endMinute;
    var start = DateTime(
      day.year,
      day.month,
      day.day,
      startMinute ~/ 60,
      startMinute % 60,
    );
    var end = DateTime(
      day.year,
      day.month,
      day.day,
      endMinute ~/ 60,
      endMinute % 60,
    );
    if (item.crossesMidnight || item.endsNextDay || endMinute <= startMinute) {
      end = end.add(const Duration(days: 1));
    }
    return DateTimeRange(start: start, end: end);
  }

  static bool _isUnavailableTime(RoutineItem item) {
    return _isStrictHard(item);
  }

  static bool _isStrictHard(RoutineItem item) {
    return item.category == RoutineCategory.classBlock ||
        item.category == RoutineCategory.job;
  }

  static bool _isSleep(RoutineItem item) {
    return item.category == RoutineCategory.sleep;
  }

  static List<RoutineConflict> _duplicateConflicts(
    List<RoutineItem> items,
    DateTime day,
  ) {
    final conflicts = <RoutineConflict>[];
    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];

        if (!a.appliesToDate(day) || !b.appliesToDate(day)) continue;

        final aTitle = a.title.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        final bTitle = b.title.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );

        if (aTitle == bTitle && a.category == b.category) {
          final conflictType = RoutineConflictType.duplicateRoutine;

          final fingerprint = scheduleFingerprint(a, b, conflictType);
          final dateKey = routineLocalDateKey(day);
          final canonicalPairId = ([a.id, b.id]..sort()).join('_');

          final aAllows = a.allowedConflicts.any(
            (c) =>
                c.canonicalPairId == canonicalPairId &&
                c.conflictType == conflictType.name &&
                c.scheduleFingerprint == fingerprint &&
                c.evaluatedDateKey == dateKey,
          );

          final bAllows = b.allowedConflicts.any(
            (c) =>
                c.canonicalPairId == canonicalPairId &&
                c.conflictType == conflictType.name &&
                c.scheduleFingerprint == fingerprint &&
                c.evaluatedDateKey == dateKey,
          );

          if (aAllows && bAllows) {
            continue; // Authorized Keep Both
          }

          conflicts.add(
            RoutineConflict(
              id: 'duplicate-${a.id}-${b.id}',
              type: conflictType,
              itemId: a.id,
              otherItemId: b.id,
              title: 'Duplicate task',
              message: '${a.title} appears more than once.',
              startMinute: a.startMinute < b.startMinute
                  ? a.startMinute
                  : b.startMinute,
              endMinute: a.endMinute > b.endMinute ? a.endMinute : b.endMinute,
              blocking: false,
              canKeepBoth: true,
            ),
          );
        }
      }
    }
    return conflicts;
  }
}
