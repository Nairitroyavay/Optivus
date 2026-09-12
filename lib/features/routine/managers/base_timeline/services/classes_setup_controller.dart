import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_setup_error_mapper.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Explicit staged state machine for Classes Base Timeline setup.
enum ClassesSetupStage {
  currentSetup,
  chooseSource,
  uploading,
  extracting,
  review,
  editingBlock,
  saving,
  saveSuccess,
  error,
}

/// Computes the initial weekday tab to display for a list of class blocks.
int computeInitialClassWeekday(
  List<ClassRoutineBlock> blocks, {
  DateTime? now,
}) {
  final currentWeekday = (now ?? DateTime.now()).weekday;
  final activeDays = blocks
      .expand((b) => b.repeatDays)
      .where((d) => d >= 1 && d <= 7)
      .toSet();
  if (activeDays.contains(currentWeekday)) return currentWeekday;
  if (activeDays.isNotEmpty) return (activeDays.toList()..sort()).first;
  return currentWeekday;
}

/// Normalizes the selected weekday after any mutation or save.
///
/// 1. If [currentDay] has scheduled classes, keep it.
/// 2. If today has scheduled classes, switch to today.
/// 3. If any other weekday has scheduled classes, pick the earliest weekday (1-7).
/// 4. Fallback to today (clamped 1-7).
int normalizeSelectedDay({
  required int currentDay,
  required List<ClassRoutineBlock> blocks,
  DateTime? now,
}) {
  final activeDays = blocks
      .expand((b) => b.repeatDays)
      .where((d) => d >= 1 && d <= 7)
      .toSet();
  if (activeDays.isEmpty) {
    final today = (now ?? DateTime.now()).weekday;
    return (today >= 1 && today <= 7) ? today : 1;
  }
  if (activeDays.contains(currentDay)) {
    return currentDay;
  }
  final today = (now ?? DateTime.now()).weekday;
  if (activeDays.contains(today)) {
    return today;
  }
  return (activeDays.toList()..sort()).first;
}

@immutable
class ClassesSetupState {
  final ClassesSetupStage stage;
  final List<ClassRoutineBlock> workingBlocks;
  final String? workingAssetId;
  final String? workingR2Key;
  final String? workingLocalPreviewPath;
  final String? candidateAssetId;
  final String? candidateR2Key;
  final int selectedDay;
  final int droppedCount;
  final List<String> droppedExamples;
  final bool isDirty;
  final bool isSaving;
  final String? errorMessage;
  final String? frontBlockId;
  final int sessionGeneration;
  final bool hasRunStartupCleanup;

  const ClassesSetupState({
    this.stage = ClassesSetupStage.currentSetup,
    this.workingBlocks = const [],
    this.workingAssetId,
    this.workingR2Key,
    this.workingLocalPreviewPath,
    this.candidateAssetId,
    this.candidateR2Key,
    this.selectedDay = 1,
    this.droppedCount = 0,
    this.droppedExamples = const [],
    this.isDirty = false,
    this.isSaving = false,
    this.errorMessage,
    this.frontBlockId,
    this.sessionGeneration = 0,
    this.hasRunStartupCleanup = false,
  });

  ClassesSetupState copyWith({
    ClassesSetupStage? stage,
    List<ClassRoutineBlock>? workingBlocks,
    String? workingAssetId,
    bool clearWorkingAssetId = false,
    String? workingR2Key,
    bool clearWorkingR2Key = false,
    String? workingLocalPreviewPath,
    bool clearWorkingLocalPreviewPath = false,
    String? candidateAssetId,
    bool clearCandidateAssetId = false,
    String? candidateR2Key,
    bool clearCandidateR2Key = false,
    int? selectedDay,
    int? droppedCount,
    List<String>? droppedExamples,
    bool? isDirty,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? frontBlockId,
    bool clearFrontBlockId = false,
    int? sessionGeneration,
    bool? hasRunStartupCleanup,
  }) {
    return ClassesSetupState(
      stage: stage ?? this.stage,
      workingBlocks: workingBlocks ?? this.workingBlocks,
      workingAssetId: clearWorkingAssetId
          ? null
          : (workingAssetId ?? this.workingAssetId),
      workingR2Key: clearWorkingR2Key
          ? null
          : (workingR2Key ?? this.workingR2Key),
      workingLocalPreviewPath: clearWorkingLocalPreviewPath
          ? null
          : (workingLocalPreviewPath ?? this.workingLocalPreviewPath),
      candidateAssetId: clearCandidateAssetId
          ? null
          : (candidateAssetId ?? this.candidateAssetId),
      candidateR2Key: clearCandidateR2Key
          ? null
          : (candidateR2Key ?? this.candidateR2Key),
      selectedDay: selectedDay ?? this.selectedDay,
      droppedCount: droppedCount ?? this.droppedCount,
      droppedExamples: droppedExamples ?? this.droppedExamples,
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
    );
  }
}

