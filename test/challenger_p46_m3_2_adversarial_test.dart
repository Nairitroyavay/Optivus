import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger P46 M3.2: Recovery Data Integrity & Safety', () {
    test(
      'RebuildBundleFromVerifiedDraftAction in AuthNotifier never fabricates completion data',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeProfileRepo = FakeProfileRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
            profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
          ],
        );
        addTearDown(container.dispose);

        const testUser = AuthUser(
          uid: 'test-synth-uid',
          email: 'test@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );
        container.read(authProvider.notifier).state = const AuthState(
          user: testUser,
          status: AuthFlowStatus.signedInOnboardingComplete,
        );

        final notifier = container.read(authProvider.notifier);
        await notifier.executeRecoveryAction(
          const RebuildBundleFromVerifiedDraftAction(),
        );

        final authState = container.read(authProvider);
        final profile = container.read(mockUserProfileProvider);

        // The action must fail closed, not fabricate a resumable draft.
        expect(authState.status, equals(AuthFlowStatus.backendRestoreFailed));
        expect(profile.onboardingCompleted, isFalse);
        expect(profile.onboardingInputCompleted, isFalse);
        expect(profile.onboardingStep, equals(0));

        // Verify no completion bundle was created in the repository
        final bundle = await fakeOnboardingRepo.fetchCompletionBundle(
          testUser.uid,
        );
        expect(bundle, isNull);
      },
    );

    test(
      'ResumeOnboardingAction without a draft fails without fabrication',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        const testUser = AuthUser(
          uid: 'test-restart-uid',
          email: 'test@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );
        container.read(authProvider.notifier).state = const AuthState(
          user: testUser,
          status: AuthFlowStatus.backendRestoreFailed,
        );

        final notifier = container.read(authProvider.notifier);
        await notifier.executeRecoveryAction(const ResumeOnboardingAction());

        final authState = container.read(authProvider);
        final profile = container.read(mockUserProfileProvider);

        expect(authState.status, equals(AuthFlowStatus.backendRestoreFailed));
        expect(profile.onboardingCompleted, isFalse);
        expect(profile.onboardingStep, equals(0));
      },
    );

    test(
      'RebuildBundleFromVerifiedDraftAction with no artifacts fails closed',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeProfileRepo = FakeProfileRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
            profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
          ],
        );
        addTearDown(container.dispose);

        const testUser = AuthUser(
          uid: 'test-missing-draft-uid',
          email: 'test@example.com',
          isAnonymous: false,
          emailVerified: true,
          providerIds: {'password'},
        );
        container.read(authProvider.notifier).state = const AuthState(
          user: testUser,
          status: AuthFlowStatus.backendRestoreFailed,
        );

        final notifier = container.read(authProvider.notifier);
        await notifier.executeRecoveryAction(
          const RebuildBundleFromVerifiedDraftAction(),
        );

        final authState = container.read(authProvider);
        expect(authState.status, equals(AuthFlowStatus.backendRestoreFailed));
      },
    );
  });

  group('Challenger P46 M3.2: Batch Limits (N > 240 Items)', () {
    test(
      'completeOnboarding throws StateError when plan.items.length > 240',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        const uid = 'user-batch-limit-over';

        final draft = _completedDraft(uid);
        final baseBundle = OnboardingCompletionService.buildBundle(draft);

        final largeRoutines = List.generate(
          241,
          (i) => RoutineItem(
            id: 'routine-item-$i',
            userId: uid,
            title: 'Routine Item $i',
            category: RoutineCategory.fixed,
            blockType: RoutineBlockType.softBlock,
            startMinute: (i * 5) % (24 * 60),
            endMinute: ((i * 5) + 4) % (24 * 60),
          ),
        );

        final largeBundle = OnboardingCompletionBundle(
          uid: baseBundle.uid,
          version: baseBundle.version,
          source: baseBundle.source,
          createdAt: baseBundle.createdAt,
          updatedAt: baseBundle.updatedAt,
          userProfilePatch: baseBundle.userProfilePatch,
          baseTimelineBlocks: baseBundle.baseTimelineBlocks,
          finalTimelineItems: baseBundle.finalTimelineItems,
          routineItemsForApp: largeRoutines,
          goodHabitTemplates: baseBundle.goodHabitTemplates,
          badHabitCheckIns: baseBundle.badHabitCheckIns,
          identityGoalSystems: baseBundle.identityGoalSystems,
          notificationPreferences: baseBundle.notificationPreferences,
          coachPreferences: baseBundle.coachPreferences,
          moneyGoal: baseBundle.moneyGoal,
          uploadedAssetReferences: baseBundle.uploadedAssetReferences,
          warnings: baseBundle.warnings,
          duplicateSystemKeysMerged: baseBundle.duplicateSystemKeysMerged,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
        );

        final plan = RoutineOnboardingProjection.build(largeBundle);
        expect(plan.items.length, equals(241));

        expect(
          () => onboardingRepo.completeOnboarding(
            finalDraft: draft,
            bundle: largeBundle,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Onboarding produced too many Routine templates.'),
            ),
          ),
        );
      },
    );

    test('completeOnboarding succeeds when plan.items.length == 240', () async {
      final onboardingRepo = FakeOnboardingRepository();
      const uid = 'user-batch-limit-exact';

      final draft = _completedDraft(uid);
      final baseBundle = OnboardingCompletionService.buildBundle(draft);

      final exactRoutines = List.generate(
        240,
        (i) => RoutineItem(
          id: 'routine-item-$i',
          userId: uid,
          title: 'Routine Item $i',
          category: RoutineCategory.fixed,
          blockType: RoutineBlockType.softBlock,
          startMinute: (i * 5) % (24 * 60),
          endMinute: ((i * 5) + 4) % (24 * 60),
        ),
      );

      final exactBundle = OnboardingCompletionBundle(
        uid: baseBundle.uid,
        version: baseBundle.version,
        source: baseBundle.source,
        createdAt: baseBundle.createdAt,
        updatedAt: baseBundle.updatedAt,
        userProfilePatch: baseBundle.userProfilePatch,
        baseTimelineBlocks: baseBundle.baseTimelineBlocks,
        finalTimelineItems: baseBundle.finalTimelineItems,
        routineItemsForApp: exactRoutines,
        goodHabitTemplates: baseBundle.goodHabitTemplates,
        badHabitCheckIns: baseBundle.badHabitCheckIns,
        identityGoalSystems: baseBundle.identityGoalSystems,
        notificationPreferences: baseBundle.notificationPreferences,
        coachPreferences: baseBundle.coachPreferences,
        moneyGoal: baseBundle.moneyGoal,
        uploadedAssetReferences: baseBundle.uploadedAssetReferences,
        warnings: baseBundle.warnings,
        duplicateSystemKeysMerged: baseBundle.duplicateSystemKeysMerged,
        sourceFingerprint: draft.effectiveSourceFingerprint,
        draftRevision: draft.revision,
      );

      final plan = RoutineOnboardingProjection.build(exactBundle);
      expect(plan.items.length, equals(240));

      final result = await onboardingRepo.completeOnboarding(
        finalDraft: draft,
        bundle: exactBundle,
      );
      expect(result.receipt, isNotNull);
      expect(result.receipt.totalCount, equals(240));
    });

    test(
      'OnboardingCompletionJobService fails gracefully when N > 240',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        const uid = 'user-job-batch-limit';
        final draft = _completedDraft(uid);
        final baseBundle = OnboardingCompletionService.buildBundle(draft);

        final largeRoutines = List.generate(
          245,
          (i) => RoutineItem(
            id: 'routine-item-$i',
            userId: uid,
            title: 'Routine Item $i',
            category: RoutineCategory.fixed,
            blockType: RoutineBlockType.softBlock,
            startMinute: (i * 5) % (24 * 60),
            endMinute: ((i * 5) + 4) % (24 * 60),
          ),
        );
        final largeBundle = OnboardingCompletionBundle(
          uid: baseBundle.uid,
          version: baseBundle.version,
          source: baseBundle.source,
          createdAt: baseBundle.createdAt,
          updatedAt: baseBundle.updatedAt,
          userProfilePatch: baseBundle.userProfilePatch,
          baseTimelineBlocks: baseBundle.baseTimelineBlocks,
          finalTimelineItems: baseBundle.finalTimelineItems,
          routineItemsForApp: largeRoutines,
          goodHabitTemplates: baseBundle.goodHabitTemplates,
          badHabitCheckIns: baseBundle.badHabitCheckIns,
          identityGoalSystems: baseBundle.identityGoalSystems,
          notificationPreferences: baseBundle.notificationPreferences,
          coachPreferences: baseBundle.coachPreferences,
          moneyGoal: baseBundle.moneyGoal,
          uploadedAssetReferences: baseBundle.uploadedAssetReferences,
          warnings: baseBundle.warnings,
          duplicateSystemKeysMerged: baseBundle.duplicateSystemKeysMerged,
          sourceFingerprint: draft.effectiveSourceFingerprint,
          draftRevision: draft.revision,
        );

        await expectLater(
          () => jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: largeBundle,
          ),
          throwsA(isA<StateError>()),
        );

        final job = await jobService.loadCurrentJob(uid);
        expect(job, isNotNull);
        expect(job!.status, equals(OnboardingJobStatus.fatalFailure));
        expect(job.lastError, contains('Completion state validation failed.'));
        expect(job.lastError, isNot(contains('Routine templates')));
      },
    );
  });

  group('Challenger P46 M3.2: linkedRoutineIds & Receipt Cursor Idempotency', () {
    test(
      'HabitSystemOnboardingProjection build is deterministic and idempotent',
      () {
        const uid = 'user-hs-idempotent';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);

        final routines = <RoutineItem>[
          RoutineItem(
            id: 'r1',
            userId: uid,
            title: 'Hydration Routine',
            category: RoutineCategory.habit,
            blockType: RoutineBlockType.softBlock,
            startMinute: 480,
            endMinute: 500,
          ),
          RoutineItem(
            id: 'r2',
            userId: uid,
            title: 'Skin Care Morning',
            category: RoutineCategory.skinCare,
            blockType: RoutineBlockType.softBlock,
            startMinute: 420,
            endMinute: 435,
          ),
        ];

        final systemsRun1 = HabitSystemOnboardingProjection.build(
          bundle,
          routines,
        );
        final systemsRun2 = HabitSystemOnboardingProjection.build(
          bundle,
          routines,
        );

        expect(systemsRun1.length, equals(systemsRun2.length));
        for (var i = 0; i < systemsRun1.length; i++) {
          expect(systemsRun1[i].systemId, equals(systemsRun2[i].systemId));
          expect(
            systemsRun1[i].linkedRoutineIds,
            equals(systemsRun2[i].linkedRoutineIds),
          );
        }
      },
    );

    test(
      'RoutineOnboardingEventProjector handles completed receipts idempotently',
      () async {
        final routineRepo = FakeRoutineRepository();
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
        );
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          ],
        );
        addTearDown(container.dispose);

        const uid = 'user-cursor-idempotent';
        final draft = _completedDraft(uid);
        final baseBundle = OnboardingCompletionService.buildBundle(draft);

        final sampleRoutines = List.generate(
          5,
          (i) => RoutineItem(
            id: 'routine-sample-$i',
            userId: uid,
            title: 'Sample Routine $i',
            category: RoutineCategory.fixed,
            blockType: RoutineBlockType.softBlock,
            startMinute: (i * 10) % (24 * 60),
            endMinute: ((i * 10) + 9) % (24 * 60),
          ),
        );

        final bundle = OnboardingCompletionBundle(
          uid: baseBundle.uid,
          version: baseBundle.version,
          source: baseBundle.source,
          createdAt: baseBundle.createdAt,
          updatedAt: baseBundle.updatedAt,
          userProfilePatch: baseBundle.userProfilePatch,
          baseTimelineBlocks: baseBundle.baseTimelineBlocks,
          finalTimelineItems: baseBundle.finalTimelineItems,
          routineItemsForApp: sampleRoutines,
          goodHabitTemplates: baseBundle.goodHabitTemplates,
          badHabitCheckIns: baseBundle.badHabitCheckIns,
          identityGoalSystems: baseBundle.identityGoalSystems,
          notificationPreferences: baseBundle.notificationPreferences,
          coachPreferences: baseBundle.coachPreferences,
          moneyGoal: baseBundle.moneyGoal,
          uploadedAssetReferences: baseBundle.uploadedAssetReferences,
          warnings: baseBundle.warnings,
          duplicateSystemKeysMerged: baseBundle.duplicateSystemKeysMerged,
        );

        final plan = RoutineOnboardingProjection.build(bundle);

        // Pre-save routine items to database
        for (final item in plan.items) {
          await routineRepo.createRoutineItem(uid, item);
        }

        const projector = RoutineOnboardingEventProjector();

        // First run: project created events
        final result1 = await projector.projectCreatedEvents(
          read: container.read,
          bundle: bundle,
        );

        expect(result1.attemptedCount, equals(plan.items.length));

        final receiptAfter1 = await routineRepo.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        expect(receiptAfter1, isNotNull);
        expect(receiptAfter1!.status, equals('completed'));
        expect(receiptAfter1.cursor, equals(plan.items.length));

        // Second run: execute again on already completed receipt
        final result2 = await projector.projectCreatedEvents(
          read: container.read,
          bundle: bundle,
        );

        // Must be idempotent with 0 attempted count and matching applied events
        expect(result2.attemptedCount, equals(0));
        expect(result2.appliedEventIds, equals(result1.appliedEventIds));
      },
    );

    test(
      'RoutineOnboardingEventProjector resumes from partial cursor correctly',
      () async {
        final routineRepo = FakeRoutineRepository();
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
        );
        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
          ],
        );
        addTearDown(container.dispose);

        const uid = 'user-cursor-partial';
        final draft = _completedDraft(uid);
        final baseBundle = OnboardingCompletionService.buildBundle(draft);

        final sampleRoutines = List.generate(
          5,
          (i) => RoutineItem(
            id: 'routine-sample-$i',
            userId: uid,
            title: 'Sample Routine $i',
            category: RoutineCategory.fixed,
            blockType: RoutineBlockType.softBlock,
            startMinute: (i * 10) % (24 * 60),
            endMinute: ((i * 10) + 9) % (24 * 60),
          ),
        );

        final bundle = OnboardingCompletionBundle(
          uid: baseBundle.uid,
          version: baseBundle.version,
          source: baseBundle.source,
          createdAt: baseBundle.createdAt,
          updatedAt: baseBundle.updatedAt,
          userProfilePatch: baseBundle.userProfilePatch,
          baseTimelineBlocks: baseBundle.baseTimelineBlocks,
          finalTimelineItems: baseBundle.finalTimelineItems,
          routineItemsForApp: sampleRoutines,
          goodHabitTemplates: baseBundle.goodHabitTemplates,
          badHabitCheckIns: baseBundle.badHabitCheckIns,
          identityGoalSystems: baseBundle.identityGoalSystems,
          notificationPreferences: baseBundle.notificationPreferences,
          coachPreferences: baseBundle.coachPreferences,
          moneyGoal: baseBundle.moneyGoal,
          uploadedAssetReferences: baseBundle.uploadedAssetReferences,
          warnings: baseBundle.warnings,
          duplicateSystemKeysMerged: baseBundle.duplicateSystemKeysMerged,
        );

        final plan = RoutineOnboardingProjection.build(bundle);
        expect(plan.items.length, equals(5));

        for (final item in plan.items) {
          await routineRepo.createRoutineItem(uid, item);
        }

        // Save partial receipt with cursor = 2 out of 5 total items
        final now = DateTime.now().toUtc();
        final partialReceipt = RoutineProjectionReceipt(
          id: plan.projectionId,
          ownerUid: uid,
          slot: plan.slot,
          revision: plan.revision,
          sourceBundleSchemaVersion: OnboardingCompletionBundle.schemaVersion,
          sourceBundleId: plan.sourceBundleId,
          sourceBundleFingerprint: plan.fingerprint,
          expectedItemIds: plan.items.map((i) => i.id).toList(),
          status: 'pending',
          cursor: 2,
          totalCount: plan.items.length,
          createdItemIds: plan.items.map((i) => i.id).toList(),
          projectedItemIds: plan.items.map((i) => i.id).toList(),
          createdAt: now,
          updatedAt: now,
        );
        routineRepo.database.receiptsByUid.putIfAbsent(
          uid,
          () => {},
        )[plan.projectionId] = partialReceipt;

        const projector = RoutineOnboardingEventProjector();
        final result = await projector.projectCreatedEvents(
          read: container.read,
          bundle: bundle,
        );

        // Should attempt remaining 3 items (5 - 2 = 3)
        expect(result.attemptedCount, equals(3));

        final finalReceipt = await routineRepo.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        expect(finalReceipt!.status, equals('completed'));
        expect(finalReceipt.cursor, equals(5));
      },
    );
  });

  group('Challenger P46 M3.2: Structured Failure Payload Sanitization', () {
    test(
      'Simulated exception containing sensitive data (emails, auth tokens) redacts lastError while preserving structural fields',
      () async {
        final mockOnboardingRepo = _ConfigurableFakeOnboardingRepository(
          saveDraftException: StateError(
            'Authentication failed for secret.user@domain.com using token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.signature',
          ),
        );
        final fakeProfileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: mockOnboardingRepo,
          profileRepository: fakeProfileRepo,
        );

        const uid = 'user-sensitive-payload';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);

        await expectLater(
          () => jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: bundle,
          ),
          throwsA(isA<StateError>()),
        );

        final job = await jobService.loadCurrentJob(uid);
        expect(job, isNotNull);
        expect(job!.status, equals(OnboardingJobStatus.fatalFailure));
        expect(job.lastFailureStage, equals('persistDraft'));
        expect(job.lastFailureCode, equals('state_error'));
        expect(job.diagnosticCategory, equals('validation_failed'));

        // Structured diagnostics never retain source exception content.
        expect(job.lastError, isNotNull);
        expect(job.lastError, contains('Completion state validation failed.'));
        expect(job.lastError, isNot(contains('secret.user@domain.com')));
        expect(
          job.lastError,
          isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
        );
      },
    );

    test(
      'OnboardingCompletionFailureException preserves structural fields and sanitizes custom error message',
      () async {
        final mockOnboardingRepo = _ConfigurableFakeOnboardingRepository(
          completeOnboardingException: OnboardingCompletionFailureException(
            OnboardingCompletionFailure(
              code: 'ROUTINE_PROJECTION_TIMEOUT',
              stage: OnboardingCompletionStage.projectRoutines,
              retryable: true,
              publicMessageKey: 'error_projection_timeout',
              diagnosticCategory: 'network_timeout',
              failedEntityIds: const ['routine_101', 'routine_102'],
              occurredAt: DateTime.now(),
            ),
          ),
        );
        final fakeProfileRepo = FakeProfileRepository();
        final jobService = OnboardingCompletionJobService(
          onboardingRepository: mockOnboardingRepo,
          profileRepository: fakeProfileRepo,
        );

        const uid = 'user-structural-payload';
        final draft = _completedDraft(uid);
        final bundle = OnboardingCompletionService.buildBundle(draft);

        await expectLater(
          () => jobService.runCompletionJob(
            uid: uid,
            finalDraft: draft,
            bundle: bundle,
          ),
          throwsA(isA<OnboardingCompletionFailureException>()),
        );

        final job = await jobService.loadCurrentJob(uid);
        expect(job, isNotNull);
        expect(job!.status, equals(OnboardingJobStatus.retryableFailure));
        expect(job.lastFailureStage, equals('reconcileRoutines'));
        expect(job.lastFailureCode, equals('ROUTINE_PROJECTION_TIMEOUT'));
        expect(job.diagnosticCategory, equals('network_timeout'));
        expect(job.retryable, isTrue);
        expect(job.failedEntityIds, equals(['routine_101', 'routine_102']));
      },
    );
  });

  group(
    'Challenger P46 M3.2: Fine-Grained Completion Stage Ordering (Stage 5 UPDATE_PROFILE)',
    () {
      test(
        'Stage 5 (UPDATE_PROFILE) cannot execute if Stage 1 (PERSIST_DRAFT) fails',
        () async {
          final mockOnboardingRepo = _ConfigurableFakeOnboardingRepository(
            saveDraftException: StateError('Stage 1 persistence failed'),
          );
          final fakeProfileRepo = FakeProfileRepository();
          final jobService = OnboardingCompletionJobService(
            onboardingRepository: mockOnboardingRepo,
            profileRepository: fakeProfileRepo,
          );

          const uid = 'user-stage5-blocked-s1';
          final draft = _completedDraft(uid);
          final bundle = OnboardingCompletionService.buildBundle(draft);

          await expectLater(
            () => jobService.runCompletionJob(
              uid: uid,
              finalDraft: draft,
              bundle: bundle,
            ),
            throwsA(isA<StateError>()),
          );

          final job = await jobService.loadCurrentJob(uid);
          expect(job, isNotNull);
          expect(job!.status, equals(OnboardingJobStatus.fatalFailure));
          expect(
            job.isStageCompleted(OnboardingCompletionStage.updateProfile),
            isFalse,
          );
          expect(job.stagesCompleted['persistDraft'], isNot(true));

          final profile = await fakeProfileRepo.fetchUserProfile(uid);
          expect(profile?.onboardingCompleted, isNot(true));
        },
      );

      test(
        'Stage 5 (UPDATE_PROFILE) cannot execute if Stage 3 (PROJECT_ROUTINES) fails',
        () async {
          final mockOnboardingRepo = _ConfigurableFakeOnboardingRepository(
            completeOnboardingException: StateError(
              'Stage 3 projection failed',
            ),
          );
          final fakeProfileRepo = FakeProfileRepository();
          final jobService = OnboardingCompletionJobService(
            onboardingRepository: mockOnboardingRepo,
            profileRepository: fakeProfileRepo,
          );

          const uid = 'user-stage5-blocked-s3';
          final draft = _completedDraft(uid);
          final bundle = OnboardingCompletionService.buildBundle(draft);

          await expectLater(
            () => jobService.runCompletionJob(
              uid: uid,
              finalDraft: draft,
              bundle: bundle,
            ),
            throwsA(isA<StateError>()),
          );

          final job = await jobService.loadCurrentJob(uid);
          expect(job, isNotNull);
          expect(job!.status, equals(OnboardingJobStatus.fatalFailure));
          expect(
            job.isStageCompleted(OnboardingCompletionStage.persistDraft),
            isTrue,
          );
          expect(
            job.isStageCompleted(OnboardingCompletionStage.persistBundle),
            isTrue,
          );
          expect(
            job.isStageCompleted(OnboardingCompletionStage.projectRoutines),
            isFalse,
          );
          expect(
            job.isStageCompleted(OnboardingCompletionStage.updateProfile),
            isFalse,
          );

          final profile = await fakeProfileRepo.fetchUserProfile(uid);
          expect(profile?.onboardingCompleted, isNot(true));
        },
      );
    },
  );
}

OnboardingDraft _completedDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    onboardingCompleted: true,
    createdAt: DateTime.utc(2026, 8, 3),
    updatedAt: DateTime.utc(2026, 8, 3),
  );
}

class _ConfigurableFakeOnboardingRepository extends FakeOnboardingRepository {
  final Object? saveDraftException;
  final Object? completeOnboardingException;

  _ConfigurableFakeOnboardingRepository({
    this.saveDraftException,
    this.completeOnboardingException,
  });

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    if (saveDraftException != null) {
      throw saveDraftException!;
    }
    await super.saveFinalDraftImmediately(draft);
  }

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    if (saveDraftException != null) {
      return null;
    }
    return super.fetchDraft(uid);
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    if (completeOnboardingException != null) {
      throw completeOnboardingException!;
    }
    return super.completeOnboarding(finalDraft: finalDraft, bundle: bundle);
  }
}
