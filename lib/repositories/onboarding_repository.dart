import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/routine_projection_receipt_validator.dart';

import 'package:optivus/core/utils/debouncer.dart';

const onboardingReconcileTransactionTimeout = Duration(seconds: 120);
const onboardingReceiptFinalizeTransactionTimeout = Duration(seconds: 120);

abstract class OnboardingRepository {
  Future<OnboardingDraft?> fetchDraft(String uid);
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid);
  Future<void> saveDraft(OnboardingDraft draft);
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {}
  Future<void> flushPendingDraftSave() async {}
  void dispose() {}
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle);

  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  });
}

abstract interface class RoutineProjectionReceiptFinalizer {
  Future<RoutineProjectionReceipt> finalizeRoutineProjectionReceipt({
    required OnboardingCompletionBundle bundle,
  });
}

class FakeOnboardingRepository
    implements OnboardingRepository, RoutineProjectionReceiptFinalizer {
  final FakeRoutineDatabase routineDatabase;
  Map<String, OnboardingDraft> _drafts = {};
  Map<String, OnboardingCompletionBundle> _bundles = {};
  bool _failNextCompletionBeforeCommit = false;

  final Debouncer _draftDebouncer = Debouncer(
    delay: const Duration(milliseconds: 400),
  );
  final Map<String, OnboardingDraft> _pendingDraftsByUid = {};

  FakeOnboardingRepository({FakeRoutineDatabase? routineDatabase})
    : routineDatabase = routineDatabase ?? FakeRoutineDatabase();

  bool isDraftSavedInMap(String uid) => _drafts.containsKey(uid);

  void failNextCompletionBeforeCommit() {
    _failNextCompletionBeforeCommit = true;
  }

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    if (_pendingDraftsByUid.containsKey(uid)) {
      return _pendingDraftsByUid[uid];
    }
    return _drafts[uid];
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    return _bundles[uid];
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _pendingDraftsByUid[draft.uid] = draft;
    _draftDebouncer.run(() async {
      final targets = Map<String, OnboardingDraft>.from(_pendingDraftsByUid);
      _pendingDraftsByUid.removeWhere((key, _) => targets.containsKey(key));
      for (final target in targets.values) {
        _drafts[target.uid] = target;
      }
    });
  }

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    _pendingDraftsByUid.remove(draft.uid);
    _drafts[draft.uid] = draft;
  }

  @override
  Future<void> flushPendingDraftSave() async {
    await _draftDebouncer.flush();
  }

  @override
  void dispose() {
    _draftDebouncer.dispose();
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    _bundles[bundle.uid] = bundle;
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    _validateCompletion(finalDraft, bundle);
    final plan = RoutineOnboardingProjection.build(bundle);
    if (plan.items.length > 240) {
      throw StateError('Onboarding produced too many Routine templates.');
    }
    final existingReceipt =
        routineDatabase.receiptsByUid[bundle.uid]?[plan.projectionId];
    final existingDraft = _drafts[bundle.uid];
    final existingBundle = _bundles[bundle.uid];
    final existingItems = routineDatabase.itemsByUid[bundle.uid] ?? const {};
    if (existingReceipt != null &&
        existingDraft != null &&
        existingBundle != null &&
        existingReceipt.sourceBundleFingerprint == plan.fingerprint) {
      final validation = const RoutineProjectionReceiptValidator().validate(
        receipt: existingReceipt,
        actualItems: [
          for (final item in plan.items)
            if (existingItems[item.id] != null) existingItems[item.id]!,
        ],
        ownerUid: bundle.uid,
        plan: plan,
      );
      if (validation.isValid) {
        final storedAcceptances =
            routineDatabase.acceptancesByUid[bundle.uid] ?? const {};
        final acceptancesValid = plan.conflictAcceptances.every((expected) {
          final actual = storedAcceptances[expected.acceptanceId];
          return actual != null && _isExpectedAcceptance(actual, expected);
        });
        if (acceptancesValid) {
          return RoutineProjectionResult(
            outcome: RoutineProjectionOutcome.noOp,
            receipt: existingReceipt,
          );
        }
      }
    }

    final nextDrafts = Map<String, OnboardingDraft>.from(_drafts);
    final nextBundles = Map<String, OnboardingCompletionBundle>.from(_bundles);
    final nextItemsByUid = _copyRoutineItems(routineDatabase.itemsByUid);
    final nextReceiptsByUid = _copyReceipts(routineDatabase.receiptsByUid);
    final nextAcceptancesByUid = _copyAcceptances(
      routineDatabase.acceptancesByUid,
    );
    nextDrafts[bundle.uid] = finalDraft;
    nextBundles[bundle.uid] = bundle;
    final userItems = nextItemsByUid.putIfAbsent(bundle.uid, () => {});
    final expectedItemIds = plan.items.map((item) => item.id).toSet().toList()
      ..sort();
    final createdItemIds = <String>[];
    final existingItemIds = <String>[];
    final repairedItemIds = <String>[];
    final failedItemIds = <String>[];
    const codec = RoutineTemplateFirestoreCodec();
    for (final item in plan.items) {
      final existingItem = userItems[item.id];
      if (existingItem != null) {
        if (_isExpectedProjectedRoutineItem(
          actualItem: existingItem,
          expectedItem: item,
          ownerUid: bundle.uid,
          projectionId: plan.projectionId,
        )) {
          existingItemIds.add(item.id);
          continue;
        }
        if (!_hasExpectedRoutineProjectionIdentity(
          actualItem: existingItem,
          expectedItem: item,
          ownerUid: bundle.uid,
        )) {
          failedItemIds.add(item.id);
          continue;
        }
        try {
          codec.toFirestore(ownerUid: bundle.uid, item: item);
          userItems[item.id] = item;
          repairedItemIds.add(item.id);
          continue;
        } catch (_) {
          failedItemIds.add(item.id);
          continue;
        }
      }
      try {
        codec.toFirestore(ownerUid: bundle.uid, item: item);
        userItems[item.id] = item;
        createdItemIds.add(item.id);
      } catch (_) {
        failedItemIds.add(item.id);
      }
    }
    final receipt = routineProjectionReceiptForCategories(
      plan.receipt,
      expectedItemIds: expectedItemIds,
      createdItemIds: createdItemIds,
      existingItemIds: existingItemIds,
      repairedItemIds: repairedItemIds,
      failedItemIds: failedItemIds,
    );
    nextReceiptsByUid.putIfAbsent(bundle.uid, () => {})[plan.projectionId] =
        receipt;
    final ownerAcceptances = nextAcceptancesByUid.putIfAbsent(
      bundle.uid,
      () => {},
    );
    for (final acceptance in plan.conflictAcceptances) {
      ownerAcceptances[acceptance.acceptanceId] = acceptance;
    }

    if (_failNextCompletionBeforeCommit) {
      _failNextCompletionBeforeCommit = false;
      throw const RoutineProjectionRetryRequiredException(
        'Injected atomic onboarding completion failure.',
      );
    }

    _drafts = nextDrafts;
    _bundles = nextBundles;
    routineDatabase.itemsByUid = nextItemsByUid;
    routineDatabase.receiptsByUid = nextReceiptsByUid;
    routineDatabase.acceptancesByUid = nextAcceptancesByUid;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: receipt,
    );
  }

  @override
  Future<RoutineProjectionReceipt> finalizeRoutineProjectionReceipt({
    required OnboardingCompletionBundle bundle,
  }) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final receipt =
        routineDatabase.receiptsByUid[bundle.uid]?[plan.projectionId];
    final actualItems =
        routineDatabase.itemsByUid[bundle.uid]?.values.toList() ??
        const <RoutineItem>[];
    final validation = const RoutineProjectionReceiptValidator().validate(
      receipt: receipt,
      actualItems: actualItems,
      ownerUid: bundle.uid,
      plan: plan,
    );
    if (!validation.isValid || receipt == null) {
      throw StateError('Routine projection receipt cannot be finalized.');
    }
    final storedAcceptances =
        routineDatabase.acceptancesByUid[bundle.uid] ?? const {};
    final acceptancesValid = plan.conflictAcceptances.every((expected) {
      final actual = storedAcceptances[expected.acceptanceId];
      return actual != null && _isExpectedAcceptance(actual, expected);
    });
    if (!acceptancesValid) {
      throw StateError('Routine projection acceptances cannot be finalized.');
    }
    if (receipt.status == 'completed' && receipt.cursor == receipt.totalCount) {
      return receipt;
    }
    if (receipt.status != 'pending') {
      throw StateError('Routine projection receipt cannot be finalized.');
    }
    final now = DateTime.now().toUtc();
    final finalized = receipt.copyWith(
      status: 'completed',
      cursor: receipt.totalCount,
      updatedAt: now,
      completedAt: now,
    );
    routineDatabase.receiptsByUid[bundle.uid]![plan.projectionId] = finalized;
    return finalized;
  }

  OnboardingCompletionBundle? savedCompletionBundle(String uid) {
    return _bundles[uid];
  }
}

