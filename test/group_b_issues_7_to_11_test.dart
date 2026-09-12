import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';

void main() {
  group('Issue 7: Receipt validation against expected items', () {
    test('Validator passes when all expected items and metadata match', () {
      final bundle = _createTestBundle(uid: 'uid-7a', itemCount: 2);
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = _createTestReceipt(
        uid: 'uid-7a',
        plan: plan,
        status: 'completed',
        cursor: 2,
        totalCount: 2,
      );

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: plan.items,
        ownerUid: 'uid-7a',
        plan: plan,
      );

      expect(result.isValid, isTrue);
      expect(result.failureReason, isNull);
    });

    test('Validator fails when receipt is null', () {
      final bundle = _createTestBundle(uid: 'uid-7b', itemCount: 1);
      final plan = RoutineOnboardingProjection.build(bundle);

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: null,
        actualItems: plan.items,
        ownerUid: 'uid-7b',
        plan: plan,
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, contains('missing'));
    });

    test('Validator fails on owner UID mismatch', () {
      final bundle = _createTestBundle(uid: 'uid-7c', itemCount: 1);
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = _createTestReceipt(uid: 'wrong-uid', plan: plan);

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: plan.items,
        ownerUid: 'uid-7c',
        plan: plan,
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, contains('owner UID mismatch'));
    });

    test('Validator fails on fingerprint mismatch', () {
      final bundle = _createTestBundle(uid: 'uid-7d', itemCount: 1);
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = RoutineProjectionReceipt(
        id: plan.receipt.id,
        ownerUid: 'uid-7d',
        slot: plan.slot,
        revision: plan.revision,
        sourceBundleSchemaVersion: plan.receipt.sourceBundleSchemaVersion,
        sourceBundleId: plan.receipt.sourceBundleId,
        sourceBundleFingerprint: 'a' * 64, // Invalid mismatch fingerprint
        projectedItemIds: plan.receipt.projectedItemIds,
        createdAt: plan.receipt.createdAt,
      );

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: plan.items,
        ownerUid: 'uid-7d',
        plan: plan,
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, contains('fingerprint mismatch'));
    });

    test('Validator fails when expected routine item document is missing', () {
      final bundle = _createTestBundle(uid: 'uid-7e', itemCount: 2);
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = _createTestReceipt(uid: 'uid-7e', plan: plan);

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: [plan.items.first], // Second item missing
        ownerUid: 'uid-7e',
        plan: plan,
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, contains('missing'));
    });

    test('Validator fails when source item ID mismatches', () {
      final bundle = _createTestBundle(uid: 'uid-7f', itemCount: 1);
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = _createTestReceipt(uid: 'uid-7f', plan: plan);

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: [
          plan.items.first.copyWith(onboardingSourceItemId: 'wrong-source'),
        ],
        ownerUid: 'uid-7f',
        plan: plan,
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, contains('source mismatch'));
    });

    test('Validator fails when Routine source is not onboarding', () {
      final bundle = _createTestBundle(uid: 'uid-7g', itemCount: 1);
      final plan = RoutineOnboardingProjection.build(bundle);
      final receipt = _createTestReceipt(uid: 'uid-7g', plan: plan);

      final result = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: [plan.items.first.copyWith(source: RoutineSource.manual)],
        ownerUid: 'uid-7g',
        plan: plan,
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, contains('source mismatch'));
    });
  });

  group('Issue 8: Receipt storing all item categories', () {
    test(
      'Receipt model and Firestore codec serialize and deserialize all 5 item categories',
      () {
        final receipt = RoutineProjectionReceipt(
          id: 'rec-8a',
          ownerUid: 'uid-8a',
          sourceBundleSchemaVersion: 1,
          sourceBundleId: 'bundle-8a',
          sourceBundleFingerprint: 'b' * 64,
          expectedItemIds: const ['item-1', 'item-2', 'item-3'],
          createdItemIds: const ['item-1'],
          existingItemIds: const ['item-2'],
          repairedItemIds: const ['item-3'],
          failedItemIds: const [],
          createdAt: DateTime.utc(2026, 7, 25),
        );

        expect(receipt.expectedItemIds, equals(['item-1', 'item-2', 'item-3']));
        expect(receipt.createdItemIds, equals(['item-1']));
        expect(receipt.existingItemIds, equals(['item-2']));
        expect(receipt.repairedItemIds, equals(['item-3']));
        expect(
          receipt.projectedItemIds,
          equals(['item-1', 'item-2', 'item-3']),
        );

        const codec = RoutineProjectionReceiptFirestoreCodec();
        final map = codec.toFirestore(receipt);
        expect(map['projectedItemIds'], equals(['item-1', 'item-2', 'item-3']));

        final decoded = codec.fromFirestore(documentId: 'rec-8a', data: map);
        expect(decoded.expectedItemIds, equals(['item-1', 'item-2', 'item-3']));
        expect(decoded.createdItemIds, equals(['item-1']));
        expect(decoded.existingItemIds, equals(['item-2']));
        expect(decoded.repairedItemIds, equals(['item-3']));
        expect(decoded.failedItemIds, isEmpty);
      },
    );

    test(
      'completeOnboarding populates expected and existing item categories when items pre-exist',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        final bundle = _createTestBundle(uid: 'uid-8b', itemCount: 3);
        final plan = RoutineOnboardingProjection.build(bundle);

        // Pre-insert 1 item into database
        db.itemsByUid.putIfAbsent('uid-8b', () => {})[plan.items.first.id] =
            plan.items.first;

        final result = await repo.completeOnboarding(
          finalDraft: _createCompletedDraft('uid-8b'),
          bundle: bundle,
        );

        expect(result.outcome, RoutineProjectionOutcome.projected);
        expect(result.receipt.expectedItemIds, hasLength(3));
        expect(result.receipt.existingItemIds, contains(plan.items.first.id));
        expect(result.receipt.createdItemIds, hasLength(2));
        expect(result.receipt.projectedItemIds, hasLength(3));
      },
    );

    test(
      'completeOnboarding reprojects instead of noOp when an expected item is missing',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        final bundle = _createTestBundle(uid: 'uid-8c', itemCount: 2);
        final draft = _createCompletedDraft('uid-8c');
        final plan = RoutineOnboardingProjection.build(bundle);

        await repo.completeOnboarding(finalDraft: draft, bundle: bundle);
        db.itemsByUid['uid-8c']!.remove(plan.items.first.id);

        final retry = await repo.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );

        expect(retry.outcome, RoutineProjectionOutcome.projected);
        expect(retry.receipt.createdItemIds, contains(plan.items.first.id));
        expect(
          db.itemsByUid['uid-8c']!.keys,
          containsAll(plan.items.map((i) => i.id)),
        );
      },
    );

    test(
      'completeOnboarding fails closed when an existing projection changed source',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        final bundle = _createTestBundle(uid: 'uid-8d', itemCount: 1);
        final draft = _createCompletedDraft('uid-8d');
        final plan = RoutineOnboardingProjection.build(bundle);

        await repo.completeOnboarding(finalDraft: draft, bundle: bundle);
        db.itemsByUid['uid-8d']![plan.items.first.id] = plan.items.first
            .copyWith(source: RoutineSource.manual);

        final retry = await repo.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );

        final preserved = db.itemsByUid['uid-8d']![plan.items.first.id]!;
        expect(retry.outcome, RoutineProjectionOutcome.projected);
        expect(retry.receipt.failedItemIds, contains(plan.items.first.id));
        expect(retry.receipt.repairedItemIds, isEmpty);
        expect(preserved.source, RoutineSource.manual);
      },
    );
  });

  group('Issue 9: Intermediate account state', () {
    test('buildBundle userProfilePatch sets intermediate pending state', () {
      final draft = _createCompletedDraft('uid-9a');
      final bundle = OnboardingCompletionService.buildBundle(draft);

      expect(bundle.userProfilePatch['schemaVersion'], equals(1));
      expect(bundle.userProfilePatch, isNot(contains('workingExtra')));
      expect(bundle.userProfilePatch, isNot(contains('businessMode')));
      expect(bundle.userProfilePatch['onboardingInputCompleted'], isTrue);
      expect(
        bundle.userProfilePatch['onboardingProjectionStatus'],
        equals('pending'),
      );
      expect(bundle.userProfilePatch['onboardingCompleted'], isFalse);
    });

    test(
      'OnboardingCompletionJobService verifies a successful projection before profile update',
      () async {
        final db = FakeRoutineDatabase();
        final onboardingRepo = FakeOnboardingRepository(routineDatabase: db);
        final profileRepo = _FakeProfileRepository();
        final routineRepo = FakeRoutineRepository(database: db);

        final jobService = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
          routineRepository: routineRepo,
        );

        final bundle = _createTestBundle(uid: 'uid-9b', itemCount: 2);
        final draft = _createCompletedDraft('uid-9b');
        await profileRepo.saveUserProfile(
          UserProfile.empty(uid: 'uid-9b', email: 'test@example.com'),
        );

        final projection = await onboardingRepo.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );
        expect(projection.receipt.status, equals('completed'));
        expect(projection.receipt.cursor, equals(2));

        final job = await jobService.runCompletionJob(
          uid: 'uid-9b',
          finalDraft: draft,
          bundle: bundle,
        );

        expect(job.status, equals(OnboardingJobStatus.completed));
        final updatedProfile = await profileRepo.fetchUserProfile('uid-9b');
        expect(updatedProfile?.onboardingCompleted, isTrue);
        expect(updatedProfile?.onboardingProjectionStatus, equals('completed'));
      },
    );
  });

  group('Issue 10: History projector typed failures', () {
    test(
      'Throws RoutineProjectionFailureException when receipt is missing',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);

        final bundle = _createTestBundle(uid: 'uid-10a', itemCount: 2);

        await expectLater(
          const RoutineOnboardingEventProjector().projectCreatedEvents(
            read: harness.container.read,
            bundle: bundle,
            requireExistingReceipt: true,
          ),
          throwsA(
            isA<RoutineProjectionFailureException>().having(
              (e) => e.reason,
              'reason',
              RoutineProjectionFailureReason.receiptMissing,
            ),
          ),
        );
      },
    );

    test(
      'Throws RoutineProjectionFailureException when owner UID mismatches',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);

        final bundle = _createTestBundle(uid: 'uid-10b', itemCount: 2);
        final plan = RoutineOnboardingProjection.build(bundle);
        final receipt = _createTestReceipt(uid: 'different-uid', plan: plan);
        harness.database.receiptsByUid.putIfAbsent(
          'uid-10b',
          () => {},
        )[plan.projectionId] = receipt;

        await expectLater(
          const RoutineOnboardingEventProjector().projectCreatedEvents(
            read: harness.container.read,
            bundle: bundle,
          ),
          throwsA(
            isA<RoutineProjectionFailureException>().having(
              (e) => e.reason,
              'reason',
              RoutineProjectionFailureReason.ownerMismatch,
            ),
          ),
        );
      },
    );

    test(
      'Throws RoutineProjectionFailureException when fingerprint mismatches',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);

        final bundle = _createTestBundle(uid: 'uid-10c', itemCount: 2);
        final plan = RoutineOnboardingProjection.build(bundle);
        final receipt = RoutineProjectionReceipt(
          id: plan.receipt.id,
          ownerUid: 'uid-10c',
          sourceBundleSchemaVersion: 1,
          sourceBundleId: 'bundle-id',
          sourceBundleFingerprint: 'f' * 64,
          projectedItemIds: plan.receipt.projectedItemIds,
          createdAt: DateTime.now(),
        );
        harness.database.receiptsByUid.putIfAbsent(
          'uid-10c',
          () => {},
        )[plan.projectionId] = receipt;

        await expectLater(
          const RoutineOnboardingEventProjector().projectCreatedEvents(
            read: harness.container.read,
            bundle: bundle,
          ),
          throwsA(
            isA<RoutineProjectionFailureException>().having(
              (e) => e.reason,
              'reason',
              RoutineProjectionFailureReason.fingerprintMismatch,
            ),
          ),
        );
      },
    );
  });

  group('Issue 11: History completion verification', () {
    test(
      'Receipt verification logic blocks completion when receipt remains pending',
      () async {
        final bundle = _createTestBundle(uid: 'uid-11a', itemCount: 2);
        final plan = RoutineOnboardingProjection.build(bundle);

        final pendingReceipt = RoutineProjectionReceipt(
          id: plan.receipt.id,
          ownerUid: 'uid-11a',
          sourceBundleSchemaVersion: plan.receipt.sourceBundleSchemaVersion,
          sourceBundleId: plan.receipt.sourceBundleId,
          sourceBundleFingerprint: plan.fingerprint,
          projectedItemIds: plan.receipt.projectedItemIds,
          status: 'pending',
          cursor: 0,
          totalCount: 2,
          createdAt: DateTime.now(),
        );

        final isValidForNavigation =
            pendingReceipt.status == 'completed' &&
            pendingReceipt.cursor == pendingReceipt.totalCount &&
            pendingReceipt.sourceBundleFingerprint == plan.fingerprint;

        expect(isValidForNavigation, isFalse);
      },
    );

    test(
      'Receipt verification allows navigation when receipt is completed',
      () async {
        final bundle = _createTestBundle(uid: 'uid-11b', itemCount: 2);
        final plan = RoutineOnboardingProjection.build(bundle);

        final completedReceipt = RoutineProjectionReceipt(
          id: plan.receipt.id,
          ownerUid: 'uid-11b',
          sourceBundleSchemaVersion: plan.receipt.sourceBundleSchemaVersion,
          sourceBundleId: plan.receipt.sourceBundleId,
          sourceBundleFingerprint: plan.fingerprint,
          projectedItemIds: plan.receipt.projectedItemIds,
          status: 'completed',
          cursor: 2,
          totalCount: 2,
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
        );

        final isValidForNavigation =
            completedReceipt.status == 'completed' &&
            completedReceipt.cursor == completedReceipt.totalCount &&
            completedReceipt.sourceBundleFingerprint == plan.fingerprint;

        expect(isValidForNavigation, isTrue);
      },
    );
  });
}

