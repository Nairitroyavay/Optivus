import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/skin_care_product_draft.dart';

/// Durable runtime Base Timeline configuration stored at
/// `users/{uid}/baseTimelineSetup/current`.
class BaseTimelineSetup {
  static const int currentSchemaVersion = 3;

  final String uid;
  final DateTime updatedAt;
  final int schemaVersion;
  final int revision;

  // ── Tracked Routine Item IDs ──────────────────────────────────
  final List<String> classRoutineItemIds;
  final List<String> workRoutineItemIds;
  final List<String> eatingRoutineItemIds;
  final List<String> fixedRoutineItemIds;
  final List<String> skinCareRoutineItemIds;

  final BaseTimelineSectionAuthority classAuthority;
  final BaseTimelineSectionAuthority workAuthority;
  final BaseTimelineSectionAuthority eatingAuthority;
  final BaseTimelineSectionAuthority fixedAuthority;
  final BaseTimelineSectionAuthority skinCareAuthority;

  // ── Classes ──────────────────────────────────────────────────
  final String? classLogicalAssetId;
  final String? classLogicalAssetR2Key;
  final List<TimelineBlockDraft> classBlocks;

  // ── Work / Business ──────────────────────────────────────────
  final String? workLogicalAssetId;
  final String? workLogicalAssetR2Key;
  final List<TimelineBlockDraft> workBlocks;

  // ── Eating ───────────────────────────────────────────────────
  final String? eatingSetupPath; // 'has_routine' vs 'create'
  final List<TimelineBlockDraft> eatingBlocks;
  final String? mealPlanningGoal;
  final int? mealsPerDay;
  final String? eatingMode;
  final String? foodType;
  final String? foodStyleCustomText;
  final String? mealBudget;
  final String? cookingAbility;
  final int? breakfastMinute;
  final int? lunchMinute;
  final int? dinnerMinute;
  final int? snackMinute;
  final int? extraSnackMinute;
  final int? targetCalories;
  final int? targetProtein;
  final String? eatingPhotoAssetId;
  final String? eatingPhotoR2Key;

  // ── Fixed ────────────────────────────────────────────────────
  final List<TimelineBlockDraft> fixedBlocks;

  // ── Skin Care ────────────────────────────────────────────────
  final String? skinCareSetupPath; // 'products', 'build_for_me', 'skip'
  final bool skinCareSkipped;
  final List<TimelineBlockDraft> skinCareBlocks;
  final String? skinCareProductNames;
  final String? skinCareProductPhotoAssetId;
  final String? skinCareProductPhotoR2Key;
  final List<SkinCareDetectedProduct> skinCareReviewedProducts;
  final String? skinCareFacePhotoAssetId;
  final String? skinCareFacePhotoR2Key;
  final bool skinCareFacePhotoSkipped;
  final String? skinCareSkinType;
  final List<String> skinCareProblems;
  final String? skinCareBudget;
  final String? skinCarePreference;
  final List<String> skinCareSelectedProductNames;
  final List<SkinCareProductRecommendationDraft> skinCareProductRecommendations;
  final List<String> skinCareSpecialCareNotes;

  const BaseTimelineSetup({
    required this.uid,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
    this.revision = 1,
    this.classRoutineItemIds = const [],
    this.workRoutineItemIds = const [],
    this.eatingRoutineItemIds = const [],
    this.fixedRoutineItemIds = const [],
    this.skinCareRoutineItemIds = const [],
    this.classAuthority = BaseTimelineSectionAuthority.onboardingSeed,
    this.workAuthority = BaseTimelineSectionAuthority.onboardingSeed,
    this.eatingAuthority = BaseTimelineSectionAuthority.onboardingSeed,
    this.fixedAuthority = BaseTimelineSectionAuthority.onboardingSeed,
    this.skinCareAuthority = BaseTimelineSectionAuthority.onboardingSeed,
    this.classLogicalAssetId,
    this.classLogicalAssetR2Key,
    this.classBlocks = const [],
    this.workLogicalAssetId,
    this.workLogicalAssetR2Key,
    this.workBlocks = const [],
    this.eatingSetupPath,
    this.eatingBlocks = const [],
    this.mealPlanningGoal,
    this.mealsPerDay,
    this.eatingMode,
    this.foodType,
    this.foodStyleCustomText,
    this.mealBudget,
    this.cookingAbility,
    this.breakfastMinute,
    this.lunchMinute,
    this.dinnerMinute,
    this.snackMinute,
    this.extraSnackMinute,
    this.targetCalories,
    this.targetProtein,
    this.eatingPhotoAssetId,
    this.eatingPhotoR2Key,
    this.fixedBlocks = const [],
    this.skinCareSetupPath,
    this.skinCareSkipped = false,
    this.skinCareBlocks = const [],
    this.skinCareProductNames,
    this.skinCareProductPhotoAssetId,
    this.skinCareProductPhotoR2Key,
    this.skinCareReviewedProducts = const [],
    this.skinCareFacePhotoAssetId,
    this.skinCareFacePhotoR2Key,
    this.skinCareFacePhotoSkipped = false,
    this.skinCareSkinType,
    this.skinCareProblems = const [],
    this.skinCareBudget,
    this.skinCarePreference,
    this.skinCareSelectedProductNames = const [],
    this.skinCareProductRecommendations = const [],
    this.skinCareSpecialCareNotes = const [],
  });

  List<TimelineBlockDraft> get allBlocks => [
    ...classBlocks,
    ...workBlocks,
    ...eatingBlocks,
    ...fixedBlocks,
    ...skinCareBlocks,
  ];

  BaseTimelineDraft toBaseTimelineDraft() {
    return BaseTimelineDraft(
      blocks: allBlocks,
      mealsPerDay: mealsPerDay,
      mealPlanningGoal: mealPlanningGoal,
      foodType: foodType,
      eatingMode: eatingMode,
      foodStyleCustomText: foodStyleCustomText,
      mealBudget: mealBudget,
      cookingAbility: cookingAbility,
      breakfastMinute: breakfastMinute,
      lunchMinute: lunchMinute,
      dinnerMinute: dinnerMinute,
      snackMinute: snackMinute,
      extraSnackMinute: extraSnackMinute,
      skinCareSetupPath: skinCareSetupPath,
      skinCareSkipped: skinCareSkipped,
      skinCareProductNames: skinCareProductNames,
      skinCareSkinType: skinCareSkinType,
      skinCareProblems: skinCareProblems,
      skinCareBudget: skinCareBudget,
      skinCarePreference: skinCarePreference,
      skinCareReviewedProducts: skinCareReviewedProducts,
      skinCareSelectedProductNames: skinCareSelectedProductNames,
      skinCareProductRecommendations: skinCareProductRecommendations,
      skinCareSpecialCareNotes: skinCareSpecialCareNotes,
      skinCareFacePhotoAssetId: skinCareFacePhotoAssetId,
      skinCareFacePhotoR2Key: skinCareFacePhotoR2Key,
      skinCareFacePhotoSkipped: skinCareFacePhotoSkipped,
    );
  }

  BaseTimelineSectionSnapshot snapshotFor(BaseTimelineSection section) {
    return switch (section) {
      BaseTimelineSection.classes => _classesSnapshot(),
      BaseTimelineSection.work => _workSnapshot(),
      BaseTimelineSection.eating => _eatingSnapshot(),
      BaseTimelineSection.fixed => _fixedSnapshot(),
      BaseTimelineSection.skinCare => _skinCareSnapshot(),
    };
  }

  BaseTimelineSectionSnapshot _classesSnapshot() {
    final configured = classBlocks.isNotEmpty;
    final origin =
        (classLogicalAssetId != null || classLogicalAssetR2Key != null)
        ? BaseSetupOrigin.photo
        : (configured ? BaseSetupOrigin.manual : BaseSetupOrigin.notConfigured);
    final summary = configured
        ? (origin == BaseSetupOrigin.photo
              ? 'Timetable photo · ${classBlocks.length} classes'
              : '${classBlocks.length} weekly classes')
        : 'Not set up';
    return BaseTimelineSectionSnapshot(
      section: BaseTimelineSection.classes,
      origin: origin,
      configured: configured,
      blocks: classBlocks,
      sourceAssetId: classLogicalAssetId,
      sourceR2Key: classLogicalAssetR2Key,
      summary: summary,
    );
  }

