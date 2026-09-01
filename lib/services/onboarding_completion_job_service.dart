import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/conflict_acceptance_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/onboarding_run_identity.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';

import 'package:optivus/services/background_sync_wake_lock_manager.dart';
import 'package:optivus/services/completion_terminalization_proof.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Injectable persistence used by non-Firestore environments.
///
/// Tests may retain this store while destroying and recreating completion
/// services to model a cold process restart against the same durable backend.
/// Production Firebase execution continues to use Firestore exclusively.
class OnboardingCompletionMemoryStore {
  final Map<String, OnboardingCompletionJob> jobs = {};
  final Map<String, String> currentRunIds = {};
  final Map<String, String> currentRunStatuses = {};
}

/// Read-only view of the durable `currentRun` pointer and its referenced job.
///
/// Keeping pointer existence separate from [job] lets session reconstruction
/// distinguish "no completion run" from a dangling/corrupt reference.
class OnboardingCurrentRunSnapshot {
  final bool hasPointer;
  final String? runId;
  final String? ownerUid;
  final int? pointerSchemaVersion;
  final String? pointerStatus;
  final String? sourceFingerprint;
  final int? draftRevision;
  final OnboardingCompletionJob? job;

  const OnboardingCurrentRunSnapshot({
    required this.hasPointer,
    this.runId,
    this.ownerUid,
    this.pointerSchemaVersion,
    this.pointerStatus,
    this.sourceFingerprint,
    this.draftRevision,
    this.job,
  });

  const OnboardingCurrentRunSnapshot.none()
    : hasPointer = false,
      runId = null,
      ownerUid = null,
      pointerSchemaVersion = null,
      pointerStatus = null,
      sourceFingerprint = null,
      draftRevision = null,
      job = null;

  CompletionTerminalizationState toTerminalizationState() {
    return CompletionTerminalizationState(
      hasPointer: hasPointer,
      runId: runId,
      ownerUid: ownerUid,
      pointerSchemaVersion: pointerSchemaVersion,
      pointerStatus: pointerStatus,
      sourceFingerprint: sourceFingerprint,
      draftRevision: draftRevision,
      job: job,
    );
  }
}

class OnboardingCompletionJobService {
  final OnboardingRepository onboardingRepository;
  final ProfileRepository profileRepository;
  final RoutineRepository? routineRepository;
  final ConflictAcceptanceRepository? conflictAcceptanceRepository;
  final FirebaseFirestore? firestore;
  final SystemWakeLock wakeLock;
  final bool requirePersistentJobs;
  final bool requireFrontendHydration;
  final bool requireRoutineVerification;
  final OnboardingCompletionMemoryStore _memoryStore;

  final Map<String, Future<OnboardingCompletionJob>> _inFlight = {};
  final Map<String, int> _operationGenerationByOwner = {};

  void cancelAll() {
    for (final owner in _operationGenerationByOwner.keys.toList()) {
      _operationGenerationByOwner[owner] =
          (_operationGenerationByOwner[owner] ?? 0) + 1;
    }
    _inFlight.clear();
  }

  void cancelOwner(String uid) {
    _operationGenerationByOwner[uid] =
        (_operationGenerationByOwner[uid] ?? 0) + 1;
    _inFlight.removeWhere((key, _) => key.startsWith('$uid:'));
  }

  OnboardingCompletionJobService({
    required this.onboardingRepository,
    required this.profileRepository,
    this.routineRepository,
    this.conflictAcceptanceRepository,
    this.firestore,
    this.requirePersistentJobs = false,
    this.requireFrontendHydration = false,
    this.requireRoutineVerification = false,
    OnboardingCompletionMemoryStore? memoryStore,
    SystemWakeLock? wakeLock,
  }) : _memoryStore = memoryStore ?? OnboardingCompletionMemoryStore(),
       wakeLock = wakeLock ?? DefaultSystemWakeLock();

  Future<OnboardingCompletionJob> runCompletionJob({
    required String uid,
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('Cannot run completion job with empty uid.');
    }
    final runId = bundle.runId.isNotEmpty
        ? bundle.runId
        : stableOnboardingRunId(
            ownerUid: uid,
            sourceFingerprint: bundle.effectiveSourceFingerprint,
            draftRevision: finalDraft.revision,
          );
    final operationKey = '$uid:$runId';
    final activeOperation = _inFlight[operationKey];
    if (activeOperation != null) return activeOperation;
    final operationGeneration = (_operationGenerationByOwner[uid] ?? 0) + 1;
    _operationGenerationByOwner[uid] = operationGeneration;
    final authGeneration = reader == null
        ? null
        : reader(authGenerationProvider);

    final operation = _runCompletionJob(
      uid: uid,
      finalDraft: finalDraft,
      bundle: bundle,
      sourceFingerprint: bundle.effectiveSourceFingerprint,
      runId: runId,
      operationGeneration: operationGeneration,
      authGeneration: authGeneration,
      reader: reader,
    );
    _inFlight[operationKey] = operation;
    operation.then<void>(
      (_) {
        if (identical(_inFlight[operationKey], operation)) {
          _inFlight.remove(operationKey);
        }
      },
      onError: (error, stackTrace) {
        if (identical(_inFlight[operationKey], operation)) {
          _inFlight.remove(operationKey);
        }
      },
    );
    return operation;
  }

  Future<OnboardingCompletionJob?> loadCurrentJob(String uid) {
    if (uid.trim().isEmpty) return Future.value(null);
    return _loadCurrentJob(uid);
  }

  Future<OnboardingCurrentRunSnapshot> loadCurrentRunSnapshot(String uid) {
    if (uid.trim().isEmpty) {
      return Future.value(const OnboardingCurrentRunSnapshot.none());
    }
    return _loadCurrentRunSnapshot(uid);
  }

