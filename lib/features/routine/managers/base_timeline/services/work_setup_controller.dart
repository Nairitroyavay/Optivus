import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_setup_error_mapper.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Explicit staged state machine for Work / Business Base Timeline setup.
enum WorkSetupStage {
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

enum WorkRemoveOutcomeStatus { removed, refreshPending, conflict, failed }

@immutable
class WorkRemoveOutcome {
  final WorkRemoveOutcomeStatus status;
  final String? message;

  const WorkRemoveOutcome({required this.status, this.message});

  bool get isSuccessful =>
      status == WorkRemoveOutcomeStatus.removed ||
      status == WorkRemoveOutcomeStatus.refreshPending;
}

enum WorkSetupErrorKind { load, upload, extraction, save, remove, concurrency }

/// Computes the initial weekday tab to display for a list of work blocks.
int computeInitialWorkWeekday(
  List<TimelineBlockDraft> blocks, {
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

/// Normalizes the selected weekday after any mutation, delete, or save.
///
/// 1. If [currentDay] has scheduled work, keep it.
/// 2. If today has scheduled work, switch to today.
/// 3. If any other weekday has scheduled work, pick the earliest weekday (1-7).
/// 4. Fallback to today (clamped 1-7).
int normalizeSelectedWorkDay({
  required int currentDay,
  required List<TimelineBlockDraft> blocks,
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
class WorkSetupState {
  final WorkSetupStage stage;
  final List<TimelineBlockDraft> workingBlocks;
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
  final WorkSetupErrorKind? errorKind;
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

  const WorkSetupState({
    this.stage = WorkSetupStage.currentSetup,
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
    this.errorKind,
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

  WorkSetupState copyWith({
    WorkSetupStage? stage,
    List<TimelineBlockDraft>? workingBlocks,
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
    WorkSetupErrorKind? errorKind,
    bool clearErrorKind = false,
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
    return WorkSetupState(
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
      errorKind: clearErrorKind ? null : (errorKind ?? this.errorKind),
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
    );
  }
}

class WorkSetupController extends StateNotifier<WorkSetupState> {
  final Ref _ref;
  final String _ownerUid;
  final BaseTimelineTransactionCoordinator _coordinator;
  final BaseTimelineUploadLifecycleHelper _lifecycleHelper;

  String get ownerUid => _ownerUid;

  WorkSetupController({
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
         WorkSetupState(
           ownerUid: (ownerUid != null && ownerUid.isNotEmpty)
               ? ownerUid
               : ref.read(userProfileProvider).uid,
           selectedDay:
               initialSelectedDay ?? DateTime.now().weekday.clamp(1, 7),
         ),
       );

  bool _isActiveOwner(String uid) {
    if (!mounted || uid.trim().isEmpty || _ownerUid != uid.trim()) {
      return false;
    }
    try {
      return _ref.read(userProfileProvider).uid.trim() == uid.trim();
    } catch (_) {
      return false;
    }
  }

  /// Safe best-effort uncommitted asset retirement helper with error absorption.
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
              'Best-effort work upload retirement completed safely: $error',
            );
          }),
    );
  }

  /// Retires any uncommitted candidate and working assets for this user session.
  /// Canonical committed assets are safely preserved.
  void retireUncommittedWorkAssets({required String uid}) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) return;
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    final workingId = state.workingAssetId;
    final workingKey = state.workingR2Key;
    final committedId = state.baseCommittedAssetId;
    final committedKey = state.baseCommittedR2Key;

    final hasUncommittedCandidate =
        (candidateId != null && candidateId != committedId) ||
        (candidateKey != null && candidateKey != committedKey);
    if (hasUncommittedCandidate) {
      _retireUncommittedBestEffort(
        uid: trimmedUid,
        assetId: candidateId,
        objectKey: candidateKey,
      );
    }

    final hasUncommittedWorking =
        (workingId != null && workingId != committedId) ||
        (workingKey != null && workingKey != committedKey);
    if (hasUncommittedWorking) {
      _retireUncommittedBestEffort(
        uid: trimmedUid,
        assetId: workingId,
        objectKey: workingKey,
      );
    }
  }

  @override
  void dispose() {
    retireUncommittedWorkAssets(uid: _ownerUid);
    super.dispose();
  }

  /// Safe startup cleanup. NEVER runs while BaseTimelineSetup is loading (null).
  /// Strictly owner-scoped; passes purposes: {workSchedule} and protected asset ID/key.
  Future<void> performStartupCleanup(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    if (!_isActiveOwner(uid) || setup == null || state.hasRunStartupCleanup) {
      return;
    }
    state = state.copyWith(hasRunStartupCleanup: true);
    try {
      await _lifecycleHelper.cleanupStaleUncommittedAssets(
        uid: uid,
        purposes: const {UploadedAssetPurpose.workSchedule},
        committedAssetIds: {
          if (setup.workLogicalAssetId != null &&
              setup.workLogicalAssetId!.isNotEmpty)
            setup.workLogicalAssetId!,
        },
        committedR2Keys: {
          if (setup.workLogicalAssetR2Key != null &&
              setup.workLogicalAssetR2Key!.isNotEmpty)
            setup.workLogicalAssetR2Key!,
        },
        committedAssetId: setup.workLogicalAssetId,
        committedR2Key: setup.workLogicalAssetR2Key,
      );
    } catch (err) {
      debugPrint('Work startup cleanup failed safely: $err');
    }
  }

  /// Initializes the selected weekday tab if not yet calibrated.
  void initDayIfNeeded(BaseTimelineSetup? setup) {
    if (state.stage != WorkSetupStage.currentSetup) return;
    if (setup != null) {
      final normalized = normalizeSelectedWorkDay(
        currentDay: state.selectedDay,
        blocks: setup.workBlocks,
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

  void chooseSource(BaseTimelineSetup? setup, {required String uid}) {
    if (!_isActiveOwner(uid)) return;
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    state = state.copyWith(
      stage: WorkSetupStage.chooseSource,
      editorBaseRevision: setup?.revision,
      baseCommittedAssetId: setup?.workLogicalAssetId,
      baseCommittedR2Key: setup?.workLogicalAssetR2Key,
      workingBlocks: state.workingBlocks.isNotEmpty
          ? state.workingBlocks
          : (setup != null
                ? List<TimelineBlockDraft>.from(setup.workBlocks)
                : const []),
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
      clearErrorKind: true,
      isConcurrencyConflict: false,
    );
    if ((candidateId != null && candidateId != state.baseCommittedAssetId) ||
        (candidateKey != null && candidateKey != state.baseCommittedR2Key)) {
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
          ? WorkSetupStage.review
          : WorkSetupStage.currentSetup,
      clearErrorMessage: true,
      clearErrorKind: true,
    );
  }

  void keepPreviousDraft(BaseTimelineSetup? setup, {required String uid}) {
    if (!_isActiveOwner(uid)) return;
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    state = state.copyWith(
      stage: WorkSetupStage.review,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
      clearErrorKind: true,
    );
    if ((candidateId != null && candidateId != state.baseCommittedAssetId) ||
        (candidateKey != null && candidateKey != state.baseCommittedR2Key)) {
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: candidateId,
        objectKey: candidateKey,
      );
    }
  }

  void startEditingBlock() {
    state = state.copyWith(stage: WorkSetupStage.editingBlock);
  }

  void stopEditingBlock() {
    if (state.stage == WorkSetupStage.editingBlock) {
      state = state.copyWith(stage: WorkSetupStage.review);
    }
  }

  /// Start manual setup: clears photo asset IDs (manual provenance), loads existing blocks if any.
  void startManualSetup(BaseTimelineSetup setup) {
    retireUncommittedWorkAssets(uid: _ownerUid);
    final normalizedDay = normalizeSelectedWorkDay(
      currentDay: state.selectedDay,
      blocks: setup.workBlocks,
    );
    state = state.copyWith(
      stage: WorkSetupStage.review,
      workingBlocks: List<TimelineBlockDraft>.from(setup.workBlocks),
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.workLogicalAssetId,
      baseCommittedR2Key: setup.workLogicalAssetR2Key,
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
      clearErrorKind: true,
      clearFrontBlockId: true,
      isConcurrencyConflict: false,
    );
  }

  /// Edit current work schedule: retains existing photo provenance and blocks.
  void editCurrentWorkSchedule(BaseTimelineSetup setup) {
    _retireCandidate();
    final normalizedDay = normalizeSelectedWorkDay(
      currentDay: state.selectedDay,
      blocks: setup.workBlocks,
    );
    state = state.copyWith(
      stage: WorkSetupStage.review,
      workingBlocks: List<TimelineBlockDraft>.from(setup.workBlocks),
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.workLogicalAssetId,
      baseCommittedR2Key: setup.workLogicalAssetR2Key,
      workingAssetId: setup.workLogicalAssetId,
      clearWorkingAssetId: setup.workLogicalAssetId == null,
      workingR2Key: setup.workLogicalAssetR2Key,
      clearWorkingR2Key: setup.workLogicalAssetR2Key == null,
      clearWorkingLocalPreviewPath: true,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      selectedDay: normalizedDay,
      droppedCount: 0,
      droppedExamples: const [],
      isDirty: false,
      clearErrorMessage: true,
      clearErrorKind: true,
      clearFrontBlockId: true,
      isConcurrencyConflict: false,
    );
  }

  Future<void> pickAndUploadPhoto({
    required String uid,
    required ImageSource source,
    BaseTimelineSetup? setup,
  }) async {
    if (!_isActiveOwner(uid)) return;
    final currentAuthGen = _ref.read(authGenerationProvider);
    final sessionGen = state.sessionGeneration + 1;

    state = state.copyWith(
      stage: WorkSetupStage.uploading,
      sessionGeneration: sessionGen,
      editorBaseRevision: setup?.revision,
      baseCommittedAssetId: setup?.workLogicalAssetId,
      baseCommittedR2Key: setup?.workLogicalAssetR2Key,
      clearErrorMessage: true,
      isConcurrencyConflict: false,
    );

    UploadedAsset? asset;
    try {
      final uploadNotifier = _ref.read(uploadControllerProvider.notifier);
      asset = await uploadNotifier.startUpload(
        uid: uid,
        purpose: UploadedAssetPurpose.workSchedule,
        sourceFeature: UploadSourceFeature.routineBaseTimeline,
        source: source,
      );
    } catch (uploadError) {
      if (!_isActiveOwner(uid)) return;
      if (state.sessionGeneration != sessionGen) return;
      state = state.copyWith(
        stage: WorkSetupStage.error,
        errorMessage: WorkSetupErrorMapper.mapUploadError(uploadError),
        errorKind: WorkSetupErrorKind.upload,
      );
      return;
    }

    if (!_isActiveOwner(uid) ||
        state.sessionGeneration != sessionGen ||
        _ref.read(authGenerationProvider) != currentAuthGen ||
        _ownerUid != uid) {
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
            ? WorkSetupStage.review
            : WorkSetupStage.chooseSource,
      );
      return;
    }

    state = state.copyWith(
      stage: WorkSetupStage.extracting,
      candidateAssetId: asset.assetId,
      candidateR2Key: asset.r2Key,
      clearErrorMessage: true,
      clearErrorKind: true,
    );

    await _runAiExtraction(
      uid: uid,
      assetId: asset.assetId,
      r2Key: asset.r2Key,
      localPreviewPath: asset.localPreviewPath,
      sessionGen: sessionGen,
      currentAuthGen: currentAuthGen,
    );
  }

  Future<void> _runAiExtraction({
    required String uid,
    required String assetId,
    required String r2Key,
    String? localPreviewPath,
    required int sessionGen,
    required int currentAuthGen,
  }) async {
    final reviewDraft = RoutineImportReviewDraft(
      id: 'rev_$assetId',
      uid: uid,
      source: RoutineImportReviewSource.work,
      status: RoutineImportReviewStatus.draft,
      sourceLabel: 'Work',
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
              if (_isActiveOwner(uid) &&
                  _ref.read(authGenerationProvider) == currentAuthGen) {
                aiController.cancelCurrentExtraction();
              }
              throw TimeoutException('AI work schedule extraction timed out.');
            },
          );

      if (!_isActiveOwner(uid)) {
        _retireUncommittedBestEffort(
          uid: uid,
          assetId: assetId,
          objectKey: r2Key,
        );
        return;
      }

      if (state.sessionGeneration != sessionGen ||
          _ref.read(authGenerationProvider) != currentAuthGen ||
          _ownerUid != uid ||
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
            "We couldn't detect work blocks in this schedule.";
        state = state.copyWith(
          stage: WorkSetupStage.error,
          errorMessage: WorkSetupErrorMapper.mapAiExtractionError(err),
          errorKind: WorkSetupErrorKind.extraction,
        );
        return;
      }

      if (result.candidates.isNotEmpty) {
        final mappingResult = mapOnboarding4Candidates(
          candidates: result.candidates,
          config: ScheduleSetupConfig.workSetup,
        );

        if (mappingResult.blocks.isNotEmpty) {
          // Retire previous working asset if it was uncommitted and replaced
          if (state.workingAssetId != null &&
              state.workingAssetId != state.baseCommittedAssetId &&
              state.workingAssetId != assetId) {
            _retireUncommittedBestEffort(
              uid: uid,
              assetId: state.workingAssetId,
              objectKey: state.workingR2Key,
            );
          }

          final candidatesById = {for (final c in result.candidates) c.id: c};
          final mappedBlocks = mappingResult.blocks.map((block) {
            final candidate = candidatesById[block.id];
            return TimelineBlockDraft(
              id: block.id,
              section: 'work',
              title: block.subject,
              startMinute: block.startMinute,
              endMinute: block.endMinute,
              repeatDays: block.repeatDays,
              location: block.room,
              notes: block.notes,
              sectionLabel: block.section,
              blockType: TimelineBlockDraft.hardBlockKey,
              source: candidate?.extractionEngine ?? 'ai_import',
              provenanceSourceIds: [assetId],
            );
          }).toList();

          final normalizedDay = normalizeSelectedWorkDay(
            currentDay: state.selectedDay,
            blocks: mappedBlocks,
          );

          state = state.copyWith(
            stage: WorkSetupStage.review,
            workingBlocks: mappedBlocks,
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
            clearErrorKind: true,
            clearFrontBlockId: true,
          );
          return;
        }
      }

      // Extraction yielded 0 blocks: retire candidate asset, preserve previous working draft
      _retireCandidate();
      state = state.copyWith(
        stage: WorkSetupStage.error,
        errorMessage: WorkSetupErrorMapper.mapAiExtractionError(
          null,
          warnings: result.warnings,
        ),
        errorKind: WorkSetupErrorKind.extraction,
      );
    } catch (e) {
      if (!_isActiveOwner(uid)) {
        _retireUncommittedBestEffort(
          uid: uid,
          assetId: assetId,
          objectKey: r2Key,
        );
        return;
      }
      if (e is TimeoutException &&
          _ref.read(authGenerationProvider) == currentAuthGen) {
        try {
          _ref
              .read(routineImportAiControllerProvider.notifier)
              .cancelCurrentExtraction();
        } catch (_) {}
      }
      if (state.sessionGeneration != sessionGen) return;
      if (_ref.read(authGenerationProvider) == currentAuthGen &&
          _ref.read(userProfileProvider).uid == uid) {
        _retireCandidate();
        state = state.copyWith(
          stage: WorkSetupStage.error,
          errorMessage: WorkSetupErrorMapper.mapAiExtractionError(e),
          errorKind: WorkSetupErrorKind.extraction,
        );
      }
    }
  }

  /// Cancels in-flight extraction or upload immediately and resets state.
  Future<void> cancelCurrentExtraction(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    if (!_isActiveOwner(uid)) return;
    final newSessionGen = state.sessionGeneration + 1;
    _ref
        .read(routineImportAiControllerProvider.notifier)
        .cancelCurrentExtraction();

    final candidateAssetId = state.candidateAssetId;
    final candidateR2Key = state.candidateR2Key;

    state = state.copyWith(
      sessionGeneration: newSessionGen,
      stage: state.workingBlocks.isNotEmpty
          ? WorkSetupStage.review
          : WorkSetupStage.chooseSource,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      clearErrorMessage: true,
      clearErrorKind: true,
    );

    if ((candidateAssetId != null &&
            candidateAssetId != state.baseCommittedAssetId) ||
        (candidateR2Key != null &&
            candidateR2Key != state.baseCommittedR2Key)) {
      _retireUncommittedBestEffort(
        uid: uid,
        assetId: candidateAssetId,
        objectKey: candidateR2Key,
      );
    }
  }

  Future<void> retryCandidateExtraction({
    required String uid,
    BaseTimelineSetup? setup,
  }) async {
    if (!_isActiveOwner(uid)) return;
    final assetId = state.candidateAssetId;
    final r2Key = state.candidateR2Key;
    if (assetId == null || r2Key == null) {
      state = state.copyWith(stage: WorkSetupStage.chooseSource);
      return;
    }

    final currentAuthGen = _ref.read(authGenerationProvider);
    final sessionGen = state.sessionGeneration + 1;
    final localPreviewPath = state.workingLocalPreviewPath;

    state = state.copyWith(
      stage: WorkSetupStage.extracting,
      sessionGeneration: sessionGen,
      clearErrorMessage: true,
      clearErrorKind: true,
    );

    await _runAiExtraction(
      uid: uid,
      assetId: assetId,
      r2Key: r2Key,
      localPreviewPath: localPreviewPath,
      sessionGen: sessionGen,
      currentAuthGen: currentAuthGen,
    );
  }

  void addBlock(TimelineBlockDraft block) {
    final updated = [...state.workingBlocks, block];
    final normalized = normalizeSelectedWorkDay(
      currentDay: state.selectedDay,
      blocks: updated,
    );
    state = state.copyWith(
      workingBlocks: updated,
      selectedDay: normalized,
      isDirty: true,
    );
  }

  void updateBlock(TimelineBlockDraft block) {
    final updated = state.workingBlocks
        .map((b) => b.id == block.id ? block : b)
        .toList();
    final normalized = normalizeSelectedWorkDay(
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
    final normalized = normalizeSelectedWorkDay(
      currentDay: state.selectedDay,
      blocks: updated,
    );
    state = state.copyWith(
      workingBlocks: updated,
      selectedDay: normalized,
      clearFrontBlockId: state.frontBlockId == blockId,
      isDirty: true,
    );
  }

  Future<void> save({required String uid, BaseTimelineSetup? setup}) async {
    if (state.isSaving) return;
    if (!_isActiveOwner(uid)) return;

    // Strict validation: Normal save must not allow empty working blocks
    if (state.workingBlocks.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Cannot save an empty work schedule. Use "Remove Work Setup" to remove it.',
        errorKind: WorkSetupErrorKind.save,
      );
      return;
    }

    // Strict validation of each block before any persistence
    for (final block in state.workingBlocks) {
      if (block.title.trim().isEmpty) {
        state = state.copyWith(
          errorMessage: 'Role or title is required for each work block.',
          errorKind: WorkSetupErrorKind.save,
        );
        return;
      }
      if (block.endMinute <= block.startMinute) {
        state = state.copyWith(
          errorMessage:
              'End time must be after start time for "${block.title}".',
          errorKind: WorkSetupErrorKind.save,
        );
        return;
      }
      if (block.repeatDays.isEmpty) {
        state = state.copyWith(
          errorMessage: 'Select at least one day for "${block.title}".',
          errorKind: WorkSetupErrorKind.save,
        );
        return;
      }
    }

    final workingBlocks = List<TimelineBlockDraft>.unmodifiable(
      state.workingBlocks,
    );
    final workingAssetId = state.workingAssetId;
    final workingR2Key = state.workingR2Key;
    final baseCommittedAssetId = state.baseCommittedAssetId;
    final baseCommittedR2Key = state.baseCommittedR2Key;
    final expectedRevision = state.editorBaseRevision ?? setup?.revision;
    final selectedDay = state.selectedDay;
    if (expectedRevision == null) {
      state = state.copyWith(
        errorMessage:
            "We couldn't verify the latest Work setup. Try reloading it.",
        errorKind: WorkSetupErrorKind.save,
      );
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearErrorKind: true,
      isConcurrencyConflict: false,
    );

    try {
      final commitResult = await _coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.work,
        newBlocks: workingBlocks,
        expectedRevision: expectedRevision,
        updateSetup: (current) => current.copyWith(
          workBlocks: workingBlocks,
          workLogicalAssetId: workingAssetId,
          clearWorkLogicalAssetId: workingAssetId == null,
          workLogicalAssetR2Key: workingR2Key,
          clearWorkLogicalAssetR2Key: workingR2Key == null,
          updatedAt: DateTime.now(),
        ),
      );

      // Clean up previous committed asset if replaced
      final oldAssetId = baseCommittedAssetId ?? setup?.workLogicalAssetId;
      final oldObjectKey = baseCommittedR2Key ?? setup?.workLogicalAssetR2Key;
      if (oldAssetId != null &&
          (oldAssetId != workingAssetId ||
              (oldObjectKey != null && oldObjectKey != workingR2Key))) {
        unawaited(
          _lifecycleHelper
              .retireReplacedAsset(
                uid: uid,
                oldAssetId: oldAssetId,
                oldObjectKey: oldObjectKey,
              )
              .catchError((err, st) {
                debugPrint('Failed retiring old work asset: $err');
              }),
        );
      }

      if (!_isActiveOwner(uid)) return;

      final normalizedDay = normalizeSelectedWorkDay(
        currentDay: selectedDay,
        blocks: workingBlocks,
      );

      state = state.copyWith(
        stage: WorkSetupStage.saveSuccess,
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
        clearErrorKind: true,
        clearFrontBlockId: true,
        routineRefreshPending: commitResult.routineRefreshPending,
        committedRevision: commitResult.revision,
        routineRefreshMessage: commitResult.routineRefreshPending
            ? WorkSetupErrorMapper.mapRefreshError(
                commitResult.routineRefreshMessage,
              )
            : null,
        clearRoutineRefreshMessage: !commitResult.routineRefreshPending,
        clearEditorBaseRevision: true,
        clearBaseCommittedAssetId: true,
        clearBaseCommittedR2Key: true,
        isConcurrencyConflict: false,
      );
    } catch (e) {
      if (!_isActiveOwner(uid)) return;
      final isConflict =
          e is BaseTimelineConcurrencyException ||
          e.toString().toLowerCase().contains('concurrency') ||
          e.toString().toLowerCase().contains('conflict');

      state = state.copyWith(
        stage: WorkSetupStage.review,
        isSaving: false,
        errorMessage: WorkSetupErrorMapper.mapSaveError(e),
        errorKind: isConflict
            ? WorkSetupErrorKind.concurrency
            : WorkSetupErrorKind.save,
        isConcurrencyConflict: isConflict,
      );
    }
  }

