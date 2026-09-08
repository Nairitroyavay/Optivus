import 'dart:math' as math;

class NutritionTargets {
  final double? bmi;
  final int? estimatedAge;
  final int? estimatedBmr;
  final double activityFactor;
  final int? estimatedMaintenanceCalories;
  final int? targetCalories;
  final double? proteinTarget;
  final String bodyGoal;
  final bool hasBodyBasics;

  final double? weightKg;
  final double? heightCm;
  final String? gender;
  final String? exerciseLevel;
  final String? lifeRole;

  const NutritionTargets({
    required this.bmi,
    required this.estimatedAge,
    required this.estimatedBmr,
    required this.activityFactor,
    required this.estimatedMaintenanceCalories,
    required this.targetCalories,
    required this.proteinTarget,
    required this.bodyGoal,
    required this.hasBodyBasics,
    this.weightKg,
    this.heightCm,
    this.gender,
    this.exerciseLevel,
    this.lifeRole,
  });

  static const empty = NutritionTargets(
    bmi: null,
    estimatedAge: null,
    estimatedBmr: null,
    activityFactor: 1.30,
    estimatedMaintenanceCalories: null,
    targetCalories: null,
    proteinTarget: null,
    bodyGoal: 'maintain',
    hasBodyBasics: false,
    weightKg: null,
    heightCm: null,
    gender: null,
    exerciseLevel: null,
    lifeRole: null,
  );
}

class NutritionTargetService {
  const NutritionTargetService();

  static const double minimumHeightCm = 120.0;
  static const double maximumHeightCm = 220.0;
  static const double minimumWeightKg = 40.0;
  static const double maximumWeightKg = 150.0;

  static const int minimumBmr = 1100;
  static const int maximumBmr = 2600;

  static const int minimumMaintenanceCalories = 1500;
  static const int maximumMaintenanceCalories = 4200;

  /// Calculates canonical nutrition targets from profile/draft metrics.
  NutritionTargets calculate({
    String? ageRange,
    double? heightCm,
    double? weightKg,
    String? gender,
    String? exerciseLevel,
    String? lifeRole,
    String? bodyGoal,
  }) {
    final normalizedGoal = normalizeGoal(bodyGoal);
    final age = estimateAgeFromRange(ageRange);
    final activity = activityFactor(exerciseLevel);

    final isValidHeight =
        heightCm != null &&
        heightCm >= minimumHeightCm &&
        heightCm <= maximumHeightCm;
    final isValidWeight =
        weightKg != null &&
        weightKg >= minimumWeightKg &&
        weightKg <= maximumWeightKg;
    final hasBasics =
        isValidHeight &&
        isValidWeight &&
        age != null &&
        gender != null &&
        gender.trim().isNotEmpty;

    if (!hasBasics) {
      final double? partialBmi;
      if (heightCm != null &&
          heightCm > 0 &&
          weightKg != null &&
          weightKg > 0) {
        final meters = heightCm / 100.0;
        final rawBmi = weightKg / (meters * meters);
        partialBmi = double.parse(rawBmi.toStringAsFixed(1));
      } else {
        partialBmi = null;
      }
      return NutritionTargets(
        bmi: partialBmi,
        estimatedAge: age,
        estimatedBmr: null,
        activityFactor: activity,
        estimatedMaintenanceCalories: null,
        targetCalories: null,
        proteinTarget: weightKg != null && weightKg > 0
            ? (weightKg * 2.0).roundToDouble()
            : null,
        bodyGoal: normalizedGoal,
        hasBodyBasics: false,
        weightKg: weightKg,
        heightCm: heightCm,
        gender: gender,
        exerciseLevel: exerciseLevel,
        lifeRole: lifeRole,
      );
    }

    final meters = heightCm / 100.0;
    final bmi = double.parse((weightKg / (meters * meters)).toStringAsFixed(1));
    final bmr = estimateBmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final maintenance = (bmr * activity).round().clamp(
      minimumMaintenanceCalories,
      maximumMaintenanceCalories,
    );
    final target = calculateTargetCalories(
      maintenanceCalories: maintenance,
      bodyGoal: normalizedGoal,
      gender: gender,
    );
    final protein = (weightKg * 2.0).roundToDouble();

    return NutritionTargets(
      bmi: bmi,
      estimatedAge: age,
      estimatedBmr: bmr,
      activityFactor: activity,
      estimatedMaintenanceCalories: maintenance,
      targetCalories: target,
      proteinTarget: protein,
      bodyGoal: normalizedGoal,
      hasBodyBasics: true,
      weightKg: weightKg,
      heightCm: heightCm,
      gender: gender,
      exerciseLevel: exerciseLevel,
      lifeRole: lifeRole,
    );
  }

