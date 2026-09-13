import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';

OnboardingCompletionBundle _buildRealisticBundle(String uid, {int count = 82}) {
  final now = DateTime.utc(2026, 9, 12);
  final items = <RoutineItem>[];
  for (var i = 0; i < count; i++) {
    final weekday = (i % 7) + 1;
    final category = switch (i % 5) {
      0 => RoutineCategory.classBlock,
      1 => RoutineCategory.job,
      2 => RoutineCategory.eating,
      3 => RoutineCategory.habit,
      _ => RoutineCategory.identity,
    };
    items.add(
      RoutineItem(
        id: 'source-item-$i',
        userId: uid,
        title: 'Projected Routine Task $i',
        startMinute: (480 + (i * 10)) % 1440,
        endMinute: (530 + (i * 10)) % 1440,
        repeatDays: [weekday],
        blockType: category == RoutineCategory.classBlock
            ? RoutineBlockType.hardBlock
            : RoutineBlockType.flexibleTask,
        category: category,
        source: RoutineSource.onboarding,
        professor: category == RoutineCategory.classBlock
            ? 'Professor $i'
            : null,
        courseCode: category == RoutineCategory.classBlock ? 'CS$i' : null,
        mealSlot: category == RoutineCategory.eating ? 'lunch' : null,
        mealCategory: category == RoutineCategory.eating ? 'balanced' : null,
        onboardingVisualStyleKey: 'style-$i',
      ),
    );
  }

  return OnboardingCompletionBundle(
    uid: uid,
    createdAt: now,
    updatedAt: now,
    userProfilePatch: const {'onboardingCompleted': true},
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
  );
}