  Future<OnboardingCompletionJob> _runCompletionJob({
    required String uid,
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    required String sourceFingerprint,
    required String runId,
    required int operationGeneration,
    required int? authGeneration,
    Reader? reader,
  }) async {
    return runWithWakeLock<OnboardingCompletionJob>(
      tag: 'onboarding_completion_$uid',
      wakeLock: wakeLock,
      syncTask: () async {
        final now = DateTime.now();
        var job = await _loadOrCreateJob(
          uid: uid,
          sourceFingerprint: sourceFingerprint,
          runId: runId,
          draftRevision: finalDraft.revision,
          now: now,
        );
        if (job.status == OnboardingJobStatus.fatalFailure) {
          throw StateError(
            'A fatally failed completion run cannot be terminalized.',
          );
        }
        if (job.status == OnboardingJobStatus.completed &&
            job.stage == OnboardingCompletionStage.completed) {
          await _verifyDurableCompletionOutputs(
            uid: uid,
            bundle: bundle,
            reader: reader,
          );
          return await _terminalizeCompletion(
            uid: uid,
            expectedRunId: runId,
            draft: finalDraft,
            bundle: bundle,
            durableOutputsVerified: true,
          );
        }

        job = job.copyWith(
          status: OnboardingJobStatus.running,
          updatedAt: now,
          clearLastError: true,
          clearLastFailure: true,
        );
        await _saveJobStatus(job, activate: true);

        void checkSession() {
          if (operationGeneration != _operationGenerationByOwner[uid]) {
            throw StateError('Job cancelled by a newer operation.');
          }
          if (uid.trim().isEmpty) {
            throw StateError(
              'Job cancelled due to invalid or empty authenticated UID.',
            );
          }
          if (reader != null) {
            if (reader(authGenerationProvider) != authGeneration) {
              throw StateError(
                'Job cancelled because the authenticated session changed.',
              );
            }
            final profile = reader(mockUserProfileProvider);
            if (profile.uid.trim().isEmpty || profile.uid != uid) {
              throw StateError(
                'Job cancelled due to sign-out or account switch.',
              );
            }
          }
        }

        try {
          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.validateInput)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.validateInput,
            );
            _validateCompletionInput(uid, finalDraft, bundle);
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.validateInput,
            );
          }

          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.persistDraft)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.persistDraft,
            );
            await onboardingRepository.flushPendingDraftSave();
            await onboardingRepository.saveFinalDraftImmediately(finalDraft);
            await onboardingRepository.flushPendingDraftSave();
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.persistDraft,
            );
          }

          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.verifyDraft)) {
            job = await _beginStage(job, OnboardingCompletionStage.verifyDraft);
            final readbackDraft = await onboardingRepository.fetchDraft(uid);
            _verifyFinalDraft(readbackDraft, finalDraft);
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.verifyDraft,
            );
          }

          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.persistBundle)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.persistBundle,
            );
            await onboardingRepository.saveCompletionBundle(bundle);
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.persistBundle,
            );
          }

          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.verifyBundle)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.verifyBundle,
            );
            final readbackBundle = await onboardingRepository
                .fetchCompletionBundle(uid);
            _verifyCompletionBundle(readbackBundle, bundle);
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.verifyBundle,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.reconcileRoutines,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.reconcileRoutines,
            );
            final result = await onboardingRepository.completeOnboarding(
              finalDraft: finalDraft,
              bundle: bundle,
            );
            final receipt = result.receipt;
            final acceptancePlan = RoutineOnboardingProjection.build(bundle);
            final storedAcceptances =
                await (reader == null
                        ? conflictAcceptanceRepository
                        : reader(conflictAcceptanceRepositoryProvider))
                    ?.fetchForOwner(uid);
            final expectedAcceptances = acceptancePlan.conflictAcceptances;
            final validAcceptanceIds = <String>[];
            final failedAcceptanceIds = <String>[];
            for (final expected in expectedAcceptances) {
              final actual = storedAcceptances
                  ?.where(
                    (candidate) =>
                        candidate.acceptanceId == expected.acceptanceId,
                  )
                  .firstOrNull;
              if (actual != null &&
                  _matchesExpectedAcceptance(actual, expected)) {
                validAcceptanceIds.add(expected.acceptanceId);
              } else {
                failedAcceptanceIds.add(expected.acceptanceId);
              }
            }
            job = job.copyWith(
              expectedRoutineIds: receipt.expectedItemIds,
              appliedRoutineIds: receipt.createdItemIds,
              existingRoutineIds: receipt.existingItemIds,
              repairedRoutineIds: receipt.repairedItemIds,
              failedRoutineIds: receipt.failedItemIds,
              expectedAcceptanceIds: expectedAcceptances
                  .map((acceptance) => acceptance.acceptanceId)
                  .toList(),
              appliedAcceptanceIds:
                  result.outcome == RoutineProjectionOutcome.projected
                  ? validAcceptanceIds
                  : const [],
              existingAcceptanceIds:
                  result.outcome == RoutineProjectionOutcome.noOp
                  ? validAcceptanceIds
                  : const [],
              failedAcceptanceIds: failedAcceptanceIds,
            );
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.reconcileRoutines,
            );
          }

          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.verifyRoutines)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.verifyRoutines,
            );
            await _verifyRoutineProjection(
              uid: uid,
              bundle: bundle,
              reader: reader,
            );
            if (job.failedRoutineIds.isNotEmpty ||
                !_sameIds(job.expectedRoutineIds, <String>{
                  ...job.appliedRoutineIds,
                  ...job.existingRoutineIds,
                  ...job.repairedRoutineIds,
                }) ||
                job.failedAcceptanceIds.isNotEmpty ||
                !_sameIds(job.expectedAcceptanceIds, <String>{
                  ...job.appliedAcceptanceIds,
                  ...job.existingAcceptanceIds,
                  ...job.repairedAcceptanceIds,
                })) {
              throw StateError('Routine accounting verification failed.');
            }
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.verifyRoutines,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.projectRoutineHistory,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.projectRoutineHistory,
            );
            final historyResult = await _projectRoutineHistory(
              bundle: bundle,
              reader: reader,
            );
            job = job.copyWith(
              expectedHistoryIds: historyResult.expectedEventIds,
              appliedHistoryIds: historyResult.appliedEventIds,
              existingHistoryIds: historyResult.existingEventIds,
              repairedHistoryIds: historyResult.repairedEventIds,
              failedHistoryIds: historyResult.failedEventIds,
            );
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.projectRoutineHistory,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.verifyRoutineHistory,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.verifyRoutineHistory,
            );
            if (job.failedHistoryIds.isNotEmpty ||
                !_sameIds(job.expectedHistoryIds, <String>{
                  ...job.appliedHistoryIds,
                  ...job.existingHistoryIds,
                  ...job.repairedHistoryIds,
                })) {
              throw StateError(
                'Routine History read-back verification failed.',
              );
            }
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.verifyRoutineHistory,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.reconcileHabitSystems,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.reconcileHabitSystems,
            );
            if (reader == null) {
              if (requireFrontendHydration) {
                throw StateError(
                  'Onboarding frontend hydration dependency is required.',
                );
              }
            } else {
              final hydration = await const OnboardingFrontendHydrationService()
                  .hydrate(read: reader, bundle: bundle);
              job = job.copyWith(
                expectedHabitIds: hydration.expectedHabitSystemIds,
                appliedHabitIds: hydration.createdHabitSystemIds,
                existingHabitIds: hydration.existingHabitSystemIds,
                repairedHabitIds: hydration.repairedHabitSystemIds,
                failedHabitIds: hydration.failedHabitSystemIds,
              );
            }
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.reconcileHabitSystems,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.verifyHabitSystems,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.verifyHabitSystems,
            );
            if (job.failedHabitIds.isNotEmpty ||
                !_sameIds(job.expectedHabitIds, <String>{
                  ...job.appliedHabitIds,
                  ...job.existingHabitIds,
                  ...job.repairedHabitIds,
                })) {
              throw StateError('Habit-system read-back verification failed.');
            }
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.verifyHabitSystems,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.reloadControllers,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.reloadControllers,
            );
            if (reader != null) {
              await const OnboardingFrontendHydrationService()
                  .reloadControllers(read: reader, bundle: bundle);
            }
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.reloadControllers,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.verifyFrontendState,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.verifyFrontendState,
            );
            if (reader != null) {
              const OnboardingFrontendHydrationService().verifyFrontendState(
                read: reader,
                bundle: bundle,
              );
            }
            job = await _markStageCompleted(
              job,
              OnboardingCompletionStage.verifyFrontendState,
            );
          }

          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.finalizeProfile,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.finalizeProfile,
            );
            _verifyFinalizationAccounting(job);
          }

          checkSession();
          await _verifyDurableCompletionOutputs(
            uid: uid,
            bundle: bundle,
            reader: reader,
          );
          return await _terminalizeCompletion(
            uid: uid,
            expectedRunId: runId,
            draft: finalDraft,
            bundle: bundle,
            durableOutputsVerified: true,
          );
        } catch (e) {
          final now = DateTime.now();
          final failure = _buildSanitizedFailure(e, job.stage);
          job = job.copyWith(
            status: failure.retryable
                ? OnboardingJobStatus.retryableFailure
                : OnboardingJobStatus.fatalFailure,
            retryCount: job.retryCount + 1,
            lastError: failure.toJsonString(),
            lastFailureCode: failure.failureCode,
            lastFailureStage: failure.stage,
            retryable: failure.retryable,
            publicMessageKey: failure.publicMessageKey,
            diagnosticCategory: failure.diagnosticCategory,
            safeCauseType: failure.errorType,
            failedEntityIds: failure.failedEntityIds,
            lastFailureOccurredAt: now,
          );
          await _saveJobStatus(job);
          rethrow;
        }
      },
    );
  }

  void _validateCompletionInput(
    String uid,
    OnboardingDraft draft,
    OnboardingCompletionBundle bundle,
  ) {
    if (draft.uid != uid || bundle.uid != uid) {
      throw ArgumentError('Completion input owner mismatch.');
    }
    if (!draft.onboardingCompleted ||
        draft.currentStep != OnboardingDraft.lastStepIndex ||
        draft.stepCompleted.length != OnboardingDraft.stepCount ||
        draft.stepCompleted.any((value) => !value)) {
      throw ArgumentError('Final onboarding draft is incomplete.');
    }
    if (bundle.sourceFingerprint != draft.effectiveSourceFingerprint ||
        bundle.draftRevision != draft.revision ||
        bundle.version != OnboardingCompletionBundle.schemaVersion) {
      throw ArgumentError('Completion bundle does not match the final draft.');
    }
  }

  void _verifyFinalDraft(OnboardingDraft? actual, OnboardingDraft expected) {
    if (actual == null ||
        actual.uid != expected.uid ||
        actual.revision != expected.revision ||
        actual.effectiveSourceFingerprint !=
            expected.effectiveSourceFingerprint ||
        actual.onboardingCompleted != expected.onboardingCompleted ||
        actual.currentStep != expected.currentStep ||
        actual.stepCompleted.length != OnboardingDraft.stepCount ||
        actual.stepCompleted.any((value) => !value) ||
        actual.toMap()['schemaVersion'] != OnboardingDraft.schemaVersion) {
      throw StateError('Final draft read-back verification failed.');
    }
  }

  void _verifyCompletionBundle(
    OnboardingCompletionBundle? actual,
    OnboardingCompletionBundle expected,
  ) {
    if (actual == null ||
        actual.uid != expected.uid ||
        actual.version != expected.version ||
        actual.sourceFingerprint != expected.sourceFingerprint ||
        actual.draftRevision != expected.draftRevision ||
        !_sameIds(actual.expectedRoutineIds, expected.expectedRoutineIds) ||
        !_sameIds(actual.expectedHistoryIds, expected.expectedHistoryIds) ||
        !_sameIds(actual.expectedHabitIds, expected.expectedHabitIds) ||
        !_sameIds(actual.acceptedSourceIds, expected.acceptedSourceIds) ||
        !_sameIds(actual.generatedSourceIds, expected.generatedSourceIds) ||
        !_sameIds(
          actual.expectedAcceptanceIds,
          expected.expectedAcceptanceIds,
        ) ||
        !_sameIds(
          actual.conflictAcceptances.map((item) => item.acceptanceId),
          expected.conflictAcceptances.map((item) => item.acceptanceId),
        )) {
      throw StateError('Completion bundle read-back verification failed.');
    }
  }

  Future<void> _verifyDurableCompletionOutputs({
    required String uid,
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    await _verifyRoutineProjectionReadOnly(
      uid: uid,
      bundle: bundle,
      reader: reader,
    );
    if (reader != null) {
      await const RoutineOnboardingEventProjector().verifyProjectedHistory(
        read: reader,
        bundle: bundle,
      );
      await const OnboardingFrontendHydrationService()
          .verifyPersistedHabitSystems(read: reader, bundle: bundle);
      return;
    }
    if (requireRoutineVerification &&
        (bundle.expectedHistoryIds.isNotEmpty ||
            bundle.expectedHabitIds.isNotEmpty)) {
      throw StateError(
        'Durable history and habit verification dependencies are required.',
      );
    }
  }

  Future<void> _verifyRoutineProjectionReadOnly({
    required String uid,
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final activeRepository = reader != null
        ? reader(routineRepositoryProvider)
        : routineRepository;
    if (activeRepository == null) {
      if (requireRoutineVerification) {
        throw StateError('Routine repository is required for verification.');
      }
      return;
    }
    final receipt = await activeRepository.fetchProjectionReceipt(
      uid,
      plan.projectionId,
    );
    final items = await activeRepository.fetchRoutineItems(uid);
    final validation = const RoutineProjectionReceiptValidator().validate(
      receipt: receipt,
      actualItems: items,
      ownerUid: uid,
      plan: plan,
    );
    if (receipt == null ||
        receipt.status != 'completed' ||
        receipt.cursor != receipt.totalCount ||
        !validation.isValid) {
      throw StateError('Routine projection terminal verification failed.');
    }
    final acceptanceRepository = reader != null
        ? reader(conflictAcceptanceRepositoryProvider)
        : conflictAcceptanceRepository;
    if (acceptanceRepository == null) {
      if (bundle.expectedAcceptanceIds.isNotEmpty) {
        throw StateError(
          'Conflict acceptance repository is required for verification.',
        );
      }
      return;
    }
    final stored = await acceptanceRepository.fetchForOwner(uid);
    final byId = {
      for (final acceptance in stored) acceptance.acceptanceId: acceptance,
    };
    for (final expected in plan.conflictAcceptances) {
      final actual = byId[expected.acceptanceId];
      if (actual == null || !_matchesExpectedAcceptance(actual, expected)) {
        throw StateError('Conflict acceptance terminal verification failed.');
      }
    }
  }

  Future<OnboardingCompletionJob> _terminalizeCompletion({
    required String uid,
    required String expectedRunId,
    required OnboardingDraft draft,
    required OnboardingCompletionBundle bundle,
    required bool durableOutputsVerified,
  }) async {
    if (firestore == null) {
      final profile = await profileRepository.fetchUserProfile(uid);
      final currentRun = await _loadCurrentRunSnapshot(uid);
      if (profile == null) {
        throw StateError('Root UserProfile is required for finalization.');
      }
      final proofBundleMap = Map<String, dynamic>.from(bundle.toMap());
      if (bundle.runId.isEmpty) proofBundleMap['runId'] = expectedRunId;
      // Non-persistent test repositories predate contract metadata. Production
      // Firestore bundles cannot omit these fields under the schema-v2 rules.
      proofBundleMap['expectedRoutineIds'] = currentRun.job!.expectedRoutineIds;
      proofBundleMap['expectedHistoryIds'] = currentRun.job!.expectedHistoryIds;
      proofBundleMap['expectedHabitIds'] = currentRun.job!.expectedHabitIds;
      proofBundleMap['expectedAcceptanceIds'] =
          currentRun.job!.expectedAcceptanceIds;
      final proofBundle = OnboardingCompletionBundle.fromMap(proofBundleMap);
      final proof = CompletionTerminalizationProof.evaluate(
        authenticatedUid: uid,
        expectedRunId: expectedRunId,
        profile: profile,
        draft: draft,
        bundle: proofBundle,
        currentRun: currentRun.toTerminalizationState(),
        durableOutputsVerified: durableOutputsVerified,
      );
      if (proof.disposition ==
          CompletionTerminalizationDisposition.alreadyTerminal) {
        return currentRun.job!;
      }
      if (!proof.canTerminalize) {
        throw StateError(
          'Completion terminalization proof failed: ${proof.reason.name}.',
        );
      }
      final now = DateTime.now();
      final persistedJob = currentRun.job!;
      final completedJob = persistedJob.status == OnboardingJobStatus.completed
          ? persistedJob
          : _completedJob(persistedJob, now);
      final completedProfile = profile.copyWith(
        onboardingInputCompleted: true,
        onboardingProjectionStatus: 'completed',
        onboardingCompleted: true,
        updatedAt: now,
      );
      await profileRepository.saveUserProfile(completedProfile);
      _memoryStore.jobs['$uid:$expectedRunId'] = completedJob;
      _memoryStore.currentRunIds[uid] = expectedRunId;
      _memoryStore.currentRunStatuses[uid] = 'completed';
      return completedJob;
    }

    try {
      return await firestore!.runTransaction<OnboardingCompletionJob>((
        tx,
      ) async {
        final profileRef = firestore!.doc(FirestoreUserPaths.user(uid));
        final pointerRef = firestore!.doc(
          FirestoreUserPaths.onboardingCurrentRun(uid),
        );
        final runRef = firestore!.doc(
          FirestoreUserPaths.onboardingRun(uid, expectedRunId),
        );
        final draftRef = firestore!.doc(
          FirestoreUserPaths.onboardingDraft(uid),
        );
        final bundleRef = firestore!.doc(
          FirestoreUserPaths.onboardingCompletionBundle(uid),
        );

        // Firestore requires every transaction read to precede its writes.
        final profileDoc = await tx.get(profileRef);
        final pointerDoc = await tx.get(pointerRef);
        final runDoc = await tx.get(runRef);
        final draftDoc = await tx.get(draftRef);
        final bundleDoc = await tx.get(bundleRef);
        final profileData = profileDoc.data();
        final pointerData = pointerDoc.data();
        final runData = runDoc.data();
        final draftData = draftDoc.data();
        final bundleData = bundleDoc.data();
        if (profileData == null ||
            pointerData == null ||
            runData == null ||
            draftData == null ||
            bundleData == null) {
          throw StateError('Terminalization control document is missing.');
        }
        final persistedProfile = UserProfile.fromFirestoreMap(profileData);
        final persistedDraft = OnboardingDraft.fromMap(draftData);
        final persistedBundle = OnboardingCompletionBundle.fromMap(bundleData);
        final persistedJob = OnboardingCompletionJob.fromMap(runData);
        final currentRun = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: pointerData['currentRunId'] as String?,
          ownerUid: pointerData['ownerUid'] as String?,
          pointerSchemaVersion: (pointerData['schemaVersion'] as num?)?.toInt(),
          pointerStatus: pointerData['status'] as String?,
          sourceFingerprint: pointerData['sourceFingerprint'] as String?,
          draftRevision: (pointerData['draftRevision'] as num?)?.toInt(),
          job: persistedJob,
        );
        final proof = CompletionTerminalizationProof.evaluate(
          authenticatedUid: uid,
          expectedRunId: expectedRunId,
          profile: persistedProfile,
          draft: persistedDraft,
          bundle: persistedBundle,
          currentRun: currentRun.toTerminalizationState(),
          durableOutputsVerified: durableOutputsVerified,
        );
        if (proof.disposition ==
            CompletionTerminalizationDisposition.alreadyTerminal) {
          return persistedJob;
        }
        if (!proof.canTerminalize) {
          throw StateError(
            'Completion terminalization proof failed: ${proof.reason.name}.',
          );
        }

        final now = DateTime.now();
        final completedJob =
            persistedJob.status == OnboardingJobStatus.completed
            ? persistedJob
            : _completedJob(persistedJob, now);
        final completedProfile = persistedProfile.copyWith(
          onboardingInputCompleted: true,
          onboardingProjectionStatus: 'completed',
          onboardingCompleted: true,
          updatedAt: now,
        );
        if (persistedJob.status != OnboardingJobStatus.completed) {
          tx.set(profileRef, completedProfile.toFirestoreMap());
          tx.set(runRef, completedJob.toFirestoreMap());
        }
        tx.set(pointerRef, _runPointerMap(completedJob, status: 'completed'));
        return completedJob;
      });
    } catch (_) {
      // A lost response is ambiguous. Resolve it by authoritative reread before
      // allowing the caller to retry or display a failure.
      final profile = await profileRepository.fetchUserProfile(uid);
      final currentRun = await _loadCurrentRunSnapshot(uid);
      if (profile != null && currentRun.job != null) {
        final proof = CompletionTerminalizationProof.evaluate(
          authenticatedUid: uid,
          expectedRunId: expectedRunId,
          profile: profile,
          draft: draft,
          bundle: bundle,
          currentRun: currentRun.toTerminalizationState(),
          durableOutputsVerified: durableOutputsVerified,
        );
        if (proof.disposition ==
            CompletionTerminalizationDisposition.alreadyTerminal) {
          return currentRun.job!;
        }
      }
      rethrow;
    }
  }

  OnboardingCompletionJob _completedJob(
    OnboardingCompletionJob job,
    DateTime completedAt,
  ) {
    final stages = Map<String, bool>.from(job.stagesCompleted)
      ..[OnboardingCompletionStage.finalizeProfile.name] = true;
    return job.copyWith(
      status: OnboardingJobStatus.completed,
      stage: OnboardingCompletionStage.completed,
      stagesCompleted: stages,
      updatedAt: completedAt,
      completedAt: completedAt,
      clearLastError: true,
      clearLastFailure: true,
    );
  }

  Future<void> _verifyRoutineProjection({
    required String uid,
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final activeRepository = reader != null
        ? reader(routineRepositoryProvider)
        : routineRepository;
    if (activeRepository == null) {
      if (requireRoutineVerification) {
        throw StateError('Routine repository is required for verification.');
      }
      return;
    }
    var receipt = await activeRepository.fetchProjectionReceipt(
      uid,
      plan.projectionId,
    );
    if (receipt == null ||
        receipt.sourceBundleFingerprint != plan.fingerprint) {
      throw StateError('Routine projection receipt verification failed.');
    }
    final items = await activeRepository.fetchRoutineItems(uid);
    var validation = const RoutineProjectionReceiptValidator().validate(
      receipt: receipt,
      actualItems: items,
      ownerUid: uid,
      plan: plan,
    );
    if (!validation.isValid) {
      throw StateError('Routine projection document verification failed.');
    }
    final acceptanceRepository = reader != null
        ? reader(conflictAcceptanceRepositoryProvider)
        : conflictAcceptanceRepository;
    if (acceptanceRepository == null) {
      if (bundle.expectedAcceptanceIds.isNotEmpty) {
        throw StateError(
          'Conflict acceptance repository is required for verification.',
        );
      }
      return;
    }
    final storedAcceptances = await acceptanceRepository.fetchForOwner(uid);
    final storedById = {
      for (final acceptance in storedAcceptances)
        acceptance.acceptanceId: acceptance,
    };
    for (final expected in plan.conflictAcceptances) {
      final actual = storedById[expected.acceptanceId];
      if (actual == null || !_matchesExpectedAcceptance(actual, expected)) {
        throw StateError('Conflict acceptance read-back verification failed.');
      }
    }
    if (receipt.status != 'completed' || receipt.cursor != receipt.totalCount) {
      final finalizer = onboardingRepository;
      if (receipt.status != 'pending' ||
          finalizer is! RoutineProjectionReceiptFinalizer) {
        throw StateError('Routine projection receipt verification failed.');
      }
      await (finalizer as RoutineProjectionReceiptFinalizer)
          .finalizeRoutineProjectionReceipt(bundle: bundle);
      receipt = await activeRepository.fetchProjectionReceipt(
        uid,
        plan.projectionId,
      );
      validation = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: items,
        ownerUid: uid,
        plan: plan,
      );
      if (receipt == null ||
          receipt.status != 'completed' ||
          receipt.cursor != receipt.totalCount ||
          !validation.isValid) {
        throw StateError('Routine projection receipt verification failed.');
      }
    }
  }

  Future<RoutineOnboardingEventProjectionResult> _projectRoutineHistory({
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    if (reader != null) {
      return const RoutineOnboardingEventProjector().projectCreatedEvents(
        read: reader,
        bundle: bundle,
      );
    }
    if (requireRoutineVerification) {
      throw StateError(
        'History repository reader is required for verification.',
      );
    }
    final ids = const RoutineOnboardingEventProjector().computeExpectedEventIds(
      bundle,
    );
    return RoutineOnboardingEventProjectionResult(
      projectionId: RoutineOnboardingProjection.build(bundle).projectionId,
      attemptedCount: 0,
      expectedEventIds: ids,
      appliedEventIds: ids,
    );
  }

  void _verifyFinalizationAccounting(OnboardingCompletionJob job) {
    if (!job.isStageCompleted(OnboardingCompletionStage.verifyDraft) ||
        !job.isStageCompleted(OnboardingCompletionStage.verifyBundle) ||
        !job.isStageCompleted(OnboardingCompletionStage.verifyRoutines) ||
        !job.isStageCompleted(OnboardingCompletionStage.verifyRoutineHistory) ||
        !job.isStageCompleted(OnboardingCompletionStage.verifyHabitSystems) ||
        !job.isStageCompleted(OnboardingCompletionStage.verifyFrontendState) ||
        job.failedRoutineIds.isNotEmpty ||
        job.failedHistoryIds.isNotEmpty ||
        job.failedHabitIds.isNotEmpty ||
        job.failedAcceptanceIds.isNotEmpty ||
        !_sameIds(job.expectedAcceptanceIds, <String>{
          ...job.appliedAcceptanceIds,
          ...job.existingAcceptanceIds,
          ...job.repairedAcceptanceIds,
        })) {
      throw StateError('Profile finalization prerequisites are incomplete.');
    }
  }

  bool _sameIds(Iterable<String> left, Iterable<String> right) {
    final a = left.toSet();
    final b = right.toSet();
    return a.length == b.length && a.containsAll(b);
  }

  bool _matchesExpectedAcceptance(
    ConflictAcceptance actual,
    ConflictAcceptance expected,
  ) {
    return actual.ownerUid == expected.ownerUid &&
        actual.acceptanceId == expected.acceptanceId &&
        actual.canonicalPairHash == expected.canonicalPairHash &&
        actual.firstProjectedRoutineId == expected.firstProjectedRoutineId &&
        actual.secondProjectedRoutineId == expected.secondProjectedRoutineId &&
        actual.combinedScheduleFingerprint ==
            expected.combinedScheduleFingerprint &&
        actual.sourceBundleFingerprint == expected.sourceBundleFingerprint &&
        actual.projectionId == expected.projectionId &&
        actual.status == expected.status &&
        actual.schemaVersion == expected.schemaVersion;
  }

  OnboardingCompletionJob _stageCompletedCopy(
    OnboardingCompletionJob job,
    OnboardingCompletionStage stage,
  ) {
    final completed = Map<String, bool>.from(job.stagesCompleted)
      ..[stage.name] = true;
    return job.copyWith(stagesCompleted: completed, updatedAt: DateTime.now());
  }

  Future<OnboardingCompletionJob> _markStageCompleted(
    OnboardingCompletionJob job,
    OnboardingCompletionStage stage,
  ) async {
    final next = _stageCompletedCopy(job, stage);
    await _saveJobStatus(next);
    return next;
  }

  Future<OnboardingCompletionJob> _loadOrCreateJob({
    required String uid,
    required String sourceFingerprint,
    required String runId,
    required int draftRevision,
    required DateTime now,
  }) async {
    final existing = await _loadJobStatus(uid, runId);
    if (existing == null) {
      return OnboardingCompletionJob(
        jobId: runId,
        uid: uid,
        status: OnboardingJobStatus.pending,
        stage: OnboardingCompletionStage.init,
        stagesCompleted: const {},
        sourceFingerprint: sourceFingerprint,
        draftRevision: draftRevision,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );
    }

    if (existing.uid != uid) {
      throw StateError('Persisted onboarding completion job owner mismatch.');
    }
    if (existing.jobId != runId ||
        existing.schemaVersion !=
            OnboardingCompletionJob.currentSchemaVersion) {
      throw StateError('Unsupported onboarding completion job schema version.');
    }
    if (existing.sourceFingerprint != sourceFingerprint ||
        existing.draftRevision != draftRevision) {
      throw StateError('Onboarding run identity collision.');
    }
    return existing.copyWith(updatedAt: now);
  }

  Future<OnboardingCompletionJob> _beginStage(
    OnboardingCompletionJob job,
    OnboardingCompletionStage stage,
  ) async {
    if (job.stage.index > stage.index &&
        job.stage != OnboardingCompletionStage.completed) {
      throw StateError(
        'Monotonicity violation: Cannot move back from ${job.stage.name} to ${stage.name}',
      );
    }
    if (stage.index > 1) {
      final prevStage = OnboardingCompletionStage.values[stage.index - 1];
      if (!job.isStageCompleted(prevStage)) {
        throw StateError(
          'Monotonicity violation: Cannot skip to ${stage.name} because ${prevStage.name} is incomplete.',
        );
      }
    }
    final next = job.copyWith(
      status: OnboardingJobStatus.running,
      stage: stage,
      updatedAt: DateTime.now(),
      clearLastError: true,
    );
    await _saveJobStatus(next);
    return next;
  }

  Future<OnboardingCompletionJob?> _loadCurrentJob(String uid) async {
    final snapshot = await _loadCurrentRunSnapshot(uid);
    return snapshot.job;
  }

  Future<OnboardingCurrentRunSnapshot> _loadCurrentRunSnapshot(
    String uid,
  ) async {
    if (firestore != null) {
      final pointer = await firestore!
          .doc(FirestoreUserPaths.onboardingCurrentRun(uid))
          .get();
      final pointerData = pointer.data();
      final runId = pointerData?['currentRunId'] as String?;
      if (runId != null && runId.isNotEmpty) {
        return OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: runId,
          ownerUid: pointerData?['ownerUid'] as String?,
          pointerSchemaVersion: (pointerData?['schemaVersion'] as num?)
              ?.toInt(),
          pointerStatus: pointerData?['status'] as String?,
          sourceFingerprint: pointerData?['sourceFingerprint'] as String?,
          draftRevision: (pointerData?['draftRevision'] as num?)?.toInt(),
          job: await _loadJobStatus(uid, runId),
        );
      }
      if (pointerData != null) {
        return OnboardingCurrentRunSnapshot(
          hasPointer: true,
          ownerUid: pointerData['ownerUid'] as String?,
          pointerSchemaVersion: (pointerData['schemaVersion'] as num?)?.toInt(),
          pointerStatus: pointerData['status'] as String?,
          sourceFingerprint: pointerData['sourceFingerprint'] as String?,
          draftRevision: (pointerData['draftRevision'] as num?)?.toInt(),
        );
      }
      // Read-only compatibility for a legacy fixed job. A new attempt always
      // creates a canonical run rather than mutating this document.
      final legacy = await firestore!
          .doc(FirestoreUserPaths.onboardingCompletionJob(uid))
          .get();
      final legacyData = legacy.data();
      if (legacyData == null) {
        return const OnboardingCurrentRunSnapshot.none();
      }
      final legacyJob = OnboardingCompletionJob.fromMap(legacyData);
      return OnboardingCurrentRunSnapshot(
        hasPointer: true,
        runId: legacyJob.jobId,
        ownerUid: legacyJob.ownerUid,
        pointerSchemaVersion: 1,
        pointerStatus: legacyJob.status == OnboardingJobStatus.completed
            ? 'completed'
            : 'active',
        sourceFingerprint: legacyJob.sourceFingerprint,
        draftRevision: legacyJob.draftRevision,
        job: legacyJob,
      );
    }
    final runId = _memoryStore.currentRunIds[uid];
    if (runId == null) return const OnboardingCurrentRunSnapshot.none();
    return OnboardingCurrentRunSnapshot(
      hasPointer: true,
      runId: runId,
      ownerUid: uid,
      pointerSchemaVersion: 1,
      pointerStatus: _memoryStore.currentRunStatuses[uid] ?? 'active',
      sourceFingerprint: _memoryStore.jobs['$uid:$runId']?.sourceFingerprint,
      draftRevision: _memoryStore.jobs['$uid:$runId']?.draftRevision,
      job: _memoryStore.jobs['$uid:$runId'],
    );
  }

  Future<OnboardingCompletionJob?> _loadJobStatus(
    String uid,
    String runId,
  ) async {
    if (firestore != null) {
      final snapshot = await firestore!
          .doc(FirestoreUserPaths.onboardingRun(uid, runId))
          .get();
      final data = snapshot.data();
      return data == null ? null : OnboardingCompletionJob.fromMap(data);
    }
    if (requirePersistentJobs) {
      throw StateError(
        'Firebase onboarding completion requires persistent job storage.',
      );
    }
    return _memoryStore.jobs['$uid:$runId'];
  }

  Future<void> _saveJobStatus(
    OnboardingCompletionJob job, {
    bool activate = false,
  }) async {
    if (firestore != null) {
      if (activate) {
        final batch = firestore!.batch();
        batch.set(
          firestore!.doc(FirestoreUserPaths.onboardingRun(job.uid, job.jobId)),
          job.toFirestoreMap(),
        );
        batch.set(
          firestore!.doc(FirestoreUserPaths.onboardingCurrentRun(job.uid)),
          _runPointerMap(job, status: 'active'),
        );
        await batch.commit();
      } else {
        await firestore!
            .doc(FirestoreUserPaths.onboardingRun(job.uid, job.jobId))
            .set(job.toFirestoreMap());
      }
      return;
    }
    if (requirePersistentJobs) {
      throw StateError(
        'Firebase onboarding completion requires persistent job storage.',
      );
    }
    _memoryStore.jobs['${job.uid}:${job.jobId}'] = job;
    if (activate) {
      _memoryStore.currentRunIds[job.uid] = job.jobId;
      _memoryStore.currentRunStatuses[job.uid] = 'active';
    }
  }

  Map<String, dynamic> _runPointerMap(
    OnboardingCompletionJob job, {
    required String status,
  }) {
    return {
      'ownerUid': job.ownerUid,
      'currentRunId': job.jobId,
      'sourceFingerprint': job.sourceFingerprint,
      'draftRevision': job.draftRevision,
      'status': status,
      'updatedAt': Timestamp.fromDate(job.updatedAt),
      'schemaVersion': 1,
    };
  }

  static SanitizedFailurePayload _buildSanitizedFailure(
    Object error,
    OnboardingCompletionStage stage,
  ) {
    if (error is OnboardingCompletionFailureException) {
      return SanitizedFailurePayload(
        errorType: 'OnboardingCompletionFailureException',
        stage: error.stage.name,
        failureCode: error.code,
        diagnosticCategory: error.diagnosticCategory,
        retryable: error.retryable,
        publicMessageKey: error.publicMessageKey,
        failedEntityIds: error.failedEntityIds,
        sanitizedMessage: 'Completion failed with code ${error.code}.',
      );
    }
    if (error is RoutineProjectionFailureException) {
      return SanitizedFailurePayload(
        errorType: 'RoutineProjectionFailureException',
        stage: stage.name,
        failureCode: error.reason.name,
        diagnosticCategory: 'projection_failed',
        retryable: error.reason == RoutineProjectionFailureReason.retryRequired,
        publicMessageKey: 'error_routine_projection_failed',
        failedEntityIds: const [],
        sanitizedMessage:
            'Routine projection failed with reason ${error.reason.name}.',
      );
    }
    if (error is RoutineProjectionRetryRequiredException) {
      return SanitizedFailurePayload(
        errorType: 'RoutineProjectionRetryRequiredException',
        stage: stage.name,
        failureCode: 'retry_required',
        diagnosticCategory: 'transient_failure',
        retryable: true,
        publicMessageKey: 'error_retry_required',
        failedEntityIds: const [],
        sanitizedMessage: 'Routine projection requires retry.',
      );
    }
    if (error is HabitSystemProjectionFailureException) {
      return SanitizedFailurePayload(
        errorType: 'HabitSystemProjectionFailureException',
        stage: stage.name,
        failureCode: error.code,
        diagnosticCategory: 'habit_projection_failed',
        retryable: true,
        publicMessageKey: 'error_habit_projection_failed',
        failedEntityIds: error.failedSystemIds.isNotEmpty
            ? error.failedSystemIds
            : error.missingSystemIds,
        sanitizedMessage:
            'Habit system projection failed with code ${error.code}',
      );
    }
    if (error is StateError) {
      return SanitizedFailurePayload(
        errorType: 'StateError',
        stage: stage.name,
        failureCode: 'state_error',
        diagnosticCategory: 'validation_failed',
        retryable: false,
        publicMessageKey: 'error_invalid_state',
        failedEntityIds: const [],
        sanitizedMessage: 'Completion state validation failed.',
      );
    }
    if (error is ArgumentError) {
      return SanitizedFailurePayload(
        errorType: 'ArgumentError',
        stage: stage.name,
        failureCode: 'argument_error',
        diagnosticCategory: 'validation_failed',
        retryable: false,
        publicMessageKey: 'error_invalid_argument',
        failedEntityIds: const [],
        sanitizedMessage: 'Completion argument validation failed.',
      );
    }
    return SanitizedFailurePayload(
      errorType: error.runtimeType.toString(),
      stage: stage.name,
      failureCode: 'unhandled_exception',
      diagnosticCategory: 'execution_failed',
      retryable: true,
      publicMessageKey: 'error_execution_failed',
      failedEntityIds: const [],
      sanitizedMessage: 'Completion execution failed safely.',
    );
  }
}