bool _isExpectedProjectedRoutineItem({
  required RoutineItem actualItem,
  required RoutineItem expectedItem,
  required String ownerUid,
  required String projectionId,
}) {
  return actualItem.id == expectedItem.id &&
      actualItem.userId == ownerUid &&
      actualItem.onboardingProjectionId == projectionId &&
      actualItem.onboardingSourceItemId ==
          expectedItem.onboardingSourceItemId &&
      actualItem.source == RoutineSource.onboarding &&
      actualItem.schemaVersion == RoutineItem.currentSchemaVersion;
}

bool _hasExpectedRoutineProjectionIdentity({
  required RoutineItem actualItem,
  required RoutineItem expectedItem,
  required String ownerUid,
}) {
  final hasValidProjection =
      actualItem.onboardingProjectionId != null &&
      actualItem.onboardingProjectionId!.trim().isNotEmpty;
  return actualItem.id == expectedItem.id &&
      actualItem.userId == ownerUid &&
      actualItem.onboardingSourceItemId ==
          expectedItem.onboardingSourceItemId &&
      actualItem.onboardingSourceItemId != null &&
      actualItem.onboardingSourceItemId!.isNotEmpty &&
      actualItem.source == RoutineSource.onboarding &&
      hasValidProjection &&
      actualItem.schemaVersion >= 1 &&
      actualItem.schemaVersion <= RoutineItem.currentSchemaVersion;
}

