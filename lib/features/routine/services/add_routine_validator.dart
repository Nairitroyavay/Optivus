import 'package:optivus/features/routine/models/add_routine_draft.dart';

/// Pure, deterministic validator for [AddRoutineDraft].
class AddRoutineValidator {
  const AddRoutineValidator._();

  /// Returns null if valid, or a user-safe error message if invalid.
  static String? validate(AddRoutineDraft draft) {
    final title = draft.title.trim();
    if (draft.type == AddRoutineType.money) {
      // Money task falls back to default title if empty, but if explicitly cleared, check
      if (title.isEmpty && draft.moneyState.defaultTitle.trim().isEmpty) {
        return 'Title is required.';
      }
    } else {
      if (title.isEmpty) {
        return 'Title is required.';
      }
    }

    if (draft.durationMinutes <= 0) {
      return 'Duration must be greater than 0.';
    }

    if (draft.durationMinutes > 1440) {
      return 'Duration cannot exceed 24 hours.';
    }

    if (draft.scheduleMode == AddRoutineScheduleMode.weekly) {
      if (draft.repeatDays.isEmpty) {
        return 'Please select at least one day of the week for a weekly routine.';
      }

      final uniqueDays = draft.repeatDays.toSet();
      if (uniqueDays.length != draft.repeatDays.length) {
        return 'Repeat days cannot contain duplicates.';
      }

      for (final day in draft.repeatDays) {
        if (day < 1 || day > 7) {
          return 'Repeat days must be between 1 (Monday) and 7 (Sunday).';
        }
      }
    }

    final endRaw = draft.startMinute + draft.durationMinutes;
    if (endRaw > 1440) {
      final isSleep =
          draft.type == AddRoutineType.fixed &&
          draft.fixedState.kind == 'Sleep';
      if (!isSleep) {
        return 'Only Sleep blocks typically cross midnight. Adjust the time or set type to Sleep.';
      }
    }

    if (draft.type == AddRoutineType.fixed &&
        draft.fixedState.kind == 'Eating') {
      final calories = draft.fixedState.caloriesEstimate;
      if (calories != null) {
        if (calories.isNaN ||
            calories.isInfinite ||
            calories < 0 ||
            calories > 20000) {
          return 'Calories must be between 0 and 20,000.';
        }
      }
      final protein = draft.fixedState.proteinEstimate;
      if (protein != null) {
        if (protein.isNaN ||
            protein.isInfinite ||
            protein < 0 ||
            protein > 1000) {
          return 'Protein must be between 0 and 1,000g.';
        }
      }
    }

    return null;
  }
}
