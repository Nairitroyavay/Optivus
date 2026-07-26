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
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';

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

        try {
          // Stage 1: PERSIST_DRAFT
          if (!job.isStageCompleted(OnboardingCompletionStage.persistDraft)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.persistDraft,
            );

            await onboardingRepository.saveDraft(finalDraft);
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.persistDraft.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 2: PERSIST_BUNDLE
          if (!job.isStageCompleted(OnboardingCompletionStage.persistBundle)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.persistBundle,
            );

            await onboardingRepository.saveCompletionBundle(bundle);
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.persistBundle.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 3: PROJECT_ROUTINES
          if (!job.isStageCompleted(
            OnboardingCompletionStage.projectRoutines,
          )) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.projectRoutines,
            );

            await onboardingRepository.completeOnboarding(
              finalDraft: finalDraft,
              bundle: bundle,
            );
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.projectRoutines.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 4: PROJECT_HABITS
          if (!job.isStageCompleted(OnboardingCompletionStage.projectHabits)) {
            job = await _beginStage(
              job,
              OnboardingCompletionStage.projectHabits,
            );

            if (reader != null) {
              await const OnboardingFrontendHydrationService().hydrate(
                read: reader,
                bundle: bundle,
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
            await profileRepository.saveUserProfile(profile);

            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.updateProfile.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
            await _saveJobStatus(job);
          }

          // Stage 6: COMPLETE_JOB
          job = job.copyWith(
            status: OnboardingJobStatus.completed,
            stage: OnboardingCompletionStage.completed,
            updatedAt: DateTime.now(),
          );
          await _saveJobStatus(job);
          return job;
        } catch (e) {
          job = job.copyWith(
            status: OnboardingJobStatus.failed,
            retryCount: job.retryCount + 1,
            lastError: e.toString(),
            updatedAt: DateTime.now(),
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
      throw StateError(
        'Persisted onboarding completion job fingerprint mismatch.',
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
