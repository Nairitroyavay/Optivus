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
    final effectiveNotes = _clean(draft.notes);

    switch (draft.type) {
      case AddRoutineType.flexible:
        final subtasks = _cleanList(draft.flexibleState.subtasks);
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
          bestTime: _clean(draft.bestTime),
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

        // Subtype discrimination: strictly extract ONLY metadata belonging to fixedState.kind!
        String? location;
        String? professor;
        String? courseCode;
        String? classType;
        String? sectionLabel;

        String? workContextType;
        String? workRole;
        String? workOrganization;
        String? workDepartmentOrProject;
        String? workMode;
        String? workBlockKind;

        String? mealCategory;
        String? mealSlot;
        List<String>? dishes;
        double? caloriesEstimate;
        double? proteinEstimate;

        List<String>? steps;
        List<String>? products;
        List<String>? missing;
        String? skincareSlotLabel;

        if (fixedState.kind == 'Class') {
          location = _clean(fixedState.classDetails.location);
          professor = _clean(fixedState.classDetails.professor);
          courseCode = _clean(fixedState.classDetails.courseCode);
          classType = _clean(fixedState.classDetails.classType);
          sectionLabel = _clean(fixedState.classDetails.sectionLabel);
        } else if (fixedState.kind == 'Job' || fixedState.kind == 'Work') {
          location = _clean(fixedState.workDetails.location);
          workContextType = _clean(fixedState.workDetails.workContextType);
          workRole = _clean(fixedState.workDetails.workRole);
          workOrganization = _clean(fixedState.workDetails.workOrganization);
          workDepartmentOrProject =
              _clean(fixedState.workDetails.workDepartmentOrProject);
          workMode = _clean(fixedState.workDetails.workMode);
          workBlockKind = _clean(fixedState.workDetails.workBlockKind);
        } else if (fixedState.kind == 'Eating' || fixedState.kind == 'Meal') {
          mealCategory = _clean(fixedState.eatingDetails.mealCategory);
          mealSlot = _clean(fixedState.eatingDetails.mealSlot);
          dishes = _cleanList(fixedState.eatingDetails.dishes);
          caloriesEstimate = fixedState.eatingDetails.caloriesEstimate;
          proteinEstimate = fixedState.eatingDetails.proteinEstimate;
        } else if (fixedState.kind == 'Skin Care' ||
            fixedState.kind == 'Skincare') {
          skincareSlotLabel = _clean(fixedState.skinDetails.skincareSlotLabel);
          steps = _cleanList(fixedState.skinDetails.steps);
          products = _cleanList(fixedState.skinDetails.skincareProducts);
          missing = _cleanList(fixedState.skinDetails.skincareMissingItems);
        }
        // Sleep/Bath/Travel/Prayer/Tuition/Other do not inherit any structured metadata.

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
          bestTime: null, // Gate D: fixed blocks do not choose or persist bestTime
          isTrackerLinked: false,
          trackerType: TrackerType.none,
          hardBlock: fixedState.hardBlock,
          notes: effectiveNotes,
          location: location,
          // Class fields
          professor: professor,
          courseCode: courseCode,
          classType: classType,
          sectionLabel: sectionLabel,
          // Work fields
          workContextType: workContextType,
          workRole: workRole,
          workOrganization: workOrganization,
          workDepartmentOrProject: workDepartmentOrProject,
          workMode: workMode,
          workBlockKind: workBlockKind,
          // Eating fields
          mealCategory: mealCategory,
          mealSlot: mealSlot,
          dishes: dishes,
          caloriesEstimate: caloriesEstimate,
          proteinEstimate: proteinEstimate,
          // Skincare fields
          steps: steps,
          skincareProducts: products,
          skincareMissingItems: missing,
          skincareSlotLabel: skincareSlotLabel,
        );

      case AddRoutineType.habit:
        final habitState = draft.habitState;
        final isLinked = habitState.trackerType != TrackerType.none;
        final subtasks = _cleanList(habitState.subtasks);
        final steps = _cleanList(habitState.steps);

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
          bestTime: _clean(draft.bestTime),
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
        final subtasks = _cleanList(trackerState.subtasks);
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
          bestTime: null, // Gate D: tracker task does not expose bestTime
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
          bestTime: null, // Gate D: checkin does not expose bestTime
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
          bestTime: null, // Gate D: money does not expose bestTime
          isTrackerLinked: true,
          trackerType: TrackerType.money,
          hardBlock: false,
          notes: effectiveNotes,
        );
    }
  }

  static String? _clean(String? val) {
    if (val == null) return null;
    final trimmed = val.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String>? _cleanList(List<String>? list) {
    if (list == null) return null;
    final cleaned = list
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return cleaned.isEmpty ? null : List.unmodifiable(cleaned);
  }

  static RoutineCategory categoryForFixedKind(String kind) {
    return switch (kind) {
      'Class' || 'Tuition' => RoutineCategory.classBlock,
      'Job' || 'Work' => RoutineCategory.job,
      'Eating' || 'Meal' => RoutineCategory.eating,
      'Sleep' => RoutineCategory.sleep,
      'Skin Care' || 'Skincare' => RoutineCategory.skinCare,
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
