import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';

/// The 6 supported Add Routine types.
enum AddRoutineType {
  flexible,
  fixed,
  habit,
  tracker,
  checkin,
  money;

  String get key => name;

  String get label => switch (this) {
    AddRoutineType.flexible => 'Flexible Task',
    AddRoutineType.fixed => 'Fixed Block',
    AddRoutineType.habit => 'Habit',
    AddRoutineType.tracker => 'Tracker Task',
    AddRoutineType.checkin => 'Check-in',
    AddRoutineType.money => 'Money Saving Task',
  };

  IconData get icon => switch (this) {
    AddRoutineType.flexible => Icons.task_alt,
    AddRoutineType.fixed => Icons.lock_outline,
    AddRoutineType.habit => Icons.repeat_rounded,
    AddRoutineType.tracker => Icons.timer,
    AddRoutineType.checkin => Icons.check_circle_outline,
    AddRoutineType.money => Icons.savings,
  };

  Color get color => switch (this) {
    AddRoutineType.flexible => OptivusColors.blockFlex,
    AddRoutineType.fixed => OptivusColors.blockHard,
    AddRoutineType.habit => OptivusColors.blockSoft,
    AddRoutineType.tracker => OptivusColors.blockTracker,
    AddRoutineType.checkin => OptivusColors.blockCheckIn,
    AddRoutineType.money => OptivusColors.blockMoney,
  };

  static AddRoutineType fromKey(String key) {
    return AddRoutineType.values.firstWhere(
      (e) => e.name == key,
      orElse: () => AddRoutineType.flexible,
    );
  }
}

/// Explicit schedule mode separating concrete one-time dates from weekly recurrence.
enum AddRoutineScheduleMode {
  once,
  weekly;

  String get label => switch (this) {
    AddRoutineScheduleMode.once => 'One time',
    AddRoutineScheduleMode.weekly => 'Weekly',
  };
}

/// Type-specific sub-state for Fixed Blocks.
@immutable
class AddRoutineFixedState {
  final String kind;
  final bool hardBlock;

  // Rich structured Class fields
  final String? professor;
  final String? courseCode;
  final String? classType;
  final String? sectionLabel;
  final String? classLocation;

  // Rich structured Work fields
  final String? workContextType;
  final String? workRole;
  final String? workOrganization;
  final String? workDepartmentOrProject;
  final String? workMode;
  final String? workBlockKind;
  final String? workLocation;

  // Rich structured Eating fields
  final String? mealCategory;
  final String? mealSlot;
  final List<String> dishes;
  final double? caloriesEstimate;
  final double? proteinEstimate;

  // Rich structured Skin Care fields
  final List<String> steps;
  final List<String> skincareProducts;
  final List<String> skincareMissingItems;
  final String? skincareSlotLabel;

  const AddRoutineFixedState({
    this.kind = 'Class',
    this.hardBlock = true,
    this.professor,
    this.courseCode,
    this.classType,
    this.sectionLabel,
    this.classLocation,
    this.workContextType,
    this.workRole,
    this.workOrganization,
    this.workDepartmentOrProject,
    this.workMode,
    this.workBlockKind,
    this.workLocation,
    this.mealCategory,
    this.mealSlot,
    this.dishes = const [],
    this.caloriesEstimate,
    this.proteinEstimate,
    this.steps = const [],
    this.skincareProducts = const [],
    this.skincareMissingItems = const [],
    this.skincareSlotLabel,
  });

  AddRoutineFixedState copyWith({
    String? kind,
    bool? hardBlock,
    String? professor,
    String? courseCode,
    String? classType,
    String? sectionLabel,
    String? classLocation,
    String? workContextType,
    String? workRole,
    String? workOrganization,
    String? workDepartmentOrProject,
    String? workMode,
    String? workBlockKind,
    String? workLocation,
    String? mealCategory,
    String? mealSlot,
    List<String>? dishes,
    double? caloriesEstimate,
    double? proteinEstimate,
    List<String>? steps,
    List<String>? skincareProducts,
    List<String>? skincareMissingItems,
    String? skincareSlotLabel,
  }) {
    return AddRoutineFixedState(
      kind: kind ?? this.kind,
      hardBlock: hardBlock ?? this.hardBlock,
      professor: professor ?? this.professor,
      courseCode: courseCode ?? this.courseCode,
      classType: classType ?? this.classType,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      classLocation: classLocation ?? this.classLocation,
      workContextType: workContextType ?? this.workContextType,
      workRole: workRole ?? this.workRole,
      workOrganization: workOrganization ?? this.workOrganization,
      workDepartmentOrProject:
          workDepartmentOrProject ?? this.workDepartmentOrProject,
      workMode: workMode ?? this.workMode,
      workBlockKind: workBlockKind ?? this.workBlockKind,
      workLocation: workLocation ?? this.workLocation,
      mealCategory: mealCategory ?? this.mealCategory,
      mealSlot: mealSlot ?? this.mealSlot,
      dishes: dishes ?? this.dishes,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
      proteinEstimate: proteinEstimate ?? this.proteinEstimate,
      steps: steps ?? this.steps,
      skincareProducts: skincareProducts ?? this.skincareProducts,
      skincareMissingItems: skincareMissingItems ?? this.skincareMissingItems,
      skincareSlotLabel: skincareSlotLabel ?? this.skincareSlotLabel,
    );
  }
}

