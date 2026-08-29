import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/conflict_acceptance_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

void main() {
  group('Routine projection receipt accounting regression', () {
    test('all-new routines complete the receipt', () async {
      final fixture = _Fixture(uid: 'receipt-all-new', itemCount: 3);

      final result = await fixture.project();

      expect(result.receipt.createdItemIds, hasLength(3));
      expect(result.receipt.existingItemIds, isEmpty);
      _expectCompletedAccounting(result.receipt, expectedCount: 3);
    });

    test('all-existing routines complete the receipt', () async {
      final fixture = _Fixture(uid: 'receipt-all-existing', itemCount: 3);
      fixture.database.itemsByUid[fixture.uid] = {
        for (final item in fixture.plan.items) item.id: item,
      };

      final result = await fixture.project();

      expect(result.receipt.createdItemIds, isEmpty);
      expect(result.receipt.existingItemIds, hasLength(3));
      _expectCompletedAccounting(result.receipt, expectedCount: 3);
    });

    test('mixed created and existing routines complete the receipt', () async {
      final fixture = _Fixture(uid: 'receipt-mixed', itemCount: 4);
      fixture.database.itemsByUid[fixture.uid] = {
        fixture.plan.items.first.id: fixture.plan.items.first,
      };

      final result = await fixture.project();

      expect(result.receipt.createdItemIds, hasLength(3));
      expect(result.receipt.existingItemIds, hasLength(1));
      _expectCompletedAccounting(result.receipt, expectedCount: 4);
    });

    test('repaired routines count as successfully accounted', () {
      final fixture = _Fixture(uid: 'receipt-repaired', itemCount: 3);
      final expectedIds = fixture.plan.items.map((item) => item.id).toList();

      final receipt = routineProjectionReceiptForCategories(
        fixture.plan.receipt,
        expectedItemIds: expectedIds,
        createdItemIds: const [],
        existingItemIds: const [],
        repairedItemIds: expectedIds,
        failedItemIds: const [],
      );

      expect(receipt.repairedItemIds, hasLength(3));
      _expectCompletedAccounting(receipt, expectedCount: 3);
    });

    test('a failed routine leaves the receipt pending', () async {
      final fixture = _Fixture(uid: 'receipt-failed', itemCount: 3);
      final conflicting = fixture.plan.items.first.copyWith(
        source: RoutineSource.manual,
      );
      fixture.database.itemsByUid[fixture.uid] = {conflicting.id: conflicting};

      final result = await fixture.project();

      expect(result.receipt.failedItemIds, [conflicting.id]);
      expect(result.receipt.status, 'pending');
      expect(result.receipt.cursor, 2);
      expect(result.receipt.totalCount, 3);
      expect(result.receipt.completedAt, isNull);
    });

    test('53-item all-new projection is structurally complete', () async {
      final fixture = _Fixture(uid: 'receipt-large', itemCount: 53);

      final result = await fixture.project();

      expect(result.receipt.createdItemIds, hasLength(53));
      _expectCompletedAccounting(result.receipt, expectedCount: 53);
    });

    test('expected and projected ID sets are exactly equal', () async {
      final fixture = _Fixture(uid: 'receipt-id-sets', itemCount: 7);

      final receipt = (await fixture.project()).receipt;

      expect(receipt.expectedItemIds.toSet(), receipt.projectedItemIds.toSet());
      expect(receipt.expectedItemIds, hasLength(7));
      expect(receipt.projectedItemIds, hasLength(7));
    });

    test('cursor, total, and status derive from all success categories', () {
      final fixture = _Fixture(uid: 'receipt-category-total', itemCount: 4);
      final ids = fixture.plan.items.map((item) => item.id).toList();

      final receipt = routineProjectionReceiptForCategories(
        fixture.plan.receipt,
        expectedItemIds: ids,
        createdItemIds: [ids[0]],
        existingItemIds: [ids[1]],
        repairedItemIds: [ids[2], ids[3]],
        failedItemIds: const [],
      );

      _expectCompletedAccounting(receipt, expectedCount: 4);
    });

    test('verifyRoutines passes after a successful projection', () async {
      final fixture = _Fixture(uid: 'receipt-verify-pass', itemCount: 3);
      await fixture.saveProfile();
      final projected = await fixture.project();
      fixture.database.receiptsByUid[fixture.uid]![fixture.plan.projectionId] =
          projected.receipt.copyWith(
            status: 'pending',
            cursor: 0,
            clearCompletedAt: true,
          );
      final service = fixture.jobService();

      final job = await service.runCompletionJob(
        uid: fixture.uid,
        finalDraft: fixture.draft,
        bundle: fixture.bundle,
      );

      expect(
        job.isStageCompleted(OnboardingCompletionStage.verifyRoutines),
        isTrue,
      );
      expect(job.status, OnboardingJobStatus.completed);
      final persisted = fixture
          .database
          .receiptsByUid[fixture.uid]![fixture.plan.projectionId]!;
      _expectCompletedAccounting(persisted, expectedCount: 3);
    });

    test('verifyRoutines rejects a genuinely incomplete projection', () async {
      final fixture = _Fixture(uid: 'receipt-verify-reject', itemCount: 3);
      await fixture.saveProfile();
      final service = fixture.jobService(
        routineRepository: _MissingRoutineReadRepository(fixture.database),
      );

      await expectLater(
        service.runCompletionJob(
          uid: fixture.uid,
          finalDraft: fixture.draft,
          bundle: fixture.bundle,
        ),
        throwsA(isA<StateError>()),
      );
      final failedJob = await service.loadCurrentJob(fixture.uid);
      expect(failedJob?.status, OnboardingJobStatus.fatalFailure);
      expect(failedJob?.lastFailureStage, 'verifyRoutines');
    });

    test('legacy pending receipt finalization is retry-idempotent', () async {
      final fixture = _Fixture(uid: 'receipt-retry', itemCount: 3);
      final projected = await fixture.project();
      final legacyPending = projected.receipt.copyWith(
        status: 'pending',
        cursor: 0,
        clearCompletedAt: true,
      );
      fixture.database.receiptsByUid[fixture.uid]![fixture.plan.projectionId] =
          legacyPending;
      final itemsBefore = Map<String, RoutineItem>.from(
        fixture.database.itemsByUid[fixture.uid]!,
      );

      final first = await fixture.repository.finalizeRoutineProjectionReceipt(
        bundle: fixture.bundle,
      );
      final second = await fixture.repository.finalizeRoutineProjectionReceipt(
        bundle: fixture.bundle,
      );

      _expectCompletedAccounting(first, expectedCount: 3);
      _expectCompletedAccounting(second, expectedCount: 3);
      expect(fixture.database.itemsByUid[fixture.uid], itemsBefore);
    });

    test('receipt-only recovery preserves conflict acceptances', () async {
      final fixture = _Fixture(
        uid: 'receipt-acceptances',
        itemCount: 2,
        includeAcceptance: true,
      );
      final projected = await fixture.project();
      final acceptancesBefore = Map<String, ConflictAcceptance>.from(
        fixture.database.acceptancesByUid[fixture.uid]!,
      );
      fixture.database.receiptsByUid[fixture.uid]![fixture.plan.projectionId] =
          projected.receipt.copyWith(
            status: 'pending',
            cursor: 0,
            clearCompletedAt: true,
          );

      final repaired = await fixture.repository
          .finalizeRoutineProjectionReceipt(bundle: fixture.bundle);

      _expectCompletedAccounting(repaired, expectedCount: 2);
      expect(acceptancesBefore, hasLength(1));
      expect(fixture.database.acceptancesByUid[fixture.uid], acceptancesBefore);
    });

    test(
      'prior legacy projection ID repairs into current projection',
      () async {
        final fixture = _Fixture(uid: 'receipt-legacy-repair', itemCount: 3);
        final legacyItem = fixture.plan.items.first.copyWith(
          onboardingProjectionId: 'onboarding-initial-v1',
        );
        fixture.database.itemsByUid[fixture.uid] = {legacyItem.id: legacyItem};

        final result = await fixture.project();

        expect(result.receipt.createdItemIds, hasLength(2));
        expect(result.receipt.existingItemIds, isEmpty);
        expect(result.receipt.repairedItemIds, [legacyItem.id]);
        expect(result.receipt.failedItemIds, isEmpty);
        _expectCompletedAccounting(result.receipt, expectedCount: 3);
        final stored =
            fixture.database.itemsByUid[fixture.uid]![legacyItem.id]!;
        expect(stored.onboardingProjectionId, fixture.plan.projectionId);
      },
    );

    test(
      'prior run-scoped projection ID repairs into new run projection',
      () async {
        final fixture = _Fixture(uid: 'receipt-run-repair', itemCount: 3);
        final priorRunItem = fixture.plan.items.first.copyWith(
          onboardingProjectionId:
              'onboarding-run_0000000000000000000000000000000000000000-v1',
        );
        fixture.database.itemsByUid[fixture.uid] = {
          priorRunItem.id: priorRunItem,
        };

        final result = await fixture.project();

        expect(result.receipt.createdItemIds, hasLength(2));
        expect(result.receipt.existingItemIds, isEmpty);
        expect(result.receipt.repairedItemIds, [priorRunItem.id]);
        expect(result.receipt.failedItemIds, isEmpty);
        _expectCompletedAccounting(result.receipt, expectedCount: 3);
      },
    );

    test(
      'unrelated manual routine with colliding ID is not overwritten and fails safely',
      () async {
        final fixture = _Fixture(uid: 'receipt-manual-collision', itemCount: 3);
        final collidingManual = fixture.plan.items.first.copyWith(
          source: RoutineSource.manual,
          onboardingProjectionId: null,
        );
        fixture.database.itemsByUid[fixture.uid] = {
          collidingManual.id: collidingManual,
        };

        final result = await fixture.project();

        expect(result.receipt.failedItemIds, [collidingManual.id]);
        expect(result.receipt.repairedItemIds, isEmpty);
        expect(result.receipt.status, 'pending');
        expect(
          fixture.database.itemsByUid[fixture.uid]![collidingManual.id]!.source,
          RoutineSource.manual,
        );
      },
    );

    test('wrong onboarding source item identity fails safely', () async {
      final fixture = _Fixture(uid: 'receipt-wrong-source-item', itemCount: 3);
      final wrongSource = fixture.plan.items.first.copyWith(
        onboardingSourceItemId: 'completely-different-source-item',
        onboardingProjectionId: 'onboarding-initial-v1',
      );
      fixture.database.itemsByUid[fixture.uid] = {wrongSource.id: wrongSource};

      final result = await fixture.project();

      expect(result.receipt.failedItemIds, [wrongSource.id]);
      expect(result.receipt.repairedItemIds, isEmpty);
      expect(result.receipt.status, 'pending');
    });

    test(
      'mixed production workload: 32 new + 20 prior-projection routines',
      () async {
        final fixture = _Fixture(uid: 'receipt-prod-mixed', itemCount: 52);
        final prior20 = {
          for (var i = 0; i < 20; i++)
            fixture.plan.items[i].id: fixture.plan.items[i].copyWith(
              onboardingProjectionId: 'onboarding-initial-v1',
            ),
        };
        fixture.database.itemsByUid[fixture.uid] = prior20;

        final result = await fixture.project();

        expect(result.receipt.createdItemIds, hasLength(32));
        expect(result.receipt.existingItemIds, isEmpty);
        expect(result.receipt.repairedItemIds, hasLength(20));
        expect(result.receipt.failedItemIds, isEmpty);
        expect(result.receipt.projectedItemIds, hasLength(52));
        expect(result.receipt.cursor, 52);
        expect(result.receipt.totalCount, 52);
        _expectCompletedAccounting(result.receipt, expectedCount: 52);

        // Retry after repair: should be idempotent noOp with completed receipt
        final retryResult = await fixture.project();
        expect(retryResult.outcome, RoutineProjectionOutcome.noOp);
        _expectCompletedAccounting(retryResult.receipt, expectedCount: 52);
      },
    );
  });
}

