import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_operation_session.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_candidate_dish_normalizer.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_source_transition_policy.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

/// Staged state machine stages for Eating Base Timeline setup.
enum EatingSetupStage {
  currentSetup,
  chooseSource,
  uploading,
  extracting,
  generating,
  review,
  editingBlock,
  saving,
  saveSuccess,
  error,
}

@immutable
class EatingSetupState {
  final EatingSetupStage stage;
  final List<TimelineBlockDraft> workingBlocks;
  final String? workingGoal;
  final int? workingMealsPerDay;
  final String? workingEatingMode;
  final String? workingFoodType;
  final String? workingFoodStyleCustomText;
  final List<String> workingFoodsToAvoid;
  final int? workingBreakfastMinute;
  final int? workingLunchMinute;
  final int? workingDinnerMinute;
  final int? workingSnackMinute;
  final int? workingExtraSnackMinute;
  final int? workingTargetCalories;
  final int? workingTargetProtein;
  final int? workingTargetCaloriesOverride;
  final int? workingTargetProteinOverride;
  final String? workingAssetId;
  final String? workingR2Key;
  final String? workingSetupPath;
  final int? workingGeneratedPlanVersion;
  final String? workingGeneratedInputFingerprint;
  final bool workingCustomized;
  final String? candidateAssetId;
  final String? candidateR2Key;
  final int selectedDay;
  final bool isDirty;
  final bool isSaving;
  final String? errorMessage;
  final String? frontBlockId;
  final int sessionGeneration;
  final bool hasRunStartupCleanup;
  final String ownerUid;
  final int? editorBaseRevision;
  final String? baseCommittedAssetId;
  final String? baseCommittedR2Key;
  final bool routineRefreshPending;
  final int? committedRevision;
  final String? routineRefreshMessage;
  final bool isConcurrencyConflict;
  final String aiActionTitle;
  final List<String> aiProgressMessages;

  const EatingSetupState({
    this.stage = EatingSetupStage.currentSetup,
    this.workingBlocks = const [],
    this.workingGoal,
    this.workingMealsPerDay,
    this.workingEatingMode,
    this.workingFoodType,
    this.workingFoodStyleCustomText,
    this.workingFoodsToAvoid = const [],
    this.workingBreakfastMinute,
    this.workingLunchMinute,
    this.workingDinnerMinute,
    this.workingSnackMinute,
    this.workingExtraSnackMinute,
    this.workingTargetCalories,
    this.workingTargetProtein,
    this.workingTargetCaloriesOverride,
    this.workingTargetProteinOverride,
    this.workingAssetId,
    this.workingR2Key,
    this.workingSetupPath,
    this.workingGeneratedPlanVersion,
    this.workingGeneratedInputFingerprint,
    this.workingCustomized = false,
    this.candidateAssetId,
    this.candidateR2Key,
    this.selectedDay = 1,
    this.isDirty = false,
    this.isSaving = false,
    this.errorMessage,
    this.frontBlockId,
    this.sessionGeneration = 0,
    this.hasRunStartupCleanup = false,
    this.ownerUid = '',
    this.editorBaseRevision,
    this.baseCommittedAssetId,
    this.baseCommittedR2Key,
    this.routineRefreshPending = false,
    this.committedRevision,
    this.routineRefreshMessage,
    this.isConcurrencyConflict = false,
    this.aiActionTitle = 'Processing meal plan...',
    this.aiProgressMessages = const [
      'Analyzing nutritional targets...',
      'Distributing meal timing and macros...',
      'Balancing weekly variety...',
    ],
  });