/// Type-specific sub-state for Habits.
@immutable
class AddRoutineHabitState {
  final RoutineCategory category;
  final TrackerType trackerType;
  final List<String> steps;
  final List<String> subtasks;

  const AddRoutineHabitState({
    this.category = RoutineCategory.habit,
    this.trackerType = TrackerType.none,
    this.steps = const [],
    this.subtasks = const [],
  });

  AddRoutineHabitState copyWith({
    RoutineCategory? category,
    TrackerType? trackerType,
    List<String>? steps,
    List<String>? subtasks,
  }) {
    return AddRoutineHabitState(
      category: category ?? this.category,
      trackerType: trackerType ?? this.trackerType,
      steps: steps ?? this.steps,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

/// Type-specific sub-state for Flexible Tasks.
@immutable
class AddRoutineFlexibleState {
  final RoutineCategory category;
  final List<String> subtasks;

  const AddRoutineFlexibleState({
    this.category = RoutineCategory.habit,
    this.subtasks = const [],
  });

  AddRoutineFlexibleState copyWith({
    RoutineCategory? category,
    List<String>? subtasks,
  }) {
    return AddRoutineFlexibleState(
      category: category ?? this.category,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

/// Type-specific sub-state for Tracker Tasks.
@immutable
class AddRoutineTrackerState {
  final TrackerType trackerType;
  final List<String> subtasks;

  const AddRoutineTrackerState({
    this.trackerType = TrackerType.meditation,
    this.subtasks = const [],
  });

  AddRoutineTrackerState copyWith({
    TrackerType? trackerType,
    List<String>? subtasks,
  }) {
    return AddRoutineTrackerState(
      trackerType: trackerType ?? this.trackerType,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

/// Type-specific sub-state for Check-ins.
@immutable
class AddRoutineCheckInState {
  final String checkInType;

  const AddRoutineCheckInState({
    this.checkInType = 'Smoking',
  });

  AddRoutineCheckInState copyWith({
    String? checkInType,
  }) {
    return AddRoutineCheckInState(
      checkInType: checkInType ?? this.checkInType,
    );
  }
}

/// Type-specific sub-state for Money Tasks.
@immutable
class AddRoutineMoneyState {
  final String defaultTitle;

  const AddRoutineMoneyState({
    this.defaultTitle = 'Tiny money save',
  });

  AddRoutineMoneyState copyWith({
    String? defaultTitle,
  }) {
    return AddRoutineMoneyState(
      defaultTitle: defaultTitle ?? this.defaultTitle,
    );
  }
}

/// Central immutable draft state model for Add Routine.
///
/// Guaranteed properties:
/// 1. Stable [id] persists across previewing, slot-finding, writes, failures, and retries.
/// 2. Mode switches NEVER leak semantic fields (e.g. hardBlock from fixed, trackerType
///    from tracker, check-in titles) across unrelated types.
/// 3. Clear schedule mode distinction between [AddRoutineScheduleMode.once] and [AddRoutineScheduleMode.weekly].
@immutable
class AddRoutineDraft {
  /// Durable, stable item identity for this logical Add session.
  final String id;

  /// The active type being created.
  final AddRoutineType type;

  /// Schedule mode (once vs weekly).
  final AddRoutineScheduleMode scheduleMode;

  /// The user-visible title.
  final String title;

  /// Date for one-time task (or preview anchor for weekly).
  final DateTime date;

  /// Start time of day.
  final TimeOfDay startTime;

  /// Duration in minutes.
  final int durationMinutes;

  /// Priority.
  final RoutinePriority priority;

  /// Best time of day preference.
  final String bestTime;

  /// Optional notes.
  final String notes;

  /// Repeat days (1 = Mon .. 7 = Sun).
  final List<int> repeatDays;

  // Sub-states isolated per mode
  final AddRoutineFixedState fixedState;
  final AddRoutineHabitState habitState;
  final AddRoutineFlexibleState flexibleState;
  final AddRoutineTrackerState trackerState;
  final AddRoutineCheckInState checkInState;
  final AddRoutineMoneyState moneyState;

  const AddRoutineDraft({
    required this.id,
    required this.type,
    required this.scheduleMode,
    required this.title,
    required this.date,
    required this.startTime,
    required this.durationMinutes,
    required this.priority,
    required this.bestTime,
    required this.notes,
    required this.repeatDays,
    required this.fixedState,
    required this.habitState,
    required this.flexibleState,
    required this.trackerState,
    required this.checkInState,
    required this.moneyState,
  });

  /// Factory creating an initial draft with a stable ID and sensible defaults.
  factory AddRoutineDraft.initial({
    String? id,
    DateTime? initialDate,
    AddRoutineType initialType = AddRoutineType.flexible,
  }) {
    final now = DateTime.now();
    final effectiveId = id ?? 'routine-${now.millisecondsSinceEpoch}';
    final effectiveDate = initialDate ?? DateTime(now.year, now.month, now.day);

    return AddRoutineDraft(
      id: effectiveId,
      type: initialType,
      scheduleMode: AddRoutineScheduleMode.once,
      title: '',
      date: effectiveDate,
      startTime: const TimeOfDay(hour: 8, minute: 0),
      durationMinutes: _defaultDurationFor(initialType),
      priority: RoutinePriority.goodToDo,
      bestTime: 'Morning',
      notes: '',
      repeatDays: const [],
      fixedState: const AddRoutineFixedState(),
      habitState: const AddRoutineHabitState(),
      flexibleState: const AddRoutineFlexibleState(),
      trackerState: const AddRoutineTrackerState(),
      checkInState: const AddRoutineCheckInState(),
      moneyState: const AddRoutineMoneyState(),
    );
  }

  static int _defaultDurationFor(AddRoutineType type) => switch (type) {
    AddRoutineType.fixed => 60,
    AddRoutineType.flexible => 30,
    AddRoutineType.habit => 15,
    AddRoutineType.tracker => 10,
    AddRoutineType.checkin => 5,
    AddRoutineType.money => 5,
  };

  int get startMinute => startTime.hour * 60 + startTime.minute;

  AddRoutineDraft copyWith({
    AddRoutineType? type,
    String? title,
    AddRoutineScheduleMode? scheduleMode,
    DateTime? date,
    TimeOfDay? startTime,
    int? durationMinutes,
    RoutinePriority? priority,
    String? bestTime,
    String? notes,
    List<int>? repeatDays,
    AddRoutineFixedState? fixedState,
    AddRoutineHabitState? habitState,
    AddRoutineFlexibleState? flexibleState,
    AddRoutineTrackerState? trackerState,
    AddRoutineCheckInState? checkInState,
    AddRoutineMoneyState? moneyState,
  }) {
    return AddRoutineDraft(
      id: id,
      type: type ?? this.type,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priority: priority ?? this.priority,
      bestTime: bestTime ?? this.bestTime,
      notes: notes ?? this.notes,
      repeatDays: repeatDays ?? this.repeatDays,
      fixedState: fixedState ?? this.fixedState,
      habitState: habitState ?? this.habitState,
      flexibleState: flexibleState ?? this.flexibleState,
      trackerState: trackerState ?? this.trackerState,
      checkInState: checkInState ?? this.checkInState,
      moneyState: moneyState ?? this.moneyState,
    );
  }

  /// Switches the type safely without leaking mode-specific state across types.
  AddRoutineDraft switchType(AddRoutineType newType) {
    if (newType == type) return this;

    // Reset default-generated titles when leaving specialized types
    final isDefaultCheckInTitle =
        const ['Smoking', 'Alcohol', 'Junk food'].contains(title);
    final isDefaultMoneyTitle = title == 'Tiny money save';

    String updatedTitle = title;
    if (isDefaultCheckInTitle || isDefaultMoneyTitle) {
      if (newType == AddRoutineType.checkin) {
        updatedTitle = checkInState.checkInType;
      } else if (newType == AddRoutineType.money) {
        updatedTitle = moneyState.defaultTitle;
      } else {
        updatedTitle = '';
      }
    } else if (title.isEmpty) {
      if (newType == AddRoutineType.checkin) {
        updatedTitle = checkInState.checkInType;
      } else if (newType == AddRoutineType.money) {
        updatedTitle = moneyState.defaultTitle;
      }
    }

    return AddRoutineDraft(
      id: id, // Stable identity preserved!
      type: newType,
      scheduleMode: scheduleMode,
      title: updatedTitle,
      date: date,
      startTime: startTime,
      durationMinutes: _defaultDurationFor(newType),
      priority: priority,
      bestTime: bestTime,
      notes: notes,
      repeatDays: repeatDays,
      // Completely clean type states for the new type
      fixedState: newType == AddRoutineType.fixed
          ? const AddRoutineFixedState()
          : fixedState,
      habitState: newType == AddRoutineType.habit
          ? const AddRoutineHabitState()
          : habitState,
      flexibleState: newType == AddRoutineType.flexible
          ? const AddRoutineFlexibleState()
          : flexibleState,
      trackerState: newType == AddRoutineType.tracker
          ? const AddRoutineTrackerState()
          : trackerState,
      checkInState: newType == AddRoutineType.checkin
          ? const AddRoutineCheckInState()
          : checkInState,
      moneyState: newType == AddRoutineType.money
          ? const AddRoutineMoneyState()
          : moneyState,
    );
  }
}