void _expectCompletedAccounting(
  RoutineProjectionReceipt receipt, {
  required int expectedCount,
}) {
  expect(receipt.status, 'completed');
  expect(receipt.cursor, expectedCount);
  expect(receipt.totalCount, expectedCount);
  expect(receipt.projectedItemIds, hasLength(expectedCount));
  expect(receipt.failedItemIds, isEmpty);
  expect(receipt.completedAt, isNotNull);
}

class _Fixture {
  _Fixture({
    required this.uid,
    required int itemCount,
    bool includeAcceptance = false,
  }) : database = FakeRoutineDatabase(),
       profileRepository = _MemoryProfileRepository(),
       draft = _completedDraft(uid),
       bundle = _bundle(uid, itemCount, includeAcceptance: includeAcceptance) {
    repository = FakeOnboardingRepository(routineDatabase: database);
    plan = RoutineOnboardingProjection.build(bundle);
  }

  final String uid;
  final FakeRoutineDatabase database;
  final _MemoryProfileRepository profileRepository;
  final OnboardingDraft draft;
  final OnboardingCompletionBundle bundle;
  late final FakeOnboardingRepository repository;
  late final RoutineOnboardingProjectionPlan plan;

  Future<RoutineProjectionResult> project() {
    return repository.completeOnboarding(finalDraft: draft, bundle: bundle);
  }

