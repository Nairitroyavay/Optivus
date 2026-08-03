import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
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

  static void resetForSignedOut() {
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
    final plan = RoutineOnboardingProjection.build(bundle);
    final operationKey = '$uid:${plan.fingerprint}';
    final activeOperation = _inFlight[operationKey];
    if (activeOperation != null) return activeOperation;

    final operation = _runCompletionJob(
      uid: uid,
      finalDraft: finalDraft,
      bundle: bundle,
      sourceFingerprint: plan.fingerprint,
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
          now: now,
        );
        if (job.status == OnboardingJobStatus.completed &&
            job.stage == OnboardingCompletionStage.completed) {
          return job;
        }

        job = job.copyWith(
          status: OnboardingJobStatus.inProgress,
          updatedAt: now,
          clearLastError: true,
        );
        await _saveJobStatus(job);

        void checkSession() {
          if (uid.trim().isEmpty) {
            throw StateError(
              'Job cancelled due to invalid or empty authenticated UID.',
            );
          }
          if (reader != null) {
            final profile = reader(mockUserProfileProvider);
            if (profile.uid.trim().isEmpty || profile.uid != uid) {
              throw StateError(
                'Job cancelled due to sign-out or account switch.',
              );
            }
          }
        }

        try {
          // Stage 1: PERSIST_DRAFT
          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.persistDraft)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.persistDraft,
            );

            await onboardingRepository.flushPendingDraftSave();
            await onboardingRepository.saveFinalDraftImmediately(finalDraft);

            final readbackDraft = await onboardingRepository.fetchDraft(uid);
            if (readbackDraft == null || 
                readbackDraft.uid != uid || 
                !readbackDraft.onboardingCompleted) {
              throw StateError('Draft read-back verification failed.');
            }

            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.persistDraft.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 2: PERSIST_BUNDLE
          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.persistBundle)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.persistBundle,
            );

            await onboardingRepository.saveCompletionBundle(bundle);

            final readbackBundle = await onboardingRepository
                .fetchCompletionBundle(uid);
            if (readbackBundle == null ||
                readbackBundle.version != bundle.version) {
              throw StateError('Bundle read-back verification failed.');
            }

            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.persistBundle.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 3: PROJECT_ROUTINES
          checkSession();
          if (!job.isStageCompleted(
            OnboardingCompletionStage.projectRoutines,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.projectRoutines,
            );

            final projectionResult = await onboardingRepository
                .completeOnboarding(finalDraft: finalDraft, bundle: bundle);

            final receipt = projectionResult.receipt;
            
            RoutineOnboardingEventProjectionResult historyResult;
            if (reader != null) {
              historyResult = await const RoutineOnboardingEventProjector()
                  .projectCreatedEvents(
                    read: reader,
                    bundle: bundle,
                  );
            } else {
              if (requireRoutineVerification) {
                throw StateError('Onboarding frontend reader is required for history verification.');
              }
              final computedHistoryIds = const RoutineOnboardingEventProjector()
                  .computeExpectedEventIds(bundle);
              final plan = RoutineOnboardingProjection.build(bundle);
              historyResult = RoutineOnboardingEventProjectionResult(
                projectionId: plan.projectionId,
                attemptedCount: 0,
                expectedEventIds: computedHistoryIds,
                appliedEventIds: computedHistoryIds,
                failedEventIds: const [],
              );
            }
            
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.projectRoutines.name] = true;
            job = job.copyWith(
              stagesCompleted: nextCompleted,
              expectedRoutineIds: receipt.expectedItemIds,
              appliedRoutineIds: receipt.createdItemIds,
              existingRoutineIds: receipt.existingItemIds,
              repairedRoutineIds: receipt.repairedItemIds,
              failedRoutineIds: receipt.failedItemIds,
              expectedHistoryIds: historyResult.expectedEventIds,
              appliedHistoryIds: historyResult.appliedEventIds,
              failedHistoryIds: historyResult.failedEventIds,
            );
            await _saveJobStatus(job);
          }

          // Stage 4: PROJECT_HABITS
          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.projectHabits)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.projectHabits,
            );

            if (reader != null) {
              final hydrationResult =
                  await const OnboardingFrontendHydrationService().hydrate(
                    read: reader,
                    bundle: bundle,
                  );
              job = job.copyWith(
                expectedHabitIds: hydrationResult.expectedHabitSystemIds,
                appliedHabitIds: hydrationResult.appliedHabitSystemIds,
                failedHabitIds: hydrationResult.failedHabitSystemIds,
                expectedHistoryIds: [
                  ...job.expectedHistoryIds,
                  ...hydrationResult.expectedHistoryIds,
                ],
                appliedHistoryIds: [
                  ...job.appliedHistoryIds,
                  ...hydrationResult.appliedHistoryIds,
                ],
                failedHistoryIds: [
                  ...job.failedHistoryIds,
                  ...hydrationResult.failedHistoryIds,
                ],
              );
            } else if (requireFrontendHydration) {
              throw StateError(
                'Onboarding frontend hydration dependency is required.',
              );
            }
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.projectHabits.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 5: UPDATE_PROFILE
          checkSession();
          if (!job.isStageCompleted(OnboardingCompletionStage.updateProfile)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.updateProfile,
            );

            final plan = RoutineOnboardingProjection.build(bundle);
            final activeRoutineRepo = reader != null
                ? reader(routineRepositoryProvider)
                : routineRepository;
            if (activeRoutineRepo == null) {
              if (requireRoutineVerification) {
                throw StateError(
                  'Routine repository dependency is required before profile finalization.',
                );
              }
            } else {
              final receipt = await activeRoutineRepo.fetchProjectionReceipt(
                uid,
                plan.projectionId,
              );
              if (receipt == null ||
                  receipt.status != 'completed' ||
                  receipt.cursor != receipt.totalCount ||
                  receipt.sourceBundleFingerprint != plan.fingerprint) {
                throw StateError(
                  'Cannot transition profile to onboardingCompleted: true before projection receipt is complete and fingerprint-matched.',
                );
              }
              final actualItems = await activeRoutineRepo.fetchRoutineItems(
                uid,
              );
              final validation = const RoutineProjectionReceiptValidator()
                  .validate(
                    receipt: receipt,
                    actualItems: actualItems,
                    ownerUid: uid,
                    plan: plan,
                  );
              if (!validation.isValid) {
                throw StateError(
                  'Cannot complete job with invalid receipt: ${validation.failureReason}',
                );
              }
            }

            var profile = await profileRepository.fetchUserProfile(uid);
            profile ??= UserProfile.empty(uid: uid);
            profile = profile.copyWith(
              onboardingInputCompleted: true,
              onboardingProjectionStatus: 'completed',
              onboardingCompleted: true,
              updatedAt: DateTime.now(),
            );

            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.updateProfile.name] = true;
            final updatedJob = job.copyWith(stagesCompleted: nextCompleted);

            if (firestore != null) {
              final batch = firestore!.batch();
              batch.set(
                firestore!.doc(FirestoreUserPaths.profile(profile.uid)),
                profile.toFirestoreMap(),
                SetOptions(merge: true),
              );
              batch.set(
                firestore!.doc(
                  FirestoreUserPaths.onboardingCompletionJob(updatedJob.uid),
                ),
                updatedJob.toMap(),
              );
              await batch.commit();
            } else {
              await profileRepository.saveUserProfile(profile);
              await _saveJobStatus(updatedJob);
            }
            job = updatedJob;

            if (reader != null) {
              try {
                reader(mockUserProfileProvider.notifier).completeOnboarding();
              } catch (e) {
                // Profile notifier update failed during job finalization
              }
            }
          }

          // Stage 6: COMPLETE_JOB
          checkSession();
          job = job.copyWith(
            status: OnboardingJobStatus.completed,
            stage: OnboardingCompletionStage.completed,
            updatedAt: DateTime.now(),
          );
          await _saveJobStatus(job);
          return job;
        } catch (e) {
          final now = DateTime.now();
          final failure = _buildSanitizedFailure(e, job.stage);
          job = job.copyWith(
            status: OnboardingJobStatus.failed,
            retryCount: job.retryCount + 1,
            lastError: failure.toJsonString(),
            lastFailureCode: failure.failureCode,
            lastFailureStage: failure.stage,
            retryable: failure.retryable,
            publicMessageKey: failure.publicMessageKey,
            diagnosticCategory: failure.diagnosticCategory,
            failedEntityIds: failure.failedEntityIds,
            lastFailureOccurredAt: now,
          );
          await _saveJobStatus(job);
          rethrow;
        }
      },
    );
  }

  Future<OnboardingCompletionJob> _loadOrCreateJob({
    required String uid,
    required String sourceFingerprint,
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
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );
    }

    if (existing.uid != uid) {
      throw StateError('Persisted onboarding completion job owner mismatch.');
    }
    if (existing.schemaVersion !=
        OnboardingCompletionJob.currentSchemaVersion) {
      throw StateError('Unsupported onboarding completion job schema version.');
    }
    if (existing.sourceFingerprint != null &&
        existing.sourceFingerprint != sourceFingerprint) {
      return existing.copyWith(
        status: OnboardingJobStatus.pending,
        stage: OnboardingCompletionStage.init,
        stagesCompleted: const {},
        sourceFingerprint: sourceFingerprint,
        retryCount: 0,
        updatedAt: now,
        clearLastError: true,
        clearLastFailure: true,
      );
    }
    return existing.copyWith(
      sourceFingerprint: sourceFingerprint,
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
      status: OnboardingJobStatus.inProgress,
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
          .set(job.toMap());
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
        sanitizedMessage: _sanitizeMessage(error.toString()),
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
        sanitizedMessage: _sanitizeMessage(error.message),
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
        sanitizedMessage: _sanitizeMessage(error.message),
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
        sanitizedMessage: _sanitizeMessage(error.message),
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
      sanitizedMessage: _sanitizeMessage(error.toString()),
    );
  }

  static String _sanitizeMessage(String msg) {
    if (msg.isEmpty) return 'No diagnostic message.';
    var clean = msg.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[REDACTED_EMAIL]',
    );
    clean = clean.replaceAll(
      RegExp(r'eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'),
      '[REDACTED_TOKEN]',
    );
    return clean;
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
