import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';

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
}

class FakeRoutineDatabase {
  Map<String, Map<String, RoutineItem>> itemsByUid = {};
  Map<String, Map<String, RoutineProjectionReceipt>> receiptsByUid = {};
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
}

final fakeRoutineDatabaseProvider = Provider<FakeRoutineDatabase>((ref) {
  return FakeRoutineDatabase();
});

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  if (ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase) {
    return FirestoreRoutineRepository();
  }
  return FakeRoutineRepository(
    database: ref.watch(fakeRoutineDatabaseProvider),
  );
});