class FirestoreOnboardingRepository
    implements OnboardingRepository, RoutineProjectionReceiptFinalizer {
  final FirebaseFirestore? _injectedFirestore;
  final RoutineTemplateFirestoreCodec _routineCodec;
  final RoutineProjectionReceiptFirestoreCodec _receiptCodec;

  FirestoreOnboardingRepository({
    FirebaseFirestore? firestore,
    RoutineTemplateFirestoreCodec routineCodec =
        const RoutineTemplateFirestoreCodec(),
    RoutineProjectionReceiptFirestoreCodec receiptCodec =
        const RoutineProjectionReceiptFirestoreCodec(),
  }) : _injectedFirestore = firestore,
       _routineCodec = routineCodec,
       _receiptCodec = receiptCodec;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    if (_pendingDraftsByUid.containsKey(uid)) {
      return _pendingDraftsByUid[uid];
    }
    final doc = await _firestore
        .doc(FirestoreUserPaths.onboardingDraft(uid))
        .get();
    final data = doc.data();
    return data == null ? null : OnboardingDraft.fromMap(data);
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.onboardingCompletionBundle(uid))
        .get();
    final data = doc.data();
    return data == null ? null : OnboardingCompletionBundle.fromMap(data);
  }

  final Debouncer _draftDebouncer = Debouncer(
    delay: const Duration(milliseconds: 400),
  );
  final Map<String, OnboardingDraft> _pendingDraftsByUid = {};

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _pendingDraftsByUid[draft.uid] = draft;
    return _draftDebouncer.run(() async {
      final targets = Map<String, OnboardingDraft>.from(_pendingDraftsByUid);
      _pendingDraftsByUid.removeWhere((key, _) => targets.containsKey(key));
      for (final target in targets.values) {
        await _firestore
            .doc(FirestoreUserPaths.onboardingDraft(target.uid))
            .set(target.toFirestoreMap());
      }
    });
  }

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    _pendingDraftsByUid.remove(draft.uid);
    await _firestore
        .doc(FirestoreUserPaths.onboardingDraft(draft.uid))
        .set(draft.toFirestoreMap());
  }

  @override
  Future<void> flushPendingDraftSave() async {
    await _draftDebouncer.flush();
  }

  @override
  void dispose() {
    _draftDebouncer.dispose();
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) {
    return _firestore
        .doc(FirestoreUserPaths.onboardingCompletionBundle(bundle.uid))
        .set(bundle.toFirestoreMap());
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    _validateCompletion(finalDraft, bundle);
    final plan = RoutineOnboardingProjection.build(bundle);
    if (plan.items.length > 240) {
      throw StateError('Onboarding produced too many Routine templates.');
    }
    final receiptReference = _firestore.doc(
      FirestoreUserPaths.routineProjection(bundle.uid, plan.projectionId),
    );
    final itemReferences = plan.items
        .map(
          (item) => _firestore.doc(
            FirestoreUserPaths.routineItem(bundle.uid, item.id),
          ),
        )
        .toList(growable: false);
    final acceptanceReferences = plan.conflictAcceptances
        .map(
          (acceptance) => _firestore.doc(
            FirestoreUserPaths.conflictAcceptance(
              bundle.uid,
              acceptance.acceptanceId,
            ),
          ),
        )
        .toList(growable: false);

    final routineCount = itemReferences.length;
    final acceptanceCount = acceptanceReferences.length;
    final estimatedReads = 4 + routineCount + acceptanceCount;
    final stopwatch = Stopwatch()..start();
    debugPrint(
      'OnboardingReconcile: routineCount=$routineCount '
      'acceptanceCount=$acceptanceCount estimatedReads=$estimatedReads '
      'elapsedMs=0 result=started',
    );

    // A single Firestore batch can hold the complete normal onboarding
    // projection. Read each collection once, reconcile locally, then commit
    // deterministic missing/repair writes atomically with the receipt.
    if (routineCount + acceptanceCount <= 480) {
      try {
        final result = await _completeOnboardingBatched(
          finalDraft: finalDraft,
          bundle: bundle,
          plan: plan,
        );
        debugPrint(
          'OnboardingReconcile: routineCount=$routineCount '
          'acceptanceCount=$acceptanceCount estimatedReads=6 '
          'elapsedMs=${stopwatch.elapsedMilliseconds} '
          'result=${result.outcome.name}',
        );
        return result;
      } catch (error) {
        debugPrint(
          'OnboardingReconcile: routineCount=$routineCount '
          'acceptanceCount=$acceptanceCount estimatedReads=6 '
          'elapsedMs=${stopwatch.elapsedMilliseconds} result=failure '
          'category=${_onboardingReconcileFailureCategory(error)}',
        );
        if (error is RoutineProjectionRetryRequiredException ||
            error is FormatException ||
            error is ArgumentError) {
          rethrow;
        }
        throw RoutineProjectionRetryRequiredException(error);
      }
    }

    try {
      final result = await _firestore.runTransaction((transaction) async {
        final receiptSnapshot = await transaction.get(receiptReference);
        final draftReference = _firestore.doc(
          FirestoreUserPaths.onboardingDraft(bundle.uid),
        );
        final bundleReference = _firestore.doc(
          FirestoreUserPaths.onboardingCompletionBundle(bundle.uid),
        );
        final profileReference = _firestore.doc(
          FirestoreUserPaths.user(bundle.uid),
        );

        final draftSnapshot = await transaction.get(draftReference);
        final bundleSnapshot = await transaction.get(bundleReference);
        final profileSnapshot = await transaction.get(profileReference);
        final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final reference in itemReferences) {
          itemSnapshots.add(await transaction.get(reference));
        }
        final acceptanceSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final reference in acceptanceReferences) {
          acceptanceSnapshots.add(await transaction.get(reference));
        }

        if (receiptSnapshot.exists &&
            draftSnapshot.exists &&
            bundleSnapshot.exists &&
            profileSnapshot.exists) {
          final receiptData = receiptSnapshot.data();
          final profileData = profileSnapshot.data();
          if (receiptData != null && profileData != null) {
            final receipt = _receiptCodec.fromFirestore(
              documentId: receiptSnapshot.id,
              data: receiptData,
            );
            final inputCompleted =
                profileData['onboardingInputCompleted'] as bool? ??
                profileData['onboardingCompleted'] as bool? ??
                false;
            if (inputCompleted &&
                receipt.sourceBundleFingerprint == plan.fingerprint) {
              final validation = const RoutineProjectionReceiptValidator()
                  .validate(
                    receipt: receipt,
                    actualItems: _routineItemsFromSnapshots(
                      itemSnapshots,
                      _routineCodec,
                    ),
                    ownerUid: bundle.uid,
                    plan: plan,
                  );
              if (validation.isValid) {
                final acceptancesValid =
                    plan.conflictAcceptances.length ==
                        acceptanceSnapshots.length &&
                    List<bool>.generate(plan.conflictAcceptances.length, (
                      index,
                    ) {
                      final data = acceptanceSnapshots[index].data();
                      if (data == null) return false;
                      return _isExpectedAcceptance(
                        ConflictAcceptance.fromMap(data),
                        plan.conflictAcceptances[index],
                      );
                    }).every((valid) => valid);
                if (acceptancesValid) {
                  return RoutineProjectionResult(
                    outcome: RoutineProjectionOutcome.noOp,
                    receipt: receipt,
                  );
                }
              }
            }
          }
        }

        transaction.set(
          _firestore.doc(FirestoreUserPaths.onboardingDraft(bundle.uid)),
          finalDraft.toFirestoreMap(),
        );
        transaction.set(
          _firestore.doc(
            FirestoreUserPaths.onboardingCompletionBundle(bundle.uid),
          ),
          bundle.toFirestoreMap(),
        );
        transaction.set(
          _firestore.doc(FirestoreUserPaths.baseTimelineSetup(bundle.uid)),
          BaseTimelineSetup.fromCompletionBundle(
            bundle.uid,
            bundle,
            finalDraft: finalDraft,
          ).toMap(),
        );
        final intermediateProfilePatch =
            Map<String, dynamic>.from(bundle.userProfilePatch)
              ..removeWhere((_, value) => value == null)
              ..remove('source')
              ..remove('createdAt');
        // The bundle is schema v2, but /users/{uid} remains profile schema v1.
        // Normalize persisted v2 bundle patches too so retries can recover.
        intermediateProfilePatch['schemaVersion'] = 1;
        intermediateProfilePatch['updatedAt'] = FieldValue.serverTimestamp();
        intermediateProfilePatch['onboardingInputCompleted'] = true;
        intermediateProfilePatch['onboardingProjectionStatus'] = 'pending';
        intermediateProfilePatch['onboardingCompleted'] = false;
        transaction.set(
          _firestore.doc(FirestoreUserPaths.user(bundle.uid)),
          intermediateProfilePatch,
          SetOptions(merge: true),
        );
        final expectedItemIds =
            plan.items.map((item) => item.id).toSet().toList()..sort();
        final createdItemIds = <String>[];
        final existingItemIds = <String>[];
        final repairedItemIds = <String>[];
        final failedItemIds = <String>[];

        for (var index = 0; index < plan.items.length; index++) {
          final item = plan.items[index];
          if (itemSnapshots[index].exists) {
            final existingItem = _routineItemFromSnapshot(
              itemSnapshots[index],
              _routineCodec,
            );
            if (existingItem != null &&
                _isExpectedProjectedRoutineItem(
                  actualItem: existingItem,
                  expectedItem: item,
                  ownerUid: bundle.uid,
                  projectionId: plan.projectionId,
                )) {
              existingItemIds.add(item.id);
              continue;
            }
            if (existingItem == null ||
                !_hasExpectedRoutineProjectionIdentity(
                  actualItem: existingItem,
                  expectedItem: item,
                  ownerUid: bundle.uid,
                )) {
              failedItemIds.add(item.id);
              continue;
            }
            try {
              final data = _routineCodec.toFirestore(
                ownerUid: bundle.uid,
                item: item,
              );
              final existingData = itemSnapshots[index].data();
              if (existingData != null && existingData['createdAt'] != null) {
                data['createdAt'] = existingData['createdAt'];
              }
              data['updatedAt'] = FieldValue.serverTimestamp();
              transaction.set(itemReferences[index], data);
              repairedItemIds.add(item.id);
              continue;
            } catch (_) {
              failedItemIds.add(item.id);
              continue;
            }
          }
          try {
            final data = _routineCodec.toFirestore(
              ownerUid: bundle.uid,
              item: item,
            );
            data['createdAt'] = FieldValue.serverTimestamp();
            data['updatedAt'] = FieldValue.serverTimestamp();
            transaction.set(itemReferences[index], data);
            createdItemIds.add(item.id);
          } catch (_) {
            failedItemIds.add(item.id);
          }
        }

        for (var index = 0; index < plan.conflictAcceptances.length; index++) {
          final acceptance = plan.conflictAcceptances[index];
          transaction.set(
            acceptanceReferences[index],
            acceptance.toFirestoreMap(),
          );
        }

        final receipt = routineProjectionReceiptForCategories(
          plan.receipt,
          expectedItemIds: expectedItemIds,
          createdItemIds: createdItemIds,
          existingItemIds: existingItemIds,
          repairedItemIds: repairedItemIds,
          failedItemIds: failedItemIds,
        );
        debugPrint(
          'OnboardingReconcilePlan: expectedCount=${expectedItemIds.length} '
          'createdCount=${createdItemIds.length} '
          'existingCount=${existingItemIds.length} '
          'repairedCount=${repairedItemIds.length} '
          'failedCount=${failedItemIds.length} '
          'projectedCount=${receipt.projectedItemIds.length} '
          'cursor=${receipt.cursor} status=${receipt.status}',
        );
        final receiptData = _receiptCodec.toFirestore(receipt);
        final existingReceiptData = receiptSnapshot.data();
        if (existingReceiptData != null &&
            existingReceiptData['createdAt'] != null) {
          receiptData['createdAt'] = existingReceiptData['createdAt'];
        } else {
          receiptData['createdAt'] = FieldValue.serverTimestamp();
        }
        receiptData['updatedAt'] = FieldValue.serverTimestamp();
        if (receipt.status == 'completed') {
          receiptData['completedAt'] = FieldValue.serverTimestamp();
        }
        transaction.set(receiptReference, receiptData);

        return RoutineProjectionResult(
          outcome: RoutineProjectionOutcome.projected,
          receipt: receipt,
        );
      }, timeout: onboardingReconcileTransactionTimeout);
      debugPrint(
        'OnboardingReconcile: routineCount=$routineCount '
        'acceptanceCount=$acceptanceCount estimatedReads=$estimatedReads '
        'elapsedMs=${stopwatch.elapsedMilliseconds} '
        'result=${result.outcome.name}',
      );
      return result;
    } catch (error) {
      debugPrint(
        'OnboardingReconcile: routineCount=$routineCount '
        'acceptanceCount=$acceptanceCount estimatedReads=$estimatedReads '
        'elapsedMs=${stopwatch.elapsedMilliseconds} result=failure '
        'category=${_onboardingReconcileFailureCategory(error)}',
      );
      if (error is RoutineProjectionRetryRequiredException ||
          error is FormatException ||
          error is ArgumentError) {
        rethrow;
      }
      throw RoutineProjectionRetryRequiredException(error);
    }
  }

  Future<RoutineProjectionResult> _completeOnboardingBatched({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
    required RoutineOnboardingProjectionPlan plan,
  }) async {
    final receiptReference = _firestore.doc(
      FirestoreUserPaths.routineProjection(bundle.uid, plan.projectionId),
    );
    final draftReference = _firestore.doc(
      FirestoreUserPaths.onboardingDraft(bundle.uid),
    );
    final bundleReference = _firestore.doc(
      FirestoreUserPaths.onboardingCompletionBundle(bundle.uid),
    );
    final profileReference = _firestore.doc(
      FirestoreUserPaths.user(bundle.uid),
    );
    final reads = await Future.wait<Object>([
      receiptReference.get(),
      draftReference.get(),
      bundleReference.get(),
      profileReference.get(),
      _firestore.collection(FirestoreUserPaths.routineItems(bundle.uid)).get(),
      _firestore
          .collection(FirestoreUserPaths.conflictAcceptances(bundle.uid))
          .get(),
    ]);
    final receiptSnapshot = reads[0] as DocumentSnapshot<Map<String, dynamic>>;
    final draftSnapshot = reads[1] as DocumentSnapshot<Map<String, dynamic>>;
    final bundleSnapshot = reads[2] as DocumentSnapshot<Map<String, dynamic>>;
    final profileSnapshot = reads[3] as DocumentSnapshot<Map<String, dynamic>>;
    final itemQuery = reads[4] as QuerySnapshot<Map<String, dynamic>>;
    final acceptanceQuery = reads[5] as QuerySnapshot<Map<String, dynamic>>;
    final itemSnapshots = {for (final doc in itemQuery.docs) doc.id: doc};
    final acceptanceSnapshots = {
      for (final doc in acceptanceQuery.docs) doc.id: doc,
    };

    if (receiptSnapshot.exists &&
        draftSnapshot.exists &&
        bundleSnapshot.exists &&
        profileSnapshot.exists) {
      final receiptData = receiptSnapshot.data();
      final profileData = profileSnapshot.data();
      if (receiptData != null && profileData != null) {
        final receipt = _receiptCodec.fromFirestore(
          documentId: receiptSnapshot.id,
          data: receiptData,
        );
        final inputCompleted =
            profileData['onboardingInputCompleted'] as bool? ??
            profileData['onboardingCompleted'] as bool? ??
            false;
        final actualItems = <RoutineItem>[];
        for (final expected in plan.items) {
          final snapshot = itemSnapshots[expected.id];
          if (snapshot == null) continue;
          final item = _routineItemFromSnapshot(snapshot, _routineCodec);
          if (item != null) actualItems.add(item);
        }
        final acceptancesValid = plan.conflictAcceptances.every((expected) {
          final data = acceptanceSnapshots[expected.acceptanceId]?.data();
          return data != null &&
              _isExpectedAcceptance(ConflictAcceptance.fromMap(data), expected);
        });
        if (inputCompleted &&
            receipt.sourceBundleFingerprint == plan.fingerprint &&
            const RoutineProjectionReceiptValidator()
                .validate(
                  receipt: receipt,
                  actualItems: actualItems,
                  ownerUid: bundle.uid,
                  plan: plan,
                )
                .isValid &&
            acceptancesValid) {
          return RoutineProjectionResult(
            outcome: RoutineProjectionOutcome.noOp,
            receipt: receipt,
          );
        }
      }
    }

    final expectedItemIds = plan.items.map((item) => item.id).toList()..sort();
    final createdItemIds = <String>[];
    final existingItemIds = <String>[];
    final repairedItemIds = <String>[];
    final failedItemIds = <String>[];
    final batch = _firestore.batch();
    batch.set(draftReference, finalDraft.toFirestoreMap());
    batch.set(bundleReference, bundle.toFirestoreMap());
    batch.set(
      _firestore.doc(FirestoreUserPaths.baseTimelineSetup(bundle.uid)),
      BaseTimelineSetup.fromCompletionBundle(
        bundle.uid,
        bundle,
        finalDraft: finalDraft,
      ).toMap(),
    );
    final profilePatch = Map<String, dynamic>.from(bundle.userProfilePatch)
      ..removeWhere((_, value) => value == null)
      ..remove('source')
      ..remove('createdAt');
    profilePatch['schemaVersion'] = 1;
    profilePatch['updatedAt'] = FieldValue.serverTimestamp();
    profilePatch['onboardingInputCompleted'] = true;
    profilePatch['onboardingProjectionStatus'] = 'pending';
    profilePatch['onboardingCompleted'] = false;
    batch.set(profileReference, profilePatch, SetOptions(merge: true));

    for (final item in plan.items) {
      final snapshot = itemSnapshots[item.id];
      final existing = snapshot == null
          ? null
          : _routineItemFromSnapshot(snapshot, _routineCodec);
      if (existing != null &&
          _isExpectedProjectedRoutineItem(
            actualItem: existing,
            expectedItem: item,
            ownerUid: bundle.uid,
            projectionId: plan.projectionId,
          )) {
        existingItemIds.add(item.id);
        continue;
      }
      if (snapshot != null &&
          (existing == null ||
              !_hasExpectedRoutineProjectionIdentity(
                actualItem: existing,
                expectedItem: item,
                ownerUid: bundle.uid,
              ))) {
        failedItemIds.add(item.id);
        continue;
      }
      try {
        final data = _routineCodec.toFirestore(
          ownerUid: bundle.uid,
          item: item,
        );
        data['createdAt'] = snapshot == null
            ? FieldValue.serverTimestamp()
            : snapshot.data()['createdAt'] ?? FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(
          _firestore.doc(FirestoreUserPaths.routineItem(bundle.uid, item.id)),
          data,
        );
        (snapshot == null ? createdItemIds : repairedItemIds).add(item.id);
      } catch (_) {
        failedItemIds.add(item.id);
      }
    }
    for (final acceptance in plan.conflictAcceptances) {
      batch.set(
        _firestore.doc(
          FirestoreUserPaths.conflictAcceptance(
            bundle.uid,
            acceptance.acceptanceId,
          ),
        ),
        acceptance.toFirestoreMap(),
      );
    }
    final receipt = routineProjectionReceiptForCategories(
      plan.receipt,
      expectedItemIds: expectedItemIds,
      createdItemIds: createdItemIds,
      existingItemIds: existingItemIds,
      repairedItemIds: repairedItemIds,
      failedItemIds: failedItemIds,
    );
    final receiptData = _receiptCodec.toFirestore(receipt);
    receiptData['createdAt'] =
        receiptSnapshot.data()?['createdAt'] ?? FieldValue.serverTimestamp();
    receiptData['updatedAt'] = FieldValue.serverTimestamp();
    if (receipt.status == 'completed') {
      receiptData['completedAt'] = FieldValue.serverTimestamp();
    }
    batch.set(receiptReference, receiptData);
    await batch.commit();
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: receipt,
    );
  }

  @override
  Future<RoutineProjectionReceipt> finalizeRoutineProjectionReceipt({
    required OnboardingCompletionBundle bundle,
  }) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final receiptReference = _firestore.doc(
      FirestoreUserPaths.routineProjection(bundle.uid, plan.projectionId),
    );
    final itemReferences = plan.items
        .map(
          (item) => _firestore.doc(
            FirestoreUserPaths.routineItem(bundle.uid, item.id),
          ),
        )
        .toList(growable: false);
    final acceptanceReferences = plan.conflictAcceptances
        .map(
          (acceptance) => _firestore.doc(
            FirestoreUserPaths.conflictAcceptance(
              bundle.uid,
              acceptance.acceptanceId,
            ),
          ),
        )
        .toList(growable: false);

    if (itemReferences.length + acceptanceReferences.length <= 480) {
      return _finalizeRoutineProjectionReceiptBatched(
        bundle: bundle,
        plan: plan,
        receiptReference: receiptReference,
      );
    }

    return _firestore.runTransaction((transaction) async {
      final receiptSnapshot = await transaction.get(receiptReference);
      final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final reference in itemReferences) {
        itemSnapshots.add(await transaction.get(reference));
      }
      final acceptanceSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final reference in acceptanceReferences) {
        acceptanceSnapshots.add(await transaction.get(reference));
      }

      final receiptData = receiptSnapshot.data();
      if (!receiptSnapshot.exists || receiptData == null) {
        throw StateError('Routine projection receipt cannot be finalized.');
      }
      final receipt = _receiptCodec.fromFirestore(
        documentId: receiptSnapshot.id,
        data: receiptData,
      );
      final validation = const RoutineProjectionReceiptValidator().validate(
        receipt: receipt,
        actualItems: _routineItemsFromSnapshots(itemSnapshots, _routineCodec),
        ownerUid: bundle.uid,
        plan: plan,
      );
      if (!validation.isValid) {
        throw StateError('Routine projection receipt cannot be finalized.');
      }
      final acceptancesValid =
          plan.conflictAcceptances.length == acceptanceSnapshots.length &&
          List<bool>.generate(plan.conflictAcceptances.length, (index) {
            final data = acceptanceSnapshots[index].data();
            if (data == null) return false;
            return _isExpectedAcceptance(
              ConflictAcceptance.fromMap(data),
              plan.conflictAcceptances[index],
            );
          }).every((valid) => valid);
      if (!acceptancesValid) {
        throw StateError('Routine projection acceptances cannot be finalized.');
      }
      if (receipt.status == 'completed' &&
          receipt.cursor == receipt.totalCount) {
        return receipt;
      }
      if (receipt.status != 'pending') {
        throw StateError('Routine projection receipt cannot be finalized.');
      }

      transaction.update(receiptReference, {
        'status': 'completed',
        'cursor': receipt.totalCount,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
      final now = DateTime.now().toUtc();
      debugPrint(
        'OnboardingReceiptFinalize: routineCount=${itemReferences.length} '
        'acceptanceCount=${acceptanceReferences.length} result=completed',
      );
      return receipt.copyWith(
        status: 'completed',
        cursor: receipt.totalCount,
        updatedAt: now,
        completedAt: now,
      );
    }, timeout: onboardingReceiptFinalizeTransactionTimeout);
  }

  Future<RoutineProjectionReceipt> _finalizeRoutineProjectionReceiptBatched({
    required OnboardingCompletionBundle bundle,
    required RoutineOnboardingProjectionPlan plan,
    required DocumentReference<Map<String, dynamic>> receiptReference,
  }) async {
    final reads = await Future.wait<Object>([
      receiptReference.get(),
      _firestore.collection(FirestoreUserPaths.routineItems(bundle.uid)).get(),
      _firestore
          .collection(FirestoreUserPaths.conflictAcceptances(bundle.uid))
          .get(),
    ]);
    final receiptSnapshot = reads[0] as DocumentSnapshot<Map<String, dynamic>>;
    final itemQuery = reads[1] as QuerySnapshot<Map<String, dynamic>>;
    final acceptanceQuery = reads[2] as QuerySnapshot<Map<String, dynamic>>;
    final receiptData = receiptSnapshot.data();
    if (!receiptSnapshot.exists || receiptData == null) {
      throw StateError('Routine projection receipt cannot be finalized.');
    }
    final receipt = _receiptCodec.fromFirestore(
      documentId: receiptSnapshot.id,
      data: receiptData,
    );
    final expectedIds = plan.items.map((item) => item.id).toSet();
    final actualItems = itemQuery.docs
        .where((doc) => expectedIds.contains(doc.id))
        .map(
          (doc) =>
              _routineCodec.fromFirestore(documentId: doc.id, data: doc.data()),
        )
        .toList(growable: false);
    final validation = const RoutineProjectionReceiptValidator().validate(
      receipt: receipt,
      actualItems: actualItems,
      ownerUid: bundle.uid,
      plan: plan,
    );
    if (!validation.isValid) {
      throw StateError('Routine projection receipt cannot be finalized.');
    }
    final storedAcceptances = {
      for (final doc in acceptanceQuery.docs) doc.id: doc.data(),
    };
    final acceptancesValid = plan.conflictAcceptances.every((expected) {
      final data = storedAcceptances[expected.acceptanceId];
      return data != null &&
          _isExpectedAcceptance(ConflictAcceptance.fromMap(data), expected);
    });
    if (!acceptancesValid) {
      throw StateError('Routine projection acceptances cannot be finalized.');
    }
    if (receipt.status == 'completed' && receipt.cursor == receipt.totalCount) {
      return receipt;
    }
    if (receipt.status != 'pending') {
      throw StateError('Routine projection receipt cannot be finalized.');
    }
    return _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(receiptReference);
      final currentData = currentSnapshot.data();
      if (!currentSnapshot.exists || currentData == null) {
        throw StateError('Routine projection receipt cannot be finalized.');
      }
      final current = _receiptCodec.fromFirestore(
        documentId: currentSnapshot.id,
        data: currentData,
      );
      if (current.sourceBundleFingerprint != plan.fingerprint ||
          current.status != 'pending') {
        throw StateError('Routine projection receipt changed during finalize.');
      }
      transaction.update(receiptReference, {
        'status': 'completed',
        'cursor': current.totalCount,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
      final now = DateTime.now().toUtc();
      debugPrint(
        'OnboardingReceiptFinalize: routineCount=${plan.items.length} '
        'acceptanceCount=${plan.conflictAcceptances.length} result=completed',
      );
      return current.copyWith(
        status: 'completed',
        cursor: current.totalCount,
        updatedAt: now,
        completedAt: now,
      );
    }, timeout: onboardingReceiptFinalizeTransactionTimeout);
  }
}

