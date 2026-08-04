enum RoutineConflictType {
  compatibleOverlap,
  hardBlockConflict,
  unavailableTime,
  duplicateRoutine,
  overnightConflict,
  invalidDuration,
  timeOverlap,
  sleepConflict,
  tooManyTasks,
  trackerTaskNotCompleted,
}

enum RoutineConflictResolution {
  unresolved,
  allowedByUser,
  prohibited,
  informational,
}

class RoutineConflict {
  final String id;
  final RoutineConflictType type;
  final String itemId;
  final String? otherItemId;
  final String title;
  final String message;
  final int startMinute;
  final int endMinute;
  final bool blocking;
  final bool canKeepBoth;
  final RoutineConflictResolution resolution;
  final String? acceptanceId;

  const RoutineConflict({
    required this.id,
    required this.type,
    required this.itemId,
    this.otherItemId,
    required this.title,
    required this.message,
    required this.startMinute,
    required this.endMinute,
    required this.blocking,
    required this.canKeepBoth,
    this.resolution = RoutineConflictResolution.unresolved,
    this.acceptanceId,
  });

  bool get alreadyResolved =>
      resolution == RoutineConflictResolution.allowedByUser;
}

class RoutineConflictSummary {
  final int total;
  final int blocking;

  const RoutineConflictSummary({required this.total, required this.blocking});
}
