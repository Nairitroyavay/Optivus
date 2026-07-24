import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/services/routine_conflict_engine.dart';

/// Thin adapter that delegates all conflict detection to [RoutineConflictEngine].
///
/// All overlap and classification rules live in [RoutineConflictEngine].
/// This class must not maintain independent overlap rules.
class BaseTimelineConflictUtils {
  BaseTimelineConflictUtils._();

  /// Returns a list of [RoutineItem]s from [allItems] that conflict with
  /// [candidate] according to the canonical [RoutineConflictEngine].
  ///
  /// The [day] parameter is required so that the engine can compute anchored
  /// date-time intervals without calling [DateTime.now] internally.
  static List<RoutineItem> findConflicts(
    RoutineItem candidate,
    List<RoutineItem> allItems, {
    required DateTime day,
  }) {
    // Build the full list including the candidate so the engine sees all items.
    final allWithCandidate = [
      ...allItems.where((i) => i.id != candidate.id),
      candidate,
    ];

    final conflicts = RoutineConflictEngine.detect(allWithCandidate, day);

    // Return the items that the engine flagged as conflicting with the candidate.
    final conflictingIds = <String>{};
    for (final conflict in conflicts) {
      if (conflict.itemId == candidate.id && conflict.otherItemId != null) {
        conflictingIds.add(conflict.otherItemId!);
      } else if (conflict.otherItemId == candidate.id) {
        conflictingIds.add(conflict.itemId);
      }
    }

    return allItems
        .where(
          (item) => item.id != candidate.id && conflictingIds.contains(item.id),
        )
        .toList();
  }
}
