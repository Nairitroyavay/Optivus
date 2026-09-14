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
import 'package:optivus/repositories/routine_transaction_repository.dart';
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
  final String ownerUid;
  final int? editorBaseRevision;
  final String? baseCommittedAssetId;
  final String? baseCommittedR2Key;
  final bool routineRefreshPending;
  final int? committedRevision;
  final String? routineRefreshMessage;
  final bool isConcurrencyConflict;

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
    this.ownerUid = '',
    this.editorBaseRevision,
    this.baseCommittedAssetId,
    this.baseCommittedR2Key,
    this.routineRefreshPending = false,
    this.committedRevision,
    this.routineRefreshMessage,
    this.isConcurrencyConflict = false,
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
      routineRefreshPending: routineRefreshPending ?? this.routineRefreshPending,
      committedRevision: clearCommittedRevision
          ? null
          : (committedRevision ?? this.committedRevision),
      routineRefreshMessage: clearRoutineRefreshMessage
          ? null
          : (routineRefreshMessage ?? this.routineRefreshMessage),
      isConcurrencyConflict: isConcurrencyConflict ?? this.isConcurrencyConflict,
    );
  }
}

class ClassesSetupController extends StateNotifier<ClassesSetupState> {
  final Ref _ref;
  final String _ownerUid;
  final BaseTimelineTransactionCoordinator _coordinator;
  final BaseTimelineUploadLifecycleHelper _lifecycleHelper;

  String get ownerUid => _ownerUid;

  ClassesSetupController({
    required Ref ref,
    String? ownerUid,
    required BaseTimelineTransactionCoordinator coordinator,
    required BaseTimelineUploadLifecycleHelper lifecycleHelper,
    int? initialSelectedDay,
  }) : _ref = ref,
       _ownerUid = (ownerUid != null && ownerUid.isNotEmpty)
           ? ownerUid
           : ref.read(userProfileProvider).uid,
       _coordinator = coordinator,
       _lifecycleHelper = lifecycleHelper,
       super(
         ClassesSetupState(
           ownerUid: (ownerUid != null && ownerUid.isNotEmpty)
               ? ownerUid
               : ref.read(userProfileProvider).uid,
           selectedDay:
               initialSelectedDay ?? DateTime.now().weekday.clamp(1, 7),
         ),
       );

