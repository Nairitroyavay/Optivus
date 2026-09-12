import 'package:flutter/foundation.dart';
import 'package:optivus/models/routine_item.dart';

/// The kind of occurrence this day entry represents.
enum RoutineDayEntryKind {
  /// A normally scheduled occurrence: the template starts on this display date.
  scheduled,

  /// An overnight continuation: the template started on the previous day and
  /// continues (00:00 → endMinute) on this display date.
  continuation,

  /// An occurrence that was moved from another date into this display date.
  movedIn,
}

/// Immutable per-day projection model for one visible timeline occurrence/segment.
///
/// Separates two identity concepts that were previously conflated:
///  - [templateId]: the durable [RoutineItem.id] stored in Firestore.
///  - [instanceId]: the stable per-render identity for this exact visible slot.
///
/// When a recurring overnight item appears on a given day, it produces TWO
/// [RoutineDayEntry] objects with the same [templateId] but different
/// [instanceId]s (one for the continuation segment, one for the day's own
/// start segment). The same applies when a moved-in occurrence co-exists with
/// the native occurrence.
///
/// DO NOT persist this model to Firestore.
@immutable
class RoutineDayEntry {
  /// The display-ready [RoutineItem] (occurrence applied, status patched).
  final RoutineItem item;

  /// Stable unique identity for this exact visible occurrence/segment.
  ///
  /// Invariants:
  ///  - Two visible instances of the same template on the same day have
  ///    DIFFERENT [instanceId]s.
  ///  - The same instance produces the same [instanceId] across rebuilds.
  ///  - Does NOT depend on list position.
  final String instanceId;

  /// Persistent identity: [RoutineItem.id] of the template in Firestore.
  final String templateId;

  /// The date key of the original occurrence that this entry targets for
  /// writes (Start, Done, Move, subtask toggles).
  ///
  /// - For [RoutineDayEntryKind.scheduled]: the [displayDateKey].
  /// - For [RoutineDayEntryKind.continuation]: the *previous* day's date key
  ///   (the overnight occurrence belongs to yesterday).
  /// - For [RoutineDayEntryKind.movedIn]: the original source occurrence date.
  final String occurrenceDateKey;

  /// The date key of the day currently being displayed.
  final String displayDateKey;

  /// The stable occurrence record ID if a persisted occurrence record exists,
  /// or null if this occurrence has not yet been acted on.
  final String? occurrenceId;

  /// What kind of occurrence/segment this entry represents.
  final RoutineDayEntryKind kind;

  const RoutineDayEntry({
    required this.item,
    required this.instanceId,
    required this.templateId,
    required this.occurrenceDateKey,
    required this.displayDateKey,
    this.occurrenceId,
    required this.kind,
  });

  int get startMinute => item.startMinute;
  int get endMinute => item.endMinute;
  int get durationMinutes => item.durationMinutes;
  String get title => item.title;

  /// Convenience: derive [instanceId] deterministically from the entry's
  /// identity components. See class documentation for the invariants.
  ///
  /// Format:
  ///  - scheduled   → `s:<templateId>:<occurrenceDateKey>`
  ///  - continuation → `c:<templateId>:<occurrenceDateKey>` (occurrenceDateKey
  ///    is yesterday)
  ///  - movedIn with occurrenceId → `m:<occurrenceId>`
  ///  - movedIn without occurrenceId → `m:<templateId>:<occurrenceDateKey>`
  static String deriveInstanceId({
    required RoutineDayEntryKind kind,
    required String templateId,
    required String occurrenceDateKey,
    String? occurrenceId,
  }) {
    switch (kind) {
      case RoutineDayEntryKind.scheduled:
        return 's:$templateId:$occurrenceDateKey';
      case RoutineDayEntryKind.continuation:
        return 'c:$templateId:$occurrenceDateKey';
      case RoutineDayEntryKind.movedIn:
        if (occurrenceId != null && occurrenceId.isNotEmpty) {
          return 'm:$occurrenceId';
        }
        return 'm:$templateId:$occurrenceDateKey';
    }
  }
}

/// Explicit compatibility adapter for presentation-only tests.
///
/// It cannot represent duplicate visible instances of one template.
/// Production callers must use `RoutineOccurrenceProjector.entriesForDay`.
@visibleForTesting
List<RoutineDayEntry> legacyRoutineDayEntriesForTesting(
  List<RoutineItem> items, {
  DateTime? displayDate,
}) {
  assert(
    items.map((item) => item.id).toSet().length == items.length,
    'Legacy testing adapter cannot represent duplicate template instances.',
  );
  final day = displayDate ?? DateTime(2026, 9, 14);
  final dateKey =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  return List.unmodifiable([
    for (final item in items)
      RoutineDayEntry(
        item: item,
        instanceId: item.id,
        templateId: item.id,
        occurrenceDateKey: dateKey,
        displayDateKey: dateKey,
        kind: item.isContinuation
            ? RoutineDayEntryKind.continuation
            : RoutineDayEntryKind.scheduled,
      ),
  ]);
}