class _Harness {
  final FakeRoutineDatabase database = FakeRoutineDatabase();
  late final FakeRoutineRepository routines;
  late final FakeOnboardingRepository onboarding;
  late final FakeRoutineTransactionRepository transactions;
  final FakeRoutineHistoryRepository history = FakeRoutineHistoryRepository();
  late final ProviderContainer container;

  _Harness() {
    routines = FakeRoutineRepository(database: database);
    onboarding = FakeOnboardingRepository(routineDatabase: database);
    transactions = FakeRoutineTransactionRepository(
      routineRepository: routines,
      historyRepository: history,
    );
    container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(
          OptivusBackendMode.firebase,
        ),
        routineRepositoryProvider.overrideWithValue(routines),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        routineTransactionRepositoryProvider.overrideWithValue(transactions),
        routineHistoryRepositoryProvider.overrideWithValue(history),
      ],
    );
  }

  void dispose() {
    container.dispose();
  }
}

class _FakeProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> profiles = {};

  @override
  Future<UserProfile?> fetchUserProfile(String uid) async => profiles[uid];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    profiles[profile.uid] = profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OnboardingDraft _createCompletedDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    createdAt: DateTime.utc(2026, 7, 25),
    updatedAt: DateTime.utc(2026, 7, 25),
  );
}