  EatingSetupState copyWith({
    EatingSetupStage? stage,
    List<TimelineBlockDraft>? workingBlocks,
    String? workingGoal,
    bool clearWorkingGoal = false,
    int? workingMealsPerDay,
    bool clearWorkingMealsPerDay = false,
    String? workingEatingMode,
    bool clearWorkingEatingMode = false,
    String? workingFoodType,
    bool clearWorkingFoodType = false,
    String? workingFoodStyleCustomText,
    bool clearWorkingFoodStyleCustomText = false,
    List<String>? workingFoodsToAvoid,
    int? workingBreakfastMinute,
    bool clearWorkingBreakfastMinute = false,
    int? workingLunchMinute,
    bool clearWorkingLunchMinute = false,
    int? workingDinnerMinute,
    bool clearWorkingDinnerMinute = false,
    int? workingSnackMinute,
    bool clearWorkingSnackMinute = false,
    int? workingExtraSnackMinute,
    bool clearWorkingExtraSnackMinute = false,
    int? workingTargetCalories,
    bool clearWorkingTargetCalories = false,
    int? workingTargetProtein,
    bool clearWorkingTargetProtein = false,
    int? workingTargetCaloriesOverride,
    bool clearWorkingTargetCaloriesOverride = false,
    int? workingTargetProteinOverride,
    bool clearWorkingTargetProteinOverride = false,
    String? workingAssetId,
    bool clearWorkingAssetId = false,
    String? workingR2Key,
    bool clearWorkingR2Key = false,
    String? workingSetupPath,
    bool clearWorkingSetupPath = false,
    int? workingGeneratedPlanVersion,
    bool clearWorkingGeneratedPlanVersion = false,
    String? workingGeneratedInputFingerprint,
    bool clearWorkingGeneratedInputFingerprint = false,
    bool? workingCustomized,
    String? candidateAssetId,
    bool clearCandidateAssetId = false,
    String? candidateR2Key,
    bool clearCandidateR2Key = false,
    int? selectedDay,
    bool? isDirty,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? frontBlockId,
    bool clearFrontBlockId = false,
    int? sessionGeneration,
    bool? hasRunStartupCleanup,
    String? ownerUid,
    int? editorBaseRevision,
    bool clearEditorBaseRevision = false,
    String? baseCommittedAssetId,
    bool clearBaseCommittedAssetId = false,
    String? baseCommittedR2Key,
    bool clearBaseCommittedR2Key = false,
    bool? routineRefreshPending,
    int? committedRevision,
    bool clearCommittedRevision = false,
    String? routineRefreshMessage,
    bool clearRoutineRefreshMessage = false,
    bool? isConcurrencyConflict,
    String? aiActionTitle,
    List<String>? aiProgressMessages,
  }) {
    return EatingSetupState(
      stage: stage ?? this.stage,
      workingBlocks: workingBlocks ?? this.workingBlocks,
      workingGoal: clearWorkingGoal ? null : (workingGoal ?? this.workingGoal),
      workingMealsPerDay: clearWorkingMealsPerDay
          ? null
          : (workingMealsPerDay ?? this.workingMealsPerDay),
      workingEatingMode: clearWorkingEatingMode
          ? null
          : (workingEatingMode ?? this.workingEatingMode),
      workingFoodType: clearWorkingFoodType
          ? null
          : (workingFoodType ?? this.workingFoodType),
      workingFoodStyleCustomText: clearWorkingFoodStyleCustomText
          ? null
          : (workingFoodStyleCustomText ?? this.workingFoodStyleCustomText),
      workingFoodsToAvoid: workingFoodsToAvoid ?? this.workingFoodsToAvoid,
      workingBreakfastMinute: clearWorkingBreakfastMinute
          ? null
          : (workingBreakfastMinute ?? this.workingBreakfastMinute),
      workingLunchMinute: clearWorkingLunchMinute
          ? null
          : (workingLunchMinute ?? this.workingLunchMinute),
      workingDinnerMinute: clearWorkingDinnerMinute
          ? null
          : (workingDinnerMinute ?? this.workingDinnerMinute),
      workingSnackMinute: clearWorkingSnackMinute
          ? null
          : (workingSnackMinute ?? this.workingSnackMinute),
      workingExtraSnackMinute: clearWorkingExtraSnackMinute
          ? null
          : (workingExtraSnackMinute ?? this.workingExtraSnackMinute),
      workingTargetCalories: clearWorkingTargetCalories
          ? null
          : (workingTargetCalories ?? this.workingTargetCalories),
      workingTargetProtein: clearWorkingTargetProtein
          ? null
          : (workingTargetProtein ?? this.workingTargetProtein),
      workingTargetCaloriesOverride: clearWorkingTargetCaloriesOverride
          ? null
          : (workingTargetCaloriesOverride ??
                this.workingTargetCaloriesOverride),
      workingTargetProteinOverride: clearWorkingTargetProteinOverride
          ? null
          : (workingTargetProteinOverride ?? this.workingTargetProteinOverride),
      workingAssetId: clearWorkingAssetId
          ? null
          : (workingAssetId ?? this.workingAssetId),
      workingR2Key: clearWorkingR2Key
          ? null
          : (workingR2Key ?? this.workingR2Key),
      workingSetupPath: clearWorkingSetupPath
          ? null
          : (workingSetupPath ?? this.workingSetupPath),
      workingGeneratedPlanVersion: clearWorkingGeneratedPlanVersion
          ? null
          : (workingGeneratedPlanVersion ?? this.workingGeneratedPlanVersion),
      workingGeneratedInputFingerprint: clearWorkingGeneratedInputFingerprint
          ? null
          : (workingGeneratedInputFingerprint ??
                this.workingGeneratedInputFingerprint),
      workingCustomized: workingCustomized ?? this.workingCustomized,
      candidateAssetId: clearCandidateAssetId
          ? null
          : (candidateAssetId ?? this.candidateAssetId),
      candidateR2Key: clearCandidateR2Key
          ? null
          : (candidateR2Key ?? this.candidateR2Key),
      selectedDay: selectedDay ?? this.selectedDay,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      frontBlockId: clearFrontBlockId
          ? null
          : (frontBlockId ?? this.frontBlockId),
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      hasRunStartupCleanup: hasRunStartupCleanup ?? this.hasRunStartupCleanup,
      ownerUid: ownerUid ?? this.ownerUid,
      editorBaseRevision: clearEditorBaseRevision
          ? null
          : (editorBaseRevision ?? this.editorBaseRevision),
      baseCommittedAssetId: clearBaseCommittedAssetId
          ? null
          : (baseCommittedAssetId ?? this.baseCommittedAssetId),
      baseCommittedR2Key: clearBaseCommittedR2Key
          ? null
          : (baseCommittedR2Key ?? this.baseCommittedR2Key),
      routineRefreshPending:
          routineRefreshPending ?? this.routineRefreshPending,
      committedRevision: clearCommittedRevision
          ? null
          : (committedRevision ?? this.committedRevision),
      routineRefreshMessage: clearRoutineRefreshMessage
          ? null
          : (routineRefreshMessage ?? this.routineRefreshMessage),
      isConcurrencyConflict:
          isConcurrencyConflict ?? this.isConcurrencyConflict,
      aiActionTitle: aiActionTitle ?? this.aiActionTitle,
      aiProgressMessages: aiProgressMessages ?? this.aiProgressMessages,
    );
  }
}

