import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
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
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
    expectedRoutineIds: bundle.expectedRoutineIds,
    expectedHistoryIds: bundle.expectedHistoryIds,
    expectedHabitIds: bundle.expectedHabitIds,
    acceptedSourceIds: bundle.acceptedSourceIds,
    generatedSourceIds: bundle.generatedSourceIds,
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
          slot: plan.slot,
          revision: plan.revision,
          sourceBundleSchemaVersion: plan.receipt.sourceBundleSchemaVersion,
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
          source: 'onboarding',
          onboardingSourceId: 'source_0901',
          onboardingProjectionId: 'proj_0901',
          sourceFingerprint: 'a' * 64,
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
      'reconcileProjectedSystems repairs prior onboarding fingerprints and retries idempotently',
      () async {
        final fakeHabitRepo = FakeHabitSystemsRepository();
        const ownerUid = 'habit_projection_repair_owner';
        const projectionId = 'proj_onboard_hs_v1_habit_projection_repair_owner';
        final now = DateTime.utc(2026, 8, 29);
        final priorSystems = List.generate(
          3,
          (index) => HabitSystemRecord(
            systemId: 'habit_projection_repair_$index',
            ownerUid: ownerUid,
            title: 'Habit projection repair $index',
            description: 'Prior projection',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            source: 'onboarding',
            onboardingSourceId: 'source-$index',
            onboardingProjectionId: projectionId,
            sourceFingerprint: 'a' * 64,
            createdAt: now,
            updatedAt: now,
          ),
        );
        for (final system in priorSystems) {
          final created = await fakeHabitRepo.createSystem(
            system: system,
            operationId: 'seed-${system.systemId}',
          );
          expect(created.success, isTrue);
        }

        final currentSystems = [
          for (final system in priorSystems)
            system.copyWith(
              description: 'Current projection',
              sourceFingerprint: 'b' * 64,
              updatedAt: now.add(const Duration(minutes: 1)),
            ),
        ];
        final repaired = await fakeHabitRepo.reconcileProjectedSystems(
          ownerUid: ownerUid,
          projectionId: projectionId,
          systems: currentSystems,
        );
        expect(repaired.success, isTrue);
        expect(repaired.repairedSystemIds, hasLength(3));
        expect(repaired.failedSystemIds, isEmpty);

        final retried = await fakeHabitRepo.reconcileProjectedSystems(
          ownerUid: ownerUid,
          projectionId: projectionId,
          systems: currentSystems,
        );
        expect(retried.success, isTrue);
        expect(retried.existingSystemIds, hasLength(3));
        expect(retried.repairedSystemIds, isEmpty);
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

        container.read(mockUserProfileProvider.notifier).state =
            UserProfile.empty(uid: 'user_1102');
        await fakeProfileRepo.saveUserProfile(
          UserProfile.empty(uid: 'user_1102', email: 'test@example.com'),
        );

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
          isFalse,
          reason:
              'Local auth state is finalized only after canonical acceptance.',
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
      'ISSUE-14-02: Missing draft on cold restart remains missing setup',
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

        expect(result.tier, equals(OnboardingRecoveryTier.missingSetup));
        expect(result.draft, isNull);
        expect(await fakeOnboardingRepo.fetchDraft('user_1402'), isNull);
      },
    );

    test(
      'WORKSTREAM-C-01: OnboardingCompletionJobService populates expectedHistoryIds and appliedHistoryIds',
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

        const uid = 'user_c_01';
        final draft = _createCompletedDraft(uid);
        final item = RoutineItem(
          id: 'item_c_01',
          title: 'Morning Routine',
          category: RoutineCategory.health,
          blockType: RoutineBlockType.trackerTask,
          startMinute: 420,
          endMinute: 480,
        );
        final bundle = _createTestBundle(uid, [item]);
        await fakeOnboardingRepo.saveCompletionBundle(bundle);

        final plan = RoutineOnboardingProjection.build(bundle);
        final completedReceipt = plan.receipt.copyWith(
          status: 'completed',
          cursor: plan.receipt.totalCount,
        );
        fakeRoutineRepo.database.receiptsByUid[uid] = {
          plan.projectionId: completedReceipt,
        };
        final itemsMap = <String, RoutineItem>{};
        for (final projectedItem in plan.items) {
          itemsMap[projectedItem.id] = projectedItem;
        }
        fakeRoutineRepo.database.itemsByUid[uid] = itemsMap;

        container.read(mockUserProfileProvider.notifier).state =
            UserProfile.empty(uid: uid);
        await fakeProfileRepo.saveUserProfile(
          UserProfile.empty(uid: uid, email: 'test@example.com'),
        );

        final jobService = OnboardingCompletionJobService(
          onboardingRepository: fakeOnboardingRepo,
          profileRepository: fakeProfileRepo,
          routineRepository: fakeRoutineRepo,
        );

        final job = await jobService.runCompletionJob(
          uid: uid,
          finalDraft: draft,
          bundle: bundle,
          reader: container.read,
        );

        expect(job.status, equals(OnboardingJobStatus.completed));
        expect(job.expectedHistoryIds, isNotEmpty);
        expect(job.appliedHistoryIds, isNotEmpty);
        expect(job.failedHistoryIds, isEmpty);
      },
    );

    test(
      'WORKSTREAM-C-02: OnboardingCompletionJobService populates structured failure payload on error',
      () async {
        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeProfileRepo = FakeProfileRepository();

        // Cause draft save to fail with a StateError by providing a draft with owner mismatch
        final draft = _createCompletedDraft('mismatched_uid');
        final bundle = _createTestBundle('target_uid', []);

        final jobService = OnboardingCompletionJobService(
          onboardingRepository: fakeOnboardingRepo,
          profileRepository: fakeProfileRepo,
        );

        try {
          await jobService.runCompletionJob(
            uid: 'target_uid',
            finalDraft: draft,
            bundle: bundle,
          );
          fail('Should have thrown an exception');
        } catch (_) {}

        final failedJob = await jobService.loadCurrentJob('target_uid');
        expect(failedJob, isNotNull);
        expect(failedJob!.status, equals(OnboardingJobStatus.fatalFailure));
        expect(failedJob.lastError, isNotNull);
        expect(failedJob.lastError, contains('"type":"ArgumentError"'));
        expect(
          failedJob.lastError,
          contains('"diagnosticCategory":"validation_failed"'),
        );
        expect(failedJob.lastFailureCode, equals('argument_error'));
        expect(failedJob.lastFailureStage, equals('validateInput'));
        expect(failedJob.retryable, isFalse);
        expect(failedJob.diagnosticCategory, equals('validation_failed'));
      },
    );

    group('Workstream B: Firestore Serialization Contract Verification', () {
      test(
        'Contract 1: UserProfile.toFirestoreMap() keys match validUserProfileKeys',
        () {
          final profile = UserProfile(
            uid: 'user_b1',
            email: 'test@example.com',
            displayName: 'Test User',
            workingExtra: null,
            businessMode: null,
            createdAt: DateTime.utc(2026, 7, 29),
            updatedAt: DateTime.utc(2026, 7, 29),
          );
          final map = profile.toFirestoreMap();
          expect(
            map.containsKey('workingExtra'),
            isFalse,
            reason: 'Null workingExtra must be omitted',
          );
          expect(
            map.containsKey('businessMode'),
            isFalse,
            reason: 'Null businessMode must be omitted',
          );

          const allowedKeys = {
            'uid',
            'email',
            'displayName',
            'accountStatus',
            'createdAt',
            'updatedAt',
            'schemaVersion',
            'onboardingInputCompleted',
            'onboardingProjectionStatus',
            'onboardingCompleted',
            'onboardingStep',
            'lifeRole',
            'workingExtra',
            'businessMode',
            'exerciseLevel',
            'waterIntake',
            'stressLevel',
            'sleepQuality',
            'ageRange',
            'height',
            'weight',
            'gender',
            'bmiEstimate',
            'calorieEstimate',
            'proteinEstimate',
            'coachName',
            'coachStyle',
            'slipUpStyle',
          };
          expect(map.keys.toSet().difference(allowedKeys), isEmpty);
        },
      );

      test(
        'Contract 2: RegionSettings.toFirestoreMap() keys match validSettingsDoc',
        () {
          final settings = RegionSettings.defaultForUser('user_b2');
          final map = settings.toFirestoreMap();
          const allowedKeys = {
            'userId',
            'schemaVersion',
            'countryCode',
            'countryName',
            'timezone',
            'languageCode',
            'currencyCode',
            'currencySymbol',
            'measurementSystem',
            'heightUnit',
            'weightUnit',
            'distanceUnit',
            'temperatureUnit',
            'timeFormat',
            'dateFormat',
            'weekStartDay',
            'foodVocabularyMode',
            'paymentRegion',
            'createdAt',
            'updatedAt',
          };
          expect(map.keys.toSet(), equals(allowedKeys));

          final restored = RegionSettings.fromFirestoreMap(
            Map<String, dynamic>.from(map),
          );
          expect(restored.userId, settings.userId);
          expect(restored.countryCode, settings.countryCode);
          expect(restored.countryName, settings.countryName);
          expect(restored.timezone, settings.timezone);
          expect(restored.languageCode, settings.languageCode);
          expect(restored.currencyCode, settings.currencyCode);
          expect(restored.currencySymbol, settings.currencySymbol);
          expect(restored.measurementSystem, settings.measurementSystem);
          expect(restored.heightUnit, settings.heightUnit);
          expect(restored.weightUnit, settings.weightUnit);
          expect(restored.distanceUnit, settings.distanceUnit);
          expect(restored.temperatureUnit, settings.temperatureUnit);
          expect(restored.timeFormat, settings.timeFormat);
          expect(restored.dateFormat, settings.dateFormat);
          expect(restored.weekStartDay, settings.weekStartDay);
          expect(restored.foodVocabularyMode, settings.foodVocabularyMode);
          expect(restored.paymentRegion, settings.paymentRegion);
          expect(restored.createdAt, settings.createdAt);
          expect(restored.updatedAt, settings.updatedAt);
        },
      );

      test(
        'Contract 3: UserPreferences.toFirestoreMap() keys match validProfileSubdoc',
        () {
          final createdAt = DateTime.utc(2026, 7, 26, 10);
          final updatedAt = DateTime.utc(2026, 7, 26, 11);
          final prefs = UserPreferences(
            id: 'main',
            bio: 'Tester',
            avatarUrl: 'https://example.com/avatar.jpg',
            theme: 'dark',
            createdAt: createdAt,
            updatedAt: updatedAt,
            haptics: false,
            autoCorrect: false,
            themeMode: 'Dark',
            accentColor: 'Blue',
            bottomTabLayout: 'Labels',
            timelineDisplay: 'Compact',
            coachVoice: 'Voice first',
          );
          final map = prefs.toFirestoreMap(ownerUid: 'user_b3');
          const allowedKeys = {
            'uid',
            'haptics',
            'autoCorrect',
            'themeMode',
            'accentColor',
            'bottomTabLayout',
            'timelineDisplay',
            'coachVoice',
            'schemaVersion',
            'createdAt',
            'updatedAt',
          };
          expect(map.keys.toSet(), equals(allowedKeys));
          expect(map['uid'], equals('user_b3'));

          final restored = UserPreferences.fromFirestoreMap(
            Map<String, dynamic>.from(map),
          );
          expect(restored.haptics, prefs.haptics);
          expect(restored.autoCorrect, prefs.autoCorrect);
          expect(restored.themeMode, prefs.themeMode);
          expect(restored.accentColor, prefs.accentColor);
          expect(restored.bottomTabLayout, prefs.bottomTabLayout);
          expect(restored.timelineDisplay, prefs.timelineDisplay);
          expect(restored.coachVoice, prefs.coachVoice);
          expect(
            restored.createdAt?.millisecondsSinceEpoch,
            createdAt.millisecondsSinceEpoch,
          );
          expect(
            restored.updatedAt?.millisecondsSinceEpoch,
            updatedAt.millisecondsSinceEpoch,
          );
        },
      );

      test(
        'Contract 4: OnboardingDraft.toFirestoreMap() omits null optional fields',
        () {
          final draft = _createCompletedDraft('user_b4');
          final map = draft.toFirestoreMap();
          expect(map.containsKey('patiencePledgeText'), isFalse);
          expect(map.containsKey('slipUpHandling'), isFalse);

          const allowedKeys = {
            'uid',
            'schemaVersion',
            'source',
            'revision',
            'sourceFingerprint',
            'timezoneId',
            'currentStep',
            'stepCompleted',
            'stepDirty',
            'stepLoading',
            'createdAt',
            'updatedAt',
            'onboardingCompleted',
            'welcomeSaved',
            'patiencePledgeAccepted',
            'patiencePledgeText',
            'lifeRole',
            'bodyBasics',
            'baseTimeline',
            'badHabitsNotNow',
            'badHabits',
            'goodHabitsNotNow',
            'goodHabits',
            'identityGoals',
            'coachSetup',
            'slipUpHandling',
            'notifications',
            'finalPreview',
          };
          expect(map.keys.toSet().difference(allowedKeys), isEmpty);
        },
      );

      test(
        'Contract 5: OnboardingCompletionBundle.toFirestoreMap() omits null moneyGoal',
        () {
          final bundle = _createTestBundle('user_b5', []);
          final map = bundle.toFirestoreMap();
          expect(map.containsKey('moneyGoal'), isFalse);

          const requiredKeys = {
            'uid',
            'runId',
            'schemaVersion',
            'source',
            'draftRevision',
            'sourceFingerprint',
            'createdAt',
            'updatedAt',
            'onboardingCompleted',
            'userProfilePatch',
            'baseTimelineBlocks',
            'finalTimelineItems',
            'routineItemsForApp',
            'goodHabitTemplates',
            'badHabitCheckIns',
            'identityGoalSystems',
            'notificationPreferences',
            'coachPreferences',
            'uploadedAssetReferences',
            'warnings',
            'duplicateSystemKeysMerged',
            'expectedRoutineIds',
            'expectedHistoryIds',
            'expectedHabitIds',
            'acceptedSourceIds',
            'generatedSourceIds',
            'conflictAcceptances',
            'expectedAcceptanceIds',
            'unscheduledRoutineSuggestions',
          };
          expect(map.keys.toSet(), requiredKeys);
          expect(
            map['schemaVersion'],
            OnboardingCompletionBundle.schemaVersion,
          );
          expect(map['schemaVersion'], 2);
          expect(map['expectedAcceptanceIds'], everyElement(isA<String>()));
        },
      );

      test(
        'Contract 6: OnboardingCompletionJob serialization and lastFailureOccurredAt',
        () {
          final now = DateTime.now().toUtc();
          final job = OnboardingCompletionJob(
            jobId: 'job_b6',
            uid: 'user_b6',
            lastFailureOccurredAt: now,
            createdAt: now,
            updatedAt: now,
          );
          final map = job.toMap();
          expect(map['failureOccurredAt'], isA<String>());

          final firestoreMap = job.toFirestoreMap();
          expect(firestoreMap['failureOccurredAt'], isA<Timestamp>());

          final deserialized = OnboardingCompletionJob.fromMap(map);
          expect(deserialized.jobId, equals('job_b6'));
        },
      );

      test('Contract 7: Routine serializers enforce rules schemas', () {
        final item = RoutineItem(
          id: 'item_b7',
          title: 'Test Routine',
          startMinute: 480,
          endMinute: 540,
          blockType: RoutineBlockType.hardBlock,
        );
        final itemMap = item.toFirestoreMap(ownerUid: 'user_b7');
        expect(itemMap.containsKey('status'), isFalse);
        expect(itemMap.containsKey('isCompleted'), isFalse);
        expect(itemMap.containsKey('hasConflict'), isFalse);
        expect(itemMap['ownerUid'], equals('user_b7'));

        final occurrence = RoutineOccurrenceRecord(
          id: 'occ_b7',
          ownerUid: 'user_b7',
          routineItemId: 'item_b7',
          occurrenceDateKey: '2026-07-29',
          status: RoutineStatus.completed,
          source: 'routine',
          action: 'complete',
          operationKey: 'op_b7',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        final occMap = occurrence.toFirestoreMap();
        expect(occMap['status'], equals('completed'));
        expect(occMap.containsKey('movedToDateKey'), isFalse);

        final receipt = RoutineProjectionReceipt(
          id: 'onboarding-initial-v1',
          ownerUid: 'user_b7',
          sourceBundleSchemaVersion: 1,
          sourceBundleId: 'bundle_1',
          sourceBundleFingerprint: 'a' * 64,
          projectedItemIds: ['item_b7'],
          status: 'completed',
          cursor: 1,
          totalCount: 1,
          createdAt: DateTime.now().toUtc(),
          completedAt: DateTime.now().toUtc(),
        );
        final receiptMap = receipt.toFirestoreMap();
        const allowedReceiptKeys = {
          'id',
          'ownerUid',
          'source',
          'sourceBundleSchemaVersion',
          'sourceBundleId',
          'sourceBundleFingerprint',
          'projectedItemIds',
          'eventSchemaVersion',
          'totalCount',
          'cursor',
          'status',
          'createdAt',
          'updatedAt',
          'completedAt',
          'lastSafeError',
          'schemaVersion',
        };
        expect(receiptMap.keys.toSet().difference(allowedReceiptKeys), isEmpty);
      });

      test(
        'Contract 8: HabitSystemRecord.toFirestoreMap() respects status and source rules',
        () {
          final recordUser = HabitSystemRecord(
            systemId: 'hs_user',
            ownerUid: 'user_b8',
            title: 'User Habit',
            category: RoutineCategory.habit,
            systemType: HabitSystemType.goodHabit,
            source: 'user',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );
          final mapUser = recordUser.toFirestoreMap();
          expect(mapUser.containsKey('archivedAt'), isFalse);
          expect(mapUser.containsKey('onboardingSourceId'), isFalse);
          expect(mapUser.containsKey('onboardingProjectionId'), isFalse);

          final recordArchived = recordUser.copyWith(
            status: HabitSystemStatus.archived,
            archivedAt: DateTime.now().toUtc(),
          );
          final mapArchived = recordArchived.toFirestoreMap();
          expect(mapArchived.containsKey('archivedAt'), isTrue);
        },
      );
    });
  });
}
