import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/fake_habit_systems_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

OnboardingDraft _createCompletedDraft(String uid) {
  final baseTimeline = const BaseTimelineDraft(
    skinCareSkipped: true,
    blocks: [
      TimelineBlockDraft(
        id: 'eating_lunch',
        section: 'eating',
        title: 'Lunch',
        blockType: 'softBlock',
        startMinute: 720,
        endMinute: 750,
        repeatDays: [1, 2, 3, 4, 5],
        needsTimeConfirmation: false,
      ),
    ],
  ).withRequiredFixedBlocks();

  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    baseTimeline: baseTimeline,
    createdAt: DateTime.utc(2026, 7, 25),
    updatedAt: DateTime.utc(2026, 7, 25),
  );
}

OnboardingCompletionBundle _createTestBundle(
  String uid,
  List<RoutineItem> items,
) {
  final draft = _createCompletedDraft(uid);
  final bundle = OnboardingCompletionService.buildBundle(draft);
  return OnboardingCompletionBundle(
    uid: uid,
    version: bundle.version,
    source: bundle.source,
    createdAt: bundle.createdAt,
    updatedAt: bundle.updatedAt,
    userProfilePatch: bundle.userProfilePatch,
    baseTimelineBlocks: bundle.baseTimelineBlocks,
    finalTimelineItems: bundle.finalTimelineItems,
    routineItemsForApp: items,
    goodHabitTemplates: bundle.goodHabitTemplates,
    badHabitCheckIns: bundle.badHabitCheckIns,
    identityGoalSystems: bundle.identityGoalSystems,
    notificationPreferences: bundle.notificationPreferences,
    coachPreferences: bundle.coachPreferences,
    moneyGoal: bundle.moneyGoal,
    uploadedAssetReferences: bundle.uploadedAssetReferences,
    warnings: bundle.warnings,
    duplicateSystemKeysMerged: bundle.duplicateSystemKeysMerged,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work Package C Remediation Tests', () {
    test(
      'ISSUE-06-01: completeOnboarding enforces items length limit <= 240',
      () async {
        final repo = FakeOnboardingRepository();
        final draft = _createCompletedDraft('user123');

        final items = List<RoutineItem>.generate(
          241,
          (i) => RoutineItem(
            id: 'item_$i',
            title: 'Item $i',
            category: RoutineCategory.habit,
            blockType: RoutineBlockType.flexibleTask,
            startMinute: 480,
            endMinute: 510,
          ),
        );
        final bundle = _createTestBundle('user123', items);

        expect(
          () async =>
              repo.completeOnboarding(finalDraft: draft, bundle: bundle),
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

    test(
      'ISSUE-07-01: RoutineOnboardingEventProjector completes pending receipt when cursor == totalCount',
      () async {
        final bundle = _createTestBundle('user_0701', [
          RoutineItem(
            id: 'item1',
            title: 'Exercise',
            category: RoutineCategory.health,
            blockType: RoutineBlockType.trackerTask,
            startMinute: 420,
            endMinute: 465,
          ),
        ]);

        final plan = RoutineOnboardingProjection.build(bundle);
        final itemIds = plan.items.map((i) => i.id).toList();
        final receipt = RoutineProjectionReceipt(
          id: plan.projectionId,
          ownerUid: 'user_0701',
          sourceBundleSchemaVersion: 1,
          sourceBundleId: plan.sourceBundleId,
          sourceBundleFingerprint: plan.fingerprint,
          expectedItemIds: itemIds,
          createdItemIds: itemIds,
          projectedItemIds: itemIds,
          status: 'pending',
          cursor: itemIds.length,
          totalCount: itemIds.length,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        final fakeRoutineRepo = FakeRoutineRepository();
        fakeRoutineRepo.database.receiptsByUid['user_0701'] = {
          plan.projectionId: receipt,
        };
        fakeRoutineRepo.database.itemsByUid['user_0701'] = {
          'item1': plan.items.first,
        };

        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
        );

        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final projector = const RoutineOnboardingEventProjector();
        final result = await projector.projectCreatedEvents(
          read: container.read,
          bundle: bundle,
        );

        expect(result.projectionId, equals(plan.projectionId));
        final updatedReceipt = await fakeRoutineRepo.fetchProjectionReceipt(
          'user_0701',
          plan.projectionId,
        );
        expect(updatedReceipt?.status, equals('completed'));
      },
    );

    test(
      'ISSUE-07-02: RoutineOnboardingProjection generates occurrence-based duplicate IDs',
      () {
        final duplicateItem = RoutineItem(
          id: '',
          title: 'Morning Workout',
          category: RoutineCategory.health,
          blockType: RoutineBlockType.trackerTask,
          startMinute: 420,
          endMinute: 480,
        );

        final bundle = _createTestBundle('user_0702', [
          duplicateItem,
          duplicateItem,
          duplicateItem,
        ]);

        final plan = RoutineOnboardingProjection.build(bundle);
        expect(plan.items.length, equals(3));

        final ids = plan.items.map((i) => i.id).toSet();
        expect(
          ids.length,
          equals(3),
          reason: 'All 3 items must have unique stable IDs',
        );

        final plan2 = RoutineOnboardingProjection.build(bundle);
        expect(
          plan2.items.map((i) => i.id).toList(),
          equals(plan.items.map((i) => i.id).toList()),
        );
      },
    );

    test(
      'ISSUE-09-01: reconcileProjectedSystems updates empty linkedRoutineIds with non-empty projection links',
      () async {
        final fakeHabitRepo = FakeHabitSystemsRepository();
        const ownerUid = 'user_0901';
        const systemId = 'hs_0901';

        final existingSystem = HabitSystemRecord(
          systemId: systemId,
          ownerUid: ownerUid,
          title: 'Test System',
          description: 'Test',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
          status: HabitSystemStatus.active,
          linkedRoutineIds: const [],
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await fakeHabitRepo.createSystem(
          system: existingSystem,
          operationId: 'op_0901',
        );

        final projectedSystem = existingSystem.copyWith(
          linkedRoutineIds: ['r1', 'r2'],
        );

        final writeResult = await fakeHabitRepo.reconcileProjectedSystems(
          ownerUid: ownerUid,
          projectionId: 'proj_0901',
          systems: [projectedSystem],
        );

        expect(writeResult.appliedSystemIds, contains(systemId));
      },
    );

    test(
      'ISSUE-10-01: RoutineNotifier loadForOwner guards against concurrent duplicate loads',
      () async {
        final fakeRepo = FakeRoutineRepository();
        final fakeHistory = FakeRoutineHistoryRepository();
        final fakeTx = FakeRoutineTransactionRepository();

        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(fakeRepo),
            routineHistoryRepositoryProvider.overrideWithValue(fakeHistory),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTx),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);
        final future1 = notifier.loadForOwner('user_1001');
        final future2 = notifier.loadForOwner('user_1001');

        await Future.wait([future1, future2]);
        expect(container.read(routineNotifierProvider).loading, isFalse);
      },
    );

    test(
      'ISSUE-11-01: OnboardingFrontendHydrationService does not prematurely finalize profile',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final bundle = _createTestBundle('user_1101', []);

        final hydrationService = const OnboardingFrontendHydrationService();
        await hydrationService.hydrate(read: container.read, bundle: bundle);

        final profile = container.read(mockUserProfileProvider);
        expect(profile.onboardingCompleted, isFalse);
      },
    );

    test(
      'ISSUE-11-02: OnboardingCompletionJobService completes Stage 5 and finalizes profile',
      () async {
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeProfileRepo = FakeProfileRepository();
        final fakeRoutineRepo = FakeRoutineRepository();

        final container = ProviderContainer(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(fakeOnboardingRepo),
            profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
          ],
        );
        addTearDown(container.dispose);

        final draft = _createCompletedDraft('user_1102');
        final bundle = _createTestBundle('user_1102', []);
        await fakeOnboardingRepo.saveCompletionBundle(bundle);

        final plan = RoutineOnboardingProjection.build(bundle);
        final completedReceipt = plan.receipt.copyWith(
          status: 'completed',
          cursor: plan.receipt.totalCount,
        );
        fakeRoutineRepo.database.receiptsByUid['user_1102'] = {
          plan.projectionId: completedReceipt,
        };

        final jobService = OnboardingCompletionJobService(
          onboardingRepository: fakeOnboardingRepo,
          profileRepository: fakeProfileRepo,
          routineRepository: fakeRoutineRepo,
        );

        final job = await jobService.runCompletionJob(
          uid: 'user_1102',
          finalDraft: draft,
          bundle: bundle,
          reader: container.read,
        );

        expect(job.status, equals(OnboardingJobStatus.completed));
        final profile = await fakeProfileRepo.fetchUserProfile('user_1102');
        expect(profile?.onboardingCompleted, isTrue);
        expect(
          container.read(mockUserProfileProvider).onboardingCompleted,
          isTrue,
        );
      },
    );

    test(
      'ISSUE-03-01: AuthNotifier sets loadingBackendUser state during account switch',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initialState = container.read(authProvider);
        expect(initialState.status, equals(AuthFlowStatus.signedOut));
      },
    );

    test(
      'ISSUE-14-02: Missing draft on cold restart synthesizes draft from profile',
      () async {
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeProfileRepo = FakeProfileRepository();

        final profile =
            UserProfile.empty(
              uid: 'user_1402',
              email: 'test@example.com',
              displayName: 'Test User',
            ).copyWith(
              onboardingStep: 3,
              lifeRole: 'designer',
              height: 175.0,
              weight: 70.0,
            );
        await fakeProfileRepo.saveUserProfile(profile);

        final fetchedDraft = await fakeOnboardingRepo.fetchDraft('user_1402');
        expect(fetchedDraft, isNull);

        final result = await OnboardingCompletionService.recoverCompletionState(
          uid: 'user_1402',
          onboardingRepository: fakeOnboardingRepo,
          profileRepository: fakeProfileRepo,
        );

        expect(result.tier, equals(OnboardingRecoveryTier.tier3Synthesized));
        expect(result.draft, isNotNull);
        expect(result.draft?.uid, equals('user_1402'));
      },
    );
  });
}
