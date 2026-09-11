import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  EatingGenerationInputs buildInputs({
    required UserProfile profile,
    required BaseTimelineSetup setup,
    required NutritionTargets targets,
  }) {
    final meals = normalizeMealsPerDay(setup.mealsPerDay);
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

    return EatingGenerationInputs(
      contractVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
      heightCm:
          targets.heightCm ?? (profile.height > 0 ? profile.height : 170.0),
      weightKg:
          targets.weightKg ?? (profile.weight > 0 ? profile.weight : 70.0),
      estimatedAge: targets.estimatedAge ?? 25,
      gender:
          targets.gender ??
          (profile.gender.isNotEmpty ? profile.gender : 'prefer_not_to_say'),
      exerciseLevel:
          targets.exerciseLevel ??
          (profile.exerciseLevel.isNotEmpty
              ? profile.exerciseLevel
              : 'moderate'),
      lifeRole:
          targets.lifeRole ??
          (profile.lifeRole.isNotEmpty ? profile.lifeRole : 'professional'),
      bmi: targets.bmi,
      estimatedBmr: targets.estimatedBmr,
      estimatedMaintenanceCalories: targets.estimatedMaintenanceCalories,
      bodyGoal: goal,
      targetMode: targetMode,
      targetCalories: targets.targetCalories ?? 2000,
      proteinTarget: targets.proteinTarget ?? 130.0,
      foodType: (setup.foodType != null && setup.foodType!.trim().isNotEmpty)
          ? setup.foodType!.trim().toLowerCase()
          : 'mixed',
      eatingMode:
          (setup.eatingMode != null && setup.eatingMode!.trim().isNotEmpty)
          ? setup.eatingMode!.trim().toLowerCase()
          : 'india',
      foodStyleCustomText: setup.foodStyleCustomText,
      mealsPerDay: meals,
      breakfastMinute: setup.breakfastMinute ?? 480,
      morningSnackMinute: meals == 5 ? (setup.extraSnackMinute ?? 660) : null,
      lunchMinute: setup.lunchMinute ?? 780,
      afternoonSnackMinute: (meals == 4 || meals == 5)
          ? (setup.snackMinute ?? 1020)
          : null,
      dinnerMinute: setup.dinnerMinute ?? 1230,
      country: 'India',
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
  }) async {
    final result = await _client.generateEatingRoutine(
      uid: uid,
      idToken: idToken,
      params: inputs.toWorkerParams(),
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

    final validationErr = validateGeneratedEatingWeeklyPlan(
      effectiveTimeline.copyWith(blocks: blocks),
      targets: targets,
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
