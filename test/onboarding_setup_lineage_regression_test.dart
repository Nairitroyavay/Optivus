import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/completion_terminalization_proof.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_run_identity.dart';
import 'package:optivus/services/onboarding_setup_reset_coordinator.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/server_reconstructor.dart';

void main() {
  const uid = 'test-lineage-user';

  group('Physical restore defect regression: completion_run_input_mismatch', () {
    test(
      'Re-run setup cold restart at Step 3 resumes Onboarding, does not enter Recovery',
      () {
        // Profile has been reset to setupGeneration 1
        final profile = UserProfile.empty(uid: uid).copyWith(
          currentSetupGeneration: 1,
          onboardingCompleted: false,
          onboardingInputCompleted: false,
          onboardingProjectionStatus: 'pending',
          onboardingStep: 0,
        );

        // Draft is progressing in setupGeneration 1, currently at Step 3 (steps 0, 1, 2 completed)
        final draft = _validDraftAtStep(
          uid,
          3,
          setupGeneration: 1,
          revision: 3,
        );

        // Stale completion run from setupGeneration 0 is still in currentRun pointer
        final staleJob = OnboardingCompletionJob(
          jobId: 'run-gen0-legacy',
          ownerUid: uid,
          status: OnboardingJobStatus.completed,
          stage: OnboardingCompletionStage.completed,
          draftRevision: 15,
          sourceFingerprint: 'stale-fingerprint-gen0',
          setupGeneration: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final staleCurrentRun = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'run-gen0-legacy',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'completed',
          sourceFingerprint: 'stale-fingerprint-gen0',
          draftRevision: 15,
          setupGeneration: 0,
          pointerOrigin: CurrentRunPointerOrigin.canonicalPointer,
          job: staleJob,
        );

        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: staleCurrentRun,
        );

        expect(
          result,
          isA<ReconstructionIncomplete>(),
          reason:
              'Stale gen 0 run must be treated as superseded, not trigger completion_run_input_mismatch',
        );
        expect((result as ReconstructionIncomplete).step, 3);
      },
    );

    test('Re-run setup cold restart at Step 6 resumes at Step 6', () {
      final profile = UserProfile.empty(uid: uid).copyWith(
        currentSetupGeneration: 1,
        onboardingCompleted: false,
        onboardingInputCompleted: false,
        onboardingProjectionStatus: 'pending',
      );
      final draft = _validDraftAtStep(uid, 6, setupGeneration: 1, revision: 6);
      final staleCurrentRun = OnboardingCurrentRunSnapshot(
        hasPointer: true,
        runId: 'run-gen0',
        ownerUid: uid,
        pointerSchemaVersion: 1,
        pointerStatus: 'completed',
        sourceFingerprint: 'old-fingerprint',
        draftRevision: 15,
        setupGeneration: 0,
        job: OnboardingCompletionJob(
          jobId: 'run-gen0',
          ownerUid: uid,
          status: OnboardingJobStatus.completed,
          stage: OnboardingCompletionStage.completed,
          draftRevision: 15,
          sourceFingerprint: 'old-fingerprint',
          setupGeneration: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: profile,
        draft: draft,
        completionBundle: null,
        currentRun: staleCurrentRun,
      );

      expect(result, isA<ReconstructionIncomplete>());
      expect((result as ReconstructionIncomplete).step, 6);
    });

    test('Re-run setup cold restart at Step 8 resumes at Step 8', () {
      final profile = UserProfile.empty(uid: uid).copyWith(
        currentSetupGeneration: 2,
        onboardingCompleted: false,
        onboardingInputCompleted: false,
        onboardingProjectionStatus: 'pending',
      );
      final draft = _validDraftAtStep(uid, 8, setupGeneration: 2, revision: 8);
      final staleCurrentRun = OnboardingCurrentRunSnapshot(
        hasPointer: true,
        runId: 'run-gen1',
        ownerUid: uid,
        pointerSchemaVersion: 1,
        pointerStatus: 'superseded',
        sourceFingerprint: 'old-fingerprint-gen1',
        draftRevision: 15,
        setupGeneration: 1,
        job: OnboardingCompletionJob(
          jobId: 'run-gen1',
          ownerUid: uid,
          status: OnboardingJobStatus.completed,
          stage: OnboardingCompletionStage.completed,
          draftRevision: 15,
          sourceFingerprint: 'old-fingerprint-gen1',
          setupGeneration: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: profile,
        draft: draft,
        completionBundle: null,
        currentRun: staleCurrentRun,
      );

      expect(result, isA<ReconstructionIncomplete>());
      expect((result as ReconstructionIncomplete).step, 8);
    });
  });

  group('Full 12 Lineage States Matrix', () {
    // 1. Fresh user
    test(
      '1. Fresh user with no durable onboarding data returns ReconstructionFresh',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 0);
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: null,
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );
        expect(result, isA<ReconstructionFresh>());
      },
    );

    // 2. Active onboarding in same generation with no run yet
    test(
      '2. Incomplete draft in same generation returns ReconstructionIncomplete',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 0);
        final draft = _validDraftAtStep(uid, 4, setupGeneration: 0);
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );
        expect(result, isA<ReconstructionIncomplete>());
        expect((result as ReconstructionIncomplete).step, 4);
      },
    );

    // 3. Stale older generation run + incomplete draft -> run ignored as superseded
    test(
      '3. Older generation run is superseded and draft resumes normally',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 1);
        final draft = _validDraftAtStep(uid, 2, setupGeneration: 1);
        final run = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'old-run',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'completed',
          sourceFingerprint: 'old-fp',
          draftRevision: 15,
          setupGeneration: 0,
          job: OnboardingCompletionJob(
            jobId: 'old-run',
            ownerUid: uid,
            draftRevision: 15,
            sourceFingerprint: 'old-fp',
            setupGeneration: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: run,
        );
        expect(result, isA<ReconstructionIncomplete>());
        expect((result as ReconstructionIncomplete).step, 2);
      },
    );

    // 4. Pointer explicitly marked 'superseded' -> ignored
    test('4. Pointer marked superseded is ignored and draft resumes', () {
      final profile = UserProfile.empty(
        uid: uid,
      ).copyWith(currentSetupGeneration: 1);
      final draft = _validDraftAtStep(uid, 5, setupGeneration: 1);
      final run = OnboardingCurrentRunSnapshot(
        hasPointer: true,
        runId: 'run-superseded',
        ownerUid: uid,
        pointerSchemaVersion: 1,
        pointerStatus: 'superseded',
        sourceFingerprint: 'fp',
        draftRevision: 1,
        setupGeneration: 1,
        job: OnboardingCompletionJob(
          jobId: 'run-superseded',
          ownerUid: uid,
          draftRevision: 1,
          sourceFingerprint: 'fp',
          setupGeneration: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: profile,
        draft: draft,
        completionBundle: null,
        currentRun: run,
      );
      expect(result, isA<ReconstructionIncomplete>());
      expect((result as ReconstructionIncomplete).step, 5);
    });

    // 5. Same-lineage active run matching final draft -> ReconstructionFinishing
    test(
      '5. Same-lineage final draft with active run returns ReconstructionFinishing',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 1);
        final draft = _finalDraft(uid, setupGeneration: 1);
        final runId = stableOnboardingRunId(
          ownerUid: uid,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
        );
        final job = OnboardingCompletionJob(
          jobId: runId,
          ownerUid: uid,
          status: OnboardingJobStatus.running,
          stage: OnboardingCompletionStage.persistBundle,
          draftRevision: draft.revision,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          setupGeneration: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final run = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: runId,
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
          setupGeneration: 1,
          job: job,
        );
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: run,
        );
        expect(result, isA<ReconstructionFinishing>());
        expect((result as ReconstructionFinishing).runId, runId);
      },
    );

    // 6. Same-lineage completed run with profile.onboardingCompleted -> ReconstructionCompleted
    test('6. Same-lineage completed state returns ReconstructionCompleted', () {
      final profile = UserProfile.empty(uid: uid).copyWith(
        currentSetupGeneration: 1,
        onboardingCompleted: true,
        onboardingProjectionStatus: 'completed',
        onboardingInputCompleted: true,
      );
      final draft = _finalDraft(uid, setupGeneration: 1);
      final bundle = _bundleForDraft(draft, setupGeneration: 1);
      final runId = bundle.runId;
      final job = OnboardingCompletionJob(
        jobId: runId,
        ownerUid: uid,
        status: OnboardingJobStatus.completed,
        stage: OnboardingCompletionStage.completed,
        draftRevision: draft.revision,
        sourceFingerprint: draft.effectiveSourceFingerprint,
        setupGeneration: 1,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final run = OnboardingCurrentRunSnapshot(
        hasPointer: true,
        runId: runId,
        ownerUid: uid,
        pointerSchemaVersion: 1,
        pointerStatus: 'completed',
        sourceFingerprint: draft.effectiveSourceFingerprint,
        draftRevision: draft.revision,
        setupGeneration: 1,
        job: job,
      );
      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: profile,
        draft: draft,
        completionBundle: bundle,
        currentRun: run,
      );
      expect(result, isA<ReconstructionCompleted>());
    });

    // 7. Same-lineage mismatch -> properly caught as completion_run_input_mismatch
    test(
      '7. Same-lineage run mismatch returns Recovery(completion_run_input_mismatch)',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 1);
        final draft = _validDraftAtStep(
          uid,
          3,
          setupGeneration: 1,
          revision: 2,
        );
        // Run claims same generation (1), but mismatched revision (5)
        final job = OnboardingCompletionJob(
          jobId: 'corrupt-run',
          ownerUid: uid,
          draftRevision: 5,
          sourceFingerprint: 'corrupt-fp',
          setupGeneration: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final run = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'corrupt-run',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: 'corrupt-fp',
          draftRevision: 5,
          setupGeneration: 1,
          job: job,
        );
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: run,
        );
        expect(result, isA<ReconstructionRecovery>());
        expect(
          (result as ReconstructionRecovery).diagnostics['code'],
          'completion_run_input_mismatch',
        );
      },
    );

    // 8. Same-lineage fatal failure -> completion_run_fatal
    test(
      '8. Same-lineage fatal failure returns Recovery(completion_run_fatal)',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 1);
        final draft = _finalDraft(uid, setupGeneration: 1);
        final runId = stableOnboardingRunId(
          ownerUid: uid,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
        );
        final job = OnboardingCompletionJob(
          jobId: runId,
          ownerUid: uid,
          status: OnboardingJobStatus.fatalFailure,
          stage: OnboardingCompletionStage.persistDraft,
          draftRevision: draft.revision,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          setupGeneration: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final run = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: runId,
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
          setupGeneration: 1,
          job: job,
        );
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: run,
        );
        expect(result, isA<ReconstructionRecovery>());
        expect(
          (result as ReconstructionRecovery).diagnostics['code'],
          'completion_run_fatal',
        );
      },
    );

    // 9. Future generation run -> setup_lineage_corrupt
    test(
      '9. Future generation run returns Recovery(setup_lineage_corrupt)',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 1);
        final draft = _validDraftAtStep(uid, 3, setupGeneration: 1);
        final run = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'future-run',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: 'future-fp',
          draftRevision: 1,
          setupGeneration: 2, // run is ahead of profile
          job: OnboardingCompletionJob(
            jobId: 'future-run',
            ownerUid: uid,
            draftRevision: 1,
            sourceFingerprint: 'future-fp',
            setupGeneration: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: run,
        );
        expect(result, isA<ReconstructionRecovery>());
        expect(
          (result as ReconstructionRecovery).diagnostics['code'],
          'setup_lineage_corrupt',
        );
      },
    );

    // 10. Mismatched draft generation -> setup_lineage_corrupt
    test(
      '10. Mismatched draft generation returns Recovery(setup_lineage_corrupt)',
      () {
        final profile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 2);
        final draft = _validDraftAtStep(
          uid,
          3,
          setupGeneration: 1,
        ); // draft is behind profile
        final result = classifyServerReconstruction(
          ownerUid: uid,
          profile: profile,
          draft: draft,
          completionBundle: null,
          currentRun: const OnboardingCurrentRunSnapshot.none(),
        );
        expect(result, isA<ReconstructionRecovery>());
        expect(
          (result as ReconstructionRecovery).diagnostics['code'],
          'setup_lineage_corrupt',
        );
      },
    );

    // 11. Completed profile with superseded run -> completed_profile_with_superseded_run
    test('11. Completed profile with superseded run returns Recovery', () {
      final profile = UserProfile.empty(
        uid: uid,
      ).copyWith(currentSetupGeneration: 2, onboardingCompleted: true);
      final draft = _finalDraft(uid, setupGeneration: 2);
      final run = OnboardingCurrentRunSnapshot(
        hasPointer: true,
        runId: 'old-completed-run',
        ownerUid: uid,
        pointerSchemaVersion: 1,
        pointerStatus: 'completed',
        sourceFingerprint: 'old-fp',
        draftRevision: 15,
        setupGeneration: 1, // older than profile's current generation 2
        job: OnboardingCompletionJob(
          jobId: 'old-completed-run',
          ownerUid: uid,
          draftRevision: 15,
          sourceFingerprint: 'old-fp',
          setupGeneration: 1,
          status: OnboardingJobStatus.completed,
          stage: OnboardingCompletionStage.completed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final result = classifyServerReconstruction(
        ownerUid: uid,
        profile: profile,
        draft: draft,
        completionBundle: null,
        currentRun: run,
      );
      expect(result, isA<ReconstructionRecovery>());
      expect(
        (result as ReconstructionRecovery).diagnostics['code'],
        'completed_profile_with_superseded_run',
      );
    });

    // 12. Legacy pointer without setupGeneration (treated as gen 0)
    test(
      '12. Legacy pointer without setupGeneration behaves as generation 0',
      () {
        // If profile is generation 0, it is evaluated as same lineage
        final profileGen0 = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 0);
        final draftGen0 = _validDraftAtStep(uid, 2, setupGeneration: 0);
        final legacyRunMismatch = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'legacy-run',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: 'different-fp',
          draftRevision: 10,
          setupGeneration: 0, // legacy default
          pointerOrigin: CurrentRunPointerOrigin.legacyFixedJob,
          job: OnboardingCompletionJob(
            jobId: 'legacy-run',
            ownerUid: uid,
            draftRevision: 10,
            sourceFingerprint: 'different-fp',
            setupGeneration: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final resultGen0 = classifyServerReconstruction(
          ownerUid: uid,
          profile: profileGen0,
          draft: draftGen0,
          completionBundle: null,
          currentRun: legacyRunMismatch,
        );
        expect(resultGen0, isA<ReconstructionRecovery>());
        expect(
          (resultGen0 as ReconstructionRecovery).diagnostics['code'],
          'completion_run_input_mismatch',
        );

        // But if profile has been reset to generation 1, the legacy run is superseded!
        final profileGen1 = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 1);
        final draftGen1 = _validDraftAtStep(uid, 2, setupGeneration: 1);
        final resultGen1 = classifyServerReconstruction(
          ownerUid: uid,
          profile: profileGen1,
          draft: draftGen1,
          completionBundle: null,
          currentRun: legacyRunMismatch,
        );
        expect(resultGen1, isA<ReconstructionIncomplete>());
        expect((resultGen1 as ReconstructionIncomplete).step, 2);
      },
    );
  });

  group('Step-14 Completion Writer Lineage Fencing', () {
    test(
      'Late completion writer from old generation is rejected by proof evaluation',
      () {
        final profile = UserProfile.empty(uid: uid).copyWith(
          currentSetupGeneration: 2, // profile moved forward
        );
        final draft = _finalDraft(uid, setupGeneration: 2);
        final bundle = _bundleForDraft(
          draft,
          setupGeneration: 1,
          runId: 'run-gen1',
        ); // stale bundle from gen 1
        final job = OnboardingCompletionJob(
          jobId: 'run-gen1',
          ownerUid: uid,
          stage: OnboardingCompletionStage.finalizeProfile,
          setupGeneration: 1, // stale job from gen 1
          draftRevision: draft.revision,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final runSnapshot = OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'run-gen1',
          ownerUid: uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
          setupGeneration: 1,
          job: job,
        );

        final proof = CompletionTerminalizationProof.evaluate(
          authenticatedUid: uid,
          expectedRunId: 'run-gen1',
          profile: profile,
          draft: draft,
          bundle: bundle,
          currentRun: runSnapshot.toTerminalizationState(),
          durableOutputsVerified: true,
        );

        expect(proof.canTerminalize, isFalse);
        expect(
          proof.disposition,
          CompletionTerminalizationDisposition.notEligible,
        );
        expect(
          proof.reason,
          CompletionTerminalizationReason.invalidCompletionBundle,
        );
      },
    );
  });

  group('OnboardingSetupResetCoordinator', () {
    test(
      'Atomic reset updates profile, draft, and marks in-memory run superseded',
      () async {
        final profileRepo = _InMemoryProfileRepository();
        final onboardingRepo = _InMemoryOnboardingRepository();
        final memoryStore = OnboardingCompletionMemoryStore();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
          routineRepository: null,
          conflictAcceptanceRepository: null,
          firestore: null,
          requirePersistentJobs: false,
          requireFrontendHydration: false,
          requireRoutineVerification: false,
          memoryStore: memoryStore,
        );

        final initialProfile = UserProfile.empty(
          uid: uid,
        ).copyWith(currentSetupGeneration: 0, onboardingCompleted: true);
        await profileRepo.saveUserProfile(initialProfile);
        memoryStore.currentRunIds[uid] = 'run-0';
        memoryStore.currentRunStatuses[uid] = 'active';

        final coordinator = OnboardingSetupResetCoordinator(
          profileRepository: profileRepo,
          onboardingRepository: onboardingRepo,
          jobService: jobService,
        );

        final result1 = await coordinator.resetSetup(
          uid: uid,
          resetOperationId: 'op-123',
        );

        expect(result1.setupGeneration, 1);
        expect(result1.profile.currentSetupGeneration, 1);
        expect(result1.profile.lastResetOperationId, 'op-123');
        expect(result1.profile.onboardingCompleted, isFalse);
        expect(result1.profile.onboardingProjectionStatus, 'pending');
        expect(result1.draft.setupGeneration, 1);
        expect(result1.draft.lastResetOperationId, 'op-123');
        expect(memoryStore.currentRunStatuses[uid], 'superseded');

        // Idempotency: second call with same operationId does not increment again
        final result2 = await coordinator.resetSetup(
          uid: uid,
          resetOperationId: 'op-123',
        );
        expect(result2.setupGeneration, 1);
        expect(result2.profile.currentSetupGeneration, 1);
      },
    );
  });
}

