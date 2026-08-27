import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_repository.dart';

abstract class ConflictAcceptanceRepository {
  Future<List<ConflictAcceptance>> fetchForOwner(String uid);

  Future<void> upsert(String uid, ConflictAcceptance acceptance);
}

class FakeConflictAcceptanceRepository implements ConflictAcceptanceRepository {
  FakeConflictAcceptanceRepository(this.database);

  final FakeRoutineDatabase database;

  @override
  Future<List<ConflictAcceptance>> fetchForOwner(String uid) async {
    _validateOwner(uid);
    final values = database.acceptancesByUid[uid]?.values.toList() ?? [];
    values.sort((a, b) => a.acceptanceId.compareTo(b.acceptanceId));
    return List.unmodifiable(values);
  }

  @override
  Future<void> upsert(String uid, ConflictAcceptance acceptance) async {
    _validateOwner(uid);
    if (acceptance.ownerUid != uid || acceptance.acceptanceId.isEmpty) {
      throw ArgumentError('Conflict acceptance owner or ID is invalid.');
    }
    database.acceptancesByUid.putIfAbsent(
      uid,
      () => {},
    )[acceptance.acceptanceId] = acceptance;
  }
}

class FirestoreConflictAcceptanceRepository
    implements ConflictAcceptanceRepository {
  FirestoreConflictAcceptanceRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  final FirebaseFirestore? _injectedFirestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ConflictAcceptance>> fetchForOwner(String uid) async {
    _validateOwner(uid);
    final snapshot = await _firestore
        .collection(FirestoreUserPaths.conflictAcceptances(uid))
        .get();
    final values = snapshot.docs
        .map((doc) => ConflictAcceptance.fromMap(doc.data()))
        .where((acceptance) => acceptance.ownerUid == uid)
        .toList();
    values.sort((a, b) => a.acceptanceId.compareTo(b.acceptanceId));
    return values;
  }

  @override
  Future<void> upsert(String uid, ConflictAcceptance acceptance) async {
    _validateOwner(uid);
    if (acceptance.ownerUid != uid || acceptance.acceptanceId.isEmpty) {
      throw ArgumentError('Conflict acceptance owner or ID is invalid.');
    }
    await _firestore
        .doc(
          FirestoreUserPaths.conflictAcceptance(uid, acceptance.acceptanceId),
        )
        .set(acceptance.toFirestoreMap());
  }
}

void _validateOwner(String uid) {
  if (uid.trim().isEmpty || uid.contains('/')) {
    throw ArgumentError('A valid conflict-acceptance owner is required.');
  }
}

final conflictAcceptanceRepositoryProvider =
    Provider<ConflictAcceptanceRepository>((ref) {
      final routineRepository = ref.watch(routineRepositoryProvider);
      if (routineRepository is FakeRoutineRepository) {
        return FakeConflictAcceptanceRepository(routineRepository.database);
      }
      if (ref.watch(optivusBackendModeProvider) ==
          OptivusBackendMode.firebase) {
        return FirestoreConflictAcceptanceRepository();
      }
      return FakeConflictAcceptanceRepository(
        ref.watch(fakeRoutineDatabaseProvider),
      );
    });
