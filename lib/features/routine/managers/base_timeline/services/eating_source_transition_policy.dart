import 'package:optivus/models/onboarding_draft.dart';

/// Immutable snapshot of working Eating setup fields during editing.
class EatingDraftState {
  final String? setupPath;
  final List<TimelineBlockDraft> blocks;
  final String? photoAssetId;
  final String? photoR2Key;
  final String? goal;
  final int? mealsPerDay;
  final String? eatingMode;
  final String? foodType;
  final String? foodStyleCustomText;
  final int? breakfastMinute;
  final int? lunchMinute;
  final int? dinnerMinute;
  final int? snackMinute;
  final int? extraSnackMinute;
  final int? targetCalories;
  final int? targetProtein;
  final int? targetCaloriesOverride;
  final int? targetProteinOverride;
  final List<String> foodsToAvoid;
  final int? planVersion;
  final String? inputFingerprint;
  final bool customized;

  const EatingDraftState({
    this.setupPath,
    this.blocks = const [],
    this.photoAssetId,
    this.photoR2Key,
    this.goal,
    this.mealsPerDay,
    this.eatingMode,
    this.foodType,
    this.foodStyleCustomText,
    this.breakfastMinute,
    this.lunchMinute,
    this.dinnerMinute,
    this.snackMinute,
    this.extraSnackMinute,
    this.targetCalories,
    this.targetProtein,
    this.targetCaloriesOverride,
    this.targetProteinOverride,
    this.foodsToAvoid = const [],
    this.planVersion,
    this.inputFingerprint,
    this.customized = false,
  });
}

/// Pure policy defining working state transitions between Eating modes.
///
/// Guarantees that switching source paths (Generated, Photo, Manual) explicitly
/// clears inapplicable metadata and avoids leaking stale targets or preferences.
class EatingSourceTransitionPolicy {
  const EatingSourceTransitionPolicy._();

  /// Transitions to Photo ('has_routine').
  ///
  /// Immediately clears all generation-only working state (calories, protein,
  /// overrides, goal, meals preference, eating mode, food type, style text, timing,
  /// fingerprint, plan version, customized flag).
  ///
  /// Meals per day is cleared to null so actual meal counts derive from schedule blocks.
  static EatingDraftState toPhoto({
    required List<TimelineBlockDraft> blocks,
    required String photoAssetId,
    required String photoR2Key,
  }) {
    return EatingDraftState(
      setupPath: 'has_routine',
      blocks: blocks,
      photoAssetId: photoAssetId,
      photoR2Key: photoR2Key,
      mealsPerDay: null,
      goal: null,
      eatingMode: null,
      foodType: null,
      foodStyleCustomText: null,
      breakfastMinute: null,
      lunchMinute: null,
      dinnerMinute: null,
      snackMinute: null,
      extraSnackMinute: null,
      targetCalories: null,
      targetProtein: null,
      targetCaloriesOverride: null,
      targetProteinOverride: null,
      planVersion: null,
      inputFingerprint: null,
      customized: false,
    );
  }

  /// Transitions to Manual ('manual').
  ///
  /// Clears photo asset provenance, generation preferences, and fingerprint.
  /// Nutrition targets are unset by default to prevent silent leakage of AI targets.
  static EatingDraftState toManual({
    List<TimelineBlockDraft> blocks = const [],
    int? targetCalories,
    int? targetProtein,
    int? targetCaloriesOverride,
    int? targetProteinOverride,
  }) {
    return EatingDraftState(
      setupPath: 'manual',
      blocks: blocks,
      photoAssetId: null,
      photoR2Key: null,
      mealsPerDay: null,
      goal: null,
      eatingMode: null,
      foodType: null,
      foodStyleCustomText: null,
      breakfastMinute: null,
      lunchMinute: null,
      dinnerMinute: null,
      snackMinute: null,
      extraSnackMinute: null,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCaloriesOverride: targetCaloriesOverride,
      targetProteinOverride: targetProteinOverride,
      planVersion: null,
      inputFingerprint: null,
      customized: false,
    );
  }

  /// Transitions to Generated ('create').
  ///
  /// Clears photo asset provenance and sets all generation metadata and targets.
  static EatingDraftState toGenerated({
    required List<TimelineBlockDraft> blocks,
    String? goal,
    int? mealsPerDay,
    String? eatingMode,
    String? foodType,
    String? foodStyleCustomText,
    int? breakfastMinute,
    int? lunchMinute,
    int? dinnerMinute,
    int? snackMinute,
    int? extraSnackMinute,
    int? targetCalories,
    int? targetProtein,
    int? targetCaloriesOverride,
    int? targetProteinOverride,
    List<String>? foodsToAvoid,
    int? planVersion,
    String? inputFingerprint,
    bool customized = false,
  }) {
    return EatingDraftState(
      setupPath: 'create',
      blocks: blocks,
      photoAssetId: null,
      photoR2Key: null,
      goal: goal,
      mealsPerDay: mealsPerDay,
      eatingMode: eatingMode,
      foodType: foodType,
      foodStyleCustomText: foodStyleCustomText,
      breakfastMinute: breakfastMinute,
      lunchMinute: lunchMinute,
      dinnerMinute: dinnerMinute,
      snackMinute: snackMinute,
      extraSnackMinute: extraSnackMinute,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCaloriesOverride: targetCaloriesOverride,
      targetProteinOverride: targetProteinOverride,
      foodsToAvoid: foodsToAvoid ?? const [],
      planVersion: planVersion,
      inputFingerprint: inputFingerprint,
      customized: customized,
    );
  }
}