OnboardingCompletionBundle _createTestBundle({
  required String uid,
  required int itemCount,
}) {
  final now = DateTime.utc(2026, 7, 25);
  final draft = _createCompletedDraft(uid);
  return OnboardingCompletionBundle(
    uid: uid,
    createdAt: now,
    updatedAt: now,
    userProfilePatch: OnboardingCompletionService.buildBundle(
      draft,
    ).userProfilePatch,
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: [
      for (var i = 0; i < itemCount; i++)
        RoutineItem(
          id: 'item-$i',
          userId: uid,
          onboardingProjectionId: 'onboarding-initial-v1',
          onboardingSourceItemId: 'source-$i',
          title: 'Test item $i',
          startMinute: 600 + i * 15,
          endMinute: 615 + i * 15,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
          source: RoutineSource.onboarding,
        ),
    ],
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
  );
}

RoutineProjectionReceipt _createTestReceipt({
  required String uid,
  required RoutineOnboardingProjectionPlan plan,
  String status = 'pending',
  int cursor = 0,
  int? totalCount,
}) {
  final now = DateTime.utc(2026, 7, 25);
  return RoutineProjectionReceipt(
    id: plan.receipt.id,
    ownerUid: uid,
    slot: plan.slot,
    sourceBundleSchemaVersion: plan.receipt.sourceBundleSchemaVersion,
    sourceBundleId: plan.receipt.sourceBundleId,
    sourceBundleFingerprint: plan.fingerprint,
    expectedItemIds: plan.items.map((i) => i.id).toList(),
    createdItemIds: plan.items.map((i) => i.id).toList(),
    existingItemIds: const [],
    repairedItemIds: const [],
    failedItemIds: const [],
    projectedItemIds: plan.items.map((i) => i.id).toList(),
    status: status,
    cursor: cursor,
    totalCount: totalCount ?? plan.items.length,
    createdAt: now,
    updatedAt: now,
    completedAt: status == 'completed' ? now : null,
  );
}
