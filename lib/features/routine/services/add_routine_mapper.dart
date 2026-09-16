import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

/// Centralized, testable mapper from [AddRoutineDraft] to [RoutineItem].
///
/// Guarantees:
/// 1. Uses the draft's stable [id].
/// 2. Zero state leakage between modes.
/// 3. Correct schedule semantics for one-time vs weekly recurrence.
/// 4. Preserves all visible inputs including [bestTime] and structured domain fields.
class AddRoutineMapper {
  const AddRoutineMapper._();

  static RoutineItem toRoutineItem(AddRoutineDraft draft) {
    final start = draft.startMinute;
    final endRaw = start + draft.durationMinutes;
    final crossesMidnight = endRaw > 1440;
    final end = crossesMidnight
        ? (endRaw - 1440).clamp(0, 1440).toInt()
        : (endRaw == 0 ? 1440 : endRaw.clamp(1, 1440).toInt());

    final isOneTime = draft.scheduleMode == AddRoutineScheduleMode.once;
    final date = isOneTime ? TimelineUtils.dateOnly(draft.date) : null;
    final endDate = crossesMidnight && isOneTime
        ? TimelineUtils.dateOnly(draft.date).add(const Duration(days: 1))
        : null;

    final repeatDays = isOneTime
        ? const <int>[]
        : List<int>.unmodifiable(draft.repeatDays);
    final repeatRule = isOneTime ? 'once' : 'weekly';

    final effectiveTitle = draft.title.trim();
    final effectiveNotes =
        draft.notes.trim().isEmpty ? null : draft.notes.trim();

    switch (draft.type) {
      case AddRoutineType.flexible:
        final subtasks = draft.flexibleState.subtasks.isEmpty
            ? null
            : List<String>.unmodifiable(draft.flexibleState.subtasks);
        return RoutineItem(
          id: draft.id,
          title: effectiveTitle,
          date: date,
          endDate: endDate,
          startMinute: start,
          endMinute: end,
          crossesMidnight: crossesMidnight,
          endsNextDay: crossesMidnight,
          repeatDays: repeatDays,
          repeatRule: repeatRule,
          blockType: RoutineBlockType.flexibleTask,
          category: draft.flexibleState.category,
          source: RoutineSource.manual,
          status: RoutineStatus.planned,
          priority: draft.priority,
          bestTime: draft.bestTime,
          isTrackerLinked: false,
          trackerType: TrackerType.none,
          hardBlock: false,
          notes: effectiveNotes,
          subtasks: subtasks,
          subtasksCompleted: subtasks == null
              ? null
              : List<bool>.filled(subtasks.length, false),
        );

      case AddRoutineType.fixed:
        final fixedState = draft.fixedState;
        final category = categoryForFixedKind(fixedState.kind);
        final steps = fixedState.steps.isEmpty
            ? null
            : List<String>.unmodifiable(fixedState.steps);
        final dishes = fixedState.dishes.isEmpty
            ? null
            : List<String>.unmodifiable(fixedState.dishes);
        final products = fixedState.skincareProducts.isEmpty
            ? null
            : List<String>.unmodifiable(fixedState.skincareProducts);
        final missing = fixedState.skincareMissingItems.isEmpty
            ? null
            : List<String>.unmodifiable(fixedState.skincareMissingItems);

        final location = fixedState.classLocation ?? fixedState.workLocation;

        return RoutineItem(
          id: draft.id,
          title: effectiveTitle,
          date: date,
          endDate: endDate,
          startMinute: start,
          endMinute: end,
          crossesMidnight: crossesMidnight,
          endsNextDay: crossesMidnight,
          repeatDays: repeatDays,
          repeatRule: repeatRule,
          blockType: fixedState.hardBlock
              ? RoutineBlockType.hardBlock
              : RoutineBlockType.softBlock,
          category: category,
          source: RoutineSource.manual,
          status: RoutineStatus.planned,
          priority: draft.priority,
          bestTime: draft.bestTime,
          isTrackerLinked: false,
          trackerType: TrackerType.none,
          hardBlock: fixedState.hardBlock,
          notes: effectiveNotes,
          location: location,
          // Class fields
          professor: fixedState.professor,
          courseCode: fixedState.courseCode,
          classType: fixedState.classType,
          sectionLabel: fixedState.sectionLabel,
          // Work fields
          workContextType: fixedState.workContextType,
          workRole: fixedState.workRole,
          workOrganization: fixedState.workOrganization,
          workDepartmentOrProject: fixedState.workDepartmentOrProject,
          workMode: fixedState.workMode,
          workBlockKind: fixedState.workBlockKind,
          // Eating fields
          mealCategory: fixedState.mealCategory,
          mealSlot: fixedState.mealSlot,
          dishes: dishes,
          caloriesEstimate: fixedState.caloriesEstimate,
          proteinEstimate: fixedState.proteinEstimate,
          // Skincare fields
          steps: steps,
          skincareProducts: products,
          skincareMissingItems: missing,
          skincareSlotLabel: fixedState.skincareSlotLabel,
        );

      case AddRoutineType.habit:
        final habitState = draft.habitState;
        final isLinked = habitState.trackerType != TrackerType.none;
        final subtasks = habitState.subtasks.isEmpty
            ? null
            : List<String>.unmodifiable(habitState.subtasks);
        final steps = habitState.steps.isEmpty
            ? null
            : List<String>.unmodifiable(habitState.steps);

        return RoutineItem(
          id: draft.id,
          title: effectiveTitle,
          date: date,
          endDate: endDate,
          startMinute: start,
          endMinute: end,
          crossesMidnight: crossesMidnight,
          endsNextDay: crossesMidnight,
          repeatDays: repeatDays,
          repeatRule: repeatRule,
          blockType: isLinked
              ? RoutineBlockType.trackerTask
              : RoutineBlockType.flexibleTask,
          category: habitState.category,
          source: RoutineSource.manual,
          status: RoutineStatus.planned,
          priority: draft.priority,
          bestTime: draft.bestTime,
          isTrackerLinked: isLinked,
          trackerType: habitState.trackerType,
          hardBlock: false,
          notes: effectiveNotes,
          steps: steps,
          subtasks: subtasks,
          subtasksCompleted: subtasks == null
              ? null
              : List<bool>.filled(subtasks.length, false),
        );

      case AddRoutineType.tracker:
        final trackerState = draft.trackerState;
        final subtasks = trackerState.subtasks.isEmpty
            ? null
            : List<String>.unmodifiable(trackerState.subtasks);
        final category = categoryForTrackerType(trackerState.trackerType);

        return RoutineItem(
          id: draft.id,
          title: effectiveTitle,
          date: date,
          endDate: endDate,
          startMinute: start,
          endMinute: end,
          crossesMidnight: crossesMidnight,
          endsNextDay: crossesMidnight,
          repeatDays: repeatDays,
          repeatRule: repeatRule,
          blockType: RoutineBlockType.trackerTask,
          category: category,
          source: RoutineSource.manual,
          status: RoutineStatus.planned,
          priority: draft.priority,
          bestTime: draft.bestTime,
          isTrackerLinked: true,
          trackerType: trackerState.trackerType,
          hardBlock: false,
          notes: effectiveNotes,
          subtasks: subtasks,
          subtasksCompleted: subtasks == null
              ? null
              : List<bool>.filled(subtasks.length, false),
        );

      case AddRoutineType.checkin:
        return RoutineItem(
          id: draft.id,
          title: effectiveTitle,
          date: date,
          endDate: endDate,
          startMinute: start,
          endMinute: end,
          crossesMidnight: crossesMidnight,
          endsNextDay: crossesMidnight,
          repeatDays: repeatDays,
          repeatRule: repeatRule,
          blockType: RoutineBlockType.checkIn,
          category: RoutineCategory.badHabit,
          source: RoutineSource.manual,
          status: RoutineStatus.planned,
          priority: draft.priority,
          bestTime: draft.bestTime,
          isTrackerLinked: false,
          trackerType: TrackerType.none,
          hardBlock: false,
          notes: effectiveNotes,
        );

      case AddRoutineType.money:
        return RoutineItem(
          id: draft.id,
          title: effectiveTitle.isEmpty
              ? draft.moneyState.defaultTitle
              : effectiveTitle,
          date: date,
          endDate: endDate,
          startMinute: start,
          endMinute: end,
          crossesMidnight: crossesMidnight,
          endsNextDay: crossesMidnight,
          repeatDays: repeatDays,
          repeatRule: repeatRule,
          blockType: RoutineBlockType.moneyTask,
          category: RoutineCategory.finance,
          source: RoutineSource.manual,
          status: RoutineStatus.planned,
          priority: draft.priority,
          bestTime: draft.bestTime,
          isTrackerLinked: true,
          trackerType: TrackerType.money,
          hardBlock: false,
          notes: effectiveNotes,
        );
    }
  }

  static RoutineCategory categoryForFixedKind(String kind) {
    return switch (kind) {
      'Class' || 'Tuition' => RoutineCategory.classBlock,
      'Job' => RoutineCategory.job,
      'Eating' => RoutineCategory.eating,
      'Sleep' => RoutineCategory.sleep,
      'Skin Care' => RoutineCategory.skinCare,
      'Bath' || 'Travel' || 'Prayer' => RoutineCategory.fixed,
      _ => RoutineCategory.fixed,
    };
  }

  static RoutineCategory categoryForTrackerType(TrackerType type) {
    return switch (type) {
      TrackerType.meditation => RoutineCategory.meditation,
      TrackerType.hydration => RoutineCategory.hydration,
      TrackerType.money => RoutineCategory.finance,
      TrackerType.focus => RoutineCategory.focus,
      TrackerType.smoking => RoutineCategory.badHabit,
      TrackerType.workout => RoutineCategory.health,
      TrackerType.none => RoutineCategory.health,
    };
  }
}