// ---------------------------------------------------------------------------
// In-Memory Test Double implementing FirebaseFirestore with call tracking
// ---------------------------------------------------------------------------
class _RecordingFirestore implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> documents;
  int runTransactionCalls = 0;
  int batchCommitCalls = 0;
  int collectionGetCalls = 0;
  int docGetCalls = 0;

  _RecordingFirestore(this.documents);

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _RecordingDocRef(this, path);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _RecordingCollectionRef(this, path);

  @override
  WriteBatch batch() => _RecordingWriteBatch(this);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    runTransactionCalls++;
    throw UnsupportedError(
      'runTransaction should not be called by bounded reconciliation!',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _RecordingDocRef implements DocumentReference<Map<String, dynamic>> {
  @override
  final _RecordingFirestore firestore;
  @override
  final String path;
  _RecordingDocRef(this.firestore, this.path);

  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    firestore.docGetCalls++;
    return _RecordingSnapshot(id, firestore.documents[path]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _RecordingCollectionRef
    implements CollectionReference<Map<String, dynamic>> {
  @override
  final _RecordingFirestore firestore;
  @override
  final String path;
  _RecordingCollectionRef(this.firestore, this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? docPath]) {
    return _RecordingDocRef(firestore, '$path/$docPath');
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    firestore.collectionGetCalls++;
    final prefix = '$path/';
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final entry in firestore.documents.entries) {
      if (entry.key.startsWith(prefix)) {
        final rest = entry.key.substring(prefix.length);
        if (!rest.contains('/')) {
          docs.add(_RecordingQueryDocSnapshot(rest, entry.value));
        }
      }
    }
    return _RecordingQuerySnapshot(docs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _RecordingSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  _RecordingSnapshot(this.id, this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() =>
      _data == null ? null : Map<String, dynamic>.from(_data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _RecordingQueryDocSnapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;
  _RecordingQueryDocSnapshot(this.id, this._data);

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => Map<String, dynamic>.from(_data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _RecordingQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _RecordingQuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingWriteBatch implements WriteBatch {
  final _RecordingFirestore firestore;
  final Map<String, Map<String, dynamic>> pendingWrites = {};

  _RecordingWriteBatch(this.firestore);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    pendingWrites[document.path] = Map<String, dynamic>.from(data as Map);
  }

  @override
  void update(DocumentReference document, Map<Object, Object?> data) {
    final existing = firestore.documents[document.path] ?? {};
    final merged = Map<String, dynamic>.from(existing)
      ..addAll(Map<String, dynamic>.from(data));
    pendingWrites[document.path] = merged;
  }

  @override
  void delete(DocumentReference<Object?> document) {
    pendingWrites.remove(document.path);
    firestore.documents.remove(document.path);
  }

  static Object? _resolveFieldValues(Object? value) {
    if (value is FieldValue) {
      return Timestamp.fromDate(DateTime.utc(2026, 9, 12, 12, 0, 0));
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _resolveFieldValues(v)));
    }
    if (value is List) {
      return value.map(_resolveFieldValues).toList();
    }
    return value;
  }

  @override
  Future<void> commit() async {
    firestore.batchCommitCalls++;
    for (final entry in pendingWrites.entries) {
      firestore.documents[entry.key] = Map<String, dynamic>.from(
        _resolveFieldValues(entry.value) as Map,
      );
    }
  }
}

void main() {
  group('P0: Routine Projection Repair Stabilization', () {
    const uid = 'p0-reconcile-user';

    test(
      'Requirement 12 & 14: 82 expected, 65 persisted, 17 restored without fan-out transaction',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 82);
        final plan = RoutineOnboardingProjection.build(bundle);
        expect(plan.items.length, 82);

        // Codec to seed documents in Firestore map
        const codec = RoutineTemplateFirestoreCodec();
        const receiptCodec = RoutineProjectionReceiptFirestoreCodec();
        final rawDocs = <String, Map<String, dynamic>>{};

        // Seed 65 items (leave 17 missing)
        for (var i = 0; i < 65; i++) {
          final item = plan.items[i];
          final path = FirestoreUserPaths.routineItem(uid, item.id);
          rawDocs[path] = codec.toFirestore(ownerUid: uid, item: item);
        }

        // Add a manual survivor item
        final manual = RoutineItem(
          id: 'manual-task-1',
          userId: uid,
          title: 'Manual survivor',
          startMinute: 300,
          endMinute: 330,
          repeatDays: const [1],
          blockType: RoutineBlockType.flexibleTask,
        );
        rawDocs[FirestoreUserPaths.routineItem(uid, manual.id)] = codec
            .toFirestore(ownerUid: uid, item: manual);

        // Seed an initial pending receipt
        final receiptPath = FirestoreUserPaths.routineProjection(
          uid,
          plan.projectionId,
        );
        rawDocs[receiptPath] = receiptCodec.toFirestore(plan.receipt);

        final firestore = _RecordingFirestore(rawDocs);
        final repository = FirestoreRoutineRepository(firestore: firestore);

        // Perform reconciliation
        final repaired = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(repaired, isTrue);

        // Verify transaction was NEVER called
        expect(firestore.runTransactionCalls, 0);
        // Verify bounded reads
        expect(firestore.collectionGetCalls, 1);
        expect(firestore.docGetCalls, 1);
        // Verify batch commit was called
        expect(firestore.batchCommitCalls, 1);

        // Verify all 82 expected items exist
        for (final expected in plan.items) {
          final path = FirestoreUserPaths.routineItem(uid, expected.id);
          expect(
            firestore.documents.containsKey(path),
            isTrue,
            reason: 'Missing expected item ${expected.id}',
          );
        }

        // Verify manual survivor is preserved
        final manualPath = FirestoreUserPaths.routineItem(uid, manual.id);
        expect(firestore.documents.containsKey(manualPath), isTrue);

        // Verify receipt is completed
        final storedReceiptDoc = firestore.documents[receiptPath]!;
        expect(storedReceiptDoc['status'], 'completed');
        expect(storedReceiptDoc['cursor'], 82);
        expect(storedReceiptDoc['totalCount'], 82);
        final expectedIds = plan.items.map((item) => item.id).toList()..sort();
        expect(storedReceiptDoc['expectedItemIds'], expectedIds);
        expect(storedReceiptDoc['projectedItemIds'], expectedIds);

        // Verify validator now reports valid
        final allStoredItems = await repository.fetchRoutineItems(uid);
        final updatedReceipt = await repository.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        final validation = const RoutineProjectionReceiptValidator().validate(
          receipt: updatedReceipt,
          actualItems: allStoredItems,
          ownerUid: uid,
          plan: plan,
        );
        expect(validation.isValid, isTrue);
        expect(
          allStoredItems
              .where((item) => expectedIds.contains(item.id))
              .map((item) => item.onboardingProjectionId)
              .toSet(),
          {plan.projectionId},
        );

        // Second run must be an idempotent no-op (returns false, 0 new batch commits)
        final transactionsBefore = firestore.runTransactionCalls;
        final batchCommitsBefore = firestore.batchCommitCalls;
        final secondRun = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(secondRun, isFalse);
        expect(firestore.runTransactionCalls, transactionsBefore);
        expect(firestore.batchCommitCalls, batchCommitsBefore);
      },
    );

    test(
      'repairs stale onboardingProjectionId when deterministic onboarding identity matches',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 4);
        final plan = RoutineOnboardingProjection.build(bundle);
        final database = FakeRoutineDatabase();
        final repository = FakeRoutineRepository(database: database);

        for (final item in plan.items) {
          await repository.createRoutineItem(
            uid,
            item.id == plan.items.first.id
                ? item.copyWith(
                    onboardingProjectionId: 'legacy-onboarding-projection-v0',
                    title: 'User preserved title',
                    notes: 'User preserved note',
                  )
                : item,
          );
        }

        final repaired = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(repaired, isTrue);

        final stored = (await repository.fetchRoutineItems(
          uid,
        )).firstWhere((item) => item.id == plan.items.first.id);
        expect(stored.onboardingProjectionId, plan.projectionId);
        expect(
          stored.onboardingSourceItemId,
          plan.items.first.onboardingSourceItemId,
        );
        expect(stored.title, 'User preserved title');
        expect(stored.notes, 'User preserved note');

        final receipt = await repository.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        final validation = const RoutineProjectionReceiptValidator().validate(
          receipt: receipt,
          actualItems: await repository.fetchRoutineItems(uid),
          ownerUid: uid,
          plan: plan,
        );
        expect(validation.isValid, isTrue);

        final secondRun = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(secondRun, isFalse);
      },
    );

    test(
      'does not adopt manual or tampered documents during projection repair',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 4);
        final plan = RoutineOnboardingProjection.build(bundle);
        final database = FakeRoutineDatabase();
        final repository = FakeRoutineRepository(database: database);

        final manualCollision = plan.items[0].copyWith(
          source: RoutineSource.manual,
          onboardingProjectionId: 'legacy-onboarding-projection-v0',
          onboardingSourceItemId: plan.items[0].onboardingSourceItemId,
          title: 'Manual Collision',
        );
        final tamperedSource = plan.items[1].copyWith(
          onboardingProjectionId: 'legacy-onboarding-projection-v0',
          onboardingSourceItemId: 'different-source-item',
          title: 'Tampered Source',
        );
        final missingSourceIdentity = plan.items[2].copyWith(
          onboardingProjectionId: 'legacy-onboarding-projection-v0',
          onboardingSourceItemId: '',
          title: 'Missing Source Identity',
        );

        await repository.createRoutineItem(uid, manualCollision);
        await repository.createRoutineItem(uid, tamperedSource);
        await repository.createRoutineItem(uid, missingSourceIdentity);
        await repository.createRoutineItem(uid, plan.items[3]);

        final repaired = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(repaired, isTrue);

        final stored = await repository.fetchRoutineItems(uid);
        expect(
          stored.firstWhere((item) => item.id == manualCollision.id).source,
          RoutineSource.manual,
        );
        expect(
          stored
              .firstWhere((item) => item.id == tamperedSource.id)
              .onboardingSourceItemId,
          'different-source-item',
        );
        expect(
          stored
              .firstWhere((item) => item.id == missingSourceIdentity.id)
              .onboardingSourceItemId,
          '',
        );

        final receipt = await repository.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        expect(
          receipt!.failedItemIds,
          containsAll([
            manualCollision.id,
            tamperedSource.id,
            missingSourceIdentity.id,
          ]),
        );
        final validation = const RoutineProjectionReceiptValidator().validate(
          receipt: receipt,
          actualItems: stored,
          ownerUid: uid,
          plan: plan,
        );
        expect(validation.isValid, isFalse);
      },
    );

    test(
      'receipt validator rejects every finalization identity and cursor drift',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 5);
        final plan = RoutineOnboardingProjection.build(bundle);
        final expectedIds = plan.items.map((item) => item.id).toList()..sort();
        final receipt = plan.receipt.copyWith(
          status: 'completed',
          cursor: plan.items.length,
          totalCount: plan.items.length,
          expectedItemIds: expectedIds,
          projectedItemIds: expectedIds,
          createdItemIds: expectedIds,
        );

        for (final entry in <(String, RoutineProjectionReceipt)>[
          ('wrong projection ID', receipt.copyWith(id: '${receipt.id}-wrong')),
          ('wrong revision', receipt.copyWith(revision: receipt.revision + 1)),
          (
            'wrong source bundle ID',
            receipt.copyWith(sourceBundleId: 'wrong-bundle'),
          ),
          (
            'wrong fingerprint',
            receipt.copyWith(sourceBundleFingerprint: 'wrong-fingerprint'),
          ),
          (
            'wrong expected IDs',
            receipt.copyWith(expectedItemIds: ['wrong-id']),
          ),
          (
            'wrong projected IDs',
            receipt.copyWith(projectedItemIds: ['wrong-id']),
          ),
          (
            'failedItemIds not empty',
            receipt.copyWith(failedItemIds: [plan.items.first.id]),
          ),
          (
            'wrong schema',
            receipt.copyWith(
              schemaVersion: RoutineProjectionReceipt.currentSchemaVersion + 1,
            ),
          ),
          (
            'wrong event schema',
            receipt.copyWith(
              eventSchemaVersion:
                  RoutineProjectionReceipt.currentEventSchemaVersion + 1,
            ),
          ),
          (
            'completed receipt with wrong cursor',
            receipt.copyWith(cursor: receipt.totalCount - 1),
          ),
        ]) {
          final result = const RoutineProjectionReceiptValidator().validate(
            receipt: entry.$2,
            actualItems: plan.items,
            ownerUid: uid,
            plan: plan,
          );
          expect(result.isValid, isFalse, reason: entry.$1);
        }

        final valid = const RoutineProjectionReceiptValidator().validate(
          receipt: receipt,
          actualItems: plan.items,
          ownerUid: uid,
          plan: plan,
        );
        expect(valid.isValid, isTrue);
      },
    );

    test(
      'rewrites legacy completed receipts whose validator-owned fields are stale',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 6);
        final plan = RoutineOnboardingProjection.build(bundle);
        final expectedIds = plan.items.map((item) => item.id).toList()..sort();

        const codec = RoutineTemplateFirestoreCodec();
        const receiptCodec = RoutineProjectionReceiptFirestoreCodec();
        final rawDocs = <String, Map<String, dynamic>>{};

        for (final item in plan.items) {
          rawDocs[FirestoreUserPaths.routineItem(uid, item.id)] = codec
              .toFirestore(ownerUid: uid, item: item);
        }

        final receiptPath = FirestoreUserPaths.routineProjection(
          uid,
          plan.projectionId,
        );
        final legacyIds = [...expectedIds]..[0] = 'legacy-projected-item';
        final now = DateTime.utc(2026, 9, 12, 11);
        final legacyReceipt =
            routineProjectionReceiptForCategories(
              plan.receipt,
              expectedItemIds: legacyIds,
              createdItemIds: legacyIds,
              existingItemIds: const [],
              repairedItemIds: const [],
              failedItemIds: const [],
            ).copyWith(
              revision: plan.revision + 1,
              sourceBundleSchemaVersion:
                  plan.receipt.sourceBundleSchemaVersion + 1,
              sourceBundleId: 'legacy-bundle-metadata',
              createdAt: now,
              updatedAt: now,
              completedAt: now,
            );
        rawDocs[receiptPath] = receiptCodec.toFirestore(legacyReceipt);

        final firestore = _RecordingFirestore(rawDocs);
        final repository = FirestoreRoutineRepository(firestore: firestore);

        final repaired = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(repaired, isTrue);
        expect(firestore.batchCommitCalls, 1);

        final storedReceipt = await repository.fetchProjectionReceipt(
          uid,
          plan.projectionId,
        );
        expect(storedReceipt, isNotNull);
        expect(storedReceipt!.revision, plan.revision);
        expect(
          storedReceipt.sourceBundleSchemaVersion,
          plan.receipt.sourceBundleSchemaVersion,
        );
        expect(storedReceipt.sourceBundleId, plan.sourceBundleId);
        expect(storedReceipt.expectedItemIds, expectedIds);
        expect(storedReceipt.projectedItemIds, expectedIds);
        expect(storedReceipt.status, 'completed');

        final validation = const RoutineProjectionReceiptValidator().validate(
          receipt: storedReceipt,
          actualItems: await repository.fetchRoutineItems(uid),
          ownerUid: uid,
          plan: plan,
        );
        expect(validation.isValid, isTrue);

        final batchCommitsBefore = firestore.batchCommitCalls;
        final secondRun = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(secondRun, isFalse);
        expect(firestore.batchCommitCalls, batchCommitsBefore);
      },
    );

    test(
      'Requirement 3: Unsafe identity collision is never overwritten',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 5);
        final plan = RoutineOnboardingProjection.build(bundle);

        const codec = RoutineTemplateFirestoreCodec();
        final rawDocs = <String, Map<String, dynamic>>{};

        // Document 0 has an identity collision: occupied by a manual item
        final collidingExpected = plan.items[0];
        final manualCollision = RoutineItem(
          id: collidingExpected.id,
          userId: uid,
          title: 'Colliding manual user task',
          startMinute: 100,
          endMinute: 120,
          repeatDays: const [1],
          blockType: RoutineBlockType.flexibleTask,
          source: RoutineSource.manual, // Not onboarding!
        );
        rawDocs[FirestoreUserPaths.routineItem(uid, collidingExpected.id)] =
            codec.toFirestore(ownerUid: uid, item: manualCollision);

        final firestore = _RecordingFirestore(rawDocs);
        final repository = FirestoreRoutineRepository(firestore: firestore);

        final result = await repository.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(result, isTrue);

        // Verify colliding document was NOT overwritten
        final storedData =
            rawDocs[FirestoreUserPaths.routineItem(uid, collidingExpected.id)]!;
        expect(storedData['title'], 'Colliding manual user task');
        expect(storedData['source'], 'manual');

        // Verify receipt recorded the failed item and remained pending
        final receiptDoc =
            rawDocs[FirestoreUserPaths.routineProjection(
              uid,
              plan.projectionId,
            )]!;
        expect(receiptDoc['status'], 'pending');
        final projectedIds = (receiptDoc['projectedItemIds'] as List?) ?? [];
        expect(projectedIds.contains(collidingExpected.id), isFalse);
        expect(receiptDoc['cursor'], lessThan(plan.items.length));
      },
    );

    test(
      'Requirement 15: Failure degradation preserves existing routine state and does not throw',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 10);
        final database = FakeRoutineDatabase();
        final baseRepo = FakeRoutineRepository(database: database);

        // Seed 5 items into database
        for (var i = 0; i < 5; i++) {
          final item = RoutineItem(
            id: 'routine-doc-$i',
            userId: uid,
            title: 'Initial item $i',
            startMinute: 600,
            endMinute: 660,
            repeatDays: const [1],
            blockType: RoutineBlockType.flexibleTask,
          );
          await baseRepo.createRoutineItem(uid, item);
        }

        final throwingRepo = _ThrowingReconcileRepository(baseRepo);
        final historyRepo = FakeRoutineHistoryRepository();
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        await onboardingRepo.saveCompletionBundle(bundle);

        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(throwingRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            routineTransactionRepositoryProvider.overrideWithValue(
              FakeRoutineTransactionRepository(),
            ),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);

        // loadForOwner must NOT rethrow or crash
        await notifier.loadForOwner(uid);

        final state = container.read(routineNotifierProvider);
        expect(state.loading, isFalse);
        expect(state.error, isNull);
        // Persisted items remain accessible
        expect(state.items.length, 5);

        // Await the background repair to ensure it caught the error safely
        final repairResult = await notifier.inFlightProjectionRepair;
        expect(repairResult, isFalse);

        // Routine state is still completely healthy and usable
        final stateAfter = container.read(routineNotifierProvider);
        expect(stateAfter.loading, isFalse);
        expect(stateAfter.error, isNull);
        expect(stateAfter.items.length, 5);
      },
    );

    test(
      'Requirement 16: Successful background repair refreshes state and preserves local pending writes',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 20);
        final plan = RoutineOnboardingProjection.build(bundle);
        final database = FakeRoutineDatabase();
        final routineRepo = FakeRoutineRepository(database: database);
        final historyRepo = FakeRoutineHistoryRepository();
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        await onboardingRepo.saveCompletionBundle(bundle);

        // Seed only 15 items in repo (5 missing)
        for (var i = 0; i < 15; i++) {
          await routineRepo.createRoutineItem(uid, plan.items[i]);
        }

        final mutationGate = Completer<void>();
        final txRepo = FakeRoutineTransactionRepository(
          routineRepository: routineRepo,
        )..onBeforeMutation = () => mutationGate.future;

        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(routineRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            routineTransactionRepositoryProvider.overrideWithValue(txRepo),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);

        // Initial load completes immediately
        await notifier.loadForOwner(uid);
        expect(container.read(routineNotifierProvider).items.length, 15);

        // Add an optimistic pending local write
        final pendingLocal = RoutineItem(
          id: 'pending-user-created-item',
          userId: uid,
          title: 'Pending local item',
          startMinute: 700,
          endMinute: 750,
          repeatDays: const [1],
          blockType: RoutineBlockType.flexibleTask,
        );

        // Start an optimistic pending local write without awaiting completion yet
        final addFuture = notifier.addItem(pendingLocal);
        // Yield to allow addItem to set pendingItemIds before hitting the gated transaction
        await Future<void>.delayed(Duration.zero);
        expect(
          container
              .read(routineNotifierProvider)
              .pendingItemIds
              .contains('pending-user-created-item'),
          isTrue,
        );

        // Wait for background self-healing repair to finish
        await notifier.inFlightProjectionRepair;

        // Verify pending local write was preserved across the background self-healing merge
        expect(
          container
              .read(routineNotifierProvider)
              .pendingItemIds
              .contains('pending-user-created-item'),
          isTrue,
        );

        // Release the gated transaction and let the local write complete
        mutationGate.complete();
        await addFuture;

        // Verify state refreshed with repaired missing items and completed local write
        final state = container.read(routineNotifierProvider);
        expect(state.items.any((item) => item.id == plan.items[19].id), isTrue);
        expect(state.items.any((item) => item.id == pendingLocal.id), isTrue);
      },
    );

    test(
      'Requirement 18: Startup-time regression guard ensures loadForOwner never blocks on self-healing latency',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 10);
        final database = FakeRoutineDatabase();
        final baseRepo = FakeRoutineRepository(database: database);
        final hangCompleter = Completer<bool>();
        final blockingRepo = _BlockingReconcileRepository(
          baseRepo,
          hangCompleter,
        );

        final historyRepo = FakeRoutineHistoryRepository();
        final onboardingRepo = FakeOnboardingRepository(
          routineDatabase: database,
        );
        await onboardingRepo.saveCompletionBundle(bundle);

        final container = ProviderContainer(
          overrides: [
            routineRepositoryProvider.overrideWithValue(blockingRepo),
            routineHistoryRepositoryProvider.overrideWithValue(historyRepo),
            routineTransactionRepositoryProvider.overrideWithValue(
              FakeRoutineTransactionRepository(),
            ),
            onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(routineNotifierProvider.notifier);

        // loadForOwner must return without waiting for hangCompleter!
        await notifier.loadForOwner(uid);

        // Routine state is already published and loading is false
        final state = container.read(routineNotifierProvider);
        expect(state.loading, isFalse);
        expect(state.error, isNull);

        // Now release the hanging reconciliation
        hangCompleter.complete(true);
        await notifier.inFlightProjectionRepair;

        final stateAfter = container.read(routineNotifierProvider);
        expect(stateAfter.loading, isFalse);
        expect(stateAfter.items.length, 10);
      },
    );

    test(
      'Requirement 17: Projection repair preserves manual and occurrence data',
      () async {
        final bundle = _buildRealisticBundle(uid, count: 5);
        final plan = RoutineOnboardingProjection.build(bundle);
        final database = FakeRoutineDatabase();
        final routineRepo = FakeRoutineRepository(database: database);
        final historyRepo = FakeRoutineHistoryRepository();

        // Seed a manual template
        final manualTemplate = RoutineItem(
          id: 'manual-daily-walk',
          userId: uid,
          title: 'Daily Walk',
          startMinute: 400,
          endMinute: 430,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: RoutineBlockType.flexibleTask,
          source: RoutineSource.manual,
        );
        await routineRepo.createRoutineItem(uid, manualTemplate);

        // Seed an occurrence record
        final occurrence = RoutineOccurrenceRecord(
          id: 'occ-manual-walk-2026-09-12',
          ownerUid: uid,
          routineItemId: manualTemplate.id,
          occurrenceDateKey: '2026-09-12',
          status: RoutineStatus.completed,
          source: 'routine',
          action: 'complete',
          operationKey: 'op-walk-completed',
          createdAt: DateTime.utc(2026, 9, 12, 7),
          updatedAt: DateTime.utc(2026, 9, 12, 7, 30),
        );
        await historyRepo.appendHistory(uid, occurrence);

        // Reconcile onboarding projection
        final repaired = await routineRepo.reconcileOnboardingProjection(
          uid,
          plan,
        );
        expect(repaired, isTrue);

        // Check manual template is untouched
        final allItems = await routineRepo.fetchRoutineItems(uid);
        final fetchedManual = allItems.firstWhere(
          (i) => i.id == manualTemplate.id,
        );
        expect(fetchedManual.title, 'Daily Walk');
        expect(fetchedManual.source, RoutineSource.manual);
        expect(fetchedManual.startMinute, 400);

        // Check occurrence record is untouched
        final history = await historyRepo.fetchHistory(uid);
        expect(history.single.id, occurrence.id);
        expect(history.single.status, RoutineStatus.completed);
      },
    );
  });
}

class _ThrowingReconcileRepository extends FakeRoutineRepository {
  final FakeRoutineRepository delegate;
  _ThrowingReconcileRepository(this.delegate)
    : super(database: delegate.database);

  @override
  Future<bool> reconcileOnboardingProjection(
    String uid,
    RoutineOnboardingProjectionPlan plan,
  ) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Simulated backend unavailability for P0 degradation testing',
    );
  }
}

class _BlockingReconcileRepository extends FakeRoutineRepository {
  final FakeRoutineRepository delegate;
  final Completer<bool> blocker;

  _BlockingReconcileRepository(this.delegate, this.blocker)
    : super(database: delegate.database);

  @override
  Future<bool> reconcileOnboardingProjection(
    String uid,
    RoutineOnboardingProjectionPlan plan,
  ) async {
    await blocker.future;
    return delegate.reconcileOnboardingProjection(uid, plan);
  }
}