  /// Estimates age in years based on the standard onboarding age range brackets.
  static int? estimateAgeFromRange(String? ageRange) {
    return switch (ageRange?.trim()) {
      '<18' => 17,
      '18-24' => 21,
      '25-34' => 30,
      '35-44' => 40,
      '45+' => 50,
      _ => null,
    };
  }

  /// Maps onboarding exercise level keys to conservative activity multipliers.
  static double activityFactor(String? exerciseLevel) {
    final key = normalizeExerciseLevel(exerciseLevel);
    return switch (key) {
      'rarely' => 1.25,
      '1_2_days' => 1.30,
      '3_4_days' => 1.35,
      '5_plus_days' => 1.45,
      _ => 1.30,
    };
  }

  /// Canonicalizes the historical activity aliases already accepted by the
  /// nutrition contract. Unknown values remain unsupported.
  static String? normalizeExerciseLevel(String? value) {
    final lower = value?.trim().toLowerCase();
    return switch (lower) {
      'rarely' || 'low' || 'sedentary' => 'rarely',
      '1_2_days' => '1_2_days',
      '3_4_days' || 'medium' || 'moderate' => '3_4_days',
      '5_plus_days' || 'high' || 'active' => '5_plus_days',
      _ => null,
    };
  }

  /// Calculates BMR using the Mifflin-St Jeor equation.
  static int estimateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required String? gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final normalizedGender = gender?.trim().toLowerCase();
    final adjustment = switch (normalizedGender) {
      'male' => 5.0,
      'female' => -161.0,
      _ => -78.0, // Neutral fallback for non_binary, prefer_not_to_say
    };
    return (base + adjustment).round().clamp(minimumBmr, maximumBmr);
  }

  /// Adjusts maintenance calories according to the selected body goal with safety floors.
  static int calculateTargetCalories({
    required int maintenanceCalories,
    required String bodyGoal,
    required String? gender,
  }) {
    final safeMaintenance = maintenanceCalories.clamp(
      minimumMaintenanceCalories,
      maximumMaintenanceCalories,
    );
    final normalizedGender = gender?.trim().toLowerCase();
    if (bodyGoal == 'gain') {
      return (safeMaintenance + 300).clamp(
        safeMaintenance,
        safeMaintenance + 500,
      );
    }
    if (bodyGoal == 'lose') {
      final floor = normalizedGender == 'female' ? 1200 : 1400;
      return (safeMaintenance - 350).clamp(
        math.max(floor, (safeMaintenance * 0.75).round()),
        safeMaintenance,
      );
    }
    return safeMaintenance;
  }

  /// Normalizes body goal to 'gain', 'lose', or 'maintain'.
  static String normalizeGoal(String? value) {
    return normalizeSupportedGoal(value) ?? 'maintain';
  }

  /// Returns a canonical current body-goal key for known current and legacy
  /// values. Unknown values stay invalid instead of becoming a different goal.
  static String? normalizeSupportedGoal(String? value) {
    final lower = value?.trim().toLowerCase();
    return switch (lower) {
      'gain' || 'gain_weight' || 'build_muscle' || 'muscle_gain' => 'gain',
      'lose' || 'lose_fat' || 'fat_loss' || 'weight_loss' => 'lose',
      'maintain' ||
      'maintenance' ||
      'eat_healthier' ||
      'balanced' => 'maintain',
      _ => null,
    };
  }
}
