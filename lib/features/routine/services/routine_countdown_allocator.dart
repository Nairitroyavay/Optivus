import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

class RoutineCountdownAllocation {
  final DateTime startedAt;
  final int durationSeconds;

  const RoutineCountdownAllocation({
    required this.startedAt,
    required this.durationSeconds,
  });
}

class RoutineCountdownAllocator {
  const RoutineCountdownAllocator._();

  static RoutineCountdownAllocation? allocate({
    required RoutineItem template,
    required String occurrenceDateKey,
    required DateTime actualStart,
    RoutineOccurrenceRecord? existing,
  }) {
    DateTime startDate;
    int startMinute;
    int endMinute;
    if (existing?.movedToDateKey != null &&
        existing?.movedStartMinute != null &&
        existing?.movedEndMinute != null) {
      startDate = parseRoutineLocalDateKey(existing!.movedToDateKey!);
      startMinute = existing.movedStartMinute!;
      endMinute = existing.movedEndMinute!;
    } else {
      startDate = parseRoutineLocalDateKey(occurrenceDateKey);
      startMinute = template.startMinute;
      endMinute = template.endMinute;
    }

    final plannedStart = startDate.add(Duration(minutes: startMinute));
    var plannedEnd = startDate.add(Duration(minutes: endMinute));
    if ((template.isOvernight && existing?.movedToDateKey == null) ||
        endMinute <= startMinute) {
      plannedEnd = plannedEnd.add(const Duration(days: 1));
    }
    final plannedDurationSeconds = plannedEnd
        .difference(plannedStart)
        .inSeconds;
    if (plannedDurationSeconds <= 0 || plannedDurationSeconds > 24 * 60 * 60) {
      return null;
    }

    final actual = actualStart.toUtc();
    final allocatedSeconds = !actual.isAfter(plannedStart.toUtc())
        ? plannedDurationSeconds
        : actual.isBefore(plannedEnd.toUtc())
        ? plannedEnd.toUtc().difference(actual).inSeconds
        : plannedDurationSeconds;
    return RoutineCountdownAllocation(
      startedAt: actual,
      durationSeconds: allocatedSeconds.clamp(1, 24 * 60 * 60),
    );
  }
}
