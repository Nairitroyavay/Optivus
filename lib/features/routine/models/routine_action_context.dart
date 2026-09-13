import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

/// Immutable action context carrying authoritative occurrence identity from
/// [RoutineDayEntry] down to cards, buttons, and sheets.
///
/// Prevents the action layer from re-inferring occurrence dates from [DateTime.now()]
/// or stale template start dates.
@immutable
class RoutineActionContext {
  /// The visible timeline instance identity.
  final String instanceId;

  /// The persistent template ID ([RoutineItem.id]).
  final String templateId;

  /// The date key of the persistent source occurrence record.
  /// Scheduled → displayDateKey.
  /// Continuation → yesterday.
  /// MovedIn → original source occurrence date.
  final String occurrenceDateKey;

  /// The date key of the day currently displayed in the viewport.
  final String displayDateKey;

  /// Stable occurrence record ID if known.
  final String? occurrenceId;

  /// The kind of timeline entry (scheduled, continuation, movedIn).
  final RoutineDayEntryKind kind;

  /// The projected [RoutineItem] for this occurrence.
  final RoutineItem item;

  const RoutineActionContext({
    required this.instanceId,
    required this.templateId,
    required this.occurrenceDateKey,
    required this.displayDateKey,
    this.occurrenceId,
    required this.kind,
    required this.item,
  });

  /// Factory creating an action context directly from the authoritative [RoutineDayEntry].
  factory RoutineActionContext.fromDayEntry(RoutineDayEntry entry) {
    return RoutineActionContext(
      instanceId: entry.instanceId,
      templateId: entry.templateId,
      occurrenceDateKey: entry.occurrenceDateKey,
      displayDateKey: entry.displayDateKey,
      occurrenceId: entry.occurrenceId,
      kind: entry.kind,
      item: entry.item,
    );
  }

  /// Fallback constructor when [RoutineDayEntry] is not available directly.
  factory RoutineActionContext.fallback({
    required RoutineItem item,
    DateTime? occurrenceDate,
    DateTime? displayDate,
    String? templateId,
    String? instanceId,
    RoutineDayEntryKind kind = RoutineDayEntryKind.scheduled,
  }) {
    final occDate = occurrenceDate ?? item.date ?? DateTime.now();
    final dispDate = displayDate ?? occDate;
    final occKey = routineLocalDateKey(occDate);
    final dispKey = routineLocalDateKey(dispDate);
    return RoutineActionContext(
      instanceId: instanceId ?? item.id,
      templateId: templateId ?? item.id,
      occurrenceDateKey: occKey,
      displayDateKey: dispKey,
      kind: kind,
      item: item,
    );
  }

  DateTime get occurrenceDate => parseRoutineLocalDateKey(occurrenceDateKey);
  DateTime get displayDate => parseRoutineLocalDateKey(displayDateKey);

  bool get isScheduled => kind == RoutineDayEntryKind.scheduled;
  bool get isContinuation => kind == RoutineDayEntryKind.continuation;
  bool get isMovedIn => kind == RoutineDayEntryKind.movedIn;
}