  /// Safe best-effort uncommitted asset retirement helper with safe error absorption.
  void _retireUncommittedBestEffort({
    required String uid,
    String? assetId,
    String? objectKey,
  }) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) return;
    final trimmedId = assetId?.trim();
    final trimmedKey = objectKey?.trim();
    if ((trimmedId == null || trimmedId.isEmpty) &&
        (trimmedKey == null || trimmedKey.isEmpty)) {
      return;
    }
    unawaited(
      _lifecycleHelper
          .retireUncommittedUpload(
            uid: trimmedUid,
            assetId: trimmedId,
            objectKey: trimmedKey,
          )
          .catchError((error, stackTrace) {
            debugPrint(
              'Best-effort upload retirement completed safely: $error',
            );
          }),
    );
  }

  /// Safe startup cleanup. NEVER runs while BaseTimelineSetup is loading (null).
  /// Strictly owner-scoped; passes purposes: {classTimetable} and protected asset ID/key.
  Future<void> performStartupCleanup(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    if (setup == null || state.hasRunStartupCleanup) return;
    final activeUid = _ref.read(userProfileProvider).uid.trim();
    if (_ownerUid.isNotEmpty &&
        (activeUid != _ownerUid || activeUid != uid.trim())) {
      return;
    }
    if (uid.trim().isEmpty) return;
    state = state.copyWith(hasRunStartupCleanup: true);
    try {
      await _lifecycleHelper.cleanupStaleUncommittedAssets(
        uid: uid,
        purposes: const {UploadedAssetPurpose.classTimetable},
        committedAssetIds: {
          if (setup.classLogicalAssetId != null &&
              setup.classLogicalAssetId!.isNotEmpty)
            setup.classLogicalAssetId!,
        },
        committedR2Keys: {
          if (setup.classLogicalAssetR2Key != null &&
              setup.classLogicalAssetR2Key!.isNotEmpty)
            setup.classLogicalAssetR2Key!,
        },
        committedAssetId: setup.classLogicalAssetId,
        committedR2Key: setup.classLogicalAssetR2Key,
      );
    } catch (err) {
      debugPrint('Classes startup cleanup failed safely: $err');
    }
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
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.classLogicalAssetId,
      baseCommittedR2Key: setup.classLogicalAssetR2Key,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
      isConcurrencyConflict: false,
    );
    if (candidateId != null && candidateId != setup.classLogicalAssetId) {
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: candidateId,
        objectKey: candidateKey,
      );
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
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: candidateId,
        objectKey: candidateKey,
      );
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
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.classLogicalAssetId,
      baseCommittedR2Key: setup.classLogicalAssetR2Key,
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
      isConcurrencyConflict: false,
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
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.classLogicalAssetId,
      baseCommittedR2Key: setup.classLogicalAssetR2Key,
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
      isConcurrencyConflict: false,
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
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.classLogicalAssetId,
      baseCommittedR2Key: setup.classLogicalAssetR2Key,
      clearErrorMessage: true,
      isConcurrencyConflict: false,
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
        _retireUncommittedBestEffort(
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
        _retireUncommittedBestEffort(
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
            _retireUncommittedBestEffort(
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
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: candidateAssetId,
        objectKey: candidateR2Key,
      );
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
    BaseTimelineSetup? setup,
  }) async {
    if (state.isSaving) return;
    final activeUid = _ref.read(userProfileProvider).uid.trim();
    if (_ownerUid.isNotEmpty &&
        (activeUid != _ownerUid || activeUid != uid.trim())) {
      return;
    }
    if (uid.trim().isEmpty) return;

    // Strict validation of each block before any persistence
    for (final block in state.workingBlocks) {
      final validationError = ClassScheduleDraftMapper.validateWorkingBlock(block);
      if (validationError != null) {
        state = state.copyWith(
          errorMessage: validationError,
        );
        return;
      }
    }

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      isConcurrencyConflict: false,
    );

    try {
      final drafts = ClassScheduleDraftMapper.toTimelineDrafts(
        state.workingBlocks,
        section: BaseTimelineSection.classes.name,
        provenanceAssetId: state.workingAssetId,
        provenanceR2Key: state.workingR2Key,
      );

      final expectedRevision =
          state.editorBaseRevision ?? setup?.revision ?? 1;

      final commitResult = await _coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: drafts,
        expectedRevision: expectedRevision,
        updateSetup: (current) => current.copyWith(
          classBlocks: drafts,
          classLogicalAssetId: state.workingAssetId,
          clearClassLogicalAssetId: state.workingAssetId == null,
          classLogicalAssetR2Key: state.workingR2Key,
          clearClassLogicalAssetR2Key: state.workingR2Key == null,
          updatedAt: DateTime.now(),
        ),
      );

      try {
        final setupNotifier =
            _ref.read(baseTimelineSetupNotifierProvider.notifier);
        if (setupNotifier.uid == uid) {
          setupNotifier.updateInMemory(commitResult.committedSetup);
        }
      } catch (_) {}

      // Clean up previous committed asset if replaced
      final oldAssetId =
          state.baseCommittedAssetId ?? setup?.classLogicalAssetId;
      final oldObjectKey =
          state.baseCommittedR2Key ?? setup?.classLogicalAssetR2Key;
      if (oldAssetId != null && oldAssetId != state.workingAssetId) {
        unawaited(
          _lifecycleHelper
              .retireReplacedAsset(
                uid: uid,
                oldAssetId: oldAssetId,
                oldObjectKey: oldObjectKey,
              )
              .catchError((err, st) {
                debugPrint('Failed retiring old asset: $err');
              }),
        );
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
        routineRefreshPending: commitResult.routineRefreshPending,
        committedRevision: commitResult.revision,
        routineRefreshMessage: commitResult.routineRefreshMessage,
        clearEditorBaseRevision: true,
        clearBaseCommittedAssetId: true,
        clearBaseCommittedR2Key: true,
        isConcurrencyConflict: false,
      );
    } catch (e) {
      final isConflict = e is BaseTimelineConcurrencyException ||
          e.toString().toLowerCase().contains('concurrency') ||
          e.toString().toLowerCase().contains('conflict');

      state = state.copyWith(
        stage: ClassesSetupStage.review,
        isSaving: false,
        errorMessage: ClassSetupErrorMapper.mapSaveError(e),
        isConcurrencyConflict: isConflict,
      );
    }
  }

  Future<void> removeSetup({
    required String uid,
    required BaseTimelineSetup setup,
  }) async {
    if (state.isSaving) return;
    final activeUid = _ref.read(userProfileProvider).uid.trim();
    if (_ownerUid.isNotEmpty &&
        (activeUid != _ownerUid || activeUid != uid.trim())) {
      return;
    }
    if (uid.trim().isEmpty) return;

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      isConcurrencyConflict: false,
    );
    try {
      final expectedRevision = state.editorBaseRevision ?? setup.revision;

      final commitResult = await _coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: const [],
        expectedRevision: expectedRevision,
        updateSetup: (current) => current.copyWith(
          classBlocks: const [],
          clearClassLogicalAssetId: true,
          clearClassLogicalAssetR2Key: true,
          updatedAt: DateTime.now(),
        ),
      );

      try {
        final setupNotifier =
            _ref.read(baseTimelineSetupNotifierProvider.notifier);
        if (setupNotifier.uid == uid) {
          setupNotifier.updateInMemory(commitResult.committedSetup);
        }
      } catch (_) {}

      if (setup.classLogicalAssetId != null) {
        unawaited(
          _lifecycleHelper
              .retireReplacedAsset(
                uid: uid,
                oldAssetId: setup.classLogicalAssetId!,
                oldObjectKey: setup.classLogicalAssetR2Key,
              )
              .catchError((err, st) {
                debugPrint('Failed retiring old asset on remove: $err');
              }),
        );
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
        routineRefreshPending: commitResult.routineRefreshPending,
        committedRevision: commitResult.revision,
        routineRefreshMessage: commitResult.routineRefreshMessage,
        clearEditorBaseRevision: true,
        clearBaseCommittedAssetId: true,
        clearBaseCommittedR2Key: true,
        isConcurrencyConflict: false,
      );
    } catch (e) {
      final isConflict = e is BaseTimelineConcurrencyException ||
          e.toString().toLowerCase().contains('concurrency') ||
          e.toString().toLowerCase().contains('conflict');
      state = state.copyWith(
        isSaving: false,
        errorMessage: ClassSetupErrorMapper.mapSaveError(e),
        isConcurrencyConflict: isConflict,
      );
    }
  }

  /// Retries routine projection / reconciliation without modifying base timeline setup.
  Future<void> retryRoutineRefresh({required String uid}) async {
    final activeUid = _ref.read(userProfileProvider).uid.trim();
    if (_ownerUid.isNotEmpty &&
        (activeUid != _ownerUid || activeUid != uid.trim())) {
      return;
    }
    if (uid.trim().isEmpty) return;
    try {
      final refreshOutcome = await _coordinator.retryRoutineRefresh(
        uid: uid,
      );
      if (refreshOutcome.isRefreshed) {
        state = state.copyWith(
          routineRefreshPending: false,
          clearRoutineRefreshMessage: true,
        );
      } else {
        state = state.copyWith(
          routineRefreshPending: true,
          routineRefreshMessage: refreshOutcome.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        routineRefreshPending: true,
        routineRefreshMessage: 'Reconciliation retry failed: $e',
      );
    }
  }

  /// Discards local conflict working blocks and reloads latest canonical setup.
  void reloadFromCanonical(BaseTimelineSetup setup) {
    _retireCandidate();
    final blocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
      setup.classBlocks,
    );
    final normalizedDay = normalizeSelectedDay(
      currentDay: state.selectedDay,
      blocks: blocks,
    );
    state = state.copyWith(
      stage: blocks.isNotEmpty
          ? ClassesSetupStage.review
          : ClassesSetupStage.currentSetup,
      workingBlocks: blocks,
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.classLogicalAssetId,
      baseCommittedR2Key: setup.classLogicalAssetR2Key,
      workingAssetId: setup.classLogicalAssetId,
      clearWorkingAssetId: setup.classLogicalAssetId == null,
      workingR2Key: setup.classLogicalAssetR2Key,
      clearWorkingR2Key: setup.classLogicalAssetR2Key == null,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      selectedDay: normalizedDay,
      isDirty: false,
      droppedCount: 0,
      droppedExamples: const [],
      clearErrorMessage: true,
      clearFrontBlockId: true,
      isConcurrencyConflict: false,
    );
  }

  void clearError() {
    state = state.copyWith(
      clearErrorMessage: true,
      isConcurrencyConflict: false,
    );
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
      clearEditorBaseRevision: true,
      clearBaseCommittedAssetId: true,
      clearBaseCommittedR2Key: true,
      isConcurrencyConflict: false,
    );

    if (candidateAssetId != null &&
        candidateAssetId != setup.classLogicalAssetId) {
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: candidateAssetId,
        objectKey: candidateR2Key,
      );
    }

    if (workingAssetId != null && workingAssetId != setup.classLogicalAssetId) {
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: workingAssetId,
        objectKey: workingR2Key,
      );
    }
  }

  void _retireCandidate() {
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    if (candidateId != null) {
      _retireUncommittedBestEffort(
        uid: _ownerUid,
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
      final uid = ref.watch(userProfileProvider.select((p) => p.uid));
      final coordinator = ref.watch(baseTimelineTransactionCoordinatorProvider);
      final lifecycleHelper = ref.watch(
        baseTimelineUploadLifecycleHelperProvider,
      );
      return ClassesSetupController(
        ref: ref,
        ownerUid: uid,
        coordinator: coordinator,
        lifecycleHelper: lifecycleHelper,
      );
    });
