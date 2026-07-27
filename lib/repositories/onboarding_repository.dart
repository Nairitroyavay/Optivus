import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
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

abstract class OnboardingRepository {
  Future<OnboardingDraft?> fetchDraft(String uid);
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid);
  Future<void> saveDraft(OnboardingDraft draft);
  Future<void> flushPendingDraftSave() async {}
  void dispose() {}
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle);

  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  });
}

class FakeOnboardingRepository implements OnboardingRepository {
  final FakeRoutineDatabase routineDatabase;
  Map<String, OnboardingDraft> _drafts = {};
  Map<String, OnboardingCompletionBundle> _bundles = {};
  bool _failNextCompletionBeforeCommit = false;

  final Debouncer _draftDebouncer = Debouncer(
    delay: const Duration(milliseconds: 400),
  );
  OnboardingDraft? _pendingDraft;

  FakeOnboardingRepository({FakeRoutineDatabase? routineDatabase})
    : routineDatabase = routineDatabase ?? FakeRoutineDatabase();

  bool isDraftSavedInMap(String uid) => _drafts.containsKey(uid);

  void failNextCompletionBeforeCommit() {
    _failNextCompletionBeforeCommit = true;
  }

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    if (_pendingDraft != null && _pendingDraft!.uid == uid) {
      return _pendingDraft;
    }
    return _drafts[uid];
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    return _bundles[uid];
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _pendingDraft = draft;
    _draftDebouncer.run(() async {
      final target = _pendingDraft;
      if (target != null) {
        _drafts[target.uid] = target;
        _pendingDraft = null;
      }
    });
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
        return RoutineProjectionResult(
          outcome: RoutineProjectionOutcome.noOp,
          receipt: existingReceipt,
        );
      }
    }

    final nextDrafts = Map<String, OnboardingDraft>.from(_drafts);
    final nextBundles = Map<String, OnboardingCompletionBundle>.from(_bundles);
    final nextItemsByUid = _copyRoutineItems(routineDatabase.itemsByUid);
    final nextReceiptsByUid = _copyReceipts(routineDatabase.receiptsByUid);
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
    final receipt = _receiptForCategories(
      plan.receipt,
      expectedItemIds: expectedItemIds,
      createdItemIds: createdItemIds,
      existingItemIds: existingItemIds,
      repairedItemIds: repairedItemIds,
      failedItemIds: failedItemIds,
    );
    nextReceiptsByUid.putIfAbsent(bundle.uid, () => {})[plan.projectionId] =
        receipt;

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
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: receipt,
    );
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

class FirestoreOnboardingRepository implements OnboardingRepository {
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
    if (_pendingDraft != null && _pendingDraft!.uid == uid) {
      return _pendingDraft;
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
  OnboardingDraft? _pendingDraft;

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _pendingDraft = draft;
    _draftDebouncer.run(() async {
      final target = _pendingDraft;
      if (target != null) {
        await _firestore
            .doc(FirestoreUserPaths.onboardingDraft(target.uid))
            .set(target.toMap(), SetOptions(merge: true));
        _pendingDraft = null;
      }
    });
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
        .set(bundle.toMap(), SetOptions(merge: true));
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    _validateCompletion(finalDraft, bundle);
    final plan = RoutineOnboardingProjection.build(bundle);
    if (plan.items.length > 450) {
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

    try {
      return await _firestore.runTransaction((transaction) async {
        final receiptSnapshot = await transaction.get(receiptReference);
        final draftReference = _firestore.doc(
          FirestoreUserPaths.onboardingDraft(bundle.uid),
        );
        final bundleReference = _firestore.doc(
          FirestoreUserPaths.onboardingCompletionBundle(bundle.uid),
        );
        final profileReference = _firestore.doc(
          FirestoreUserPaths.profile(bundle.uid),
        );

        final draftSnapshot = await transaction.get(draftReference);
        final bundleSnapshot = await transaction.get(bundleReference);
        final profileSnapshot = await transaction.get(profileReference);
        final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final reference in itemReferences) {
          itemSnapshots.add(await transaction.get(reference));
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
                return RoutineProjectionResult(
                  outcome: RoutineProjectionOutcome.noOp,
                  receipt: receipt,
                );
              }
            }
          }
        }

        transaction.set(
          _firestore.doc(FirestoreUserPaths.onboardingDraft(bundle.uid)),
          finalDraft.toMap(),
        );
        transaction.set(
          _firestore.doc(
            FirestoreUserPaths.onboardingCompletionBundle(bundle.uid),
          ),
          bundle.toMap(),
        );
        final intermediateProfilePatch = Map<String, dynamic>.from(
          bundle.userProfilePatch,
        );
        intermediateProfilePatch['onboardingInputCompleted'] = true;
        intermediateProfilePatch['onboardingProjectionStatus'] = 'pending';
        intermediateProfilePatch['onboardingCompleted'] = false;
        transaction.set(
          _firestore.doc(FirestoreUserPaths.profile(bundle.uid)),
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
            try {
              final data = _routineCodec.toFirestore(
                ownerUid: bundle.uid,
                item: item,
              );
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

        final receipt = _receiptForCategories(
          plan.receipt,
          expectedItemIds: expectedItemIds,
          createdItemIds: createdItemIds,
          existingItemIds: existingItemIds,
          repairedItemIds: repairedItemIds,
          failedItemIds: failedItemIds,
        );
        final receiptData = _receiptCodec.toFirestore(receipt);
        receiptData['createdAt'] = FieldValue.serverTimestamp();
        receiptData['updatedAt'] = FieldValue.serverTimestamp();
        transaction.set(receiptReference, receiptData);

        return RoutineProjectionResult(
          outcome: RoutineProjectionOutcome.projected,
          receipt: receipt,
        );
      });
    } on RoutineProjectionRetryRequiredException {
      rethrow;
    } on FormatException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (error) {
      throw RoutineProjectionRetryRequiredException(error);
    }
  }
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

RoutineProjectionReceipt _receiptForCategories(
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

  final initialCursor = existingItemIds.length;
  final isCompleted =
      initialCursor >= expectedItemIds.length && expectedItemIds.isNotEmpty;
  return RoutineProjectionReceipt(
    id: receipt.id,
    ownerUid: receipt.ownerUid,
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
    cursor: initialCursor,
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

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final repository =
      ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase
      ? FirestoreOnboardingRepository()
      : FakeOnboardingRepository(
          routineDatabase: ref.watch(fakeRoutineDatabaseProvider),
        );
  ref.onDispose(repository.dispose);
  return repository;
});