/// StateNotifier controller managing Eating Base Timeline draft and mutations.
class EatingSetupController extends StateNotifier<EatingSetupState> {
  final Ref ref;
  http.Client? _activeHttpClient;
  EatingOperationSession? _currentOperation;

  EatingSetupController(this.ref) : super(const EatingSetupState());

  @override
  void dispose() {
    _activeHttpClient?.close();
    _activeHttpClient = null;
    super.dispose();
  }

  void performStartupCleanup(BaseTimelineSetup setup, {required String uid}) {
    if (state.hasRunStartupCleanup && state.ownerUid == uid) return;
    state = state.copyWith(
      hasRunStartupCleanup: true,
      ownerUid: uid,
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.eatingPhotoAssetId,
      baseCommittedR2Key: setup.eatingPhotoR2Key,
    );
  }

  void initDayIfNeeded(BaseTimelineSetup setup) {
    if (state.isDirty || state.stage == EatingSetupStage.review) return;
    final activeDays = setup.eatingBlocks
        .expand((b) => b.repeatDays)
        .where((d) => d >= 1 && d <= 7)
        .toSet();
    if (activeDays.isEmpty) return;
    final today = DateTime.now().weekday;
    final initialDay = activeDays.contains(today)
        ? today
        : (activeDays.toList()..sort()).first;
    state = state.copyWith(selectedDay: initialDay);
  }

  void selectDay(int day) {
    state = state.copyWith(selectedDay: day);
  }

  void setFrontBlockId(String? id) {
    state = state.copyWith(frontBlockId: id);
  }

  void clearError() {
    state = state.copyWith(
      clearErrorMessage: true,
      isConcurrencyConflict: false,
    );
  }

  void startChooseSource() {
    state = state.copyWith(
      stage: EatingSetupStage.chooseSource,
      clearErrorMessage: true,
    );
  }

  void cancelChooseSource() {
    state = state.copyWith(
      stage: EatingSetupStage.currentSetup,
      clearErrorMessage: true,
    );
  }

  void startManualSetup(BaseTimelineSetup setup) {
    _initWorkingStateFromSetup(setup);
    final manualState = EatingSourceTransitionPolicy.toManual(blocks: const []);
    _applyEatingDraftState(manualState, markDirty: false);
    state = state.copyWith(stage: EatingSetupStage.review);
  }

  void editCurrentMealPlan(BaseTimelineSetup setup) {
    _initWorkingStateFromSetup(setup);
    state = state.copyWith(
      stage: EatingSetupStage.review,
      isDirty: false,
      clearErrorMessage: true,
    );
  }

  void _initWorkingStateFromSetup(BaseTimelineSetup setup) {
    state = state.copyWith(
      workingBlocks: List.from(setup.eatingBlocks),
      workingGoal: setup.mealPlanningGoal,
      clearWorkingGoal: setup.mealPlanningGoal == null,
      workingMealsPerDay: setup.mealsPerDay,
      clearWorkingMealsPerDay: setup.mealsPerDay == null,
      workingEatingMode: setup.eatingMode,
      clearWorkingEatingMode: setup.eatingMode == null,
      workingFoodType: setup.foodType,
      clearWorkingFoodType: setup.foodType == null,
      workingFoodStyleCustomText: setup.foodStyleCustomText,
      clearWorkingFoodStyleCustomText: setup.foodStyleCustomText == null,
      workingFoodsToAvoid: List<String>.from(setup.foodsToAvoid),
      workingBreakfastMinute: setup.breakfastMinute,
      clearWorkingBreakfastMinute: setup.breakfastMinute == null,
      workingLunchMinute: setup.lunchMinute,
      clearWorkingLunchMinute: setup.lunchMinute == null,
      workingDinnerMinute: setup.dinnerMinute,
      clearWorkingDinnerMinute: setup.dinnerMinute == null,
      workingSnackMinute: setup.snackMinute,
      clearWorkingSnackMinute: setup.snackMinute == null,
      workingExtraSnackMinute: setup.extraSnackMinute,
      clearWorkingExtraSnackMinute: setup.extraSnackMinute == null,
      workingTargetCalories: setup.targetCalories,
      clearWorkingTargetCalories: setup.targetCalories == null,
      workingTargetProtein: setup.targetProtein,
      clearWorkingTargetProtein: setup.targetProtein == null,
      workingTargetCaloriesOverride: setup.targetCaloriesOverride,
      clearWorkingTargetCaloriesOverride: setup.targetCaloriesOverride == null,
      workingTargetProteinOverride: setup.targetProteinOverride,
      clearWorkingTargetProteinOverride: setup.targetProteinOverride == null,
      workingSetupPath: setup.eatingSetupPath,
      clearWorkingSetupPath: setup.eatingSetupPath == null,
      workingGeneratedPlanVersion: setup.eatingGeneratedPlanVersion,
      clearWorkingGeneratedPlanVersion:
          setup.eatingGeneratedPlanVersion == null,
      workingGeneratedInputFingerprint: setup.eatingGeneratedInputFingerprint,
      clearWorkingGeneratedInputFingerprint:
          setup.eatingGeneratedInputFingerprint == null,
      workingCustomized: setup.eatingCustomized,
      workingAssetId: setup.eatingPhotoAssetId,
      clearWorkingAssetId: setup.eatingPhotoAssetId == null,
      workingR2Key: setup.eatingPhotoR2Key,
      clearWorkingR2Key: setup.eatingPhotoR2Key == null,
      baseCommittedAssetId: setup.eatingPhotoAssetId,
      clearBaseCommittedAssetId: setup.eatingPhotoAssetId == null,
      baseCommittedR2Key: setup.eatingPhotoR2Key,
      clearBaseCommittedR2Key: setup.eatingPhotoR2Key == null,
      editorBaseRevision: setup.revision,
      ownerUid: setup.uid,
      isDirty: false,
    );
  }

