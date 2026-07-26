import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/routine_item.dart';

class ReconciledScheduleResult {
  final HabitSystemRecord system;
  final List<RoutineItem> routines;

  const ReconciledScheduleResult({
    required this.system,
    required this.routines,
  });
}

class HabitSystemScheduleReconciler {
  const HabitSystemScheduleReconciler();

  /// Prunes routine IDs from [system.linkedRoutineIds] that do not exist in [existingRoutineIds].
  HabitSystemRecord pruneOrphanedRoutineIds(
    HabitSystemRecord system,
    Set<String> existingRoutineIds,
  ) {
    final validIds = system.linkedRoutineIds
        .where((id) => existingRoutineIds.contains(id))
        .toList();
    if (validIds.length == system.linkedRoutineIds.length) {
      return system;
    }
    return system.copyWith(linkedRoutineIds: validIds);
  }

  /// Propagates habit system status (active, paused, archived) to linked routine items.
  List<RoutineItem> propagateStatusToRoutines({
    required HabitSystemRecord system,
    required List<RoutineItem> routines,
    List<int>? activeRepeatDays,
  }) {
    final linkedSet = system.linkedRoutineIds.toSet();
    if (linkedSet.isEmpty) return routines;

    final now = DateTime.now().toUtc();
    return routines.map((item) {
      if (!linkedSet.contains(item.id)) return item;

      switch (system.status) {
        case HabitSystemStatus.active:
          return item.copyWith(
            status: RoutineStatus.active,
            repeatDays:
                activeRepeatDays ??
                (item.repeatDays.isEmpty
                    ? const [1, 2, 3, 4, 5, 6, 7]
                    : item.repeatDays),
            updatedAt: now,
          );
        case HabitSystemStatus.paused:
          return item.copyWith(
            status: RoutineStatus.planned,
            repeatDays: const [],
            updatedAt: now,
          );
        case HabitSystemStatus.archived:
          return item.copyWith(
            status: RoutineStatus.planned,
            repeatDays: const [],
            updatedAt: now,
          );
      }
    }).toList();
  }

  /// Synchronizes frequency [repeatDays] to linked routine items.
  List<RoutineItem> synchronizeFrequency({
    required HabitSystemRecord system,
    required List<RoutineItem> routines,
    required List<int> repeatDays,
  }) {
    final linkedSet = system.linkedRoutineIds.toSet();
    if (linkedSet.isEmpty) return routines;

    final now = DateTime.now().toUtc();
    return routines.map((item) {
      if (!linkedSet.contains(item.id)) return item;
      return item.copyWith(repeatDays: repeatDays, updatedAt: now);
    }).toList();
  }

  /// Reconciles both habit system record and routine items together.
  ReconciledScheduleResult reconcile({
    required HabitSystemRecord system,
    required List<RoutineItem> routines,
    List<int>? repeatDays,
  }) {
    final existingIds = routines.map((r) => r.id).toSet();
    final prunedSystem = pruneOrphanedRoutineIds(system, existingIds);

    List<RoutineItem> updatedRoutines = routines;
    if (repeatDays != null) {
      updatedRoutines = synchronizeFrequency(
        system: prunedSystem,
        routines: updatedRoutines,
        repeatDays: repeatDays,
      );
    }

    updatedRoutines = propagateStatusToRoutines(
      system: prunedSystem,
      routines: updatedRoutines,
      activeRepeatDays: repeatDays,
    );

    return ReconciledScheduleResult(
      system: prunedSystem,
      routines: updatedRoutines,
    );
  }
}