  BaseTimelineSectionSnapshot _workSnapshot() {
    final configured = workBlocks.isNotEmpty;
    final origin = (workLogicalAssetId != null || workLogicalAssetR2Key != null)
        ? BaseSetupOrigin.photo
        : (configured ? BaseSetupOrigin.manual : BaseSetupOrigin.notConfigured);
    final summary = configured
        ? (origin == BaseSetupOrigin.photo
              ? 'Schedule photo · ${workBlocks.length} blocks'
              : '${workBlocks.length} weekly blocks')
        : 'Not set up';
    return BaseTimelineSectionSnapshot(
      section: BaseTimelineSection.work,
      origin: origin,
      configured: configured,
      blocks: workBlocks,
      sourceAssetId: workLogicalAssetId,
      sourceR2Key: workLogicalAssetR2Key,
      summary: summary,
    );
  }

  BaseTimelineSectionSnapshot _eatingSnapshot() {
    final configured = eatingBlocks.isNotEmpty;
    final isPhoto =
        eatingSetupPath == 'has_routine' || eatingPhotoAssetId != null;
    final origin = !configured
        ? BaseSetupOrigin.notConfigured
        : (isPhoto
              ? BaseSetupOrigin.photo
              : BaseSetupOrigin.generatedFromAnswers);
    final summary = configured
        ? (origin == BaseSetupOrigin.photo
              ? 'Imported from meal plan · ${mealsPerDay ?? _distinctMealCount(eatingBlocks)} meals/day'
              : 'Built for me · ${mealsPerDay ?? _distinctMealCount(eatingBlocks)} meals/day')
        : 'Not set up';
    return BaseTimelineSectionSnapshot(
      section: BaseTimelineSection.eating,
      origin: origin,
      configured: configured,
      blocks: eatingBlocks,
      sourceAssetId: eatingPhotoAssetId,
      sourceR2Key: eatingPhotoR2Key,
      sourceDetails: {
        if (mealPlanningGoal != null) 'goal': mealPlanningGoal,
        if (mealsPerDay != null) 'mealsPerDay': mealsPerDay,
        if (foodType != null) 'foodType': foodType,
        if (foodStyleCustomText != null) 'foodStyle': foodStyleCustomText,
        if (mealBudget != null) 'budget': mealBudget,
        if (cookingAbility != null) 'cookingAbility': cookingAbility,
        if (breakfastMinute != null) 'breakfastMinute': breakfastMinute,
        if (lunchMinute != null) 'lunchMinute': lunchMinute,
        if (dinnerMinute != null) 'dinnerMinute': dinnerMinute,
        if (snackMinute != null) 'snackMinute': snackMinute,
        if (extraSnackMinute != null) 'extraSnackMinute': extraSnackMinute,
        if (targetCalories != null) 'targetCalories': targetCalories,
        if (targetProtein != null) 'targetProtein': targetProtein,
      },
      summary: summary,
    );
  }

  int _distinctMealCount(List<TimelineBlockDraft> blocks) {
    final categories = blocks
        .map((b) => b.mealCategory ?? b.title)
        .where((s) => s.isNotEmpty)
        .toSet();
    return categories.isEmpty ? 3 : categories.length;
  }

  BaseTimelineSectionSnapshot _fixedSnapshot() {
    final configured = fixedBlocks.isNotEmpty;
    final origin = configured
        ? BaseSetupOrigin.manual
        : BaseSetupOrigin.notConfigured;
    final nonRequiredCount = fixedBlocks
        .where(
          (b) =>
              b.id != BaseTimelineDraft.fixedSleepId &&
              b.id != BaseTimelineDraft.fixedBathId,
        )
        .length;
    final summary = configured
        ? (nonRequiredCount > 0
              ? 'Sleep, Bath + $nonRequiredCount'
              : 'Sleep, Bath')
        : 'Not set up';
    return BaseTimelineSectionSnapshot(
      section: BaseTimelineSection.fixed,
      origin: origin,
      configured: configured,
      blocks: fixedBlocks,
      summary: summary,
    );
  }