  Future<WorkRemoveOutcome> removeSetup({
    required String uid,
    required BaseTimelineSetup setup,
  }) async {
    if (state.isSaving) {
      return const WorkRemoveOutcome(
        status: WorkRemoveOutcomeStatus.failed,
        message: 'A save or remove operation is already in progress.',
      );
    }
    if (!_isActiveOwner(uid)) {
      return const WorkRemoveOutcome(
        status: WorkRemoveOutcomeStatus.failed,
        message: 'Active user changed. Cannot remove work setup.',
      );
    }

    final expectedRevision = state.editorBaseRevision ?? setup.revision;
    final oldAssetId = setup.workLogicalAssetId;
    final oldObjectKey = setup.workLogicalAssetR2Key;

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearErrorKind: true,
      isConcurrencyConflict: false,
    );
    try {
      final commitResult = await _coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.work,
        newBlocks: const [],
        expectedRevision: expectedRevision,
        updateSetup: (current) => current.copyWith(
          workBlocks: const [],
          clearWorkLogicalAssetId: true,
          clearWorkLogicalAssetR2Key: true,
          updatedAt: DateTime.now(),
        ),
      );

      if (oldAssetId != null && oldAssetId.isNotEmpty) {
        unawaited(
          _lifecycleHelper
              .retireReplacedAsset(
                uid: uid,
                oldAssetId: oldAssetId,
                oldObjectKey: oldObjectKey,
              )
              .catchError((err, st) {
                debugPrint('Failed retiring old work asset on remove: $err');
              }),
        );
      }