  Future<void> saveProfile() {
    return profileRepository.saveUserProfile(UserProfile.empty(uid: uid));
  }

  OnboardingCompletionJobService jobService({
    RoutineRepository? routineRepository,
  }) {
    return OnboardingCompletionJobService(
      onboardingRepository: repository,
      profileRepository: profileRepository,
      routineRepository:
          routineRepository ?? FakeRoutineRepository(database: database),
      conflictAcceptanceRepository: FakeConflictAcceptanceRepository(database),
    );
  }
}

class _MissingRoutineReadRepository extends FakeRoutineRepository {
  _MissingRoutineReadRepository(FakeRoutineDatabase database)
    : super(database: database);

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    final items = await super.fetchRoutineItems(uid);
    return items.isEmpty ? items : items.sublist(0, items.length - 1);
  }
}

class _MemoryProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {};

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async => _profiles[uid];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OnboardingDraft _completedDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    createdAt: DateTime.utc(2026, 8, 29),
    updatedAt: DateTime.utc(2026, 8, 29),
  );
}

OnboardingCompletionBundle _bundle(
  String uid,
  int itemCount, {
  required bool includeAcceptance,
}) {
  final draft = _completedDraft(uid);
  final now = DateTime.utc(2026, 8, 29);
  final items = [
    for (var index = 0; index < itemCount; index++)
      RoutineItem(
        id: 'source-$index',
        userId: uid,
        title: 'Item $index',
        startMinute: includeAcceptance && index < 2
            ? 600
            : 60 + (index * 20) % 1200,
        endMinute: includeAcceptance && index < 2
            ? 630
            : 75 + (index * 20) % 1200,
        repeatDays: const [1, 2, 3, 4, 5],
        blockType: RoutineBlockType.flexibleTask,
        category: includeAcceptance && index == 0
            ? RoutineCategory.eating
            : includeAcceptance && index == 1
            ? RoutineCategory.fixed
            : RoutineCategory.habit,
        hardBlock: includeAcceptance && index == 1,
        source: RoutineSource.onboarding,
      ),
  ];
  final sourceAcceptance = includeAcceptance
      ? ConflictAcceptance(
          acceptanceId: 'source-acceptance',
          ownerUid: uid,
          canonicalPairHash: 'source-pair',
          firstSourceBlockId: 'source-0',
          secondSourceBlockId: 'source-1',
          firstProjectedRoutineId: '',
          secondProjectedRoutineId: '',
          conflictType: 'compatibleOverlap',
          scope: ConflictAcceptanceScope.recurringWeekdays,
          dateKey: '',
          applicableWeekdays: const [1, 2, 3, 4, 5],
          timezoneId: 'UTC',
          firstScheduleFingerprint: 'a' * 64,
          secondScheduleFingerprint: 'b' * 64,
          combinedScheduleFingerprint: 'c' * 64,
          sourceBundleFingerprint: '',
          projectionId: '',
          acceptedAt: now,
          acceptedFrom: ConflictAcceptanceOrigin.onboarding,
          status: ConflictAcceptanceStatus.active,
          invalidatedAt: null,
          invalidationReason: null,
        )
      : null;
  return OnboardingCompletionBundle(
    uid: uid,
    createdAt: now,
    updatedAt: now,
    userProfilePatch: OnboardingCompletionService.buildBundle(
      draft,
    ).userProfilePatch,
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: items,
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
    conflictAcceptances: sourceAcceptance == null
        ? const []
        : [sourceAcceptance],
    expectedAcceptanceIds: sourceAcceptance == null
        ? const []
        : [sourceAcceptance.acceptanceId],
  );
}