  void _applyEatingDraftState(
    EatingDraftState draftState, {
    bool markDirty = true,
  }) {
    state = state.copyWith(
      workingBlocks: List.from(draftState.blocks),
      workingSetupPath: draftState.setupPath,
      clearWorkingSetupPath: draftState.setupPath == null,
      workingAssetId: draftState.photoAssetId,
      clearWorkingAssetId: draftState.photoAssetId == null,
      workingR2Key: draftState.photoR2Key,
      clearWorkingR2Key: draftState.photoR2Key == null,
      workingGeneratedPlanVersion: draftState.planVersion,
      clearWorkingGeneratedPlanVersion: draftState.planVersion == null,
      workingGeneratedInputFingerprint: draftState.inputFingerprint,
      clearWorkingGeneratedInputFingerprint:
          draftState.inputFingerprint == null,
      workingCustomized: draftState.customized,
      workingGoal: draftState.goal,
      clearWorkingGoal: draftState.goal == null,
      workingMealsPerDay: draftState.mealsPerDay,
      clearWorkingMealsPerDay: draftState.mealsPerDay == null,
      workingEatingMode: draftState.eatingMode,
      clearWorkingEatingMode: draftState.eatingMode == null,
      workingFoodType: draftState.foodType,
      clearWorkingFoodType: draftState.foodType == null,
      workingFoodStyleCustomText: draftState.foodStyleCustomText,
      clearWorkingFoodStyleCustomText: draftState.foodStyleCustomText == null,
      workingFoodsToAvoid: List.from(draftState.foodsToAvoid),
      workingBreakfastMinute: draftState.breakfastMinute,
      clearWorkingBreakfastMinute: draftState.breakfastMinute == null,
      workingLunchMinute: draftState.lunchMinute,
      clearWorkingLunchMinute: draftState.lunchMinute == null,
      workingDinnerMinute: draftState.dinnerMinute,
      clearWorkingDinnerMinute: draftState.dinnerMinute == null,
      workingSnackMinute: draftState.snackMinute,
      clearWorkingSnackMinute: draftState.snackMinute == null,
      workingExtraSnackMinute: draftState.extraSnackMinute,
      clearWorkingExtraSnackMinute: draftState.extraSnackMinute == null,
      workingTargetCalories: draftState.targetCalories,
      clearWorkingTargetCalories: draftState.targetCalories == null,
      workingTargetProtein: draftState.targetProtein,
      clearWorkingTargetProtein: draftState.targetProtein == null,
      workingTargetCaloriesOverride: draftState.targetCaloriesOverride,
      clearWorkingTargetCaloriesOverride:
          draftState.targetCaloriesOverride == null,
      workingTargetProteinOverride: draftState.targetProteinOverride,
      clearWorkingTargetProteinOverride:
          draftState.targetProteinOverride == null,
      stage: EatingSetupStage.review,
      isDirty: markDirty ? true : state.isDirty,
      clearErrorMessage: true,
    );
  }

  void updateSettingsParameters({
    required String? goal,
    required int? mealsPerDay,
    required String? eatingMode,
    required String? foodType,
    required String? foodStyleCustomText,
    required List<String> foodsToAvoid,
    required int? breakfastMinute,
    required int? lunchMinute,
    required int? dinnerMinute,
    required int? snackMinute,
    required int? extraSnackMinute,
    required int? targetCalories,
    required int? targetProtein,
    required int? targetCaloriesOverride,
    required int? targetProteinOverride,
  }) {
    _applyUserMutation((s) {
      return s.copyWith(
        workingGoal: goal,
        clearWorkingGoal: goal == null,
        workingMealsPerDay: mealsPerDay,
        clearWorkingMealsPerDay: mealsPerDay == null,
        workingEatingMode: eatingMode,
        clearWorkingEatingMode: eatingMode == null,
        workingFoodType: foodType,
        clearWorkingFoodType: foodType == null,
        workingFoodStyleCustomText: foodStyleCustomText,
        clearWorkingFoodStyleCustomText: foodStyleCustomText == null,
        workingFoodsToAvoid: List.from(foodsToAvoid),
        workingBreakfastMinute: breakfastMinute,
        clearWorkingBreakfastMinute: breakfastMinute == null,
        workingLunchMinute: lunchMinute,
        clearWorkingLunchMinute: lunchMinute == null,
        workingDinnerMinute: dinnerMinute,
        clearWorkingDinnerMinute: dinnerMinute == null,
        workingSnackMinute: snackMinute,
        clearWorkingSnackMinute: snackMinute == null,
        workingExtraSnackMinute: extraSnackMinute,
        clearWorkingExtraSnackMinute: extraSnackMinute == null,
        workingTargetCalories: targetCalories,
        clearWorkingTargetCalories: targetCalories == null,
        workingTargetProtein: targetProtein,
        clearWorkingTargetProtein: targetProtein == null,
        workingTargetCaloriesOverride: targetCaloriesOverride,
        clearWorkingTargetCaloriesOverride: targetCaloriesOverride == null,
        workingTargetProteinOverride: targetProteinOverride,
        clearWorkingTargetProteinOverride: targetProteinOverride == null,
        stage: EatingSetupStage.review,
      );
    });
  }

