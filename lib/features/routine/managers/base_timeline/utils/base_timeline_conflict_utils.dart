import 'package:optivus/models/routine_item.dart';

class BaseTimelineConflictUtils {
  BaseTimelineConflictUtils._();

  /// Validates a new or updated item to see if it introduces hard block conflicts
  /// against the existing list of items. Returns a list of conflicting items.
  static List<RoutineItem> findConflicts(
    RoutineItem candidate,
    List<RoutineItem> allItems,
  ) {
    if (!candidate.isHardBlock &&
        candidate.blockType != RoutineBlockType.hardBlock) {
      return [];
    }

    final List<RoutineItem> conflicts = [];

    for (final existing in allItems) {
      if (existing.id == candidate.id) continue;
      if (!existing.isHardBlock &&
          existing.blockType != RoutineBlockType.hardBlock) {
        continue;
      }

      // Check if they share any days
      if (candidate.repeatDays.isNotEmpty && existing.repeatDays.isNotEmpty) {
        final shareDays = candidate.repeatDays.any(
          (day) => existing.repeatDays.contains(day),
        );
        if (!shareDays) {
          continue;
        }
      }

      // Time overlap check
      final cStart = candidate.startMinute;
      final cEnd = candidate.isOvernight
          ? candidate.endMinute + 1440
          : candidate.endMinute;
      final eStart = existing.startMinute;
      final eEnd = existing.isOvernight
          ? existing.endMinute + 1440
          : existing.endMinute;

      if (cStart < eEnd && cEnd > eStart) {
        conflicts.add(existing);
      }
    }

    return conflicts;
  }
}