      if (!_isActiveOwner(uid)) {
        return const WorkRemoveOutcome(
          status: WorkRemoveOutcomeStatus.failed,
          message: 'Active user changed during removal.',
        );
      }

      state = state.copyWith(
        stage: WorkSetupStage.currentSetup,
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
        clearErrorKind: true,
        clearFrontBlockId: true,
        routineRefreshPending: commitResult.routineRefreshPending,
        committedRevision: commitResult.revision,
        routineRefreshMessage: commitResult.routineRefreshPending
            ? WorkSetupErrorMapper.mapRefreshError(
                commitResult.routineRefreshMessage,
              )
            : null,
        clearRoutineRefreshMessage: !commitResult.routineRefreshPending,
        clearEditorBaseRevision: true,
        clearBaseCommittedAssetId: true,
        clearBaseCommittedR2Key: true,
        isConcurrencyConflict: false,
      );

      if (commitResult.routineRefreshPending) {
        return WorkRemoveOutcome(
          status: WorkRemoveOutcomeStatus.refreshPending,
          message: commitResult.routineRefreshMessage,
        );
      }
      return const WorkRemoveOutcome(status: WorkRemoveOutcomeStatus.removed);
    } catch (e) {
      if (!_isActiveOwner(uid)) {
        return const WorkRemoveOutcome(
          status: WorkRemoveOutcomeStatus.failed,
          message: 'Active user changed during removal.',
        );
      }
      final isConflict =
          e is BaseTimelineConcurrencyException ||
          e.toString().toLowerCase().contains('concurrency') ||
          e.toString().toLowerCase().contains('conflict');
      final mappedError = WorkSetupErrorMapper.mapRemoveError(e);
      state = state.copyWith(
        isSaving: false,
        errorMessage: mappedError,
        errorKind: isConflict
            ? WorkSetupErrorKind.concurrency
            : WorkSetupErrorKind.remove,
        isConcurrencyConflict: isConflict,
      );
      return WorkRemoveOutcome(
        status: isConflict
            ? WorkRemoveOutcomeStatus.conflict
            : WorkRemoveOutcomeStatus.failed,
        message: mappedError,
      );
    }
  }

  /// Retries routine projection / reconciliation without modifying base timeline setup.
  Future<void> retryRoutineRefresh({required String uid}) async {
    if (!_isActiveOwner(uid)) return;
    try {
      final refreshOutcome = await _coordinator.retryRoutineRefresh(uid: uid);
      if (!_isActiveOwner(uid)) return;
      if (refreshOutcome.isRefreshed) {
        state = state.copyWith(
          routineRefreshPending: false,
          clearRoutineRefreshMessage: true,
        );
      } else {
        state = state.copyWith(
          routineRefreshPending: true,
          routineRefreshMessage: WorkSetupErrorMapper.mapRefreshError(
            refreshOutcome.message,
          ),
        );
      }
    } catch (e) {
      if (!_isActiveOwner(uid)) return;
      state = state.copyWith(
        routineRefreshPending: true,
        routineRefreshMessage: WorkSetupErrorMapper.mapRefreshError(e),
      );
    }
  }

  /// Discards local conflict working blocks and reloads latest canonical setup.
  void reloadFromCanonical(BaseTimelineSetup setup) {
    retireUncommittedWorkAssets(uid: _ownerUid);
    final normalizedDay = normalizeSelectedWorkDay(
      currentDay: state.selectedDay,
      blocks: setup.workBlocks,
    );
    state = state.copyWith(
      stage: setup.workBlocks.isNotEmpty
          ? WorkSetupStage.review
          : WorkSetupStage.currentSetup,
      workingBlocks: List<TimelineBlockDraft>.from(setup.workBlocks),
      editorBaseRevision: setup.revision,
      baseCommittedAssetId: setup.workLogicalAssetId,
      baseCommittedR2Key: setup.workLogicalAssetR2Key,
      workingAssetId: setup.workLogicalAssetId,
      clearWorkingAssetId: setup.workLogicalAssetId == null,
      workingR2Key: setup.workLogicalAssetR2Key,
      clearWorkingR2Key: setup.workLogicalAssetR2Key == null,
      clearCandidateAssetId: true,
      clearCandidateR2Key: true,
      selectedDay: normalizedDay,
      isDirty: false,
      droppedCount: 0,
      droppedExamples: const [],
      clearErrorMessage: true,
      clearErrorKind: true,
      clearFrontBlockId: true,
      isConcurrencyConflict: false,
    );
  }

  @visibleForTesting
  void setWorkingAssetsForTesting({
    String? workingAssetId,
    String? workingR2Key,
    String? candidateAssetId,
    String? candidateR2Key,
  }) {
    state = state.copyWith(
      workingAssetId: workingAssetId,
      workingR2Key: workingR2Key,
      candidateAssetId: candidateAssetId,
      candidateR2Key: candidateR2Key,
    );
  }

  void clearError() {
    state = state.copyWith(
      clearErrorMessage: true,
      clearErrorKind: true,
      isConcurrencyConflict: false,
    );
  }

  void dismissSuccess() {
    state = state.copyWith(stage: WorkSetupStage.currentSetup);
  }

  Future<void> resetWorkingDraft(
    BaseTimelineSetup? setup, {
    required String uid,
  }) async {
    if (!_isActiveOwner(uid)) return;
    retireUncommittedWorkAssets(uid: uid);

    state = state.copyWith(
      stage: WorkSetupStage.currentSetup,
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
      clearErrorKind: true,
      clearFrontBlockId: true,
      clearEditorBaseRevision: true,
      clearBaseCommittedAssetId: true,
      clearBaseCommittedR2Key: true,
      isConcurrencyConflict: false,
    );
  }

  void _retireCandidate() {
    final candidateId = state.candidateAssetId;
    final candidateKey = state.candidateR2Key;
    if ((candidateId != null && candidateId != state.baseCommittedAssetId) ||
        (candidateKey != null && candidateKey != state.baseCommittedR2Key)) {
      _retireUncommittedBestEffort(
        uid: _ownerUid,
        assetId: candidateId,
        objectKey: candidateKey,
      );
    }
  }
}

final workSetupControllerProvider =
    StateNotifierProvider.autoDispose<WorkSetupController, WorkSetupState>((
      ref,
    ) {
      final uid = ref.watch(userProfileProvider.select((p) => p.uid));
      final coordinator = ref.watch(baseTimelineTransactionCoordinatorProvider);
      final lifecycleHelper = ref.watch(
        baseTimelineUploadLifecycleHelperProvider,
      );
      return WorkSetupController(
        ref: ref,
        ownerUid: uid,
        coordinator: coordinator,
        lifecycleHelper: lifecycleHelper,
      );
    });
