import 'package:flutter/material.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';

class RoutineMaterializer {
  RoutineMaterializer._();

  static List<RoutineItem> itemsForDay(List<RoutineItem> items, DateTime day) {
    final selected = TimelineUtils.dateOnly(day);
    final previous = selected.subtract(const Duration(days: 1));
    final result = <RoutineItem>[];

    for (final item in items) {
      if (_startsOnDay(item, selected)) {
        result.add(item);
      }
      if (_isOvernight(item) && _startsOnDay(item, previous)) {
        result.add(
          item.copyWith(
            date: selected,
            startMinute: 0,
            endMinute: item.endMinute,
            crossesMidnight: false,
            endsNextDay: false,
            isContinuation: true,
          ),
        );
      }
    }

    return result;
  }

  static bool occursOnDay(RoutineItem item, DateTime day) {
    final selected = TimelineUtils.dateOnly(day);
    return _startsOnDay(item, selected) ||
        (_isOvernight(item) &&
            _startsOnDay(item, selected.subtract(const Duration(days: 1))));
  }

  static bool startsOnDay(RoutineItem item, DateTime day) {
    return _startsOnDay(item, TimelineUtils.dateOnly(day));
  }

  static bool _startsOnDay(RoutineItem item, DateTime day) {
    final date = item.date;
    if (date != null && _isOneTimeDatedItem(item)) {
      return DateUtils.isSameDay(date, day);
    }
    if (date != null && day.isBefore(TimelineUtils.dateOnly(date))) {
      return false;
    }
    final endDate = item.endDate;
    if (endDate != null && day.isAfter(TimelineUtils.dateOnly(endDate))) {
      return false;
    }
    if (item.repeatDays.contains(day.weekday)) {
      return true;
    }
    return _repeatRuleMatches(item.repeatRule, day);
  }

  static bool _isOneTimeDatedItem(RoutineItem item) {
    final rule = item.repeatRule?.trim().toLowerCase();
    return rule == null || rule.isEmpty || rule == 'once' || rule == 'none';
  }

  static bool _isOvernight(RoutineItem item) {
    return item.crossesMidnight ||
        item.endsNextDay ||
        item.endMinute <= item.startMinute;
  }

  static bool _repeatRuleMatches(String? repeatRule, DateTime day) {
    final rule = repeatRule?.trim().toLowerCase();
    if (rule == null || rule.isEmpty || rule == 'once' || rule == 'none') {
      return false;
    }
    if (rule == 'daily' || rule == 'everyday') {
      return true;
    }
    if (rule == 'weekly') return false;
    if (rule == 'weekdays') return day.weekday <= DateTime.friday;
    if (rule == 'weekends') return day.weekday >= DateTime.saturday;

    const names = {
      DateTime.monday: ['mon', 'monday'],
      DateTime.tuesday: ['tue', 'tuesday'],
      DateTime.wednesday: ['wed', 'wednesday'],
      DateTime.thursday: ['thu', 'thursday'],
      DateTime.friday: ['fri', 'friday'],
      DateTime.saturday: ['sat', 'saturday'],
      DateTime.sunday: ['sun', 'sunday'],
    };
    return names[day.weekday]!.any(rule.contains);
  }
}

class RoutineOccurrenceProjector {
  const RoutineOccurrenceProjector._();

