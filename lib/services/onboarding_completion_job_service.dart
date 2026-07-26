import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  OnboardingCompletionJobService({
    required this.onboardingRepository,
    required this.profileRepository,
    this.routineRepository,
    this.firestore,
    SystemWakeLock? wakeLock,
  }) : wakeLock = wakeLock ?? DefaultSystemWakeLock();

  Future<OnboardingCompletionJob> runCompletionJob({
    required String uid,
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    Reader? reader,
  }) async {
    return runWithWakeLock<OnboardingCompletionJob>(
      tag: 'onboarding_completion_$uid',
      wakeLock: wakeLock,
      syncTask: () async {
        final now = DateTime.now();
        var job = OnboardingCompletionJob(
          jobId: 'current',
          uid: uid,
          status: OnboardingJobStatus.inProgress,
          stage: OnboardingCompletionStage.init,
          stagesCompleted: const {},
          retryCount: 0,
          createdAt: now,
          updatedAt: now,
        );

        await _saveJobStatus(job);

        try {
          // Stage 1: PERSIST_DRAFT
          if (!job.isStageCompleted(OnboardingCompletionStage.persistDraft)) {
            job = job.copyWith(
              stage: OnboardingCompletionStage.persistDraft,
              updatedAt: DateTime.now(),
            );
            await _saveJobStatus(job);

            await onboardingRepository.saveDraft(finalDraft);
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.persistDraft.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
          }

          // Stage 2: PERSIST_BUNDLE
          if (!job.isStageCompleted(OnboardingCompletionStage.persistBundle)) {
            job = job.copyWith(
              stage: OnboardingCompletionStage.persistBundle,
              updatedAt: DateTime.now(),
            );
            await _saveJobStatus(job);

            await onboardingRepository.saveCompletionBundle(bundle);
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.persistBundle.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
          }

          // Stage 3: PROJECT_ROUTINES
          if (!job.isStageCompleted(
            OnboardingCompletionStage.projectRoutines,
          )) {
            job = job.copyWith(
              stage: OnboardingCompletionStage.projectRoutines,
              updatedAt: DateTime.now(),
            );
            await _saveJobStatus(job);

            await onboardingRepository.completeOnboarding(
              finalDraft: finalDraft,
              bundle: bundle,
            );
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.projectRoutines.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
          }

          // Stage 4: PROJECT_HABITS
          if (!job.isStageCompleted(OnboardingCompletionStage.projectHabits)) {
            job = job.copyWith(
              stage: OnboardingCompletionStage.projectHabits,
              updatedAt: DateTime.now(),
            );
            await _saveJobStatus(job);

            if (reader != null) {
              await const OnboardingFrontendHydrationService().hydrate(
                read: reader,
                bundle: bundle,
              );
            }
            final nextCompleted = Map<String, bool>.from(job.stagesCompleted)
              ..[OnboardingCompletionStage.projectHabits.name] = true;
            job = job.copyWith(stagesCompleted: nextCompleted);
          }

          // Stage 5: UPDATE_PROFILE
          if (!job.isStageCompleted(OnboardingCompletionStage.updateProfile)) {
            job = job.copyWith(
              stage: OnboardingCompletionStage.updateProfile,
              updatedAt: DateTime.now(),
            );
            await _saveJobStatus(job);

            final plan = RoutineOnboardingProjection.build(bundle);
            final activeRoutineRepo = reader != null
                ? reader(routineRepositoryProvider)
                : routineRepository;
            if (activeRoutineRepo != null) {
              final receipt = await activeRoutineRepo.fetchProjectionReceipt(
                uid,
                plan.projectionId,
              );
              if (receipt == null || receipt.status != 'completed') {
                throw StateError(
                  'Cannot transition profile to onboardingCompleted: true before projection receipt status is completed.',
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

  Future<void> _saveJobStatus(OnboardingCompletionJob job) async {
    if (firestore != null) {
      await firestore!
          .doc(FirestoreUserPaths.onboardingCompletionJob(job.uid))
          .set(job.toMap(), SetOptions(merge: true));
    }
  }
}

final onboardingCompletionJobServiceProvider =
    Provider<OnboardingCompletionJobService>((ref) {
      return OnboardingCompletionJobService(
        onboardingRepository: ref.watch(onboardingRepositoryProvider),
        profileRepository: ref.watch(profileRepositoryProvider),
      );
    });
