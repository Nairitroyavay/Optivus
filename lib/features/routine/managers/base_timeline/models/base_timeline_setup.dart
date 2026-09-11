import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';


/// Durable runtime Base Timeline configuration stored at
/// `users/{uid}/baseTimelineSetup/current`.
class BaseTimelineSetup {
  static const int currentSchemaVersion = 1;

  final String uid;
  final DateTime updatedAt;
  final int schemaVersion;

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
    final origin = (classLogicalAssetId != null || classLogicalAssetR2Key != null)
        ? BaseSetupOrigin.photo
        : (configured ? BaseSetupOrigin.manual : BaseSetupOrigin.notConfigured);
    final summary = configured
        ? (origin == BaseSetupOrigin.photo
            ? 'Timetable photo · ${classBlocks.length} blocks'
            : '${classBlocks.length} weekly blocks')
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
    final isPhoto = eatingSetupPath == 'has_routine' || eatingPhotoAssetId != null;
    final origin = !configured
        ? BaseSetupOrigin.notConfigured
        : (isPhoto ? BaseSetupOrigin.photo : BaseSetupOrigin.generatedFromAnswers);
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
    final origin = configured ? BaseSetupOrigin.manual : BaseSetupOrigin.notConfigured;
    final nonRequiredCount = fixedBlocks.where(
      (b) => b.id != BaseTimelineDraft.fixedSleepId && b.id != BaseTimelineDraft.fixedBathId,
    ).length;
    final summary = configured
        ? (nonRequiredCount > 0 ? 'Sleep, Bath + $nonRequiredCount' : 'Sleep, Bath')
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
    final isProducts = skinCareSetupPath == 'products' || skinCareProductPhotoAssetId != null;
    final origin = isProducts ? BaseSetupOrigin.photo : BaseSetupOrigin.generatedFromAnswers;
    final summary = isProducts
        ? 'Using my products'
        : 'Built for you · ${skinCareSelectedProductNames.length} products';
    return BaseTimelineSectionSnapshot(
      section: BaseTimelineSection.skinCare,
      origin: origin,
      configured: true,
      blocks: skinCareBlocks,
      sourceAssetId: isProducts ? skinCareProductPhotoAssetId : skinCareFacePhotoAssetId,
      sourceR2Key: isProducts ? skinCareProductPhotoR2Key : skinCareFacePhotoR2Key,
      sourceDetails: {
        if (skinCareSkinType != null) 'skinType': skinCareSkinType,
        if (skinCareProblems.isNotEmpty) 'problems': skinCareProblems,
        if (skinCareBudget != null) 'budget': skinCareBudget,
        if (skinCarePreference != null) 'preference': skinCarePreference,
        if (skinCareProductNames != null) 'productNames': skinCareProductNames,
        if (skinCareSelectedProductNames.isNotEmpty) 'selectedProducts': skinCareSelectedProductNames,
      },
      summary: summary,
    );
  }

  BaseTimelineSetup copyWith({
    String? uid,
    DateTime? updatedAt,
    int? schemaVersion,
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
    List<TimelineBlockDraft>? eatingBlocks,
    String? mealPlanningGoal,
    int? mealsPerDay,
    String? eatingMode,
    String? foodType,
    String? foodStyleCustomText,
    String? mealBudget,
    String? cookingAbility,
    int? breakfastMinute,
    int? lunchMinute,
    int? dinnerMinute,
    int? snackMinute,
    int? extraSnackMinute,
    int? targetCalories,
    int? targetProtein,
    String? eatingPhotoAssetId,
    bool clearEatingPhotoAssetId = false,
    String? eatingPhotoR2Key,
    bool clearEatingPhotoR2Key = false,
    List<TimelineBlockDraft>? fixedBlocks,
    String? skinCareSetupPath,
    bool? skinCareSkipped,
    List<TimelineBlockDraft>? skinCareBlocks,
    String? skinCareProductNames,
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
    List<String>? skinCareProblems,
    String? skinCareBudget,
    String? skinCarePreference,
    List<String>? skinCareSelectedProductNames,
    List<SkinCareProductRecommendationDraft>? skinCareProductRecommendations,
    List<String>? skinCareSpecialCareNotes,
  }) {
    return BaseTimelineSetup(
      uid: uid ?? this.uid,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      classLogicalAssetId: clearClassLogicalAssetId ? null : (classLogicalAssetId ?? this.classLogicalAssetId),
      classLogicalAssetR2Key: clearClassLogicalAssetR2Key ? null : (classLogicalAssetR2Key ?? this.classLogicalAssetR2Key),
      classBlocks: classBlocks ?? this.classBlocks,
      workLogicalAssetId: clearWorkLogicalAssetId ? null : (workLogicalAssetId ?? this.workLogicalAssetId),
      workLogicalAssetR2Key: clearWorkLogicalAssetR2Key ? null : (workLogicalAssetR2Key ?? this.workLogicalAssetR2Key),
      workBlocks: workBlocks ?? this.workBlocks,
      eatingSetupPath: eatingSetupPath ?? this.eatingSetupPath,
      eatingBlocks: eatingBlocks ?? this.eatingBlocks,
      mealPlanningGoal: mealPlanningGoal ?? this.mealPlanningGoal,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      eatingMode: eatingMode ?? this.eatingMode,
      foodType: foodType ?? this.foodType,
      foodStyleCustomText: foodStyleCustomText ?? this.foodStyleCustomText,
      mealBudget: mealBudget ?? this.mealBudget,
      cookingAbility: cookingAbility ?? this.cookingAbility,
      breakfastMinute: breakfastMinute ?? this.breakfastMinute,
      lunchMinute: lunchMinute ?? this.lunchMinute,
      dinnerMinute: dinnerMinute ?? this.dinnerMinute,
      snackMinute: snackMinute ?? this.snackMinute,
      extraSnackMinute: extraSnackMinute ?? this.extraSnackMinute,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      eatingPhotoAssetId: clearEatingPhotoAssetId ? null : (eatingPhotoAssetId ?? this.eatingPhotoAssetId),
      eatingPhotoR2Key: clearEatingPhotoR2Key ? null : (eatingPhotoR2Key ?? this.eatingPhotoR2Key),
      fixedBlocks: fixedBlocks ?? this.fixedBlocks,
      skinCareSetupPath: skinCareSetupPath ?? this.skinCareSetupPath,
      skinCareSkipped: skinCareSkipped ?? this.skinCareSkipped,
      skinCareBlocks: skinCareBlocks ?? this.skinCareBlocks,
      skinCareProductNames: skinCareProductNames ?? this.skinCareProductNames,
      skinCareProductPhotoAssetId: clearSkinCareProductPhotoAssetId ? null : (skinCareProductPhotoAssetId ?? this.skinCareProductPhotoAssetId),
      skinCareProductPhotoR2Key: clearSkinCareProductPhotoR2Key ? null : (skinCareProductPhotoR2Key ?? this.skinCareProductPhotoR2Key),
      skinCareReviewedProducts: skinCareReviewedProducts ?? this.skinCareReviewedProducts,
      skinCareFacePhotoAssetId: clearSkinCareFacePhotoAssetId ? null : (skinCareFacePhotoAssetId ?? this.skinCareFacePhotoAssetId),
      skinCareFacePhotoR2Key: clearSkinCareFacePhotoR2Key ? null : (skinCareFacePhotoR2Key ?? this.skinCareFacePhotoR2Key),
      skinCareFacePhotoSkipped: skinCareFacePhotoSkipped ?? this.skinCareFacePhotoSkipped,
      skinCareSkinType: skinCareSkinType ?? this.skinCareSkinType,
      skinCareProblems: skinCareProblems ?? this.skinCareProblems,
      skinCareBudget: skinCareBudget ?? this.skinCareBudget,
      skinCarePreference: skinCarePreference ?? this.skinCarePreference,
      skinCareSelectedProductNames: skinCareSelectedProductNames ?? this.skinCareSelectedProductNames,
      skinCareProductRecommendations: skinCareProductRecommendations ?? this.skinCareProductRecommendations,
      skinCareSpecialCareNotes: skinCareSpecialCareNotes ?? this.skinCareSpecialCareNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'schemaVersion': schemaVersion,
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
      'skinCareReviewedProducts': skinCareReviewedProducts.map((p) => p.toMap()).toList(),
      'skinCareFacePhotoAssetId': skinCareFacePhotoAssetId,
      'skinCareFacePhotoR2Key': skinCareFacePhotoR2Key,
      'skinCareFacePhotoSkipped': skinCareFacePhotoSkipped,
      'skinCareSkinType': skinCareSkinType,
      'skinCareProblems': skinCareProblems,
      'skinCareBudget': skinCareBudget,
      'skinCarePreference': skinCarePreference,
      'skinCareSelectedProductNames': skinCareSelectedProductNames,
      'skinCareProductRecommendations': skinCareProductRecommendations.map((r) => r.toMap()).toList(),
      'skinCareSpecialCareNotes': skinCareSpecialCareNotes,
    };
  }

  factory BaseTimelineSetup.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime updated = DateTime.now();
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) {
      updated = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      updated = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    }

    List<TimelineBlockDraft> parseBlocks(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => TimelineBlockDraft.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    return BaseTimelineSetup(
      uid: (map['uid'] as String?)?.trim().isNotEmpty == true ? map['uid'] as String : uid,
      updatedAt: updated,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
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
      skinCareProductPhotoAssetId: map['skinCareProductPhotoAssetId'] as String?,
      skinCareProductPhotoR2Key: map['skinCareProductPhotoR2Key'] as String?,
      skinCareReviewedProducts: (map['skinCareReviewedProducts'] as List?)
              ?.whereType<Map>()
              .map((m) => SkinCareDetectedProduct.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      skinCareFacePhotoAssetId: map['skinCareFacePhotoAssetId'] as String?,
      skinCareFacePhotoR2Key: map['skinCareFacePhotoR2Key'] as String?,
      skinCareFacePhotoSkipped: map['skinCareFacePhotoSkipped'] as bool? ?? false,
      skinCareSkinType: map['skinCareSkinType'] as String?,
      skinCareProblems: (map['skinCareProblems'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      skinCareBudget: map['skinCareBudget'] as String?,
      skinCarePreference: map['skinCarePreference'] as String?,
      skinCareSelectedProductNames: (map['skinCareSelectedProductNames'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      skinCareProductRecommendations: (map['skinCareProductRecommendations'] as List?)
              ?.whereType<Map>()
              .map((m) => SkinCareProductRecommendationDraft.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      skinCareSpecialCareNotes: (map['skinCareSpecialCareNotes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  factory BaseTimelineSetup.fromOnboardingDraft(
    String uid,
    OnboardingDraft draft,
  ) {
    final base = draft.baseTimeline;
    final blocks = base.blocks;
    final classBlocks = blocks.where((b) => b.section.toLowerCase().contains('class')).toList();
    final workBlocks = blocks.where((b) => b.section.toLowerCase().contains('job') || b.section.toLowerCase().contains('work')).toList();
    final eatingBlocks = blocks.where((b) => b.section.toLowerCase().contains('eat') || b.section.toLowerCase().contains('meal')).toList();
    final fixedBlocks = blocks.where((b) => b.section.toLowerCase().contains('fixed') || b.section.toLowerCase().contains('sleep') || b.section.toLowerCase().contains('bath')).toList();
    final skinCareBlocks = blocks.where((b) => b.section.toLowerCase().contains('skin')).toList();

    String? classAssetId;
    String? classR2Key;
    String? classLocalPath;
    String? workAssetId;
    String? workR2Key;
    String? workLocalPath;

    for (final imp in base.pendingFutureImports) {
      final s = imp.section.toLowerCase();
      if (s.contains('class')) {
        classAssetId = imp.uploadedAssetId;
        classR2Key = imp.uploadedAssetR2Key;
        classLocalPath = imp.uploadPlaceholderPath;
      } else if (s.contains('job') || s.contains('work')) {
        workAssetId = imp.uploadedAssetId;
        workR2Key = imp.uploadedAssetR2Key;
        workLocalPath = imp.uploadPlaceholderPath;
      }
    }

    return BaseTimelineSetup(
      uid: uid,
      updatedAt: draft.updatedAt ?? DateTime.now(),
      schemaVersion: currentSchemaVersion,
      classLogicalAssetId: classAssetId,
      classLogicalAssetR2Key: classR2Key,
      classBlocks: classBlocks,
      workLogicalAssetId: workAssetId,
      workLogicalAssetR2Key: workR2Key,
      workBlocks: workBlocks,
      eatingSetupPath: base.eatingSetupPath,
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
      fixedBlocks: fixedBlocks,
      skinCareSetupPath: base.skinCareSetupPath,
      skinCareSkipped: base.skinCareSkipped,
      skinCareBlocks: skinCareBlocks,
      skinCareProductNames: base.skinCareProductNames,
      skinCareProductPhotoAssetId: base.skinCareProductPhotoAssetId,
      skinCareProductPhotoR2Key: base.skinCareProductPhotoR2Key,
      skinCareFacePhotoAssetId: base.skinCareFacePhotoAssetId,
      skinCareFacePhotoR2Key: base.skinCareFacePhotoR2Key,
      skinCareFacePhotoSkipped: base.skinCareFacePhotoSkipped,
      skinCareSkinType: base.skinCareSkinType,
      skinCareProblems: base.skinCareProblems,
      skinCareBudget: base.skinCareBudget,
      skinCarePreference: base.skinCarePreference,
    );
  }

  factory BaseTimelineSetup.fromCompletionBundle(
    String uid,
    OnboardingCompletionBundle bundle,
  ) {
    final blocks = bundle.baseTimelineBlocks;
    final classBlocks = blocks.where((b) => b.section.toLowerCase().contains('class')).toList();
    final workBlocks = blocks.where((b) => b.section.toLowerCase().contains('job') || b.section.toLowerCase().contains('work')).toList();
    final eatingBlocks = blocks.where((b) => b.section.toLowerCase().contains('eat') || b.section.toLowerCase().contains('meal')).toList();
    final fixedBlocks = blocks.where((b) => b.section.toLowerCase().contains('fixed') || b.section.toLowerCase().contains('sleep') || b.section.toLowerCase().contains('bath')).toList();
    final skinCareBlocks = blocks.where((b) => b.section.toLowerCase().contains('skin')).toList();

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

    return BaseTimelineSetup(
      uid: uid,
      updatedAt: bundle.updatedAt,
      schemaVersion: currentSchemaVersion,
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

