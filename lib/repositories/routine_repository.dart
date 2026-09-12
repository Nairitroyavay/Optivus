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
    for (final expected in plan.items) {
      final actual = items[expected.id];
      if (actual != null &&
          (actual.source != RoutineSource.onboarding ||
              actual.onboardingSourceItemId !=
                  expected.onboardingSourceItemId)) {
        return false;
      }
    }
    var changed = false;
    for (final expected in plan.items) {
      final actual = items[expected.id];
      if (actual == null) {
        items[expected.id] = _safeProjectedItem(expected);
        changed = true;
        continue;
      }
      final repaired = _reconciledProjectedItem(expected, actual);
      if (repaired.onboardingVisualStyleKey !=
              actual.onboardingVisualStyleKey ||
          repaired.notes != actual.notes) {
        items[expected.id] = repaired;
        changed = true;
      }
    }
    if (receipt == null) {
      final now = DateTime.now().toUtc();
      receipts[plan.projectionId] = plan.receipt.copyWith(
        status: 'completed',
        cursor: plan.receipt.totalCount,
        updatedAt: now,
        completedAt: now,
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
    final itemRefs = [
      for (final item in plan.items)
        _firestore.doc(FirestoreUserPaths.routineItem(uid, item.id)),
    ];
    return _firestore.runTransaction((transaction) async {
      final receiptSnapshot = await transaction.get(receiptRef);
      RoutineProjectionReceipt? receipt;
      final receiptData = receiptSnapshot.data();
      if (receiptData != null) {
        receipt = _receiptCodec.fromFirestore(
          documentId: receiptSnapshot.id,
          data: receiptData,
        );
        if (receipt.ownerUid != uid ||
            receipt.sourceBundleFingerprint != plan.fingerprint) {
          return false;
        }
      }
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in itemRefs) {
        snapshots.add(await transaction.get(ref));
      }
      for (var index = 0; index < plan.items.length; index++) {
        final data = snapshots[index].data();
        if (data == null) continue;
        final actual = _codec.fromFirestore(
          documentId: snapshots[index].id,
          data: data,
        );
        final expected = plan.items[index];
        if (actual.source != RoutineSource.onboarding ||
            actual.onboardingSourceItemId != expected.onboardingSourceItemId) {
          return false;
        }
      }
      var changed = false;
      for (var index = 0; index < plan.items.length; index++) {
        final expected = plan.items[index];
        final snapshot = snapshots[index];
        final data = snapshot.data();
        if (data == null) {
          final created = _codec.toFirestore(
            ownerUid: uid,
            item: _safeProjectedItem(expected),
          );
          created['createdAt'] = FieldValue.serverTimestamp();
          created['updatedAt'] = FieldValue.serverTimestamp();
          transaction.set(itemRefs[index], created);
          changed = true;
          continue;
        }
        final actual = _codec.fromFirestore(
          documentId: snapshot.id,
          data: data,
        );
        final repaired = _reconciledProjectedItem(expected, actual);
        if (repaired.onboardingVisualStyleKey !=
                actual.onboardingVisualStyleKey ||
            repaired.notes != actual.notes) {
          final repairedData = _codec.toFirestore(
            ownerUid: uid,
            item: repaired,
          );
          repairedData['createdAt'] = data['createdAt'];
          repairedData['updatedAt'] = FieldValue.serverTimestamp();
          transaction.set(itemRefs[index], repairedData);
          changed = true;
        }
      }
      if (receipt == null) {
        final completed = plan.receipt.copyWith(
          status: 'completed',
          cursor: plan.receipt.totalCount,
          completedAt: DateTime.now().toUtc(),
        );
        final data = _receiptCodec.toFirestore(completed);
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        data['completedAt'] = FieldValue.serverTimestamp();
        transaction.set(receiptRef, data);
        changed = true;
      }
      return changed;
    });
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