  BaseTimelineSectionSnapshot _skinCareSnapshot() {
    if (skinCareSkipped) {
      return const BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.skinCare,
        origin: BaseSetupOrigin.skipped,
        configured: false,
        blocks: [],
        summary: 'Not set up',
      );
    }
    final configured = skinCareBlocks.isNotEmpty;
    if (!configured) {
      return const BaseTimelineSectionSnapshot(
        section: BaseTimelineSection.skinCare,
        origin: BaseSetupOrigin.notConfigured,
        configured: false,
        blocks: [],
        summary: 'Not set up',
      );
    }
    final isProducts =
        skinCareSetupPath == 'products' || skinCareProductPhotoAssetId != null;
    final origin = isProducts
        ? BaseSetupOrigin.photo
        : BaseSetupOrigin.generatedFromAnswers;
    final summary = isProducts
        ? 'Using my products'
        : 'Built for you · ${skinCareSelectedProductNames.length} products';
    return BaseTimelineSectionSnapshot(
      section: BaseTimelineSection.skinCare,
      origin: origin,
      configured: true,
      blocks: skinCareBlocks,
      sourceAssetId: isProducts
          ? skinCareProductPhotoAssetId
          : skinCareFacePhotoAssetId,
      sourceR2Key: isProducts
          ? skinCareProductPhotoR2Key
          : skinCareFacePhotoR2Key,
      sourceDetails: {
        if (skinCareSkinType != null) 'skinType': skinCareSkinType,
        if (skinCareProblems.isNotEmpty) 'problems': skinCareProblems,
        if (skinCareBudget != null) 'budget': skinCareBudget,
        if (skinCarePreference != null) 'preference': skinCarePreference,
        if (skinCareProductNames != null) 'productNames': skinCareProductNames,
        if (skinCareSelectedProductNames.isNotEmpty)
          'selectedProducts': skinCareSelectedProductNames,
      },
      summary: summary,
    );
  }

  List<String> trackedIdsFor(BaseTimelineSection section) {
    return switch (section) {
      BaseTimelineSection.classes => List.unmodifiable(classRoutineItemIds),
      BaseTimelineSection.work => List.unmodifiable(workRoutineItemIds),
      BaseTimelineSection.eating => List.unmodifiable(eatingRoutineItemIds),
      BaseTimelineSection.fixed => List.unmodifiable(fixedRoutineItemIds),
      BaseTimelineSection.skinCare => List.unmodifiable(skinCareRoutineItemIds),
    };
  }

  List<TimelineBlockDraft> blocksFor(BaseTimelineSection section) {
    return switch (section) {
      BaseTimelineSection.classes => List.unmodifiable(classBlocks),
      BaseTimelineSection.work => List.unmodifiable(workBlocks),
      BaseTimelineSection.eating => List.unmodifiable(eatingBlocks),
      BaseTimelineSection.fixed => List.unmodifiable(fixedBlocks),
      BaseTimelineSection.skinCare => List.unmodifiable(skinCareBlocks),
    };
  }

  BaseTimelineSectionAuthority authorityFor(BaseTimelineSection section) {
    return switch (section) {
      BaseTimelineSection.classes => classAuthority,
      BaseTimelineSection.work => workAuthority,
      BaseTimelineSection.eating => eatingAuthority,
      BaseTimelineSection.fixed => fixedAuthority,
      BaseTimelineSection.skinCare => skinCareAuthority,
    };
  }

  BaseTimelineSetup withSectionRoutineIds(
    BaseTimelineSection section,
    List<String> newIds,
  ) {
    return switch (section) {
      BaseTimelineSection.classes => copyWith(classRoutineItemIds: newIds),
      BaseTimelineSection.work => copyWith(workRoutineItemIds: newIds),
      BaseTimelineSection.eating => copyWith(eatingRoutineItemIds: newIds),
      BaseTimelineSection.fixed => copyWith(fixedRoutineItemIds: newIds),
      BaseTimelineSection.skinCare => copyWith(skinCareRoutineItemIds: newIds),
    };
  }

  BaseTimelineSetup withSectionAuthority(
    BaseTimelineSection section,
    BaseTimelineSectionAuthority authority,
  ) {
    return switch (section) {
      BaseTimelineSection.classes => copyWith(classAuthority: authority),
      BaseTimelineSection.work => copyWith(workAuthority: authority),
      BaseTimelineSection.eating => copyWith(eatingAuthority: authority),
      BaseTimelineSection.fixed => copyWith(fixedAuthority: authority),
      BaseTimelineSection.skinCare => copyWith(skinCareAuthority: authority),
    };
  }

  /// Prepares state when transitioning to or rebuilding Skin Care 'products' flow.
  /// Retains current product inputs/photos, but clears 'build_for_me' face recommendations.
  BaseTimelineSetup asSkinCareProducts({
    String? productNames,
    String? productPhotoAssetId,
    String? productPhotoR2Key,
    List<SkinCareDetectedProduct>? reviewedProducts,
    List<TimelineBlockDraft>? blocks,
  }) {
    return copyWith(
      skinCareSetupPath: 'products',
      skinCareSkipped: false,
      skinCareProductNames: productNames ?? skinCareProductNames,
      skinCareProductPhotoAssetId:
          productPhotoAssetId ?? skinCareProductPhotoAssetId,
      skinCareProductPhotoR2Key: productPhotoR2Key ?? skinCareProductPhotoR2Key,
      skinCareReviewedProducts: reviewedProducts ?? skinCareReviewedProducts,
      skinCareBlocks: blocks ?? skinCareBlocks,
      clearSkinCareFacePhotoAssetId: true,
      clearSkinCareFacePhotoR2Key: true,
      skinCareFacePhotoSkipped: false,
      clearSkinCareSkinType: true,
      clearSkinCareBudget: true,
      clearSkinCarePreference: true,
      skinCareProblems: const [],
      skinCareProductRecommendations: const [],
      skinCareSelectedProductNames: const [],
      skinCareSpecialCareNotes: const [],
    );
  }

  /// Prepares state when transitioning to or rebuilding Skin Care 'build_for_me' flow.
  /// Retains face photo & preference answers, but clears pre-existing product inputs.
  BaseTimelineSetup asSkinCareBuildForMe({
    String? facePhotoAssetId,
    String? facePhotoR2Key,
    bool? facePhotoSkipped,
    String? skinType,
    List<String>? problems,
    String? budget,
    String? preference,
    List<String>? selectedProductNames,
    List<SkinCareProductRecommendationDraft>? productRecommendations,
    List<String>? specialCareNotes,
    List<TimelineBlockDraft>? blocks,
  }) {
    return copyWith(
      skinCareSetupPath: 'build_for_me',
      skinCareSkipped: false,
      skinCareFacePhotoAssetId: facePhotoAssetId ?? skinCareFacePhotoAssetId,
      skinCareFacePhotoR2Key: facePhotoR2Key ?? skinCareFacePhotoR2Key,
      skinCareFacePhotoSkipped: facePhotoSkipped ?? skinCareFacePhotoSkipped,
      skinCareSkinType: skinType ?? skinCareSkinType,
      skinCareProblems: problems ?? skinCareProblems,
      skinCareBudget: budget ?? skinCareBudget,
      skinCarePreference: preference ?? skinCarePreference,
      skinCareSelectedProductNames:
          selectedProductNames ?? skinCareSelectedProductNames,
      skinCareProductRecommendations:
          productRecommendations ?? skinCareProductRecommendations,
      skinCareSpecialCareNotes: specialCareNotes ?? skinCareSpecialCareNotes,
      skinCareBlocks: blocks ?? skinCareBlocks,
      clearSkinCareProductNames: true,
      clearSkinCareProductPhotoAssetId: true,
      clearSkinCareProductPhotoR2Key: true,
      skinCareReviewedProducts: const [],
    );
  }

  /// Sets Skin Care as skipped.
  BaseTimelineSetup asSkinCareSkipped() {
    return copyWith(
      skinCareSetupPath: 'skip',
      skinCareSkipped: true,
      skinCareBlocks: const [],
      skinCareRoutineItemIds: const [],
      clearSkinCareProductNames: true,
      clearSkinCareProductPhotoAssetId: true,
      clearSkinCareProductPhotoR2Key: true,
      skinCareReviewedProducts: const [],
      clearSkinCareFacePhotoAssetId: true,
      clearSkinCareFacePhotoR2Key: true,
      skinCareFacePhotoSkipped: false,
      clearSkinCareSkinType: true,
      skinCareProblems: const [],
      clearSkinCareBudget: true,
      clearSkinCarePreference: true,
      skinCareSelectedProductNames: const [],
      skinCareProductRecommendations: const [],
      skinCareSpecialCareNotes: const [],
    );
  }

  /// Transitions Eating to AI generated from answers ('create').
  BaseTimelineSetup asEatingGenerated({
    List<TimelineBlockDraft>? blocks,
    String? goal,
    int? meals,
    String? mode,
    String? type,
    String? styleCustomText,
    String? budget,
    String? ability,
    int? breakfast,
    int? lunch,
    int? dinner,
    int? snack,
    int? extraSnack,
    int? calories,
    int? protein,
  }) {
    return copyWith(
      eatingSetupPath: 'create',
      eatingBlocks: blocks ?? eatingBlocks,
      clearEatingPhotoAssetId: true,
      clearEatingPhotoR2Key: true,
      mealPlanningGoal: goal ?? mealPlanningGoal,
      mealsPerDay: meals ?? mealsPerDay,
      eatingMode: mode ?? eatingMode,
      foodType: type ?? foodType,
      foodStyleCustomText: styleCustomText ?? foodStyleCustomText,
      mealBudget: budget ?? mealBudget,
      cookingAbility: ability ?? cookingAbility,
      breakfastMinute: breakfast ?? breakfastMinute,
      lunchMinute: lunch ?? lunchMinute,
      dinnerMinute: dinner ?? dinnerMinute,
      snackMinute: snack ?? snackMinute,
      extraSnackMinute: extraSnack ?? extraSnackMinute,
      targetCalories: calories ?? targetCalories,
      targetProtein: protein ?? targetProtein,
    );
  }

  /// Transitions Eating to meal plan photo ('has_routine').
  BaseTimelineSetup asEatingPhoto({
    required String photoAssetId,
    required String photoR2Key,
    List<TimelineBlockDraft>? blocks,
    int? meals,
  }) {
    return copyWith(
      eatingSetupPath: 'has_routine',
      eatingPhotoAssetId: photoAssetId,
      eatingPhotoR2Key: photoR2Key,
      eatingBlocks: blocks ?? eatingBlocks,
      mealsPerDay: meals ?? mealsPerDay,
      clearMealsPerDay: meals == null,
      clearMealPlanningGoal: true,
      clearEatingMode: true,
      clearFoodType: true,
      clearFoodStyleCustomText: true,
      clearMealBudget: true,
      clearCookingAbility: true,
      clearBreakfastMinute: true,
      clearLunchMinute: true,
      clearDinnerMinute: true,
      clearSnackMinute: true,
      clearExtraSnackMinute: true,
      clearTargetCalories: true,
      clearTargetProtein: true,
    );
  }

  BaseTimelineSetup copyWith({
    String? uid,
    DateTime? updatedAt,
    int? schemaVersion,
    int? revision,
    List<String>? classRoutineItemIds,
    List<String>? workRoutineItemIds,
    List<String>? eatingRoutineItemIds,
    List<String>? fixedRoutineItemIds,
    List<String>? skinCareRoutineItemIds,
    BaseTimelineSectionAuthority? classAuthority,
    BaseTimelineSectionAuthority? workAuthority,
    BaseTimelineSectionAuthority? eatingAuthority,
    BaseTimelineSectionAuthority? fixedAuthority,
    BaseTimelineSectionAuthority? skinCareAuthority,
    String? classLogicalAssetId,
    bool clearClassLogicalAssetId = false,
    String? classLogicalAssetR2Key,
    bool clearClassLogicalAssetR2Key = false,
    List<TimelineBlockDraft>? classBlocks,
    String? workLogicalAssetId,
    bool clearWorkLogicalAssetId = false,
    String? workLogicalAssetR2Key,
    bool clearWorkLogicalAssetR2Key = false,
    List<TimelineBlockDraft>? workBlocks,
    String? eatingSetupPath,
    bool clearEatingSetupPath = false,
    List<TimelineBlockDraft>? eatingBlocks,
    String? mealPlanningGoal,
    bool clearMealPlanningGoal = false,
    int? mealsPerDay,
    bool clearMealsPerDay = false,
    String? eatingMode,
    bool clearEatingMode = false,
    String? foodType,
    bool clearFoodType = false,
    String? foodStyleCustomText,
    bool clearFoodStyleCustomText = false,
    String? mealBudget,
    bool clearMealBudget = false,
    String? cookingAbility,
    bool clearCookingAbility = false,
    int? breakfastMinute,
    bool clearBreakfastMinute = false,
    int? lunchMinute,
    bool clearLunchMinute = false,
    int? dinnerMinute,
    bool clearDinnerMinute = false,
    int? snackMinute,
    bool clearSnackMinute = false,
    int? extraSnackMinute,
    bool clearExtraSnackMinute = false,
    int? targetCalories,
    bool clearTargetCalories = false,
    int? targetProtein,
    bool clearTargetProtein = false,
    String? eatingPhotoAssetId,
    bool clearEatingPhotoAssetId = false,
    String? eatingPhotoR2Key,
    bool clearEatingPhotoR2Key = false,
    List<TimelineBlockDraft>? fixedBlocks,
    String? skinCareSetupPath,
    bool clearSkinCareSetupPath = false,
    bool? skinCareSkipped,
    List<TimelineBlockDraft>? skinCareBlocks,
    String? skinCareProductNames,
    bool clearSkinCareProductNames = false,
    String? skinCareProductPhotoAssetId,
    bool clearSkinCareProductPhotoAssetId = false,
    String? skinCareProductPhotoR2Key,
    bool clearSkinCareProductPhotoR2Key = false,
    List<SkinCareDetectedProduct>? skinCareReviewedProducts,
    String? skinCareFacePhotoAssetId,
    bool clearSkinCareFacePhotoAssetId = false,
    String? skinCareFacePhotoR2Key,
    bool clearSkinCareFacePhotoR2Key = false,
    bool? skinCareFacePhotoSkipped,
    String? skinCareSkinType,
    bool clearSkinCareSkinType = false,
    List<String>? skinCareProblems,
    String? skinCareBudget,
    bool clearSkinCareBudget = false,
    String? skinCarePreference,
    bool clearSkinCarePreference = false,
    List<String>? skinCareSelectedProductNames,
    List<SkinCareProductRecommendationDraft>? skinCareProductRecommendations,
    List<String>? skinCareSpecialCareNotes,
  }) {
    return BaseTimelineSetup(
      uid: uid ?? this.uid,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      classRoutineItemIds: classRoutineItemIds ?? this.classRoutineItemIds,
      workRoutineItemIds: workRoutineItemIds ?? this.workRoutineItemIds,
      eatingRoutineItemIds: eatingRoutineItemIds ?? this.eatingRoutineItemIds,
      fixedRoutineItemIds: fixedRoutineItemIds ?? this.fixedRoutineItemIds,
      skinCareRoutineItemIds:
          skinCareRoutineItemIds ?? this.skinCareRoutineItemIds,
      classAuthority: classAuthority ?? this.classAuthority,
      workAuthority: workAuthority ?? this.workAuthority,
      eatingAuthority: eatingAuthority ?? this.eatingAuthority,
      fixedAuthority: fixedAuthority ?? this.fixedAuthority,
      skinCareAuthority: skinCareAuthority ?? this.skinCareAuthority,
      classLogicalAssetId: clearClassLogicalAssetId
          ? null
          : (classLogicalAssetId ?? this.classLogicalAssetId),
      classLogicalAssetR2Key: clearClassLogicalAssetR2Key
          ? null
          : (classLogicalAssetR2Key ?? this.classLogicalAssetR2Key),
      classBlocks: classBlocks ?? this.classBlocks,
      workLogicalAssetId: clearWorkLogicalAssetId
          ? null
          : (workLogicalAssetId ?? this.workLogicalAssetId),
      workLogicalAssetR2Key: clearWorkLogicalAssetR2Key
          ? null
          : (workLogicalAssetR2Key ?? this.workLogicalAssetR2Key),
      workBlocks: workBlocks ?? this.workBlocks,
      eatingSetupPath: clearEatingSetupPath
          ? null
          : (eatingSetupPath ?? this.eatingSetupPath),
      eatingBlocks: eatingBlocks ?? this.eatingBlocks,
      mealPlanningGoal: clearMealPlanningGoal
          ? null
          : (mealPlanningGoal ?? this.mealPlanningGoal),
      mealsPerDay: clearMealsPerDay ? null : (mealsPerDay ?? this.mealsPerDay),
      eatingMode: clearEatingMode ? null : (eatingMode ?? this.eatingMode),
      foodType: clearFoodType ? null : (foodType ?? this.foodType),
      foodStyleCustomText: clearFoodStyleCustomText
          ? null
          : (foodStyleCustomText ?? this.foodStyleCustomText),
      mealBudget: clearMealBudget ? null : (mealBudget ?? this.mealBudget),
      cookingAbility: clearCookingAbility
          ? null
          : (cookingAbility ?? this.cookingAbility),
      breakfastMinute: clearBreakfastMinute
          ? null
          : (breakfastMinute ?? this.breakfastMinute),
      lunchMinute: clearLunchMinute ? null : (lunchMinute ?? this.lunchMinute),
      dinnerMinute: clearDinnerMinute
          ? null
          : (dinnerMinute ?? this.dinnerMinute),
      snackMinute: clearSnackMinute ? null : (snackMinute ?? this.snackMinute),
      extraSnackMinute: clearExtraSnackMinute
          ? null
          : (extraSnackMinute ?? this.extraSnackMinute),
      targetCalories: clearTargetCalories
          ? null
          : (targetCalories ?? this.targetCalories),
      targetProtein: clearTargetProtein
          ? null
          : (targetProtein ?? this.targetProtein),
      eatingPhotoAssetId: clearEatingPhotoAssetId
          ? null
          : (eatingPhotoAssetId ?? this.eatingPhotoAssetId),
      eatingPhotoR2Key: clearEatingPhotoR2Key
          ? null
          : (eatingPhotoR2Key ?? this.eatingPhotoR2Key),
      fixedBlocks: fixedBlocks ?? this.fixedBlocks,
      skinCareSetupPath: clearSkinCareSetupPath
          ? null
          : (skinCareSetupPath ?? this.skinCareSetupPath),
      skinCareSkipped: skinCareSkipped ?? this.skinCareSkipped,
      skinCareBlocks: skinCareBlocks ?? this.skinCareBlocks,
      skinCareProductNames: clearSkinCareProductNames
          ? null
          : (skinCareProductNames ?? this.skinCareProductNames),
      skinCareProductPhotoAssetId: clearSkinCareProductPhotoAssetId
          ? null
          : (skinCareProductPhotoAssetId ?? this.skinCareProductPhotoAssetId),
      skinCareProductPhotoR2Key: clearSkinCareProductPhotoR2Key
          ? null
          : (skinCareProductPhotoR2Key ?? this.skinCareProductPhotoR2Key),
      skinCareReviewedProducts:
          skinCareReviewedProducts ?? this.skinCareReviewedProducts,
      skinCareFacePhotoAssetId: clearSkinCareFacePhotoAssetId
          ? null
          : (skinCareFacePhotoAssetId ?? this.skinCareFacePhotoAssetId),
      skinCareFacePhotoR2Key: clearSkinCareFacePhotoR2Key
          ? null
          : (skinCareFacePhotoR2Key ?? this.skinCareFacePhotoR2Key),
      skinCareFacePhotoSkipped:
          skinCareFacePhotoSkipped ?? this.skinCareFacePhotoSkipped,
      skinCareSkinType: clearSkinCareSkinType
          ? null
          : (skinCareSkinType ?? this.skinCareSkinType),
      skinCareProblems: skinCareProblems ?? this.skinCareProblems,
      skinCareBudget: clearSkinCareBudget
          ? null
          : (skinCareBudget ?? this.skinCareBudget),
      skinCarePreference: clearSkinCarePreference
          ? null
          : (skinCarePreference ?? this.skinCarePreference),
      skinCareSelectedProductNames:
          skinCareSelectedProductNames ?? this.skinCareSelectedProductNames,
      skinCareProductRecommendations:
          skinCareProductRecommendations ?? this.skinCareProductRecommendations,
      skinCareSpecialCareNotes:
          skinCareSpecialCareNotes ?? this.skinCareSpecialCareNotes,
    );
  }

  /// Durable schema boundary shared by fake/Firebase repositories and
  /// transaction commits. This intentionally validates persistence shape,
  /// not every product form rule.
  void validateForOwner(String pathUid) {
    final owner = pathUid.trim();
    if (owner.isEmpty || owner.contains('/') || uid.trim() != owner) {
      throw ArgumentError('Base Timeline owner does not match document path.');
    }
    if (schemaVersion < 1 || schemaVersion > currentSchemaVersion) {
      throw ArgumentError('Unsupported Base Timeline schema version.');
    }
    if (revision < 1) {
      throw ArgumentError('Base Timeline revision must be positive.');
    }

    void validateStrings(List<String> values, String field) {
      if (values.length > 500 || values.toSet().length != values.length) {
        throw ArgumentError('Base Timeline $field is malformed.');
      }
      for (final value in values) {
        if (value.trim().isEmpty || value.length > 512) {
          throw ArgumentError('Base Timeline $field is malformed.');
        }
      }
    }

    for (final entry in <(List<String>, String)>[
      (classRoutineItemIds, 'classRoutineItemIds'),
      (workRoutineItemIds, 'workRoutineItemIds'),
      (eatingRoutineItemIds, 'eatingRoutineItemIds'),
      (fixedRoutineItemIds, 'fixedRoutineItemIds'),
      (skinCareRoutineItemIds, 'skinCareRoutineItemIds'),
      (skinCareProblems, 'skinCareProblems'),
      (skinCareSelectedProductNames, 'skinCareSelectedProductNames'),
      (skinCareSpecialCareNotes, 'skinCareSpecialCareNotes'),
    ]) {
      validateStrings(entry.$1, entry.$2);
    }

    bool sectionMatches(BaseTimelineSection section, String raw) {
      final value = raw.trim().toLowerCase();
      return switch (section) {
        BaseTimelineSection.classes => value.contains('class'),
        BaseTimelineSection.work =>
          value.contains('work') ||
              value.contains('job') ||
              value.contains('business'),
        BaseTimelineSection.eating =>
          value.contains('eat') || value.contains('meal'),
        BaseTimelineSection.fixed =>
          value.contains('fixed') ||
              value.contains('sleep') ||
              value.contains('bath'),
        BaseTimelineSection.skinCare => value.contains('skin'),
      };
    }

    void validateBlocks(
      BaseTimelineSection section,
      List<TimelineBlockDraft> blocks,
    ) {
      if (blocks.length > 500) {
        throw ArgumentError('Too many Base Timeline blocks.');
      }
      final ids = <String>{};
      for (final block in blocks) {
        if (block.id.trim().isEmpty ||
            block.id.length > 256 ||
            !ids.add(block.id) ||
            block.title.trim().isEmpty ||
            block.title.length > 512 ||
            !sectionMatches(section, block.section) ||
            block.startMinute < 0 ||
            block.startMinute > 1439 ||
            block.endMinute < 0 ||
            block.endMinute > 1440 ||
            block.endMinute == block.startMinute ||
            block.repeatDays.isEmpty ||
            block.repeatDays.length > 7 ||
            block.repeatDays.toSet().length != block.repeatDays.length ||
            block.repeatDays.any((day) => day < 1 || day > 7)) {
          throw ArgumentError('Malformed ${section.name} timeline block.');
        }
      }
    }

    validateBlocks(BaseTimelineSection.classes, classBlocks);
    validateBlocks(BaseTimelineSection.work, workBlocks);
    validateBlocks(BaseTimelineSection.eating, eatingBlocks);
    validateBlocks(BaseTimelineSection.fixed, fixedBlocks);
    validateBlocks(BaseTimelineSection.skinCare, skinCareBlocks);

    for (final minute in <int?>[
      breakfastMinute,
      lunchMinute,
      dinnerMinute,
      snackMinute,
      extraSnackMinute,
    ]) {
      if (minute != null && (minute < 0 || minute > 1439)) {
        throw ArgumentError('Base Timeline meal time is out of range.');
      }
    }
    if (mealsPerDay != null && mealsPerDay! < 1) {
      throw ArgumentError('Base Timeline mealsPerDay must be positive.');
    }
    if (targetCalories != null && targetCalories! < 1) {
      throw ArgumentError('Base Timeline targetCalories must be positive.');
    }
    if (targetProtein != null && targetProtein! < 1) {
      throw ArgumentError('Base Timeline targetProtein must be positive.');
    }
    if (eatingSetupPath != null &&
        eatingSetupPath != 'has_routine' &&
        eatingSetupPath != 'create') {
      throw ArgumentError('Base Timeline eating setup path is invalid.');
    }
    if (skinCareSetupPath != null &&
        skinCareSetupPath != 'products' &&
        skinCareSetupPath != 'build_for_me' &&
        skinCareSetupPath != 'skip') {
      throw ArgumentError('Base Timeline skin care setup path is invalid.');
    }
    if (skinCareSkipped &&
        ((skinCareSetupPath != null && skinCareSetupPath != 'skip') ||
            skinCareBlocks.isNotEmpty)) {
      throw ArgumentError('Skipped skin care setup is inconsistent.');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'schemaVersion': schemaVersion,
      'revision': revision,
      'classRoutineItemIds': classRoutineItemIds,
      'workRoutineItemIds': workRoutineItemIds,
      'eatingRoutineItemIds': eatingRoutineItemIds,
      'fixedRoutineItemIds': fixedRoutineItemIds,
      'skinCareRoutineItemIds': skinCareRoutineItemIds,
      'classAuthority': classAuthority.name,
      'workAuthority': workAuthority.name,
      'eatingAuthority': eatingAuthority.name,
      'fixedAuthority': fixedAuthority.name,
      'skinCareAuthority': skinCareAuthority.name,
      'classLogicalAssetId': classLogicalAssetId,
      'classLogicalAssetR2Key': classLogicalAssetR2Key,
      'classBlocks': classBlocks.map((b) => b.toMap()).toList(),
      'workLogicalAssetId': workLogicalAssetId,
      'workLogicalAssetR2Key': workLogicalAssetR2Key,
      'workBlocks': workBlocks.map((b) => b.toMap()).toList(),
      'eatingSetupPath': eatingSetupPath,
      'eatingBlocks': eatingBlocks.map((b) => b.toMap()).toList(),
      'mealPlanningGoal': mealPlanningGoal,
      'mealsPerDay': mealsPerDay,
      'eatingMode': eatingMode,
      'foodType': foodType,
      'foodStyleCustomText': foodStyleCustomText,
      'mealBudget': mealBudget,
      'cookingAbility': cookingAbility,
      'breakfastMinute': breakfastMinute,
      'lunchMinute': lunchMinute,
      'dinnerMinute': dinnerMinute,
      'snackMinute': snackMinute,
      'extraSnackMinute': extraSnackMinute,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'eatingPhotoAssetId': eatingPhotoAssetId,
      'eatingPhotoR2Key': eatingPhotoR2Key,
      'fixedBlocks': fixedBlocks.map((b) => b.toMap()).toList(),
      'skinCareSetupPath': skinCareSetupPath,
      'skinCareSkipped': skinCareSkipped,
      'skinCareBlocks': skinCareBlocks.map((b) => b.toMap()).toList(),
      'skinCareProductNames': skinCareProductNames,
      'skinCareProductPhotoAssetId': skinCareProductPhotoAssetId,
      'skinCareProductPhotoR2Key': skinCareProductPhotoR2Key,
      'skinCareReviewedProducts': skinCareReviewedProducts
          .map((p) => p.toMap())
          .toList(),
      'skinCareFacePhotoAssetId': skinCareFacePhotoAssetId,
      'skinCareFacePhotoR2Key': skinCareFacePhotoR2Key,
      'skinCareFacePhotoSkipped': skinCareFacePhotoSkipped,
      'skinCareSkinType': skinCareSkinType,
      'skinCareProblems': skinCareProblems,
      'skinCareBudget': skinCareBudget,
      'skinCarePreference': skinCarePreference,
      'skinCareSelectedProductNames': skinCareSelectedProductNames,
      'skinCareProductRecommendations': skinCareProductRecommendations
          .map((r) => r.toMap())
          .toList(),
      'skinCareSpecialCareNotes': skinCareSpecialCareNotes,
    };
  }

  factory BaseTimelineSetup.fromMap(
    Map<String, dynamic> map, {
    required String uid,
  }) {
    final pathUid = uid.trim();
    final embeddedUid = map['uid'];
    if (pathUid.isEmpty ||
        embeddedUid is! String ||
        embeddedUid.trim() != pathUid) {
      throw FormatException(
        'Base Timeline owner does not match document path.',
      );
    }
    DateTime updated = DateTime.now();
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) {
      updated = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    }

    List<TimelineBlockDraft> parseBlocks(dynamic raw) {
      if (raw == null) return const [];
      if (raw is! List || raw.any((value) => value is! Map)) {
        throw const FormatException('Base Timeline blocks are malformed.');
      }
      return raw
          .cast<Map>()
          .map((m) => TimelineBlockDraft.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    List<String> parseStrings(dynamic raw, String field) {
      if (raw == null) return const [];
      if (raw is! List || raw.any((value) => value is! String)) {
        throw FormatException('Base Timeline $field is malformed.');
      }
      return raw.cast<String>().toList();
    }

    BaseTimelineSectionAuthority parseAuthority(dynamic raw) {
      if (raw is String) {
        for (final authority in BaseTimelineSectionAuthority.values) {
          if (authority.name == raw) return authority;
        }
      }
      if (raw == null) return BaseTimelineSectionAuthority.onboardingSeed;
      throw const FormatException('Base Timeline authority is malformed.');
    }

    final setup = BaseTimelineSetup(
      uid: pathUid,
      updatedAt: updated,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      revision: (map['revision'] as num?)?.toInt() ?? 1,
      classRoutineItemIds: parseStrings(
        map['classRoutineItemIds'],
        'classRoutineItemIds',
      ),
      workRoutineItemIds: parseStrings(
        map['workRoutineItemIds'],
        'workRoutineItemIds',
      ),
      eatingRoutineItemIds: parseStrings(
        map['eatingRoutineItemIds'],
        'eatingRoutineItemIds',
      ),
      fixedRoutineItemIds: parseStrings(
        map['fixedRoutineItemIds'],
        'fixedRoutineItemIds',
      ),
      skinCareRoutineItemIds: parseStrings(
        map['skinCareRoutineItemIds'],
        'skinCareRoutineItemIds',
      ),
      classAuthority: parseAuthority(map['classAuthority']),
      workAuthority: parseAuthority(map['workAuthority']),
      eatingAuthority: parseAuthority(map['eatingAuthority']),
      fixedAuthority: parseAuthority(map['fixedAuthority']),
      skinCareAuthority: parseAuthority(map['skinCareAuthority']),
      classLogicalAssetId: map['classLogicalAssetId'] as String?,
      classLogicalAssetR2Key: map['classLogicalAssetR2Key'] as String?,
      classBlocks: parseBlocks(map['classBlocks']),
      workLogicalAssetId: map['workLogicalAssetId'] as String?,
      workLogicalAssetR2Key: map['workLogicalAssetR2Key'] as String?,
      workBlocks: parseBlocks(map['workBlocks']),
      eatingSetupPath: map['eatingSetupPath'] as String?,
      eatingBlocks: parseBlocks(map['eatingBlocks']),
      mealPlanningGoal: map['mealPlanningGoal'] as String?,
      mealsPerDay: (map['mealsPerDay'] as num?)?.toInt(),
      eatingMode: map['eatingMode'] as String?,
      foodType: map['foodType'] as String?,
      foodStyleCustomText: map['foodStyleCustomText'] as String?,
      mealBudget: map['mealBudget'] as String?,
      cookingAbility: map['cookingAbility'] as String?,
      breakfastMinute: (map['breakfastMinute'] as num?)?.toInt(),
      lunchMinute: (map['lunchMinute'] as num?)?.toInt(),
      dinnerMinute: (map['dinnerMinute'] as num?)?.toInt(),
      snackMinute: (map['snackMinute'] as num?)?.toInt(),
      extraSnackMinute: (map['extraSnackMinute'] as num?)?.toInt(),
      targetCalories: (map['targetCalories'] as num?)?.toInt(),
      targetProtein: (map['targetProtein'] as num?)?.toInt(),
      eatingPhotoAssetId: map['eatingPhotoAssetId'] as String?,
      eatingPhotoR2Key: map['eatingPhotoR2Key'] as String?,
      fixedBlocks: parseBlocks(map['fixedBlocks']),
      skinCareSetupPath: map['skinCareSetupPath'] as String?,
      skinCareSkipped: map['skinCareSkipped'] as bool? ?? false,
      skinCareBlocks: parseBlocks(map['skinCareBlocks']),
      skinCareProductNames: map['skinCareProductNames'] as String?,
      skinCareProductPhotoAssetId:
          map['skinCareProductPhotoAssetId'] as String?,
      skinCareProductPhotoR2Key: map['skinCareProductPhotoR2Key'] as String?,
      skinCareReviewedProducts:
          (map['skinCareReviewedProducts'] as List?)
              ?.whereType<Map>()
              .map(
                (m) => SkinCareDetectedProduct.fromMap(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList() ??
          const [],
      skinCareFacePhotoAssetId: map['skinCareFacePhotoAssetId'] as String?,
      skinCareFacePhotoR2Key: map['skinCareFacePhotoR2Key'] as String?,
      skinCareFacePhotoSkipped:
          map['skinCareFacePhotoSkipped'] as bool? ?? false,
      skinCareSkinType: map['skinCareSkinType'] as String?,
      skinCareProblems: parseStrings(
        map['skinCareProblems'],
        'skinCareProblems',
      ),
      skinCareBudget: map['skinCareBudget'] as String?,
      skinCarePreference: map['skinCarePreference'] as String?,
      skinCareSelectedProductNames: parseStrings(
        map['skinCareSelectedProductNames'],
        'skinCareSelectedProductNames',
      ),
      skinCareProductRecommendations:
          (map['skinCareProductRecommendations'] as List?)
              ?.whereType<Map>()
              .map(
                (m) => SkinCareProductRecommendationDraft.fromMap(
                  Map<String, dynamic>.from(m),
                ),
              )
              .toList() ??
          const [],
      skinCareSpecialCareNotes: parseStrings(
        map['skinCareSpecialCareNotes'],
        'skinCareSpecialCareNotes',
      ),
    );
    setup.validateForOwner(pathUid);
    return setup;
  }

  factory BaseTimelineSetup.fromOnboardingDraft(
    String uid,
    OnboardingDraft draft,
  ) {
    final base = draft.baseTimeline;
    final blocks = base.blocks;
    final classBlocks = blocks
        .where((b) => b.section.toLowerCase().contains('class'))
        .toList();
    final workBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('job') ||
              b.section.toLowerCase().contains('work'),
        )
        .toList();
    final eatingBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('eat') ||
              b.section.toLowerCase().contains('meal'),
        )
        .toList();
    final fixedBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('fixed') ||
              b.section.toLowerCase().contains('sleep') ||
              b.section.toLowerCase().contains('bath'),
        )
        .toList();
    final skinCareBlocks = blocks
        .where((b) => b.section.toLowerCase().contains('skin'))
        .toList();

    String? classAssetId = base.classLogicalAssetId;
    String? classR2Key = base.classLogicalAssetR2Key;
    String? workAssetId = base.workLogicalAssetId;
    String? workR2Key = base.workLogicalAssetR2Key;
    String? eatingAssetId;
    String? eatingR2Key;

    for (final imp in base.pendingFutureImports) {
      final s = imp.section.toLowerCase();
      if (s.contains('class')) {
        classAssetId ??= imp.uploadedAssetId;
        classR2Key ??= imp.uploadedAssetR2Key;
      } else if (s.contains('job') || s.contains('work')) {
        workAssetId ??= imp.uploadedAssetId;
        workR2Key ??= imp.uploadedAssetR2Key;
      } else if (s.contains('eat') || s.contains('meal')) {
        eatingAssetId ??= imp.uploadedAssetId;
        eatingR2Key ??= imp.uploadedAssetR2Key;
      }
    }

    final targets = draft.canonicalNutritionTargets();

    return BaseTimelineSetup(
      uid: uid,
      updatedAt: draft.updatedAt ?? DateTime.now(),
      schemaVersion: currentSchemaVersion,
      classRoutineItemIds: classBlocks.map((b) => b.id).toList(),
      workRoutineItemIds: workBlocks.map((b) => b.id).toList(),
      eatingRoutineItemIds: eatingBlocks.map((b) => b.id).toList(),
      fixedRoutineItemIds: fixedBlocks.map((b) => b.id).toList(),
      skinCareRoutineItemIds: skinCareBlocks.map((b) => b.id).toList(),
      classLogicalAssetId: classAssetId,
      classLogicalAssetR2Key: classR2Key,
      classBlocks: classBlocks,
      workLogicalAssetId: workAssetId,
      workLogicalAssetR2Key: workR2Key,
      workBlocks: workBlocks,
      eatingSetupPath:
          base.eatingSetupPath ??
          (eatingAssetId != null ? 'has_routine' : 'create'),
      eatingBlocks: eatingBlocks,
      mealPlanningGoal: base.mealPlanningGoal,
      mealsPerDay: base.mealsPerDay,
      eatingMode: base.eatingMode,
      foodType: base.foodType,
      foodStyleCustomText: base.foodStyleCustomText,
      mealBudget: base.mealBudget,
      cookingAbility: base.cookingAbility,
      breakfastMinute: base.breakfastMinute,
      lunchMinute: base.lunchMinute,
      dinnerMinute: base.dinnerMinute,
      snackMinute: base.snackMinute,
      extraSnackMinute: base.extraSnackMinute,
      targetCalories: targets.targetCalories,
      targetProtein: targets.proteinTarget?.round(),
      eatingPhotoAssetId: eatingAssetId,
      eatingPhotoR2Key: eatingR2Key,
      fixedBlocks: fixedBlocks,
      skinCareSetupPath: base.skinCareSetupPath,
      skinCareSkipped: base.skinCareSkipped,
      skinCareBlocks: skinCareBlocks,
      skinCareProductNames: base.skinCareProductNames,
      skinCareProductPhotoAssetId: base.skinCareProductPhotoAssetId,
      skinCareProductPhotoR2Key: base.skinCareProductPhotoR2Key,
      skinCareReviewedProducts: base.skinCareReviewedProducts,
      skinCareFacePhotoAssetId: base.skinCareFacePhotoAssetId,
      skinCareFacePhotoR2Key: base.skinCareFacePhotoR2Key,
      skinCareFacePhotoSkipped: base.skinCareFacePhotoSkipped,
      skinCareSkinType: base.skinCareSkinType,
      skinCareProblems: base.skinCareProblems,
      skinCareBudget: base.skinCareBudget,
      skinCarePreference: base.skinCarePreference,
      skinCareSelectedProductNames: base.skinCareSelectedProductNames,
      skinCareProductRecommendations: base.skinCareProductRecommendations,
      skinCareSpecialCareNotes: base.skinCareSpecialCareNotes,
    );
  }

  factory BaseTimelineSetup.fromOnboardingCompletion({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    required List<RoutineItem> projectedRoutineItems,
  }) {
    final base = finalDraft.baseTimeline;
    final blocks = bundle.baseTimelineBlocks.isNotEmpty
        ? bundle.baseTimelineBlocks
        : base.blocks;
    final classBlocks = blocks
        .where((b) => b.section.toLowerCase().contains('class'))
        .toList();
    final workBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('job') ||
              b.section.toLowerCase().contains('work'),
        )
        .toList();
    final eatingBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('eat') ||
              b.section.toLowerCase().contains('meal'),
        )
        .toList();
    final fixedBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('fixed') ||
              b.section.toLowerCase().contains('sleep') ||
              b.section.toLowerCase().contains('bath'),
        )
        .toList();
    final skinCareBlocks = blocks
        .where((b) => b.section.toLowerCase().contains('skin'))
        .toList();

    String? classAssetId = base.classLogicalAssetId;
    String? classR2Key = base.classLogicalAssetR2Key;
    String? workAssetId = base.workLogicalAssetId;
    String? workR2Key = base.workLogicalAssetR2Key;
    String? eatingAssetId;
    String? eatingR2Key;
    String? skinCareProductAssetId = base.skinCareProductPhotoAssetId;
    String? skinCareProductR2Key = base.skinCareProductPhotoR2Key;
    String? skinCareFaceAssetId = base.skinCareFacePhotoAssetId;
    String? skinCareFaceR2Key = base.skinCareFacePhotoR2Key;

    for (final imp in base.pendingFutureImports) {
      final s = imp.section.toLowerCase();
      if (s.contains('class')) {
        classAssetId ??= imp.uploadedAssetId;
        classR2Key ??= imp.uploadedAssetR2Key;
      } else if (s.contains('job') || s.contains('work')) {
        workAssetId ??= imp.uploadedAssetId;
        workR2Key ??= imp.uploadedAssetR2Key;
      } else if (s.contains('eat') || s.contains('meal')) {
        eatingAssetId ??= imp.uploadedAssetId;
        eatingR2Key ??= imp.uploadedAssetR2Key;
      }
    }

    for (final ref in bundle.uploadedAssetReferences) {
      final sec = ref.section.toLowerCase();
      if (sec.contains('class')) {
        classAssetId = ref.uploadedAssetId;
        classR2Key = ref.uploadedAssetR2Key;
      } else if (sec.contains('job') || sec.contains('work')) {
        workAssetId = ref.uploadedAssetId;
        workR2Key = ref.uploadedAssetR2Key;
      } else if (sec.contains('eat') || sec.contains('meal')) {
        eatingAssetId = ref.uploadedAssetId;
        eatingR2Key = ref.uploadedAssetR2Key;
      } else if (sec.contains('skin')) {
        if (ref.mode == 'no_products' || ref.id.contains('face')) {
          skinCareFaceAssetId = ref.uploadedAssetId;
          skinCareFaceR2Key = ref.uploadedAssetR2Key;
        } else {
          skinCareProductAssetId = ref.uploadedAssetId;
          skinCareProductR2Key = ref.uploadedAssetR2Key;
        }
      }
    }

    final classRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              classBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'classes' ||
              item.category == RoutineCategory.classBlock,
        )
        .map((e) => e.id)
        .toList();
    final workRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              workBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'work' ||
              item.category == RoutineCategory.job,
        )
        .map((e) => e.id)
        .toList();
    final eatingRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              eatingBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'eating' ||
              item.category == RoutineCategory.eating,
        )
        .map((e) => e.id)
        .toList();
    final fixedRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              fixedBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'fixed' ||
              item.category == RoutineCategory.fixed ||
              item.category == RoutineCategory.sleep,
        )
        .map((e) => e.id)
        .toList();
    final skinCareRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              skinCareBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'skinCare' ||
              item.category == RoutineCategory.skinCare,
        )
        .map((e) => e.id)
        .toList();

    final targets = finalDraft.canonicalNutritionTargets();

    return BaseTimelineSetup(
      uid: bundle.uid,
      updatedAt: bundle.updatedAt,
      schemaVersion: currentSchemaVersion,
      revision: 1,
      classRoutineItemIds: classRoutineItemIds,
      workRoutineItemIds: workRoutineItemIds,
      eatingRoutineItemIds: eatingRoutineItemIds,
      fixedRoutineItemIds: fixedRoutineItemIds,
      skinCareRoutineItemIds: skinCareRoutineItemIds,
      classLogicalAssetId: classAssetId,
      classLogicalAssetR2Key: classR2Key,
      classBlocks: classBlocks,
      workLogicalAssetId: workAssetId,
      workLogicalAssetR2Key: workR2Key,
      workBlocks: workBlocks,
      eatingSetupPath:
          base.eatingSetupPath ??
          (eatingAssetId != null ? 'has_routine' : 'create'),
      eatingBlocks: eatingBlocks,
      mealPlanningGoal: base.mealPlanningGoal,
      mealsPerDay: base.mealsPerDay,
      eatingMode: base.eatingMode,
      foodType: base.foodType,
      foodStyleCustomText: base.foodStyleCustomText,
      mealBudget: base.mealBudget,
      cookingAbility: base.cookingAbility,
      breakfastMinute: base.breakfastMinute,
      lunchMinute: base.lunchMinute,
      dinnerMinute: base.dinnerMinute,
      snackMinute: base.snackMinute,
      extraSnackMinute: base.extraSnackMinute,
      targetCalories: targets.targetCalories,
      targetProtein: targets.proteinTarget?.round(),
      eatingPhotoAssetId: eatingAssetId,
      eatingPhotoR2Key: eatingR2Key,
      fixedBlocks: fixedBlocks,
      skinCareSetupPath: base.skinCareSetupPath,
      skinCareSkipped: base.skinCareSkipped,
      skinCareBlocks: skinCareBlocks,
      skinCareProductNames: base.skinCareProductNames,
      skinCareProductPhotoAssetId: skinCareProductAssetId,
      skinCareProductPhotoR2Key: skinCareProductR2Key,
      skinCareReviewedProducts: base.skinCareReviewedProducts,
      skinCareFacePhotoAssetId: skinCareFaceAssetId,
      skinCareFacePhotoR2Key: skinCareFaceR2Key,
      skinCareFacePhotoSkipped: base.skinCareFacePhotoSkipped,
      skinCareSkinType: base.skinCareSkinType,
      skinCareProblems: base.skinCareProblems,
      skinCareBudget: base.skinCareBudget,
      skinCarePreference: base.skinCarePreference,
      skinCareSelectedProductNames: base.skinCareSelectedProductNames,
      skinCareProductRecommendations: base.skinCareProductRecommendations,
      skinCareSpecialCareNotes: base.skinCareSpecialCareNotes,
    );
  }

  factory BaseTimelineSetup.fromCompletionBundle(
    String uid,
    OnboardingCompletionBundle bundle, {
    OnboardingDraft? finalDraft,
    required List<RoutineItem> projectedRoutineItems,
  }) {
    if (finalDraft != null) {
      return BaseTimelineSetup.fromOnboardingCompletion(
        finalDraft: finalDraft,
        bundle: bundle,
        projectedRoutineItems: projectedRoutineItems,
      );
    }
    final blocks = bundle.baseTimelineBlocks;
    final classBlocks = blocks
        .where((b) => b.section.toLowerCase().contains('class'))
        .toList();
    final workBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('job') ||
              b.section.toLowerCase().contains('work'),
        )
        .toList();
    final eatingBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('eat') ||
              b.section.toLowerCase().contains('meal'),
        )
        .toList();
    final fixedBlocks = blocks
        .where(
          (b) =>
              b.section.toLowerCase().contains('fixed') ||
              b.section.toLowerCase().contains('sleep') ||
              b.section.toLowerCase().contains('bath'),
        )
        .toList();
    final skinCareBlocks = blocks
        .where((b) => b.section.toLowerCase().contains('skin'))
        .toList();

    String? classAssetId;
    String? classR2Key;
    String? workAssetId;
    String? workR2Key;
    String? eatingAssetId;
    String? eatingR2Key;
    String? skinCareProductAssetId;
    String? skinCareProductR2Key;
    String? skinCareFaceAssetId;
    String? skinCareFaceR2Key;

    for (final ref in bundle.uploadedAssetReferences) {
      final sec = ref.section.toLowerCase();
      if (sec.contains('class')) {
        classAssetId = ref.uploadedAssetId;
        classR2Key = ref.uploadedAssetR2Key;
      } else if (sec.contains('job') || sec.contains('work')) {
        workAssetId = ref.uploadedAssetId;
        workR2Key = ref.uploadedAssetR2Key;
      } else if (sec.contains('eat') || sec.contains('meal')) {
        eatingAssetId = ref.uploadedAssetId;
        eatingR2Key = ref.uploadedAssetR2Key;
      } else if (sec.contains('skin')) {
        if (ref.mode == 'no_products' || ref.id.contains('face')) {
          skinCareFaceAssetId = ref.uploadedAssetId;
          skinCareFaceR2Key = ref.uploadedAssetR2Key;
        } else {
          skinCareProductAssetId = ref.uploadedAssetId;
          skinCareProductR2Key = ref.uploadedAssetR2Key;
        }
      }
    }

    final classRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              classBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'classes' ||
              item.category == RoutineCategory.classBlock,
        )
        .map((e) => e.id)
        .toList();
    final workRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              workBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'work' ||
              item.category == RoutineCategory.job,
        )
        .map((e) => e.id)
        .toList();
    final eatingRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              eatingBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'eating' ||
              item.category == RoutineCategory.eating,
        )
        .map((e) => e.id)
        .toList();
    final fixedRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              fixedBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'fixed' ||
              item.category == RoutineCategory.fixed ||
              item.category == RoutineCategory.sleep,
        )
        .map((e) => e.id)
        .toList();
    final skinCareRoutineItemIds = projectedRoutineItems
        .where(
          (item) =>
              skinCareBlocks.any((b) => b.id == item.id) ||
              item.baseTimelineSection == 'skinCare' ||
              item.category == RoutineCategory.skinCare,
        )
        .map((e) => e.id)
        .toList();

    return BaseTimelineSetup(
      uid: uid,
      updatedAt: bundle.updatedAt,
      schemaVersion: currentSchemaVersion,
      classRoutineItemIds: classRoutineItemIds,
      workRoutineItemIds: workRoutineItemIds,
      eatingRoutineItemIds: eatingRoutineItemIds,
      fixedRoutineItemIds: fixedRoutineItemIds,
      skinCareRoutineItemIds: skinCareRoutineItemIds,
      classLogicalAssetId: classAssetId,
      classLogicalAssetR2Key: classR2Key,
      classBlocks: classBlocks,
      workLogicalAssetId: workAssetId,
      workLogicalAssetR2Key: workR2Key,
      workBlocks: workBlocks,
      eatingSetupPath: eatingAssetId != null ? 'has_routine' : 'create',
      eatingBlocks: eatingBlocks,
      eatingPhotoAssetId: eatingAssetId,
      eatingPhotoR2Key: eatingR2Key,
      fixedBlocks: fixedBlocks,
      skinCareBlocks: skinCareBlocks,
      skinCareProductPhotoAssetId: skinCareProductAssetId,
      skinCareProductPhotoR2Key: skinCareProductR2Key,
      skinCareFacePhotoAssetId: skinCareFaceAssetId,
      skinCareFacePhotoR2Key: skinCareFaceR2Key,
    );
  }
}