String _onboardingReconcileFailureCategory(Object error) {
  if (error is FirebaseException) {
    return 'firestore_${error.code}';
  }
  if (error is RoutineProjectionRetryRequiredException) {
    return 'retry_required';
  }
  if (error is FormatException) {
    return 'format';
  }
  if (error is ArgumentError) {
    return 'argument';
  }
  return 'unexpected';
}

List<RoutineItem> _routineItemsFromSnapshots(
  List<DocumentSnapshot<Map<String, dynamic>>> snapshots,
  RoutineTemplateFirestoreCodec codec,
) {
  final items = <RoutineItem>[];
  for (final snapshot in snapshots) {
    final item = _routineItemFromSnapshot(snapshot, codec);
    if (item != null) {
      items.add(item);
    }
  }
  return items;
}

RoutineItem? _routineItemFromSnapshot(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
  RoutineTemplateFirestoreCodec codec,
) {
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  try {
    return codec.fromFirestore(documentId: snapshot.id, data: data);
  } catch (_) {
    return null;
  }
}

@visibleForTesting
RoutineProjectionReceipt routineProjectionReceiptForCategories(
  RoutineProjectionReceipt receipt, {
  required List<String> expectedItemIds,
  required List<String> createdItemIds,
  required List<String> existingItemIds,
  required List<String> repairedItemIds,
  required List<String> failedItemIds,
}) {
  final projectedItemIds = <String>{
    ...createdItemIds,
    ...existingItemIds,
    ...repairedItemIds,
  }.toList()..sort();

  final expectedIdSet = expectedItemIds.toSet();
  final projectedIdSet = projectedItemIds.toSet();
  final accountedCount = projectedIdSet.length;
  final isCompleted =
      failedItemIds.isEmpty &&
      expectedIdSet.length == expectedItemIds.length &&
      projectedIdSet.length == expectedIdSet.length &&
      projectedIdSet.containsAll(expectedIdSet);
  return RoutineProjectionReceipt(
    id: receipt.id,
    ownerUid: receipt.ownerUid,
    slot: receipt.slot,
    revision: receipt.revision,
    source: receipt.source,
    sourceBundleSchemaVersion: receipt.sourceBundleSchemaVersion,
    sourceBundleId: receipt.sourceBundleId,
    sourceBundleFingerprint: receipt.sourceBundleFingerprint,
    expectedItemIds: expectedItemIds,
    createdItemIds: createdItemIds,
    existingItemIds: existingItemIds,
    repairedItemIds: repairedItemIds,
    failedItemIds: failedItemIds,
    projectedItemIds: projectedItemIds,
    eventSchemaVersion: receipt.eventSchemaVersion,
    status: isCompleted ? 'completed' : 'pending',
    cursor: accountedCount,
    totalCount: expectedItemIds.length,
    createdAt: receipt.createdAt,
    updatedAt: receipt.updatedAt,
    completedAt: isCompleted ? receipt.createdAt : null,
    schemaVersion: receipt.schemaVersion,
  );
}

