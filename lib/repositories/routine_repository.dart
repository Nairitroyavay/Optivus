import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

abstract class RoutineRepository {
  Future<List<RoutineItem>> fetchRoutineItems(String uid);

  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item);

  Future<RoutineItem> updateRoutineItem(String uid, RoutineItem item);

  Future<List<String>> createRoutineItemsIfMissing(
    String uid,
    List<RoutineItem> items,
  );

  Future<void> deleteRoutineItem(String uid, String itemId);

  Future<RoutineProjectionReceipt?> fetchProjectionReceipt(
    String uid,
    String projectionId,
  );

  /// Repairs only authoritative onboarding-projected templates/receipt.
  /// Manual templates and occurrence history are outside this contract.
  Future<bool> reconcileOnboardingProjection(
    String uid,
    RoutineOnboardingProjectionPlan plan,
  );
}

bool _hasLegacyGeneratedSourceNote(RoutineItem item) {
  if (item.source != RoutineSource.onboarding) return false;
  return switch (item.notes?.trim()) {
    'identity_system' => item.category == RoutineCategory.identity,
    'merged_habit_system' ||
    'good_habit' => item.category == RoutineCategory.habit,
    'bad_habit_check_in' => item.category == RoutineCategory.badHabit,
    'money' || 'money_task' => item.category == RoutineCategory.finance,
    _ => false,
  };
}

RoutineItem _safeProjectedItem(RoutineItem item) {
  return _hasLegacyGeneratedSourceNote(item)
      ? item.copyWith(clearNotes: true)
      : item;
}

RoutineItem _reconciledProjectedItem(RoutineItem expected, RoutineItem actual) {
  return actual.copyWith(
    onboardingVisualStyleKey:
        expected.onboardingVisualStyleKey ?? actual.onboardingVisualStyleKey,
    clearNotes:
        _hasLegacyGeneratedSourceNote(expected) &&
        actual.notes?.trim() == expected.notes?.trim(),
    createdAt: actual.createdAt,
  );
}

class FakeRoutineDatabase {
  Map<String, Map<String, RoutineItem>> itemsByUid = {};
  Map<String, Map<String, RoutineProjectionReceipt>> receiptsByUid = {};
  Map<String, Map<String, ConflictAcceptance>> acceptancesByUid = {};
}

class FakeRoutineRepository implements RoutineRepository {
  final FakeRoutineDatabase database;

