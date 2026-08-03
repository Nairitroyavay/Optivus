import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';

import 'package:optivus/services/background_sync_wake_lock_manager.dart';

typedef Reader = T Function<T>(ProviderListenable<T> provider);

class OnboardingCompletionJobService {
  final OnboardingRepository onboardingRepository;
  final ProfileRepository profileRepository;
  final RoutineRepository? routineRepository;
  final FirebaseFirestore? firestore;
  final SystemWakeLock wakeLock;
  final bool requirePersistentJobs;
  final bool requireFrontendHydration;
  final bool requireRoutineVerification;
  final Map<String, OnboardingCompletionJob> _memoryJobs = {};

  static final Map<String, Future<OnboardingCompletionJob>> _inFlight = {};
  static int _operationGeneration = 0;

  static void resetForSignedOut() {
    _operationGeneration++;
    _inFlight.clear();
  }

  OnboardingCompletionJobService({
    required this.onboardingRepository,
    required this.profileRepository,
    this.routineRepository,
    this.firestore,
    this.requirePersistentJobs = false,
    this.requireFrontendHydration = false,
    this.requireRoutineVerification = false,
    SystemWakeLock? wakeLock,
  }) : wakeLock = wakeLock ?? DefaultSystemWakeLock();

  Future<OnboardingCompletionJob> runCompletionJob({
    required String uid,
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('Cannot run completion job with empty uid.');
    }
    final operationKey = '$uid:${bundle.effectiveSourceFingerprint}';
    final activeOperation = _inFlight[operationKey];
    if (activeOperation != null) return activeOperation;
    final operationGeneration = ++_operationGeneration;
    final authGeneration = reader == null
        ? null
        : reader(authGenerationProvider);

    final operation = _runCompletionJob(
      uid: uid,
      finalDraft: finalDraft,
      bundle: bundle,
      sourceFingerprint: bundle.effectiveSourceFingerprint,
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
    return _loadJobStatus(uid);
  }

  Future<OnboardingCompletionJob> _runCompletionJob({
    required String uid,
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    required String sourceFingerprint,
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
          draftRevision: finalDraft.revision,
          now: now,
        );
        if (job.status == OnboardingJobStatus.completed &&
            job.stage == OnboardingCompletionStage.completed) {
          return job;
        }

        job = job.copyWith(
          status: OnboardingJobStatus.running,
          updatedAt: now,
          clearLastError: true,
        );
        await _saveJobStatus(job);

        void checkSession() {
          if (operationGeneration != _operationGeneration) {
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
            job = job.copyWith(
              expectedRoutineIds: receipt.expectedItemIds,
              appliedRoutineIds: receipt.createdItemIds,
              existingRoutineIds: receipt.existingItemIds,
              repairedRoutineIds: receipt.repairedItemIds,
              failedRoutineIds: receipt.failedItemIds,
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
            var profile = await profileRepository.fetchUserProfile(uid);
            if (profile == null) {
              throw StateError(
                'Root UserProfile is required for finalization.',
              );
            }
            profile = profile.copyWith(
              onboardingInputCompleted: true,
              onboardingProjectionStatus: 'completed',
              onboardingCompleted: true,
              updatedAt: DateTime.now(),
            );
            final updatedJob = _stageCompletedCopy(
              job,
              OnboardingCompletionStage.finalizeProfile,
            );
            if (firestore != null) {
              final batch = firestore!.batch();
              batch.set(
                firestore!.doc(FirestoreUserPaths.user(profile.uid)),
                profile.toFirestoreMap(),
                SetOptions(merge: true),
              );
              batch.set(
                firestore!.doc(
                  FirestoreUserPaths.onboardingCompletionJob(
                    updatedJob.ownerUid,
                  ),
                ),
                updatedJob.toFirestoreMap(),
              );
              await batch.commit();
            } else {
              await profileRepository.saveUserProfile(profile);
              await _saveJobStatus(updatedJob);
            }
            job = updatedJob;
          }

          checkSession();
          job = job.copyWith(
            status: OnboardingJobStatus.completed,
            stage: OnboardingCompletionStage.completed,
            updatedAt: DateTime.now(),
            completedAt: DateTime.now(),
          );
          await _saveJobStatus(job);
          return job;
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
        !_sameIds(actual.generatedSourceIds, expected.generatedSourceIds)) {
      throw StateError('Completion bundle read-back verification failed.');
    }
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
    final receipt = await activeRepository.fetchProjectionReceipt(
      uid,
      plan.projectionId,
    );
    if (receipt == null ||
        receipt.status != 'completed' ||
        receipt.cursor != receipt.totalCount ||
        receipt.sourceBundleFingerprint != plan.fingerprint) {
      throw StateError('Routine projection receipt verification failed.');
    }
    final items = await activeRepository.fetchRoutineItems(uid);
    final validation = const RoutineProjectionReceiptValidator().validate(
      receipt: receipt,
      actualItems: items,
      ownerUid: uid,
      plan: plan,
    );
    if (!validation.isValid) {
      throw StateError('Routine projection document verification failed.');
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
        job.failedHabitIds.isNotEmpty) {
      throw StateError('Profile finalization prerequisites are incomplete.');
    }
  }

  bool _sameIds(Iterable<String> left, Iterable<String> right) {
    final a = left.toSet();
    final b = right.toSet();
    return a.length == b.length && a.containsAll(b);
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
    required int draftRevision,
    required DateTime now,
  }) async {
    final existing = await _loadJobStatus(uid);
    if (existing == null) {
      return OnboardingCompletionJob(
        jobId: 'current',
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
    if (existing.schemaVersion < 1 ||
        existing.schemaVersion > OnboardingCompletionJob.currentSchemaVersion) {
      throw StateError('Unsupported onboarding completion job schema version.');
    }
    // Legacy broad stages cannot prove completion of any of the finer v2
    // verification barriers. Restart safely from validation while retaining
    // only owner-scoped identity and retry evidence in the legacy document.
    if (existing.schemaVersion < OnboardingCompletionJob.currentSchemaVersion) {
      return OnboardingCompletionJob(
        jobId: existing.jobId,
        ownerUid: uid,
        status: OnboardingJobStatus.pending,
        stage: OnboardingCompletionStage.validateInput,
        stagesCompleted: const {},
        sourceFingerprint: sourceFingerprint,
        draftRevision: draftRevision,
        retryCount: existing.retryCount,
        lastFailureCode: existing.lastFailureCode,
        lastFailureStage: existing.lastFailureStage,
        retryable: existing.retryable,
        publicMessageKey: existing.publicMessageKey,
        diagnosticCategory: existing.diagnosticCategory,
        safeCauseType: existing.safeCauseType,
        failedEntityIds: existing.failedEntityIds,
        lastFailureOccurredAt: existing.lastFailureOccurredAt,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    }
    if (existing.sourceFingerprint.isNotEmpty &&
        existing.sourceFingerprint != sourceFingerprint) {
      return existing.copyWith(
        status: OnboardingJobStatus.pending,
        stage: OnboardingCompletionStage.init,
        stagesCompleted: const {},
        sourceFingerprint: sourceFingerprint,
        draftRevision: draftRevision,
        retryCount: 0,
        updatedAt: now,
        clearLastError: true,
        clearLastFailure: true,
      );
    }
    return existing.copyWith(
      sourceFingerprint: sourceFingerprint,
      draftRevision: draftRevision,
      schemaVersion: OnboardingCompletionJob.currentSchemaVersion,
      updatedAt: now,
    );
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

  Future<OnboardingCompletionJob?> _loadJobStatus(String uid) async {
    if (firestore != null) {
      final snapshot = await firestore!
          .doc(FirestoreUserPaths.onboardingCompletionJob(uid))
          .get();
      final data = snapshot.data();
      return data == null ? null : OnboardingCompletionJob.fromMap(data);
    }
    if (requirePersistentJobs) {
      throw StateError(
        'Firebase onboarding completion requires persistent job storage.',
      );
    }
    return _memoryJobs[uid];
  }

  Future<void> _saveJobStatus(OnboardingCompletionJob job) async {
    if (firestore != null) {
      await firestore!
          .doc(FirestoreUserPaths.onboardingCompletionJob(job.uid))
          .set(job.toFirestoreMap());
      return;
    }
    if (requirePersistentJobs) {
      throw StateError(
        'Firebase onboarding completion requires persistent job storage.',
      );
    }
    _memoryJobs[job.uid] = job;
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
      final firebaseMode =
          ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase;
      return OnboardingCompletionJobService(
        onboardingRepository: ref.watch(onboardingRepositoryProvider),
        profileRepository: ref.watch(profileRepositoryProvider),
        routineRepository: ref.watch(routineRepositoryProvider),
        firestore: firebaseMode ? FirebaseFirestore.instance : null,
        requirePersistentJobs: firebaseMode,
        requireFrontendHydration: firebaseMode,
        requireRoutineVerification: firebaseMode,
      );
    });

final onboardingCompletionJobProvider =
    FutureProvider.family<OnboardingCompletionJob?, String>((ref, uid) {
      return ref
          .watch(onboardingCompletionJobServiceProvider)
          .loadCurrentJob(uid);
    });
