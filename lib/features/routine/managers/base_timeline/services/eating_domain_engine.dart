import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/services/nutrition_target_service.dart';

class EatingDomainEngine {
  final NutritionAiClient _client;

  const EatingDomainEngine({required NutritionAiClient client})
    : _client = client;

  static String dayName(int day) {
    return switch (day) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Day $day',
    };
  }

  String? validatePreferredMealTimes({
    required int mealsPerDay,
    required int breakfastMinute,
    int? morningSnackMinute,
    required int lunchMinute,
    int? afternoonSnackMinute,
    required int dinnerMinute,
  }) {
    if (breakfastMinute < 0 || breakfastMinute > 1439) {
      return 'Breakfast time must be within a valid day range.';
    }
    if (lunchMinute < 0 || lunchMinute > 1439) {
      return 'Lunch time must be within a valid day range.';
    }
    if (dinnerMinute < 0 || dinnerMinute > 1439) {
      return 'Dinner time must be within a valid day range.';
    }
    if (mealsPerDay == 3) {
      if (lunchMinute <= breakfastMinute) {
        return 'Lunch must be scheduled after breakfast.';
      }
      if (lunchMinute - breakfastMinute < 120) {
        return 'Meals must be scheduled at least 2 hours apart.';
      }
      if (dinnerMinute <= lunchMinute) {
        return 'Dinner must be scheduled after lunch.';
      }
      if (dinnerMinute - lunchMinute < 120) {
        return 'Meals must be scheduled at least 2 hours apart.';
      }
    } else if (mealsPerDay == 4) {
      final snack = afternoonSnackMinute;
      if (snack == null || snack < 0 || snack > 1439) {
        return 'Snack time must be within a valid day range.';
      }
      if (lunchMinute <= breakfastMinute ||
          lunchMinute - breakfastMinute < 120) {
        return 'Lunch must be scheduled at least 2 hours after breakfast.';
      }
      if (snack <= lunchMinute || snack - lunchMinute < 120) {
        return 'Snack must be scheduled at least 2 hours after lunch.';
      }
      if (dinnerMinute <= snack || dinnerMinute - snack < 120) {
        return 'Dinner must be scheduled at least 2 hours after snack.';
      }
    } else if (mealsPerDay == 5) {
      final mSnack = morningSnackMinute;
      final aSnack = afternoonSnackMinute;
      if (mSnack == null || mSnack < 0 || mSnack > 1439) {
        return 'Morning snack time must be within a valid day range.';
      }
      if (aSnack == null || aSnack < 0 || aSnack > 1439) {
        return 'Afternoon snack time must be within a valid day range.';
      }
      if (mSnack <= breakfastMinute || mSnack - breakfastMinute < 120) {
        return 'Morning snack must be scheduled at least 2 hours after breakfast.';
      }
      if (lunchMinute <= mSnack || lunchMinute - mSnack < 120) {
        return 'Lunch must be scheduled at least 2 hours after morning snack.';
      }
      if (aSnack <= lunchMinute || aSnack - lunchMinute < 120) {
        return 'Afternoon snack must be scheduled at least 2 hours after lunch.';
      }
      if (dinnerMinute <= aSnack || dinnerMinute - aSnack < 120) {
        return 'Dinner must be scheduled at least 2 hours after afternoon snack.';
      }
    }
    return null;
  }

  String? validateBeforeSave({
    required List<TimelineBlockDraft> blocks,
    required BaseTimelineSetup setup,
    NutritionTargets? targets,
    bool isFreshAiGeneration = false,
  }) {
    if (blocks.isEmpty) {
      return 'Meal plan must contain at least one meal.';
    }

    for (final block in blocks) {
      if (block.title.trim().isEmpty) {
        return 'Every meal must have a title.';
      }
      if (block.startMinute < 0 ||
          block.startMinute > 1439 ||
          block.endMinute < 0 ||
          block.endMinute > 1439) {
        return 'Meal times must be within a valid day range (0:00 - 23:59).';
      }
      if (block.endMinute <= block.startMinute) {
        return 'Meal end time must be after start time (${block.title}).';
      }
      if (block.repeatDays.isEmpty) {
        return 'Every meal must have at least one scheduled day (${block.title}).';
      }
      final dishes = block.dishes.where((d) => d.trim().isNotEmpty).toList();
      if (dishes.isEmpty) {
        return 'Every meal must contain at least one dish (${block.title}).';
      }
    }

    for (var day = 1; day <= 7; day++) {
      final dayBlocks = blocks.where((b) => b.repeatDays.contains(day)).toList()
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

      if (dayBlocks.length > 6) {
        return 'Meals per day cannot exceed 6 meals on ${dayName(day)}.';
      }

      final isPristineGenerated =
          setup.eatingSetupPath == 'create' && !setup.eatingCustomized;

      if (isPristineGenerated) {
        for (var i = 0; i < dayBlocks.length - 1; i++) {
          final current = dayBlocks[i];
          final next = dayBlocks[i + 1];
          if (next.startMinute - current.startMinute < 120) {
            return 'Meals must be scheduled at least 120 minutes apart (${current.title} and ${next.title} on ${dayName(day)}).';
          }
        }
      }
    }

    final hasAiBlocks = blocks.any(
      (b) => b.source == 'ai_generated_meal_setup',
    );
    // Full generated weekly-plan validation (cardinality, exact slot coverage,
    // macro tolerances, diversity) ONLY applies to pristine AI plans.
    // Customized plans (where the user edited dishes, timing, or added/deleted meals)
    // require standard schedule integrity instead.
    if (setup.eatingSetupPath == 'create' &&
        !setup.eatingCustomized &&
        hasAiBlocks) {
      final draft = setup.toBaseTimelineDraft().copyWith(blocks: blocks);
      final effectiveTargets = (isFreshAiGeneration && targets != null)
          ? targets.copyWith(
              targetCalories:
                  setup.targetCaloriesOverride ??
                  setup.targetCalories ??
                  targets.targetCalories,
              proteinTarget:
                  setup.targetProteinOverride?.toDouble() ??
                  setup.targetProtein?.toDouble() ??
                  targets.proteinTarget,
            )
          : NutritionTargets.empty;
      final validationErr = validateGeneratedEatingWeeklyPlan(
        draft,
        targets: effectiveTargets,
      );
      if (validationErr != null) {
        return validationErr;
      }
    }

    return null;
  }

  EatingGenerationInputs buildInputs({
    required UserProfile profile,
    required BaseTimelineSetup setup,
    required NutritionTargets targets,
    String? country,
  }) {
    final hasHeight =
        (targets.heightCm != null && targets.heightCm! > 0) ||
        profile.height > 0;
    final hasWeight =
        (targets.weightKg != null && targets.weightKg! > 0) ||
        profile.weight > 0;
    final hasAge =
        targets.estimatedAge != null || profile.ageRange.trim().isNotEmpty;
    final hasGender =
        (targets.gender != null && targets.gender!.trim().isNotEmpty) ||
        profile.gender.trim().isNotEmpty;

    if (!hasHeight || !hasWeight || !hasAge || !hasGender) {
      throw StateError(
        'Complete Body Basics before generating a personalized eating plan.',
      );
    }

    final mode = setup.eatingMode?.trim().toLowerCase();
    if (mode == 'custom' && (setup.foodStyleCustomText ?? '').trim().isEmpty) {
      throw StateError('Please describe your custom food style.');
    }

    final meals = normalizeMealsPerDay(setup.mealsPerDay);
    final bMinute = setup.breakfastMinute ?? 480;
    final lMinute = setup.lunchMinute ?? 780;
    final dMinute = setup.dinnerMinute ?? 1230;
    final mSnackMinute = meals == 5 ? (setup.extraSnackMinute ?? 660) : null;
    final aSnackMinute = (meals == 4 || meals == 5)
        ? (setup.snackMinute ?? 1020)
        : null;

    final timeErr = validatePreferredMealTimes(
      mealsPerDay: meals,
      breakfastMinute: bMinute,
      morningSnackMinute: mSnackMinute,
      lunchMinute: lMinute,
      afternoonSnackMinute: aSnackMinute,
      dinnerMinute: dMinute,
    );
    if (timeErr != null) {
      throw StateError(timeErr);
    }

    final goal =
        (setup.mealPlanningGoal != null &&
            setup.mealPlanningGoal!.trim().isNotEmpty)
        ? setup.mealPlanningGoal!
        : targets.bodyGoal;
    final targetMode = switch (goal.trim().toLowerCase()) {
      'gain' => 'mild_surplus',
      'lose' => 'mild_deficit',
      _ => 'maintenance',
    };

    final height =
        targets.heightCm ?? (profile.height > 0 ? profile.height : null);
    final weight =
        targets.weightKg ?? (profile.weight > 0 ? profile.weight : null);
    final age = targets.estimatedAge;
    final gender =
        targets.gender ?? (profile.gender.isNotEmpty ? profile.gender : null);
    final exercise =
        targets.exerciseLevel ??
        (profile.exerciseLevel.isNotEmpty ? profile.exerciseLevel : null);
    final role =
        targets.lifeRole ??
        (profile.lifeRole.isNotEmpty ? profile.lifeRole : null);

    final targetCalories =
        setup.targetCaloriesOverride ??
        setup.targetCalories ??
        targets.targetCalories;
    final targetProtein =
        setup.targetProteinOverride?.toDouble() ??
        setup.targetProtein?.toDouble() ??
        targets.proteinTarget;

    return EatingGenerationInputs(
      contractVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
      heightCm: height,
      weightKg: weight,
      estimatedAge: age,
      gender: gender,
      exerciseLevel: exercise,
      lifeRole: role,
      bmi: targets.bmi,
      estimatedBmr: targets.estimatedBmr,
      estimatedMaintenanceCalories: targets.estimatedMaintenanceCalories,
      bodyGoal: goal,
      targetMode: targetMode,
      targetCalories: targetCalories,
      proteinTarget: targetProtein,
      foodType: (setup.foodType != null && setup.foodType!.trim().isNotEmpty)
          ? setup.foodType!.trim().toLowerCase()
          : 'mixed',
      eatingMode:
          (setup.eatingMode != null && setup.eatingMode!.trim().isNotEmpty)
          ? setup.eatingMode!.trim().toLowerCase()
          : 'balanced',
      foodStyleCustomText: setup.foodStyleCustomText,
      mealsPerDay: meals,
      breakfastMinute: bMinute,
      morningSnackMinute: mSnackMinute,
      lunchMinute: lMinute,
      afternoonSnackMinute: aSnackMinute,
      dinnerMinute: dMinute,
      country: country,
      foodsToAvoid: setup.foodsToAvoid,
    );
  }

  NutritionTargets calculateTargets({
    required UserProfile profile,
    required BaseTimelineSetup setup,
  }) {
    return const NutritionTargetService().calculate(
      weightKg: profile.weight > 0 ? profile.weight : null,
      heightCm: profile.height > 0 ? profile.height : null,
      ageRange: profile.ageRange.isNotEmpty ? profile.ageRange : null,
      gender: profile.gender.isNotEmpty ? profile.gender : null,
      exerciseLevel: profile.exerciseLevel.isNotEmpty
          ? profile.exerciseLevel
          : null,
      lifeRole: profile.lifeRole.isNotEmpty ? profile.lifeRole : null,
      bodyGoal: setup.mealPlanningGoal,
    );
  }

  Future<List<TimelineBlockDraft>> generateEatingRoutine({
    required String uid,
    required String idToken,
    required EatingGenerationInputs inputs,
    required NutritionTargets targets,
    required BaseTimelineDraft baseTimeline,
    http.Client? client,
  }) async {
    final result = await _client.generateEatingRoutine(
      uid: uid,
      idToken: idToken,
      params: inputs.toWorkerParams(),
      client: client,
    );

    if (result.id.trim().isEmpty ||
        result.uid != uid ||
        result.candidates.isEmpty) {
      throw StateError(
        result.warnings.isNotEmpty
            ? result.warnings.first
            : 'AI returned empty meal candidates. Please try again.',
      );
    }

    final effectiveTimeline = baseTimeline.copyWith(
      mealsPerDay: inputs.mealsPerDay,
      breakfastMinute: inputs.breakfastMinute,
      extraSnackMinute: inputs.morningSnackMinute,
      lunchMinute: inputs.lunchMinute,
      snackMinute: inputs.afternoonSnackMinute,
      dinnerMinute: inputs.dinnerMinute,
    );

    // ignore: invalid_use_of_visible_for_testing_member
    final mapped = mapOnboarding5MealCandidates(
      result.candidates,
      now: DateTime.now(),
      source: onboardingEatingGeneratedSource,
      baseTimeline: effectiveTimeline,
    );
    final blocks = mapped.blocks;

    if (blocks.isEmpty) {
      throw StateError(
        mapped.droppedNoDishes > 0
            ? 'AI did not return specific dishes. Please try again.'
            : 'Generated routine was invalid. Please try again.',
      );
    }

    final effectiveTargets = targets.copyWith(
      targetCalories: inputs.targetCalories,
      proteinTarget: inputs.proteinTarget,
    );
    final validationErr = validateGeneratedEatingWeeklyPlan(
      effectiveTimeline.copyWith(blocks: blocks),
      targets: effectiveTargets,
    );
    if (validationErr != null) {
      throw StateError(validationErr);
    }

    return blocks;
  }
}

final eatingDomainEngineProvider = Provider<EatingDomainEngine>((ref) {
  return EatingDomainEngine(client: ref.watch(nutritionAiClientProvider));
});