  FakeRoutineRepository({FakeRoutineDatabase? database})
    : database = database ?? FakeRoutineDatabase();

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    validateOwnerUid(uid);
    final items = database.itemsByUid[uid]?.values.toList() ?? <RoutineItem>[];
    items.sort((a, b) {
      final created = a.createdAt.compareTo(b.createdAt);
      return created == 0 ? a.id.compareTo(b.id) : created;
    });
    return List<RoutineItem>.unmodifiable(items);
  }

  @override
  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item) async {
    const codec = RoutineTemplateFirestoreCodec();
    final userItems = database.itemsByUid.putIfAbsent(uid, () => {});
    if (userItems.containsKey(item.id)) {
      final existing = userItems[item.id]!;
      if (item.createdByOperationId != null &&
          existing.createdByOperationId == item.createdByOperationId) {
        return existing;
      }
      throw Exception('Routine item already exists.');
    }
    final effective = item.copyWith(
      userId: uid,
      createdAt: item.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    // Validate via codec
    codec.toFirestore(ownerUid: uid, item: effective);
    userItems[item.id] = effective;
    return effective;
  }

  @override
  Future<RoutineItem> updateRoutineItem(String uid, RoutineItem item) async {
    const codec = RoutineTemplateFirestoreCodec();
    final userItems = database.itemsByUid.putIfAbsent(uid, () => {});
    if (!userItems.containsKey(item.id)) {
      throw Exception('Routine item does not exist.');
    }
    final current = userItems[item.id]!;
    if (item.lastMutationOperationId != null &&
        current.lastMutationOperationId == item.lastMutationOperationId) {
      return current;
    }
    final effective = item.copyWith(
      userId: uid,
      onboardingProjectionId:
          item.onboardingProjectionId ?? current.onboardingProjectionId,
      onboardingSourceItemId:
          item.onboardingSourceItemId ?? current.onboardingSourceItemId,
      createdByOperationId:
          item.createdByOperationId ?? current.createdByOperationId,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    codec.toFirestore(ownerUid: uid, item: effective);
    userItems[item.id] = effective;
    return effective;
  }

  @override
  Future<List<String>> createRoutineItemsIfMissing(
    String uid,
    List<RoutineItem> items,
  ) async {
    validateOwnerUid(uid);
    final userItems = database.itemsByUid.putIfAbsent(uid, () => {});
    final created = <String>[];
    const codec = RoutineTemplateFirestoreCodec();
    for (final item in items) {
      if (userItems.containsKey(item.id)) continue;
      final effective = item.copyWith(userId: uid);
      codec.toFirestore(ownerUid: uid, item: effective);
      userItems[item.id] = effective;
      created.add(item.id);
    }
    return created;
  }

  @override
  Future<void> deleteRoutineItem(String uid, String itemId) async {
    validateOwnerUid(uid);
    validateDocumentId(itemId);
    database.itemsByUid[uid]?.remove(itemId);
  }

  @override
  Future<RoutineProjectionReceipt?> fetchProjectionReceipt(
    String uid,
    String projectionId,
  ) async {
    validateOwnerUid(uid);
    validateDocumentId(projectionId);
    return database.receiptsByUid[uid]?[projectionId];
  }

  @override
  Future<bool> reconcileOnboardingProjection(
    String uid,
    RoutineOnboardingProjectionPlan plan,
  ) async {
    validateOwnerUid(uid);
    if (uid != plan.ownerUid) return false;
    final receipts = database.receiptsByUid.putIfAbsent(uid, () => {});
    final receipt = receipts[plan.projectionId];
    if (receipt != null &&
        (receipt.ownerUid != uid ||
            receipt.sourceBundleFingerprint != plan.fingerprint)) {
      return false;
    }
    final items = database.itemsByUid.putIfAbsent(uid, () => {});

    final expectedItemIds = plan.items.map((e) => e.id).toList()..sort();
    final createdItemIds = <String>[];
    final existingItemIds = <String>[];
    final repairedItemIds = <String>[];
    final failedItemIds = <String>[];

    var changed = false;
    for (final expected in plan.items) {
      final actual = items[expected.id];
      if (actual == null) {
        items[expected.id] = _safeProjectedItem(expected);
        createdItemIds.add(expected.id);
        changed = true;
        continue;
      }

      final hasValidProjection =
          actual.onboardingProjectionId != null &&
          actual.onboardingProjectionId!.trim().isNotEmpty;
      final isUnsafe =
          actual.source != RoutineSource.onboarding ||
          actual.onboardingSourceItemId != expected.onboardingSourceItemId ||
          actual.onboardingSourceItemId == null ||
          actual.onboardingSourceItemId!.isEmpty ||
          actual.userId != uid ||
          !hasValidProjection ||
          actual.schemaVersion < 1 ||
          actual.schemaVersion > RoutineItem.currentSchemaVersion;

      if (isUnsafe) {
        failedItemIds.add(expected.id);
        continue;
      }

      final repaired = _reconciledProjectedItem(expected, actual);
      if (repaired.onboardingVisualStyleKey !=
              actual.onboardingVisualStyleKey ||
          repaired.notes != actual.notes) {
        items[expected.id] = repaired;
        repairedItemIds.add(expected.id);
        changed = true;
      } else {
        existingItemIds.add(expected.id);
      }
    }

    final updatedReceipt = routineProjectionReceiptForCategories(
      plan.receipt,
      expectedItemIds: expectedItemIds,
      createdItemIds: createdItemIds,
      existingItemIds: existingItemIds,
      repairedItemIds: repairedItemIds,
      failedItemIds: failedItemIds,
    );

    final isReceiptAlreadyFinalized =
        receipt != null &&
        receipt.status == 'completed' &&
        receipt.cursor == receipt.totalCount &&
        receipt.failedItemIds.isEmpty;

    if (!isReceiptAlreadyFinalized || updatedReceipt.status != receipt.status) {
      final now = DateTime.now().toUtc();
      receipts[plan.projectionId] = updatedReceipt.copyWith(
        createdAt: receipt?.createdAt ?? now,
        updatedAt: now,
        completedAt: updatedReceipt.status == 'completed' ? now : null,
      );
      changed = true;
    }
    return changed;
  }
}

class FirestoreRoutineRepository implements RoutineRepository {
  final FirebaseFirestore? _injectedFirestore;
  final RoutineTemplateFirestoreCodec _codec;
  final RoutineProjectionReceiptFirestoreCodec _receiptCodec;

  FirestoreRoutineRepository({
    FirebaseFirestore? firestore,
    RoutineTemplateFirestoreCodec codec = const RoutineTemplateFirestoreCodec(),
    RoutineProjectionReceiptFirestoreCodec receiptCodec =
        const RoutineProjectionReceiptFirestoreCodec(),
  }) : _injectedFirestore = firestore,
       _codec = codec,
       _receiptCodec = receiptCodec;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    validateOwnerUid(uid);
    final snapshot = await _firestore
        .collection(FirestoreUserPaths.routineItems(uid))
        .get();
    final items = snapshot.docs
        .map(
          (doc) => _codec.fromFirestore(documentId: doc.id, data: doc.data()),
        )
        .toList(growable: false);
    return [...items]..sort((a, b) {
      final created = a.createdAt.compareTo(b.createdAt);
      return created == 0 ? a.id.compareTo(b.id) : created;
    });
  }

  @override
  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item) async {
    validateOwnerUid(uid);
    validateDocumentId(item.id);
    final reference = _firestore.doc(
      FirestoreUserPaths.routineItem(uid, item.id),
    );
    return await _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(reference);
      if (existingSnapshot.exists) {
        final data = existingSnapshot.data()!;
        if (item.createdByOperationId != null &&
            data['createdByOperationId'] == item.createdByOperationId) {
          return _codec.fromFirestore(
            documentId: existingSnapshot.id,
            data: data,
          );
        }
        throw Exception('Routine item already exists.');
      }
      final effective = item.copyWith(userId: uid);
      final data = _codec.toFirestore(ownerUid: uid, item: effective);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      transaction.set(reference, data);
      return effective; // Canonical will be refreshed by caller if needed
    });
  }

  @override
  Future<RoutineItem> updateRoutineItem(String uid, RoutineItem item) async {
    validateOwnerUid(uid);
    validateDocumentId(item.id);
    final reference = _firestore.doc(
      FirestoreUserPaths.routineItem(uid, item.id),
    );
    return await _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(reference);
      if (!existingSnapshot.exists) {
        throw Exception('Routine item does not exist.');
      }
      final existingData = existingSnapshot.data()!;
      if (item.lastMutationOperationId != null &&
          existingData['lastMutationOperationId'] ==
              item.lastMutationOperationId) {
        return _codec.fromFirestore(
          documentId: existingSnapshot.id,
          data: existingData,
        );
      }
      final existing = _codec.fromFirestore(
        documentId: existingSnapshot.id,
        data: existingData,
      );
      final effective = item.copyWith(
        userId: uid,
        onboardingProjectionId:
            item.onboardingProjectionId ?? existing.onboardingProjectionId,
        onboardingSourceItemId:
            item.onboardingSourceItemId ?? existing.onboardingSourceItemId,
        createdByOperationId:
            item.createdByOperationId ?? existing.createdByOperationId,
        createdAt: existing.createdAt,
      );
      final data = _codec.toFirestore(ownerUid: uid, item: effective);
      data['createdAt'] = existingData['createdAt'];
      data['updatedAt'] = FieldValue.serverTimestamp();
      transaction.set(reference, data);
      return effective;
    });
  }

  @override
  Future<List<String>> createRoutineItemsIfMissing(
    String uid,
    List<RoutineItem> items,
  ) async {
    validateOwnerUid(uid);
    if (items.isEmpty) return const [];
    final references = <DocumentReference<Map<String, dynamic>>>[];
    final dataById = <String, Map<String, dynamic>>{};
    for (final item in items) {
      validateDocumentId(item.id);
      references.add(
        _firestore.doc(FirestoreUserPaths.routineItem(uid, item.id)),
      );
      dataById[item.id] = _codec.toFirestore(
        ownerUid: uid,
        item: item.copyWith(userId: uid),
      );
    }
    return _firestore.runTransaction((transaction) async {
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final reference in references) {
        snapshots.add(await transaction.get(reference));
      }
      final created = <String>[];
      for (var index = 0; index < references.length; index++) {
        if (snapshots[index].exists) continue;
        final id = references[index].id;
        final data = dataById[id]!;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        transaction.set(references[index], data);
        created.add(id);
      }
      return created;
    });
  }

  @override
  Future<void> deleteRoutineItem(String uid, String itemId) async {
    validateOwnerUid(uid);
    validateDocumentId(itemId);
    final ref = _firestore.doc(FirestoreUserPaths.routineItem(uid, itemId));
    await ref.delete();
  }

  @override
  Future<RoutineProjectionReceipt?> fetchProjectionReceipt(
    String uid,
    String projectionId,
  ) async {
    validateOwnerUid(uid);
    validateDocumentId(projectionId);
    final snapshot = await _firestore
        .doc(FirestoreUserPaths.routineProjection(uid, projectionId))
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return _receiptCodec.fromFirestore(documentId: snapshot.id, data: data);
  }

  @override
  Future<bool> reconcileOnboardingProjection(
    String uid,
    RoutineOnboardingProjectionPlan plan,
  ) async {
    validateOwnerUid(uid);
    if (uid != plan.ownerUid) return false;

    final receiptRef = _firestore.doc(
      FirestoreUserPaths.routineProjection(uid, plan.projectionId),
    );
    final itemsCollection = _firestore.collection(
      FirestoreUserPaths.routineItems(uid),
    );

    final reads = await Future.wait<Object>([
      receiptRef.get(),
      itemsCollection.get(),
    ]);

    final receiptSnapshot = reads[0] as DocumentSnapshot<Map<String, dynamic>>;
    final itemsSnapshot = reads[1] as QuerySnapshot<Map<String, dynamic>>;

    RoutineProjectionReceipt? receipt;
    final receiptData = receiptSnapshot.data();
    if (receiptSnapshot.exists && receiptData != null) {
      receipt = _receiptCodec.fromFirestore(
        documentId: receiptSnapshot.id,
        data: receiptData,
      );
      if (receipt.ownerUid != uid ||
          receipt.sourceBundleFingerprint != plan.fingerprint) {
        return false;
      }
    }

    final persistedDocs = {for (final doc in itemsSnapshot.docs) doc.id: doc};

    final expectedItemIds = plan.items.map((e) => e.id).toList()..sort();
    final createdItemIds = <String>[];
    final existingItemIds = <String>[];
    final repairedItemIds = <String>[];
    final failedItemIds = <String>[];

    final missingItems = <RoutineItem>[];
    final repairedItems = <RoutineItem>[];

    for (final expected in plan.items) {
      final doc = persistedDocs[expected.id];
      if (doc == null || !doc.exists) {
        missingItems.add(_safeProjectedItem(expected));
        createdItemIds.add(expected.id);
        continue;
      }

      final data = doc.data();
      RoutineItem actual;
      try {
        actual = _codec.fromFirestore(documentId: doc.id, data: data);
      } catch (_) {
        failedItemIds.add(expected.id);
        continue;
      }

      final hasValidProjection =
          actual.onboardingProjectionId != null &&
          actual.onboardingProjectionId!.trim().isNotEmpty;
      final isUnsafe =
          actual.source != RoutineSource.onboarding ||
          actual.onboardingSourceItemId != expected.onboardingSourceItemId ||
          actual.onboardingSourceItemId == null ||
          actual.onboardingSourceItemId!.isEmpty ||
          actual.userId != uid ||
          !hasValidProjection ||
          actual.schemaVersion < 1 ||
          actual.schemaVersion > RoutineItem.currentSchemaVersion;

      if (isUnsafe) {
        failedItemIds.add(expected.id);
        continue;
      }

      final repaired = _reconciledProjectedItem(expected, actual);
      final needsRepair =
          repaired.onboardingVisualStyleKey !=
              actual.onboardingVisualStyleKey ||
          repaired.notes != actual.notes;

      if (needsRepair) {
        repairedItems.add(repaired);
        repairedItemIds.add(expected.id);
      } else {
        existingItemIds.add(expected.id);
      }
    }

    final updatedReceipt = routineProjectionReceiptForCategories(
      plan.receipt,
      expectedItemIds: expectedItemIds,
      createdItemIds: createdItemIds,
      existingItemIds: existingItemIds,
      repairedItemIds: repairedItemIds,
      failedItemIds: failedItemIds,
    );

    final isReceiptAlreadyFinalized =
        receipt != null &&
        receipt.status == 'completed' &&
        receipt.cursor == receipt.totalCount &&
        receipt.failedItemIds.isEmpty;

    final hasItemMutations =
        missingItems.isNotEmpty || repairedItems.isNotEmpty;
    final needsReceiptWrite =
        !isReceiptAlreadyFinalized || updatedReceipt.status != receipt.status;

    if (!hasItemMutations && !needsReceiptWrite) {
      return false;
    }

    const maxOpsPerBatch = 400;
    final writeOps = <void Function(WriteBatch batch)>[];

    for (final item in missingItems) {
      writeOps.add((batch) {
        final ref = _firestore.doc(
          FirestoreUserPaths.routineItem(uid, item.id),
        );
        final data = _codec.toFirestore(ownerUid: uid, item: item);
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(ref, data);
      });
    }

    for (final item in repairedItems) {
      writeOps.add((batch) {
        final ref = _firestore.doc(
          FirestoreUserPaths.routineItem(uid, item.id),
        );
        final data = _codec.toFirestore(ownerUid: uid, item: item);
        final existingDoc = persistedDocs[item.id];
        final existingData = existingDoc?.data();
        if (existingData != null && existingData['createdAt'] != null) {
          data['createdAt'] = existingData['createdAt'];
        } else {
          data['createdAt'] = FieldValue.serverTimestamp();
        }
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(ref, data);
      });
    }

    writeOps.add((batch) {
      final receiptMap = _receiptCodec.toFirestore(updatedReceipt);
      if (receiptData != null && receiptData['createdAt'] != null) {
        receiptMap['createdAt'] = receiptData['createdAt'];
      } else {
        receiptMap['createdAt'] = FieldValue.serverTimestamp();
      }
      receiptMap['updatedAt'] = FieldValue.serverTimestamp();
      if (updatedReceipt.status == 'completed') {
        receiptMap['completedAt'] = FieldValue.serverTimestamp();
      }
      batch.set(receiptRef, receiptMap);
    });

    for (var i = 0; i < writeOps.length; i += maxOpsPerBatch) {
      final end = (i + maxOpsPerBatch < writeOps.length)
          ? i + maxOpsPerBatch
          : writeOps.length;
      final chunk = writeOps.sublist(i, end);
      final batch = _firestore.batch();
      for (final op in chunk) {
        op(batch);
      }
      await batch.commit();
    }

    return true;
  }
}

final fakeRoutineDatabaseProvider = Provider<FakeRoutineDatabase>((ref) {
  return FakeRoutineDatabase();
});

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return ref
      .watch(fakeBackendPolicyProvider)
      .selectBackend(
        firebase: FirestoreRoutineRepository.new,
        fake: () => FakeRoutineRepository(
          database: ref.watch(fakeRoutineDatabaseProvider),
        ),
      );
});
