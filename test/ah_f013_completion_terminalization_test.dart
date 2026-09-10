import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/fake_habit_systems_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/completion_terminalization_proof.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/auth_generation.dart';

void main() {
  group('AH-F013 terminalization proof', () {
    test('normal and historical completed-profile gaps are eligible', () {
      final fixture = _Fixture();

      expect(
        fixture.prove(profile: fixture.incompleteProfile).disposition,
        CompletionTerminalizationDisposition.eligible,
      );
      expect(
        fixture.prove(profile: fixture.completedProfile).disposition,
        CompletionTerminalizationDisposition.eligible,
      );
    });

    test('completed profile alone cannot prove completion', () {
      final fixture = _Fixture();
      final proof = fixture.prove(
        profile: fixture.completedProfile,
        durableOutputsVerified: false,
      );

      expect(
        proof.disposition,
        CompletionTerminalizationDisposition.notEligible,
      );
      expect(
        proof.reason,
        CompletionTerminalizationReason.invalidOutputAccounting,
      );
    });

    test('owner mismatch and dangling current run require Recovery', () {
      final fixture = _Fixture();
      expect(
        fixture
            .prove(
              profile: fixture.completedProfile,
              currentRun: fixture.currentRun(ownerUid: 'other-owner'),
            )
            .reason,
        CompletionTerminalizationReason.ownerMismatch,
      );
      expect(
        fixture
            .prove(
              profile: fixture.completedProfile,
              currentRun: fixture.currentRun(omitJob: true),
            )
            .reason,
        CompletionTerminalizationReason.currentRunMismatch,
      );
    });

    test(
      'unsupported schema and incompatible terminal failure cannot close',
      () {
        final fixture = _Fixture();
        expect(
          fixture
              .prove(
                profile: fixture.completedProfile,
                currentRun: fixture.currentRun(pointerSchemaVersion: 99),
              )
              .reason,
          CompletionTerminalizationReason.unsupportedSchema,
        );
        expect(
          fixture
              .prove(
                profile: fixture.completedProfile,
                currentRun: fixture.currentRun(
                  job: fixture.job.copyWith(
                    status: OnboardingJobStatus.fatalFailure,
                  ),
                ),
              )
              .reason,
          CompletionTerminalizationReason.incompatibleTerminalState,
        );
      },
    );

    test('stale run cannot terminalize a newer currentRun', () {
      final fixture = _Fixture();
      final proof = fixture.prove(
        profile: fixture.completedProfile,
        currentRun: fixture.currentRun(runId: 'newer-run'),
      );

      expect(
        proof.disposition,
        CompletionTerminalizationDisposition.recoveryRequired,
      );
      expect(proof.reason, CompletionTerminalizationReason.currentRunMismatch);
    });

    test('draft and bundle mismatch or incomplete draft is not eligible', () {
      final fixture = _Fixture();
      final incompleteDraft = fixture.draft.copyWith(
        onboardingCompleted: false,
        incrementRevision: false,
      );
      final proofIncomplete = CompletionTerminalizationProof.evaluate(
        authenticatedUid: _Fixture.uid,
        expectedRunId: fixture.runId,
        profile: fixture.completedProfile,
        draft: incompleteDraft,
        bundle: fixture.bundle,
        currentRun: fixture.currentRun(),
        durableOutputsVerified: true,
      );
      expect(
        proofIncomplete.disposition,
        CompletionTerminalizationDisposition.notEligible,
      );
      expect(
        proofIncomplete.reason,
        CompletionTerminalizationReason.invalidFinalDraft,
      );

      final mismatchedBundle = OnboardingCompletionBundle.fromMap(
        Map<String, dynamic>.from(fixture.bundle.toMap())
          ..['sourceFingerprint'] = 'a' * 64,
      );
      final proofMismatched = CompletionTerminalizationProof.evaluate(
        authenticatedUid: _Fixture.uid,
        expectedRunId: fixture.runId,
        profile: fixture.completedProfile,
        draft: fixture.draft,
        bundle: mismatchedBundle,
        currentRun: fixture.currentRun(),
        durableOutputsVerified: true,
      );
      expect(
        proofMismatched.disposition,
        CompletionTerminalizationDisposition.notEligible,
      );
      expect(
        proofMismatched.reason,
        CompletionTerminalizationReason.invalidCompletionBundle,
      );
    });

    test('failed output accounting blocks terminalization', () {
      final fixture = _Fixture();
      final jobWithFailedRoutine = fixture.job.copyWith(
        failedRoutineIds: ['routine_fail_1'],
      );
      final proof = fixture.prove(
        profile: fixture.completedProfile,
        currentRun: fixture.currentRun(job: jobWithFailedRoutine),
      );
      expect(
        proof.disposition,
        CompletionTerminalizationDisposition.notEligible,
      );
      expect(
        proof.reason,
        CompletionTerminalizationReason.invalidOutputAccounting,
      );
    });

    test('fully terminal retry is an already-terminal no-op', () {
      final fixture = _Fixture();
      final completedAt = DateTime.utc(2026, 8, 31);
      final completedJob = fixture.job.copyWith(
        status: OnboardingJobStatus.completed,
        stage: OnboardingCompletionStage.completed,
        stagesCompleted: {
          ...fixture.job.stagesCompleted,
          OnboardingCompletionStage.finalizeProfile.name: true,
        },
        completedAt: completedAt,
      );

      expect(
        fixture
            .prove(
              profile: fixture.completedProfile,
              currentRun: fixture.currentRun(
                job: completedJob,
                pointerStatus: 'completed',
              ),
            )
            .disposition,
        CompletionTerminalizationDisposition.alreadyTerminal,
      );
    });

    test(
      'final crash cut states converge without a partial terminal result',
      () {
        final fixture = _Fixture();
        final beforeTransaction = fixture.prove(
          profile: fixture.incompleteProfile,
        );
        final abortedTransaction = fixture.prove(
          profile: fixture.incompleteProfile,
        );
        expect(
          beforeTransaction.disposition,
          CompletionTerminalizationDisposition.eligible,
        );
        expect(
          abortedTransaction.disposition,
          CompletionTerminalizationDisposition.eligible,
        );

        final completedAt = DateTime.utc(2026, 8, 31, 1);
        final committedJob = fixture.job.copyWith(
          status: OnboardingJobStatus.completed,
          stage: OnboardingCompletionStage.completed,
          stagesCompleted: {
            ...fixture.job.stagesCompleted,
            OnboardingCompletionStage.finalizeProfile.name: true,
          },
          completedAt: completedAt,
        );
        final committedState = fixture.prove(
          profile: fixture.completedProfile,
          currentRun: fixture.currentRun(
            job: committedJob,
            pointerStatus: 'completed',
          ),
        );
        final responseLostThenReread = fixture.prove(
          profile: fixture.completedProfile,
          currentRun: fixture.currentRun(
            job: committedJob,
            pointerStatus: 'completed',
          ),
        );
        expect(
          committedState.disposition,
          CompletionTerminalizationDisposition.alreadyTerminal,
        );
        expect(
          responseLostThenReread.disposition,
          CompletionTerminalizationDisposition.alreadyTerminal,
        );
        expect(
          fixture.prove(profile: fixture.completedProfile).disposition,
          CompletionTerminalizationDisposition.eligible,
        );
      },
    );
  });

  group('AH-F013 completion service closure and durable verification', () {
    test(
      'normal closure and repeated retry produce one coherent terminal state',
      () async {
        const uid = _Fixture.uid;
        final onboarding = _CountingOnboardingRepository();
        final profiles = FakeProfileRepository();
        final service = OnboardingCompletionJobService(
          onboardingRepository: onboarding,
          profileRepository: profiles,
        );
        final draft = _Fixture().draft;
        final bundle = _Fixture().bundle;
        await profiles.saveUserProfile(
          UserProfile.empty(uid: uid, email: 'terminal@example.com'),
        );

        final first = await service.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
        );
        final originalCompletedAt = first.completedAt;
        final second = await service.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
        );
        final snapshot = await service.loadCurrentRunSnapshot(uid);
        final profile = await profiles.fetchUserProfile(uid);

        expect(first.status, OnboardingJobStatus.completed);
        expect(first.stage, OnboardingCompletionStage.completed);
        expect(
          first.isStageCompleted(OnboardingCompletionStage.finalizeProfile),
          isTrue,
        );
        expect(profile?.onboardingCompleted, isTrue);
        expect(snapshot.pointerStatus, 'completed');
        expect(snapshot.job?.status, OnboardingJobStatus.completed);
        expect(second.completedAt, originalCompletedAt);
        expect(onboarding.completionCalls, 1);
      },
    );

    test('two concurrent terminalizers deduplicate output work', () async {
      const uid = _Fixture.uid;
      final onboarding = _CountingOnboardingRepository();
      final profiles = FakeProfileRepository();
      final service = OnboardingCompletionJobService(
        onboardingRepository: onboarding,
        profileRepository: profiles,
      );
      final fixture = _Fixture();
      await profiles.saveUserProfile(
        UserProfile.empty(uid: uid, email: 'terminal@example.com'),
      );

      final results = await Future.wait([
        service.runCompletionJob(
          uid: uid,
          finalDraft: fixture.draft,
          bundle: fixture.bundle,
        ),
        service.runCompletionJob(
          uid: uid,
          finalDraft: fixture.draft,
          bundle: fixture.bundle,
        ),
      ]);

      expect(
        results.map((job) => job.status),
        everyElement(OnboardingJobStatus.completed),
      );
      expect(onboarding.completionCalls, 1);
    });

    test('invalid projection receipt blocks terminalization', () async {
      const uid = _Fixture.uid;
      final db = FakeRoutineDatabase();
      final onboarding = FakeOnboardingRepository(routineDatabase: db);
      final profiles = FakeProfileRepository();
      final routines = FakeRoutineRepository(database: db);
      final fixture = _Fixture();

      final service = OnboardingCompletionJobService(
        onboardingRepository: onboarding,
        profileRepository: profiles,
        routineRepository: routines,
        requireRoutineVerification: true,
      );
      await profiles.saveUserProfile(fixture.incompleteProfile);

      // Save an incomplete receipt (cursor != totalCount)
      final plan = RoutineOnboardingProjection.build(fixture.bundle);
      db.receiptsByUid.putIfAbsent(
        uid,
        () => {},
      )[plan.projectionId] = RoutineProjectionReceipt(
        id: plan.projectionId,
        ownerUid: uid,
        sourceBundleId: fixture.bundle.runId,
        sourceBundleSchemaVersion: fixture.bundle.version,
        sourceBundleFingerprint: plan.fingerprint,
        status: 'pending',
        cursor: 0,
        totalCount: plan.items.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => service.runCompletionJob(
          uid: uid,
          finalDraft: fixture.draft,
          bundle: fixture.bundle,
        ),
        throwsStateError,
      );
      final profile = await profiles.fetchUserProfile(uid);
      expect(profile?.onboardingCompleted, isFalse);
    });

    test('missing projected history record blocks terminalization', () async {
      const uid = _Fixture.uid;
      final db = FakeRoutineDatabase();
      final onboarding = FakeOnboardingRepository(routineDatabase: db);
      final profiles = FakeProfileRepository();
      final routines = FakeRoutineRepository(database: db);
      final history = FakeRoutineHistoryRepository();
      final habits = FakeHabitSystemsRepository();
      final fixture = _Fixture();

      final container = ProviderContainer(
        overrides: [
          routineRepositoryProvider.overrideWithValue(routines),
          routineHistoryRepositoryProvider.overrideWithValue(history),
          habitSystemsRepositoryProvider.overrideWithValue(habits),
        ],
      );

      final service = OnboardingCompletionJobService(
        onboardingRepository: onboarding,
        profileRepository: profiles,
        routineRepository: routines,
        requireRoutineVerification: true,
      );
      await profiles.saveUserProfile(fixture.incompleteProfile);

      // Save a valid routine receipt and items but omit history records
      final plan = RoutineOnboardingProjection.build(fixture.bundle);
      db.receiptsByUid.putIfAbsent(
        uid,
        () => {},
      )[plan.projectionId] = RoutineProjectionReceipt(
        id: plan.projectionId,
        ownerUid: uid,
        sourceBundleId: fixture.bundle.runId,
        sourceBundleSchemaVersion: fixture.bundle.version,
        sourceBundleFingerprint: plan.fingerprint,
        status: 'completed',
        cursor: plan.items.length,
        totalCount: plan.items.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      for (final item in plan.items) {
        db.itemsByUid.putIfAbsent(uid, () => {})[item.id] = item.copyWith(
          userId: uid,
        );
      }

      expect(
        () => service.runCompletionJob(
          uid: uid,
          finalDraft: fixture.draft,
          bundle: fixture.bundle,
          reader: container.read,
        ),
        throwsStateError,
      );
      final profile = await profiles.fetchUserProfile(uid);
      expect(profile?.onboardingCompleted, isFalse);
    });

    test('missing habit system blocks terminalization', () async {
      const uid = _Fixture.uid;
      final db = FakeRoutineDatabase();
      final onboarding = FakeOnboardingRepository(routineDatabase: db);
      final profiles = FakeProfileRepository();
      final routines = FakeRoutineRepository(database: db);
      final history = FakeRoutineHistoryRepository();
      final habits = FakeHabitSystemsRepository();
      final fixture = _Fixture();

      final container = ProviderContainer(
        overrides: [
          routineRepositoryProvider.overrideWithValue(routines),
          routineHistoryRepositoryProvider.overrideWithValue(history),
          habitSystemsRepositoryProvider.overrideWithValue(habits),
        ],
      );

      final service = OnboardingCompletionJobService(
        onboardingRepository: onboarding,
        profileRepository: profiles,
        routineRepository: routines,
        requireRoutineVerification: true,
      );
      await profiles.saveUserProfile(fixture.incompleteProfile);

      // Save valid routine receipt and valid history but omit habit systems
      final plan = RoutineOnboardingProjection.build(fixture.bundle);
      db.receiptsByUid.putIfAbsent(
        uid,
        () => {},
      )[plan.projectionId] = RoutineProjectionReceipt(
        id: plan.projectionId,
        ownerUid: uid,
        sourceBundleId: fixture.bundle.runId,
        sourceBundleSchemaVersion: fixture.bundle.version,
        sourceBundleFingerprint: plan.fingerprint,
        status: 'completed',
        cursor: plan.items.length,
        totalCount: plan.items.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      for (final item in plan.items) {
        db.itemsByUid.putIfAbsent(uid, () => {})[item.id] = item.copyWith(
          userId: uid,
        );
      }
      final expectedHistory = const RoutineOnboardingEventProjector()
          .computeExpectedEventIds(fixture.bundle);
      for (final id in expectedHistory) {
        await history.appendHistory(
          uid,
          RoutineOccurrenceRecord(
            id: id,
            ownerUid: uid,
            routineItemId: 'item_1',
            occurrenceDateKey: '2026-08-31',
            status: RoutineStatus.planned,
            source: 'onboarding',
            action: 'create',
            operationKey: 'op_$id',
            onboardingProjectionId: plan.projectionId,
            onboardingSourceItemId: 'item_1',
            sourceFingerprint: fixture.bundle.effectiveSourceFingerprint,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (fixture.bundle.expectedHabitIds.isNotEmpty) {
        expect(
          () => service.runCompletionJob(
            uid: uid,
            finalDraft: fixture.draft,
            bundle: fixture.bundle,
            reader: container.read,
          ),
          throwsStateError,
        );
        final profile = await profiles.fetchUserProfile(uid);
        expect(profile?.onboardingCompleted, isFalse);
      }
    });

    test(
      'account switch mid-run isolates state and cancels stale job',
      () async {
        const userA = 'user-a';
        const userB = 'user-b';
        final onboarding = FakeOnboardingRepository();
        final profiles = FakeProfileRepository();
        final service = OnboardingCompletionJobService(
          onboardingRepository: onboarding,
          profileRepository: profiles,
        );

        final container = ProviderContainer(
          overrides: [authGenerationProvider.overrideWith((ref) => 1)],
        );

        service.cancelOwner(userA);

        final snapshotA = await service.loadCurrentRunSnapshot(userA);
        expect(snapshotA.hasPointer, isFalse);
        final snapshotB = await service.loadCurrentRunSnapshot(userB);
        expect(snapshotB.hasPointer, isFalse);
        container.dispose();
      },
    );

    test('fatally failed job cannot be terminalized', () async {
      const uid = _Fixture.uid;
      final onboarding = FakeOnboardingRepository();
      final profiles = FakeProfileRepository();
      final service = OnboardingCompletionJobService(
        onboardingRepository: onboarding,
        profileRepository: profiles,
      );
      final fixture = _Fixture();
      await profiles.saveUserProfile(fixture.completedProfile);

      // Save a fatal failure job by running with mismatched owner/draft
      final badBundle = OnboardingCompletionBundle.fromMap(
        Map<String, dynamic>.from(fixture.bundle.toMap())
          ..['sourceFingerprint'] = '0' * 64,
      );
      await expectLater(
        () => service.runCompletionJob(
          uid: uid,
          finalDraft: fixture.draft,
          bundle: badBundle,
        ),
        throwsA(isA<ArgumentError>()),
      );

      final job = await service.loadCurrentJob(uid);
      if (job?.status == OnboardingJobStatus.fatalFailure) {
        expect(
          () => service.runCompletionJob(
            uid: uid,
            finalDraft: fixture.draft,
            bundle: fixture.bundle,
          ),
          throwsStateError,
        );
      }
    });
  });

  group('AH-F013 server reconstructor and destination resolution', () {
    test(
      'AH-F007 classifies legacy gap as Finishing and repaired state as Completed',
      () {
        final fixture = _Fixture();
        final legacy = classifyServerReconstruction(
          ownerUid: _Fixture.uid,
          profile: fixture.completedProfile,
          draft: fixture.draft,
          completionBundle: fixture.bundle,
          currentRun: OnboardingCurrentRunSnapshot(
            hasPointer: true,
            runId: fixture.runId,
            ownerUid: _Fixture.uid,
            pointerSchemaVersion: 1,
            pointerStatus: 'active',
            sourceFingerprint: fixture.job.sourceFingerprint,
            draftRevision: fixture.job.draftRevision,
            job: fixture.job,
          ),
        );
        expect(legacy, isA<ReconstructionFinishing>());
        expect(
          resolveReconstructionDestination(legacy).kind,
          SessionDestinationKind.finishOnboarding,
        );

        final completedJob = fixture.job.copyWith(
          status: OnboardingJobStatus.completed,
          stage: OnboardingCompletionStage.completed,
          stagesCompleted: {
            ...fixture.job.stagesCompleted,
            OnboardingCompletionStage.finalizeProfile.name: true,
          },
          completedAt: DateTime.utc(2026, 8, 31),
        );
        final repaired = classifyServerReconstruction(
          ownerUid: _Fixture.uid,
          profile: fixture.completedProfile,
          draft: fixture.draft,
          completionBundle: fixture.bundle,
          currentRun: OnboardingCurrentRunSnapshot(
            hasPointer: true,
            runId: fixture.runId,
            ownerUid: _Fixture.uid,
            pointerSchemaVersion: 1,
            pointerStatus: 'completed',
            sourceFingerprint: fixture.job.sourceFingerprint,
            draftRevision: fixture.job.draftRevision,
            job: completedJob,
          ),
        );
        expect(repaired, isA<ReconstructionCompleted>());
        expect(
          resolveReconstructionDestination(repaired).kind,
          SessionDestinationKind.home,
        );
      },
    );

    test('dangling run or fatal failure reconstructs as Recovery', () {
      final fixture = _Fixture();
      final dangling = classifyServerReconstruction(
        ownerUid: _Fixture.uid,
        profile: fixture.completedProfile,
        draft: fixture.draft,
        completionBundle: fixture.bundle,
        currentRun: const OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: 'missing-job-id',
          ownerUid: _Fixture.uid,
          pointerSchemaVersion: 1,
          job: null,
        ),
      );
      expect(dangling, isA<ReconstructionRecovery>());
      expect(
        (dangling as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.danglingRunReference,
      );

      final fatal = classifyServerReconstruction(
        ownerUid: _Fixture.uid,
        profile: fixture.completedProfile,
        draft: fixture.draft,
        completionBundle: fixture.bundle,
        currentRun: OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: fixture.runId,
          ownerUid: _Fixture.uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'active',
          job: fixture.job.copyWith(status: OnboardingJobStatus.fatalFailure),
        ),
      );
      expect(fatal, isA<ReconstructionRecovery>());
      expect(
        (fatal as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.completionFatalFailure,
      );
    });

    test('invalid pointer status reconstructs as Recovery', () {
      final fixture = _Fixture();
      final invalidPointer = classifyServerReconstruction(
        ownerUid: _Fixture.uid,
        profile: fixture.completedProfile,
        draft: fixture.draft,
        completionBundle: fixture.bundle,
        currentRun: OnboardingCurrentRunSnapshot(
          hasPointer: true,
          runId: fixture.runId,
          ownerUid: _Fixture.uid,
          pointerSchemaVersion: 1,
          pointerStatus: 'corrupted_status',
          job: fixture.job,
        ),
      );
      expect(invalidPointer, isA<ReconstructionRecovery>());
      expect(
        (invalidPointer as ReconstructionRecovery).reason,
        ReconstructionRecoveryReason.durableStateConflict,
      );
    });
  });
}

class _Fixture {
  static const uid = 'ah-f013-owner';

  late final OnboardingDraft draft = OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    createdAt: DateTime.utc(2026, 8, 31),
    updatedAt: DateTime.utc(2026, 8, 31),
  );
  late final OnboardingCompletionBundle bundle =
      OnboardingCompletionService.buildBundle(draft);
  late final String runId = bundle.runId;
  late final OnboardingCompletionJob job = OnboardingCompletionJob(
    jobId: runId,
    ownerUid: uid,
    status: OnboardingJobStatus.running,
    stage: OnboardingCompletionStage.finalizeProfile,
    stagesCompleted: {
      for (final stage in OnboardingCompletionStage.values)
        if (stage.index <= OnboardingCompletionStage.verifyFrontendState.index)
          stage.name: true,
    },
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
    expectedRoutineIds: bundle.expectedRoutineIds,
    existingRoutineIds: bundle.expectedRoutineIds,
    expectedHistoryIds: bundle.expectedHistoryIds,
    existingHistoryIds: bundle.expectedHistoryIds,
    expectedHabitIds: bundle.expectedHabitIds,
    existingHabitIds: bundle.expectedHabitIds,
    expectedAcceptanceIds: bundle.expectedAcceptanceIds,
    existingAcceptanceIds: bundle.expectedAcceptanceIds,
    createdAt: DateTime.utc(2026, 8, 31),
    updatedAt: DateTime.utc(2026, 8, 31),
  );

  UserProfile get incompleteProfile =>
      UserProfile.empty(uid: uid, email: 'terminal@example.com');
  UserProfile get completedProfile => incompleteProfile.copyWith(
    onboardingInputCompleted: true,
    onboardingProjectionStatus: 'completed',
    onboardingCompleted: true,
  );

  CompletionTerminalizationState currentRun({
    String? runId,
    String? ownerUid,
    int pointerSchemaVersion = 1,
    String pointerStatus = 'active',
    OnboardingCompletionJob? job,
    bool omitJob = false,
  }) {
    return CompletionTerminalizationState(
      hasPointer: true,
      runId: runId ?? this.runId,
      ownerUid: ownerUid ?? uid,
      pointerSchemaVersion: pointerSchemaVersion,
      pointerStatus: pointerStatus,
      sourceFingerprint: this.job.sourceFingerprint,
      draftRevision: this.job.draftRevision,
      job: omitJob ? null : (job ?? this.job),
    );
  }

  CompletionTerminalizationProof prove({
    required UserProfile profile,
    CompletionTerminalizationState? currentRun,
    bool durableOutputsVerified = true,
  }) {
    return CompletionTerminalizationProof.evaluate(
      authenticatedUid: uid,
      expectedRunId: runId,
      profile: profile,
      draft: draft,
      bundle: bundle,
      currentRun: currentRun ?? this.currentRun(),
      durableOutputsVerified: durableOutputsVerified,
    );
  }
}

class _CountingOnboardingRepository extends FakeOnboardingRepository {
  int completionCalls = 0;

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) {
    completionCalls += 1;
    return super.completeOnboarding(finalDraft: finalDraft, bundle: bundle);
  }
}