  Future<List<TimelineBlockDraft>?> pickAndUploadPhoto({
    required String uid,
    required ImageSource source,
  }) async {
    if (uid.trim().isEmpty) return null;
    final generation = state.sessionGeneration + 1;
    final lifecycleHelper = ref.read(baseTimelineUploadLifecycleHelperProvider);
    final uploadNotifier = ref.read(uploadControllerProvider.notifier);

    state = state.copyWith(
      stage: EatingSetupStage.uploading,
      sessionGeneration: generation,
      clearErrorMessage: true,
      aiActionTitle: 'Analyzing meal plan photo...',
      aiProgressMessages: const [
        'Uploading high-resolution image...',
        'Extracting meals and schedule timings...',
        'Formatting timeline entries...',
      ],
    );

    String? candidateAssetId;
    String? candidateR2Key;

    _currentOperation = EatingOperationSession(
      generationId: generation,
      ownerUid: uid,
      type: EatingOperationType.uploading,
    );

    try {
      final asset = await uploadNotifier.startUpload(
        uid: uid,
        sourceFeature: 'routine_base_timeline',
        purpose: UploadedAssetPurpose.eatingMenu,
        source: source,
      );

      if (asset == null) {
        if (_currentOperation?.generationId == generation) {
          _currentOperation = null;
        }
        state = state.copyWith(
          stage: state.workingBlocks.isNotEmpty
              ? EatingSetupStage.review
              : EatingSetupStage.chooseSource,
        );
        return null;
      }

      if (state.sessionGeneration != generation) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: asset.assetId,
            objectKey: asset.r2Key,
          );
        } catch (_) {}
        return null;
      }

      candidateAssetId = asset.assetId;
      candidateR2Key = asset.r2Key;
      _currentOperation = EatingOperationSession(
        generationId: generation,
        ownerUid: uid,
        type: EatingOperationType.extracting,
        candidateAssetId: candidateAssetId,
        candidateR2Key: candidateR2Key,
      );

      state = state.copyWith(
        stage: EatingSetupStage.extracting,
        candidateAssetId: candidateAssetId,
        candidateR2Key: candidateR2Key,
      );

      final reviewDraft = RoutineImportReviewDraft(
        id: 'rev_${asset.assetId}',
        uid: uid,
        source: RoutineImportReviewSource.eating,
        status: RoutineImportReviewStatus.draft,
        sourceLabel: 'Eating',
        uploadedAssetId: asset.assetId,
        uploadedAssetR2Key: asset.r2Key,
        uploadedAssetStatus: 'uploaded',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final result = await aiController.runExtraction(reviewDraft);

      if (generation != state.sessionGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
        return null;
      }

      final candidateBlocks = (result?.candidates ?? []).map((c) {
        final blockId = c.id.trim().isNotEmpty
            ? c.id.trim()
            : 'meal_${DateTime.now().millisecondsSinceEpoch}_${c.startMinute}';
        return TimelineBlockDraft(
          id: blockId,
          title: c.title,
          startMinute: c.startMinute,
          endMinute: c.endMinute,
          repeatDays: c.repeatDays,
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: c.mealCategory,
          mealSlot: c.mealSlot,
          dishes: EatingCandidateDishNormalizer.extractDishes(c),
          calories: c.caloriesEstimate,
          protein: c.proteinEstimate,
          location: c.location,
          notes: c.notes,
          source: c.extractionEngine,
          provenanceSourceIds: [
            ?candidateAssetId,
            if (c.sourceAssetId != null &&
                c.sourceAssetId!.trim().isNotEmpty &&
                c.sourceAssetId != candidateAssetId)
              c.sourceAssetId!,
          ],
        );
      }).toList();

      if (candidateBlocks.isEmpty) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
        final err =
            result?.warnings.firstOrNull ??
            'No meals detected in photo. Your existing eating schedule was preserved.';
        state = state.copyWith(
          stage: state.workingBlocks.isNotEmpty
              ? EatingSetupStage.review
              : EatingSetupStage.chooseSource,
          errorMessage: err,
          clearCandidateAssetId: true,
          clearCandidateR2Key: true,
        );
        return null;
      }

      return candidateBlocks;
    } catch (e) {
      if (candidateAssetId != null) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: candidateAssetId,
            objectKey: candidateR2Key,
          );
        } catch (_) {}
      }
      final errText = EatingSetupErrorMapper.mapError(e);
      state = state.copyWith(
        stage: state.workingBlocks.isNotEmpty
            ? EatingSetupStage.review
            : EatingSetupStage.chooseSource,
        errorMessage: errText,
        clearCandidateAssetId: true,
        clearCandidateR2Key: true,
      );
      return null;
    } finally {
      if (_currentOperation?.generationId == generation) {
        _currentOperation = null;
      }
    }
  }

  Future<void> applyReviewedCandidates({
    required String uid,
    required List<TimelineBlockDraft>? reviewed,
    required String? candidateAssetId,
    required String? candidateR2Key,
  }) async {
    final lifecycleHelper = ref.read(baseTimelineUploadLifecycleHelperProvider);
    if (reviewed != null &&
        reviewed.isNotEmpty &&
        candidateAssetId != null &&
        candidateR2Key != null) {
      if (state.workingAssetId != null &&
          state.workingAssetId != state.baseCommittedAssetId) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: state.workingAssetId!,
            objectKey: state.workingR2Key,
          );
        } catch (_) {}
      }

      final transition = EatingSourceTransitionPolicy.toPhoto(
        blocks: reviewed,
        photoAssetId: candidateAssetId,
        photoR2Key: candidateR2Key,
      );

      _applyEatingDraftState(transition, markDirty: true);
      state = state.copyWith(
        clearCandidateAssetId: true,
        clearCandidateR2Key: true,
        stage: EatingSetupStage.review,
      );
    } else {
      if (candidateAssetId != null) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
      }
      state = state.copyWith(
        clearCandidateAssetId: true,
        clearCandidateR2Key: true,
        stage: state.workingBlocks.isNotEmpty
            ? EatingSetupStage.review
            : EatingSetupStage.chooseSource,
      );
    }
  }

  Future<bool> generateBalancedPlan({
    required String uid,
    required BaseTimelineSetup currentSetup,
  }) async {
    if (uid.trim().isEmpty) return false;
    final generation = state.sessionGeneration + 1;

    _activeHttpClient?.close();
    final client = http.Client();
    _activeHttpClient = client;

    final idToken =
        await ref.read(authRepositoryProvider).currentIdToken() ?? '';
    final engine = ref.read(eatingDomainEngineProvider);
    final profile = ref.read(userProfileProvider);

    final workingSetup = currentSetup.copyWith(
      mealPlanningGoal: state.workingGoal,
      mealsPerDay: state.workingMealsPerDay,
      eatingMode: state.workingEatingMode,
      foodType: state.workingFoodType,
      foodStyleCustomText: state.workingFoodStyleCustomText,
      foodsToAvoid: state.workingFoodsToAvoid,
      breakfastMinute: state.workingBreakfastMinute,
      lunchMinute: state.workingLunchMinute,
      dinnerMinute: state.workingDinnerMinute,
      snackMinute: state.workingSnackMinute,
      extraSnackMinute: state.workingExtraSnackMinute,
      targetCalories: state.workingTargetCalories,
      targetProtein: state.workingTargetProtein,
      targetCaloriesOverride: state.workingTargetCaloriesOverride,
      targetProteinOverride: state.workingTargetProteinOverride,
    );

    state = state.copyWith(
      stage: EatingSetupStage.generating,
      sessionGeneration: generation,
      clearErrorMessage: true,
      aiActionTitle: 'Generating balanced meal plan...',
      aiProgressMessages: const [
        'Calculating canonical macro targets...',
        'Structuring breakfast, lunch, and dinner slots...',
        'Ensuring daily and weekly meal diversity...',
      ],
    );

    _currentOperation = EatingOperationSession(
      generationId: generation,
      ownerUid: uid,
      type: EatingOperationType.generating,
    );

    try {
      final targets = engine.calculateTargets(
        profile: profile,
        setup: workingSetup,
      );
      final region = ref.read(regionSettingsProvider);
      final country = region.countryCode.isNotEmpty ? region.countryCode : null;
      final inputs = engine.buildInputs(
        profile: profile,
        setup: workingSetup,
        targets: targets,
        country: country,
      );

      final blocks = await engine.generateEatingRoutine(
        uid: uid,
        idToken: idToken,
        inputs: inputs,
        targets: targets,
        baseTimeline: workingSetup.toBaseTimelineDraft(),
        client: client,
      );

      if (generation != state.sessionGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        return false;
      }

      if (state.workingAssetId != null &&
          state.workingAssetId != state.baseCommittedAssetId) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: state.workingAssetId,
            objectKey: state.workingR2Key,
          );
        } catch (_) {}
      }

      final transition = EatingSourceTransitionPolicy.toGenerated(
        blocks: blocks,
        goal: state.workingGoal,
        mealsPerDay: state.workingMealsPerDay,
        eatingMode: state.workingEatingMode,
        foodType: state.workingFoodType,
        foodStyleCustomText: state.workingFoodStyleCustomText,
        foodsToAvoid: state.workingFoodsToAvoid,
        breakfastMinute: state.workingBreakfastMinute,
        lunchMinute: state.workingLunchMinute,
        dinnerMinute: state.workingDinnerMinute,
        snackMinute: state.workingSnackMinute,
        extraSnackMinute: state.workingExtraSnackMinute,
        targetCalories: targets.targetCalories,
        targetProtein: targets.proteinTarget?.round(),
        targetCaloriesOverride: state.workingTargetCaloriesOverride,
        targetProteinOverride: state.workingTargetProteinOverride,
        planVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
        inputFingerprint: inputs.computeFingerprint(),
        customized: false,
      );

      _applyEatingDraftState(transition, markDirty: true);
      return true;
    } catch (e) {
      final errText = EatingSetupErrorMapper.mapError(e);
      if (currentSetup.eatingBlocks.isNotEmpty) {
        _initWorkingStateFromSetup(currentSetup);
        state = state.copyWith(
          stage: EatingSetupStage.currentSetup,
          errorMessage:
              "Couldn't create the new plan. Your current plan is unchanged. $errText",
          isDirty: false,
        );
      } else {
        state = state.copyWith(
          stage: EatingSetupStage.error,
          errorMessage: errText,
        );
      }
      return false;
    } finally {
      if (_activeHttpClient == client) {
        _activeHttpClient = null;
      }
      if (_currentOperation?.generationId == generation) {
        _currentOperation = null;
      }
    }
  }

  void _applyUserMutation(
    EatingSetupState Function(EatingSetupState) mutation,
  ) {
    var newState = mutation(state);
    final isGenerated =
        newState.workingSetupPath == 'create' ||
        newState.workingGeneratedPlanVersion != null ||
        newState.workingGeneratedInputFingerprint != null;
    if (isGenerated) {
      newState = newState.copyWith(workingCustomized: true);
    }
    state = newState.copyWith(
      isDirty: true,
      workingSetupPath: newState.workingSetupPath ?? 'manual',
    );
  }

  void addBlock(TimelineBlockDraft block) {
    _applyUserMutation((s) {
      final updated = List<TimelineBlockDraft>.from(s.workingBlocks)
        ..add(block);
      return s.copyWith(workingBlocks: updated, stage: EatingSetupStage.review);
    });
  }

  void updateBlock(TimelineBlockDraft block) {
    _applyUserMutation((s) {
      final updated = List<TimelineBlockDraft>.from(s.workingBlocks);
      final idx = updated.indexWhere((b) => b.id == block.id);
      if (idx != -1) {
        updated[idx] = block;
      }
      return s.copyWith(workingBlocks: updated, stage: EatingSetupStage.review);
    });
  }

  void deleteBlock(String id) {
    _applyUserMutation((s) {
      final updated = List<TimelineBlockDraft>.from(s.workingBlocks)
        ..removeWhere((b) => b.id == id);
      return s.copyWith(
        workingBlocks: updated,
        frontBlockId: s.frontBlockId == id ? null : s.frontBlockId,
        clearFrontBlockId: s.frontBlockId == id,
        stage: EatingSetupStage.review,
      );
    });
  }

  Future<bool> saveWorkingSetup({
    required String uid,
    required BaseTimelineSetup currentSetup,
  }) async {
    if (state.isSaving) return false;
    if (uid.trim().isEmpty ||
        (state.ownerUid.isNotEmpty && uid != state.ownerUid)) {
      state = state.copyWith(
        errorMessage: 'The active account changed. Reload Eating setup.',
      );
      return false;
    }

    if (state.workingBlocks.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Cannot save an empty eating schedule. Add meals or build a plan.',
      );
      return false;
    }

    final validationSetup = currentSetup.copyWith(
      eatingBlocks: state.workingBlocks,
      eatingSetupPath: state.workingSetupPath,
      mealPlanningGoal: state.workingGoal,
      mealsPerDay: state.workingMealsPerDay,
      eatingMode: state.workingEatingMode,
      foodType: state.workingFoodType,
      foodStyleCustomText: state.workingFoodStyleCustomText,
      foodsToAvoid: state.workingFoodsToAvoid,
      breakfastMinute: state.workingBreakfastMinute,
      lunchMinute: state.workingLunchMinute,
      dinnerMinute: state.workingDinnerMinute,
      snackMinute: state.workingSnackMinute,
      extraSnackMinute: state.workingExtraSnackMinute,
      targetCalories: state.workingTargetCalories,
      targetProtein: state.workingTargetProtein,
      targetCaloriesOverride: state.workingTargetCaloriesOverride,
      targetProteinOverride: state.workingTargetProteinOverride,
      eatingGeneratedPlanVersion: state.workingGeneratedPlanVersion,
      eatingGeneratedInputFingerprint: state.workingGeneratedInputFingerprint,
      eatingCustomized: state.workingCustomized,
      eatingPhotoAssetId: state.workingAssetId,
      eatingPhotoR2Key: state.workingR2Key,
    );

    final engine = ref.read(eatingDomainEngineProvider);
    NutritionTargets? targets;
    if (state.workingSetupPath == 'create') {
      try {
        final profile = ref.read(userProfileProvider);
        targets = engine.calculateTargets(
          profile: profile,
          setup: validationSetup,
        );
      } catch (_) {}
    }

    final validationErr = engine.validateBeforeSave(
      blocks: state.workingBlocks,
      setup: validationSetup,
      targets: targets,
    );
    if (validationErr != null) {
      state = state.copyWith(errorMessage: validationErr);
      return false;
    }

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.eating,
        newBlocks: state.workingBlocks,
        expectedRevision: state.editorBaseRevision,
        updateSetup: (current) {
          if (state.workingSetupPath == 'has_routine' ||
              state.workingSetupPath == 'photo') {
            assert(
              state.workingAssetId != null && state.workingR2Key != null,
              'Eating photo setup requires valid assetId and r2Key',
            );
            return current.asEatingPhoto(
              photoAssetId: state.workingAssetId!,
              photoR2Key: state.workingR2Key!,
              blocks: state.workingBlocks,
              meals: state.workingMealsPerDay,
            );
          } else if (state.workingSetupPath == 'manual') {
            return current.asEatingManual(
              blocks: state.workingBlocks,
              meals: state.workingMealsPerDay,
              targetCalories: state.workingTargetCalories,
              targetProtein: state.workingTargetProtein,
              targetCaloriesOverride: state.workingTargetCaloriesOverride,
              targetProteinOverride: state.workingTargetProteinOverride,
            );
          } else if (state.workingSetupPath == 'create') {
            return current.replaceEatingGeneratedConfiguration(
              blocks: state.workingBlocks,
              goal: state.workingGoal,
              meals: state.workingMealsPerDay,
              mode: state.workingEatingMode,
              type: state.workingFoodType,
              styleCustomText: state.workingFoodStyleCustomText,
              foodsToAvoid: state.workingFoodsToAvoid,
              breakfast: state.workingBreakfastMinute,
              lunch: state.workingLunchMinute,
              dinner: state.workingDinnerMinute,
              snack: state.workingSnackMinute,
              extraSnack: state.workingExtraSnackMinute,
              calories: state.workingTargetCalories,
              protein: state.workingTargetProtein,
              caloriesOverride: state.workingTargetCaloriesOverride,
              proteinOverride: state.workingTargetProteinOverride,
              planVersion: state.workingGeneratedPlanVersion,
              inputFingerprint: state.workingGeneratedInputFingerprint,
              customized: state.workingCustomized,
            );
          } else {
            throw StateError(
              'Cannot save eating setup with unknown path: ${state.workingSetupPath}',
            );
          }
        },
      );

      if (state.baseCommittedAssetId != null &&
          state.baseCommittedAssetId != state.workingAssetId) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: state.baseCommittedAssetId!,
            oldObjectKey: state.baseCommittedR2Key,
          );
        } catch (_) {}
      }

      state = state.copyWith(
        isSaving: false,
        stage: EatingSetupStage.saveSuccess,
        isDirty: false,
        editorBaseRevision: result.revision,
        baseCommittedAssetId: state.workingAssetId,
        baseCommittedR2Key: state.workingR2Key,
        routineRefreshPending: result.routineRefreshPending,
        committedRevision: result.routineRefreshPending
            ? result.revision
            : null,
        routineRefreshMessage: result.routineRefreshMessage,
      );
      return true;
    } catch (e) {
      final errorText = EatingSetupErrorMapper.mapSaveError(e);
      state = state.copyWith(
        isSaving: false,
        errorMessage: errorText,
        isConcurrencyConflict: e is BaseTimelineConcurrencyException,
      );
      return false;
    }
  }

  Future<bool> removeSetup({
    required String uid,
    required BaseTimelineSetup currentSetup,
  }) async {
    final targetUid = state.ownerUid.isNotEmpty
        ? state.ownerUid
        : currentSetup.uid;
    if (uid.trim().isEmpty || uid != targetUid) {
      state = state.copyWith(
        errorMessage: 'The active account changed. Reload Eating setup.',
      );
      return false;
    }

    try {
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.eating,
        newBlocks: const [],
        expectedRevision: currentSetup.revision,
        updateSetup: (current) => current.asEatingReset(),
      );

      if (currentSetup.eatingPhotoAssetId != null) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: currentSetup.eatingPhotoAssetId!,
            oldObjectKey: currentSetup.eatingPhotoR2Key,
          );
        } catch (_) {}
      }

      state = state.copyWith(
        stage: EatingSetupStage.currentSetup,
        isDirty: false,
        workingBlocks: const [],
        routineRefreshPending: result.routineRefreshPending,
        committedRevision: result.routineRefreshPending
            ? result.revision
            : null,
        routineRefreshMessage: result.routineRefreshMessage,
      );
      return true;
    } catch (e) {
      final msg = EatingSetupErrorMapper.mapError(e);
      state = state.copyWith(errorMessage: msg);
      return false;
    }
  }

  Future<void> cancelCurrentOperation(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    final nextGeneration = state.sessionGeneration + 1;
    final op = _currentOperation;
    _currentOperation = null;
    _activeHttpClient?.close();
    _activeHttpClient = null;

    try {
      ref
          .read(routineImportAiControllerProvider.notifier)
          .cancelCurrentExtraction();
    } catch (_) {}

    if (op != null && op.candidateAssetId != null) {
      try {
        final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
        await helper.retireUncommittedUpload(
          uid: op.ownerUid,
          assetId: op.candidateAssetId!,
          objectKey: op.candidateR2Key,
        );
      } catch (_) {}
    }

    state = state.copyWith(
      sessionGeneration: nextGeneration,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      stage: state.workingBlocks.isNotEmpty
          ? EatingSetupStage.review
          : (setup != null && setup.eatingBlocks.isNotEmpty
                ? EatingSetupStage.currentSetup
                : EatingSetupStage.chooseSource),
      clearErrorMessage: true,
    );
  }

  Future<void> resetWorkingDraft(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    if (state.workingAssetId != null &&
        state.workingAssetId != state.baseCommittedAssetId) {
      try {
        final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
        await helper.retireUncommittedUpload(
          uid: uid,
          assetId: state.workingAssetId,
          objectKey: state.workingR2Key,
        );
      } catch (_) {}
    }

    if (setup != null) {
      _initWorkingStateFromSetup(setup);
      state = state.copyWith(
        stage: EatingSetupStage.currentSetup,
        isDirty: false,
        clearErrorMessage: true,
      );
    } else {
      state = state.copyWith(
        stage: EatingSetupStage.chooseSource,
        workingBlocks: const [],
        isDirty: false,
        clearErrorMessage: true,
      );
    }
  }

  void keepPreviousDraft(BaseTimelineSetup? setup, {required String uid}) {
    state = state.copyWith(
      stage: EatingSetupStage.review,
      clearErrorMessage: true,
    );
  }

  void reloadFromCanonical(BaseTimelineSetup setup) {
    _initWorkingStateFromSetup(setup);
    state = state.copyWith(
      stage: EatingSetupStage.currentSetup,
      isDirty: false,
      clearErrorMessage: true,
    );
  }
}

final eatingSetupControllerProvider =
    StateNotifierProvider.autoDispose<EatingSetupController, EatingSetupState>(
      (ref) => EatingSetupController(ref),
    );