class SanitizedFailurePayload {
  final String errorType;
  final String stage;
  final String failureCode;
  final String diagnosticCategory;
  final bool retryable;
  final String publicMessageKey;
  final List<String> failedEntityIds;
  final String sanitizedMessage;

  const SanitizedFailurePayload({
    required this.errorType,
    required this.stage,
    required this.failureCode,
    required this.diagnosticCategory,
    required this.retryable,
    required this.publicMessageKey,
    required this.failedEntityIds,
    required this.sanitizedMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': errorType,
      'stage': stage,
      'failureCode': failureCode,
      'diagnosticCategory': diagnosticCategory,
      'retryable': retryable,
      'publicMessageKey': publicMessageKey,
      if (failedEntityIds.isNotEmpty) 'failedEntityIds': failedEntityIds,
      'message': sanitizedMessage,
    };
  }

  String toJsonString() => jsonEncode(toMap());
}

final onboardingCompletionJobServiceProvider =
    Provider<OnboardingCompletionJobService>((ref) {
      final firebaseMode = !ref.watch(fakeDataAllowedProvider);
      final firebaseReady = firebaseMode && Firebase.apps.isNotEmpty;
      final service = OnboardingCompletionJobService(
        onboardingRepository: ref.watch(onboardingRepositoryProvider),
        profileRepository: ref.watch(profileRepositoryProvider),
        routineRepository: ref.watch(routineRepositoryProvider),
        conflictAcceptanceRepository: ref.watch(
          conflictAcceptanceRepositoryProvider,
        ),
        firestore: firebaseReady ? FirebaseFirestore.instance : null,
        requirePersistentJobs: firebaseReady,
        requireFrontendHydration: firebaseReady,
        requireRoutineVerification: firebaseReady,
      );
      ref.onDispose(service.cancelAll);
      return service;
    });

final onboardingCompletionJobProvider =
    FutureProvider.family<OnboardingCompletionJob?, String>((ref, uid) {
      return ref
          .watch(onboardingCompletionJobServiceProvider)
          .loadCurrentJob(uid);
    });