class ClassesSetupController extends StateNotifier<ClassesSetupState> {
  final Ref _ref;
  final BaseTimelineTransactionCoordinator _coordinator;
  final BaseTimelineUploadLifecycleHelper _lifecycleHelper;

  ClassesSetupController({
    required Ref ref,
    required BaseTimelineTransactionCoordinator coordinator,
    required BaseTimelineUploadLifecycleHelper lifecycleHelper,
    int? initialSelectedDay,
  }) : _ref = ref,
       _coordinator = coordinator,
       _lifecycleHelper = lifecycleHelper,
       super(
         ClassesSetupState(
           selectedDay:
               initialSelectedDay ?? DateTime.now().weekday.clamp(1, 7),
         ),
       );

  /// Safe startup cleanup. NEVER runs while BaseTimelineSetup is loading (null).
  /// Passes both committedAssetId and committedR2Key.
  Future<void> performStartupCleanup(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    if (setup == null || state.hasRunStartupCleanup) return;
    state = state.copyWith(hasRunStartupCleanup: true);
    await _lifecycleHelper.cleanupStaleUncommittedAssets(
      uid: uid,
      committedAssetId: setup.classLogicalAssetId,
      committedR2Key: setup.classLogicalAssetR2Key,
    );
  }

  /// Initializes the selected weekday tab if not yet calibrated.
  void initDayIfNeeded(BaseTimelineSetup? setup) {
    if (state.stage != ClassesSetupStage.currentSetup) return;
    if (setup != null) {
      final blocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
        setup.classBlocks,
      );
      final normalized = normalizeSelectedDay(
        currentDay: state.selectedDay,
        blocks: blocks,
      );
      if (normalized != state.selectedDay) {
        state = state.copyWith(selectedDay: normalized);
      }
    }
  }

  void selectDay(int day) {
    state = state.copyWith(selectedDay: day);
  }

  void selectFrontBlock(String? blockId) {
    state = state.copyWith(
      frontBlockId: blockId,
      clearFrontBlockId: blockId == null,
    );
  }

  void chooseSource(BaseTimelineSetup setup, {required String uid}) {
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    state = state.copyWith(
      stage: ClassesSetupStage.chooseSource,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
    );
    if (candidateId != null && candidateId != setup.classLogicalAssetId) {
      try {
        _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateId,
          objectKey: candidateKey,
        );
      } catch (_) {}
    }
  }

  void cancelChooseSource() {
    state = state.copyWith(
      stage: state.workingBlocks.isNotEmpty
          ? ClassesSetupStage.review
          : ClassesSetupStage.currentSetup,
      clearErrorMessage: true,
    );
  }

  void keepPreviousDraft(BaseTimelineSetup setup, {required String uid}) {
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    state = state.copyWith(
      stage: ClassesSetupStage.review,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
    );
    if (candidateId != null && candidateId != setup.classLogicalAssetId) {
      try {
        _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateId,
          objectKey: candidateKey,
        );
      } catch (_) {}
    }
  }

  void startEditingBlock() {
    state = state.copyWith(stage: ClassesSetupStage.editingBlock);
  }

  void stopEditingBlock() {
    if (state.stage == ClassesSetupStage.editingBlock) {
      state = state.copyWith(stage: ClassesSetupStage.review);
    }
  }

  /// Start manual setup: clears photo asset IDs (manual provenance), loads existing blocks if any.
  void startManualSetup(BaseTimelineSetup setup) {
    _retireCandidate();
    final existingBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
      setup.classBlocks,
    );
    final normalizedDay = normalizeSelectedDay(
      currentDay: state.selectedDay,
      blocks: existingBlocks,
    );
    state = state.copyWith(
      stage: ClassesSetupStage.review,
      workingBlocks: existingBlocks,
      clearWorkingAssetId: true,
      clearWorkingR2Key: true,
      clearWorkingLocalPreviewPath: true,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      selectedDay: normalizedDay,
      droppedCount: 0,
      droppedExamples: const [],
      isDirty: false,
      clearErrorMessage: true,
      clearFrontBlockId: true,
    );
  }

  /// Edit current timetable: retains existing photo provenance and blocks.
  void editCurrentTimetable(BaseTimelineSetup setup) {
    _retireCandidate();
    final existingBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
      setup.classBlocks,
    );
    final normalizedDay = normalizeSelectedDay(
      currentDay: state.selectedDay,
      blocks: existingBlocks,
    );
    state = state.copyWith(
      stage: ClassesSetupStage.review,
      workingBlocks: existingBlocks,
      workingAssetId: setup.classLogicalAssetId,
      clearWorkingAssetId: setup.classLogicalAssetId == null,
      workingR2Key: setup.classLogicalAssetR2Key,
      clearWorkingR2Key: setup.classLogicalAssetR2Key == null,
      clearWorkingLocalPreviewPath: true,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      selectedDay: normalizedDay,
      droppedCount: 0,
      droppedExamples: const [],
      isDirty: false,
      clearErrorMessage: true,
      clearFrontBlockId: true,
    );
  }

  Future<void> pickAndUploadPhoto({
    required String uid,
    required ImageSource source,
    required BaseTimelineSetup setup,
  }) async {
    if (uid.trim().isEmpty) return;
    final currentAuthGen = _ref.read(authGenerationProvider);
    final sessionGen = state.sessionGeneration + 1;

    state = state.copyWith(
      stage: ClassesSetupStage.uploading,
      sessionGeneration: sessionGen,
      clearErrorMessage: true,
    );

    UploadedAsset? asset;
    try {
      final uploadNotifier = _ref.read(uploadControllerProvider.notifier);
      asset = await uploadNotifier.startUpload(
        uid: uid,
        purpose: UploadedAssetPurpose.classTimetable,
        sourceFeature: UploadSourceFeature.routineBaseTimeline,
        source: source,
      );
    } catch (uploadError) {
      if (state.sessionGeneration != sessionGen) return;
      state = state.copyWith(
        stage: ClassesSetupStage.error,
        errorMessage: ClassSetupErrorMapper.mapUploadError(uploadError),
      );
      return;
    }

    if (state.sessionGeneration != sessionGen ||
        _ref.read(authGenerationProvider) != currentAuthGen ||
        _ref.read(userProfileProvider).uid != uid) {
      if (asset != null) {
        _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: asset.assetId,
          objectKey: asset.r2Key,
        );
      }
      return;
    }

    if (asset == null) {
      state = state.copyWith(
        stage: state.workingBlocks.isNotEmpty
            ? ClassesSetupStage.review
            : ClassesSetupStage.chooseSource,
      );
      return;
    }

    state = state.copyWith(
      stage: ClassesSetupStage.extracting,
      candidateAssetId: asset.assetId,
      candidateR2Key: asset.r2Key,
      clearErrorMessage: true,
    );

    await _runAiExtraction(
      uid: uid,
      assetId: asset.assetId,
      r2Key: asset.r2Key,
      localPreviewPath: asset.localPreviewPath,
      sessionGen: sessionGen,
      currentAuthGen: currentAuthGen,
      setup: setup,
    );
  }

  Future<void> _runAiExtraction({
    required String uid,
    required String assetId,
    required String r2Key,
    String? localPreviewPath,
    required int sessionGen,
    required int currentAuthGen,
    required BaseTimelineSetup setup,
  }) async {
    final reviewDraft = RoutineImportReviewDraft(
      id: 'rev_$assetId',
      uid: uid,
      source: RoutineImportReviewSource.classes,
      status: RoutineImportReviewStatus.draft,
      sourceLabel: 'Classes',
      uploadedAssetId: assetId,
      uploadedAssetR2Key: r2Key,
      uploadedAssetStatus: 'uploaded',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final aiController = _ref.read(
        routineImportAiControllerProvider.notifier,
      );
      final result = await aiController
          .runExtraction(reviewDraft)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              aiController.cancelCurrentExtraction();
              throw TimeoutException('AI timetable extraction timed out.');
            },
          );

      if (state.sessionGeneration != sessionGen ||
          _ref.read(authGenerationProvider) != currentAuthGen ||
          _ref.read(userProfileProvider).uid != uid ||
          state.candidateAssetId != assetId) {
        _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: assetId,
          objectKey: r2Key,
        );
        return;
      }

      if (result == null) {
        final aiState = _ref.read(routineImportAiControllerProvider);
        if (aiState.lifecycle.phase == AiGenerationPhase.idle &&
            aiState.errorMessage == null) {
          // Operation was intentionally cancelled.
          return;
        }
        final err =
            aiState.errorMessage ??
            aiState.lifecycle.error?.message ??
            'We couldn\'t detect classes in this timetable.';
        state = state.copyWith(
          stage: ClassesSetupStage.error,
          errorMessage: ClassSetupErrorMapper.mapAiExtractionError(err),
        );
        return;
      }

      if (result.candidates.isNotEmpty) {
        final mappingResult = mapOnboarding4Candidates(
          candidates: result.candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        if (mappingResult.blocks.isNotEmpty) {
          // Retire previous working asset if it was uncommitted
          if (state.workingAssetId != null &&
              state.workingAssetId != setup.classLogicalAssetId &&
              state.workingAssetId != assetId) {
            _lifecycleHelper.retireUncommittedUpload(
              uid: uid,
              assetId: state.workingAssetId,
              objectKey: state.workingR2Key,
            );
          }

          final normalizedDay = normalizeSelectedDay(
            currentDay: state.selectedDay,
            blocks: mappingResult.blocks,
          );

          state = state.copyWith(
            stage: ClassesSetupStage.review,
            workingBlocks: mappingResult.blocks,
            workingAssetId: assetId,
            workingR2Key: r2Key,
            workingLocalPreviewPath: localPreviewPath,
            clearCandidateAssetId: true,
            clearCandidateR2Key: true,
            droppedCount: mappingResult.droppedTotal,
            droppedExamples: mappingResult.droppedExamples,
            selectedDay: normalizedDay,
            isDirty: true,
            clearErrorMessage: true,
            clearFrontBlockId: true,
          );
          return;
        }
      }

      state = state.copyWith(
        stage: ClassesSetupStage.error,
        errorMessage: ClassSetupErrorMapper.mapAiExtractionError(
          null,
          warnings: result.warnings,
        ),
      );
    } catch (e) {
      if (e is TimeoutException) {
        try {
          _ref
              .read(routineImportAiControllerProvider.notifier)
              .cancelCurrentExtraction();
        } catch (_) {}
      }
      if (state.sessionGeneration != sessionGen) return;
      if (_ref.read(authGenerationProvider) == currentAuthGen &&
          _ref.read(userProfileProvider).uid == uid) {
        state = state.copyWith(
          stage: ClassesSetupStage.error,
          errorMessage: ClassSetupErrorMapper.mapAiExtractionError(e),
        );
      }
    }
  }

  /// Cancels in-flight extraction or upload immediately and resets state.
  Future<void> cancelCurrentExtraction(
    BaseTimelineSetup setup, {
    required String uid,
  }) async {
    final newSessionGen = state.sessionGeneration + 1;
    _ref
        .read(routineImportAiControllerProvider.notifier)
        .cancelCurrentExtraction();

    final candidateAssetId = state.candidateAssetId;
    final candidateR2Key = state.candidateR2Key;

    state = state.copyWith(
      sessionGeneration: newSessionGen,
      stage: state.workingBlocks.isNotEmpty
          ? ClassesSetupStage.review
          : ClassesSetupStage.chooseSource,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
    );

    if (candidateAssetId != null &&
        candidateAssetId != setup.classLogicalAssetId) {
      try {
        await _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
      } catch (_) {}
    }
  }

  Future<void> retryCandidateExtraction({
    required String uid,
    required BaseTimelineSetup setup,
  }) async {
    final assetId = state.candidateAssetId;
    final r2Key = state.candidateR2Key;
    if (assetId == null || r2Key == null) {
      state = state.copyWith(stage: ClassesSetupStage.chooseSource);
      return;
    }

    final currentAuthGen = _ref.read(authGenerationProvider);
    final sessionGen = state.sessionGeneration + 1;

    state = state.copyWith(
      stage: ClassesSetupStage.extracting,
      sessionGeneration: sessionGen,
      clearErrorMessage: true,
    );

    await _runAiExtraction(
      uid: uid,
      assetId: assetId,
      r2Key: r2Key,
      localPreviewPath: state.workingLocalPreviewPath,
      sessionGen: sessionGen,
      currentAuthGen: currentAuthGen,
      setup: setup,
    );
  }

  void addBlock(ClassRoutineBlock block) {
    final updated = [...state.workingBlocks, block];
    final normalized = normalizeSelectedDay(
      currentDay: state.selectedDay,
      blocks: updated,
    );
    state = state.copyWith(
      workingBlocks: updated,
      selectedDay: normalized,
      isDirty: true,
    );
  }

  void updateBlock(ClassRoutineBlock block) {
    final updated = state.workingBlocks
        .map((b) => b.id == block.id ? block : b)
        .toList();
    final normalized = normalizeSelectedDay(
      currentDay: state.selectedDay,
      blocks: updated,
    );
    state = state.copyWith(
      workingBlocks: updated,
      selectedDay: normalized,
      isDirty: true,
    );
  }

  void deleteBlock(String blockId) {
    final updated = state.workingBlocks.where((b) => b.id != blockId).toList();
    final normalized = normalizeSelectedDay(
      currentDay: state.selectedDay,
      blocks: updated,
    );
    state = state.copyWith(
      workingBlocks: updated,
      selectedDay: normalized,
      isDirty: true,
    );
  }

  Future<void> save({
    required String uid,
    required BaseTimelineSetup setup,
  }) async {
    if (state.isSaving) return;

    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      final drafts = ClassScheduleDraftMapper.toTimelineDrafts(
        state.workingBlocks,
        section: BaseTimelineSection.classes.name,
        provenanceAssetId: state.workingAssetId,
        provenanceR2Key: state.workingR2Key,
      );

      final commitResult = await _coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: drafts,
        updateSetup: (current) => current.copyWith(
          classBlocks: drafts,
          classLogicalAssetId: state.workingAssetId,
          clearClassLogicalAssetId: state.workingAssetId == null,
          classLogicalAssetR2Key: state.workingR2Key,
          clearClassLogicalAssetR2Key: state.workingR2Key == null,
          updatedAt: DateTime.now(),
        ),
      );

      _ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(commitResult.committedSetup);

      // Clean up previous committed asset if replaced
      if (setup.classLogicalAssetId != null &&
          setup.classLogicalAssetId != state.workingAssetId) {
        try {
          await _lifecycleHelper.retireReplacedAsset(
            uid: uid,
            oldAssetId: setup.classLogicalAssetId!,
            oldObjectKey: setup.classLogicalAssetR2Key,
          );
        } catch (_) {}
      }

      final savedBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(drafts);
      final normalizedDay = normalizeSelectedDay(
        currentDay: state.selectedDay,
        blocks: savedBlocks,
      );

      state = state.copyWith(
        stage: ClassesSetupStage.saveSuccess,
        isSaving: false,
        workingBlocks: const [],
        clearWorkingAssetId: true,
        clearWorkingR2Key: true,
        clearWorkingLocalPreviewPath: true,
        clearCandidateAssetId: true,
        clearCandidateR2Key: true,
        selectedDay: normalizedDay,
        isDirty: false,
        droppedCount: 0,
        droppedExamples: const [],
        clearErrorMessage: true,
        clearFrontBlockId: true,
      );
    } catch (e) {
      state = state.copyWith(
        stage: ClassesSetupStage.review,
        isSaving: false,
        errorMessage: ClassSetupErrorMapper.mapSaveError(e),
      );
    }
  }

  Future<void> removeSetup({
    required String uid,
    required BaseTimelineSetup setup,
  }) async {
    state = state.copyWith(isSaving: true, clearErrorMessage: true);
    try {
      final commitResult = await _coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: const [],
        updateSetup: (current) => current.copyWith(
          classBlocks: const [],
          clearClassLogicalAssetId: true,
          clearClassLogicalAssetR2Key: true,
          updatedAt: DateTime.now(),
        ),
      );

      _ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(commitResult.committedSetup);

      if (setup.classLogicalAssetId != null) {
        try {
          await _lifecycleHelper.retireReplacedAsset(
            uid: uid,
            oldAssetId: setup.classLogicalAssetId!,
            oldObjectKey: setup.classLogicalAssetR2Key,
          );
        } catch (_) {}
      }

      state = state.copyWith(
        stage: ClassesSetupStage.currentSetup,
        isSaving: false,
        workingBlocks: const [],
        clearWorkingAssetId: true,
        clearWorkingR2Key: true,
        clearWorkingLocalPreviewPath: true,
        clearCandidateAssetId: true,
        clearCandidateR2Key: true,
        isDirty: false,
        droppedCount: 0,
        droppedExamples: const [],
        clearErrorMessage: true,
        clearFrontBlockId: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ClassSetupErrorMapper.mapSaveError(e),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void dismissSuccess() {
    state = state.copyWith(stage: ClassesSetupStage.currentSetup);
  }

  Future<void> resetWorkingDraft(
    BaseTimelineSetup setup, {
    required String uid,
  }) async {
    final candidateAssetId = state.candidateAssetId;
    final candidateR2Key = state.candidateR2Key;
    final workingAssetId = state.workingAssetId;
    final workingR2Key = state.workingR2Key;

    state = state.copyWith(
      stage: ClassesSetupStage.currentSetup,
      workingBlocks: const [],
      clearWorkingAssetId: true,
      clearWorkingR2Key: true,
      clearWorkingLocalPreviewPath: true,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      isDirty: false,
      droppedCount: 0,
      droppedExamples: const [],
      clearErrorMessage: true,
      clearFrontBlockId: true,
    );

    if (candidateAssetId != null &&
        candidateAssetId != setup.classLogicalAssetId) {
      try {
        await _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
      } catch (_) {}
    }

    if (workingAssetId != null && workingAssetId != setup.classLogicalAssetId) {
      try {
        await _lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: workingAssetId,
          objectKey: workingR2Key,
        );
      } catch (_) {}
    }
  }

  void _retireCandidate() {
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    if (candidateId != null) {
      final uid = _ref.read(userProfileProvider).uid;
      _lifecycleHelper.retireUncommittedUpload(
        uid: uid,
        assetId: candidateId,
        objectKey: candidateKey,
      );
    }
  }
}

final classesSetupControllerProvider =
    StateNotifierProvider.autoDispose<
      ClassesSetupController,
      ClassesSetupState
    >((ref) {
      final coordinator = ref.watch(baseTimelineTransactionCoordinatorProvider);
      final lifecycleHelper = ref.watch(
        baseTimelineUploadLifecycleHelperProvider,
      );
      return ClassesSetupController(
        ref: ref,
        coordinator: coordinator,
        lifecycleHelper: lifecycleHelper,
      );
    });