OnboardingDraft _validDraftAtStep(
  String uid,
  int step, {
  int setupGeneration = 0,
  int revision = 1,
}) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var index = 0; index < step; index++) {
    completed[index] = true;
  }
  return OnboardingDraft(
    uid: uid,
    currentStep: step,
    stepCompleted: completed,
    setupGeneration: setupGeneration,
    revision: revision,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'male',
    ),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    baseTimeline: const BaseTimelineDraft(
      eatingSetupPath: 'skip',
      eatingMode: 'flat',
      shouldPlanMeals: false,
      skinCareSkipped: true,
    ).withRequiredFixedBlocks(),
  );
}

OnboardingDraft _finalDraft(String uid, {int setupGeneration = 0}) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: completed,
    onboardingCompleted: true,
    setupGeneration: setupGeneration,
    revision: 15,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'male',
    ),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    baseTimeline: const BaseTimelineDraft(
      eatingSetupPath: 'skip',
      eatingMode: 'flat',
      shouldPlanMeals: false,
      skinCareSkipped: true,
    ).withRequiredFixedBlocks(),
  );
}

OnboardingCompletionBundle _bundleForDraft(
  OnboardingDraft draft, {
  required int setupGeneration,
  String? runId,
}) {
  final now = DateTime.now();
  return OnboardingCompletionBundle(
    uid: draft.uid,
    runId:
        runId ??
        stableOnboardingRunId(
          ownerUid: draft.uid,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
        ),
    createdAt: now,
    updatedAt: now,
    setupGeneration: setupGeneration,
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
    userProfilePatch: const {},
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
  );
}

class _InMemoryProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async => _profiles[uid];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  Future<UserProfileSettings> fetchProfileSettings(String uid) async =>
      const UserProfileSettings();

  @override
  Future<void> saveProfileSettings(
    String uid,
    UserProfileSettings settings,
  ) async {}
}

class _InMemoryOnboardingRepository implements OnboardingRepository {
  final Map<String, OnboardingDraft> _drafts = {};
  final Map<String, OnboardingCompletionBundle> _bundles = {};

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async => _drafts[uid];

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _drafts[draft.uid] = draft;
  }

  @override
  Future<void> flushPendingDraftSave() async {}

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    _drafts[draft.uid] = draft;
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async =>
      _bundles[uid];

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    _bundles[bundle.uid] = bundle;
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    await saveDraft(finalDraft);
    _bundles[bundle.uid] = bundle;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: RoutineOnboardingProjection.build(bundle).receipt,
    );
  }

  @override
  void dispose() {}
}