void _validateCompletion(
  OnboardingDraft finalDraft,
  OnboardingCompletionBundle bundle,
) {
  if (finalDraft.uid != bundle.uid) {
    throw ArgumentError('Final draft and completion bundle uid mismatch.');
  }
  validateOwnerUid(bundle.uid);
  if (!finalDraft.onboardingCompleted) {
    throw ArgumentError('Final onboarding draft is not marked complete.');
  }
}

Map<String, Map<String, RoutineItem>> _copyRoutineItems(
  Map<String, Map<String, RoutineItem>> source,
) {
  return {
    for (final entry in source.entries)
      entry.key: Map<String, RoutineItem>.from(entry.value),
  };
}

Map<String, Map<String, RoutineProjectionReceipt>> _copyReceipts(
  Map<String, Map<String, RoutineProjectionReceipt>> source,
) {
  return {
    for (final entry in source.entries)
      entry.key: Map<String, RoutineProjectionReceipt>.from(entry.value),
  };
}

Map<String, Map<String, ConflictAcceptance>> _copyAcceptances(
  Map<String, Map<String, ConflictAcceptance>> source,
) {
  return {
    for (final entry in source.entries)
      entry.key: Map<String, ConflictAcceptance>.from(entry.value),
  };
}

bool _isExpectedAcceptance(
  ConflictAcceptance actual,
  ConflictAcceptance expected,
) {
  return actual.acceptanceId == expected.acceptanceId &&
      actual.ownerUid == expected.ownerUid &&
      actual.canonicalPairHash == expected.canonicalPairHash &&
      actual.firstProjectedRoutineId == expected.firstProjectedRoutineId &&
      actual.secondProjectedRoutineId == expected.secondProjectedRoutineId &&
      actual.combinedScheduleFingerprint ==
          expected.combinedScheduleFingerprint &&
      actual.sourceBundleFingerprint == expected.sourceBundleFingerprint &&
      actual.projectionId == expected.projectionId &&
      actual.status == expected.status &&
      actual.schemaVersion == expected.schemaVersion;
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final OnboardingRepository repository = ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: FirestoreOnboardingRepository.new,
        fake: () => FakeOnboardingRepository(
          routineDatabase: ref.watch(fakeRoutineDatabaseProvider),
        ),
      );
  ref.onDispose(repository.dispose);
  return repository;
});