  /// Returns occurrence-aware entries for [day], each with a stable
  /// [RoutineDayEntry.instanceId] that is unique even when the same template
  /// appears twice (overnight continuation + native, or moved-in + native).
  ///
  /// This is the authoritative source for the live timeline. All existing
  /// callers that only need [RoutineItem] should use [itemsForDay].
  static List<RoutineDayEntry> entriesForDay(
    List<RoutineItem> templates,
    List<RoutineOccurrenceRecord> occurrences,
    DateTime day,
  ) {
    final dateKey = routineLocalDateKey(day);
    final byTemplateAndDate = {
      for (final occurrence in occurrences)
        '${occurrence.routineItemId}\u001f${occurrence.occurrenceDateKey}':
            occurrence,
    };
    final result = <RoutineDayEntry>[];

    for (final item in RoutineMaterializer.itemsForDay(templates, day)) {
      final isContinuation = item.isContinuation;
      final occDateKey = isContinuation
          ? routineLocalDateKey(day.subtract(const Duration(days: 1)))
          : dateKey;
      final occurrence = byTemplateAndDate['${item.id}\u001f$occDateKey'];
      if (occurrence?.movedToDateKey != null &&
          occurrence!.movedToDateKey != dateKey) {
        continue;
      }
      final kind = isContinuation
          ? RoutineDayEntryKind.continuation
          : RoutineDayEntryKind.scheduled;
      final occId = occurrence?.id;
      final instanceId = RoutineDayEntry.deriveInstanceId(
        kind: kind,
        templateId: item.id,
        occurrenceDateKey: occDateKey,
        occurrenceId: occId,
      );
      result.add(
        RoutineDayEntry(
          item: _applyOccurrence(item, occurrence, day),
          instanceId: instanceId,
          templateId: item.id,
          occurrenceDateKey: occDateKey,
          displayDateKey: dateKey,
          occurrenceId: occId,
          kind: kind,
        ),
      );
    }

    // Moved-in occurrences from other dates.
    for (final occurrence in occurrences) {
      if (occurrence.movedToDateKey != dateKey ||
          occurrence.occurrenceDateKey == dateKey) {
        continue;
      }
      RoutineItem? template;
      for (final candidate in templates) {
        if (candidate.id == occurrence.routineItemId) {
          template = candidate;
          break;
        }
      }
      if (template == null) continue;
      final instanceId = RoutineDayEntry.deriveInstanceId(
        kind: RoutineDayEntryKind.movedIn,
        templateId: template.id,
        occurrenceDateKey: occurrence.occurrenceDateKey,
        occurrenceId: occurrence.id,
      );
      result.add(
        RoutineDayEntry(
          item: _applyOccurrence(template, occurrence, day),
          instanceId: instanceId,
          templateId: template.id,
          occurrenceDateKey: occurrence.occurrenceDateKey,
          displayDateKey: dateKey,
          occurrenceId: occurrence.id,
          kind: RoutineDayEntryKind.movedIn,
        ),
      );
    }
    return result;
  }

  static List<RoutineItem> itemsForDay(
    List<RoutineItem> templates,
    List<RoutineOccurrenceRecord> occurrences,
    DateTime day,
  ) {
    return entriesForDay(templates, occurrences, day)
        .map((e) => e.item)
        .toList(growable: false);
  }


  static RoutineItem _applyOccurrence(
    RoutineItem item,
    RoutineOccurrenceRecord? occurrence,
    DateTime day,
  ) {
    if (occurrence == null) {
      return item.copyWith(
        status: RoutineStatus.planned,
        isCompleted: false,
        isMissed: false,
      );
    }
    final subtasksCompleted = item.subtasks == null
        ? null
        : List<bool>.generate(
            item.subtasks!.length,
            occurrence.completedSubtaskIndexes.contains,
          );
    final moved = occurrence.movedToDateKey != null;
    final occurrenceNote = occurrence.note?.trim();
    final templateNote = item.notes?.trim();
    final notes = occurrenceNote == null || occurrenceNote.isEmpty
        ? item.notes
        : templateNote == null || templateNote.isEmpty
        ? occurrenceNote
        : '$templateNote\n$occurrenceNote';
    return item.copyWith(
      title: occurrence.displayTitleOverride ?? item.title,
      date: moved ? TimelineUtils.dateOnly(day) : item.date,
      startMinute: occurrence.movedStartMinute ?? item.startMinute,
      endMinute: occurrence.movedEndMinute ?? item.endMinute,
      crossesMidnight: moved ? false : item.crossesMidnight,
      endsNextDay: moved ? false : item.endsNextDay,
      repeatDays: moved ? const [] : item.repeatDays,
      status: occurrence.status,
      isCompleted: occurrence.status == RoutineStatus.completed,
      isMissed: occurrence.status == RoutineStatus.missed,
      subtasksCompleted: subtasksCompleted,
      notes: notes,
      undoToPlannedAllowed: occurrence.undoToPlannedAllowed,
    );
  }
}
