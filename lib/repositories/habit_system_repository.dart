import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class HabitSystemRepository {
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid);
  Future<void> saveHabitSystem(String uid, HabitSystemRecord system);
  Future<void> deleteHabitSystem(String uid, String systemId);
  Stream<List<HabitSystemRecord>> watchHabitSystems(String uid);
}

class FirestoreHabitSystemRepository implements HabitSystemRepository {
  final FirebaseFirestore? _injectedFirestore;

  FirestoreHabitSystemRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  void _validateOwnerUid(String uid) {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('Valid owner UID is required.');
    }
  }

  void _validateSystemId(String systemId) {
    if (systemId.trim().isEmpty || systemId.contains('/')) {
      throw ArgumentError('Valid system ID is required.');
    }
  }

  @override
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid) async {
    _validateOwnerUid(uid);
    final snapshot = await _firestore
        .collection(FirestoreUserPaths.habitSystems(uid))
        .get();

    return snapshot.docs
        .map((doc) => HabitSystemRecord.fromMap(doc.data(), documentId: doc.id))
        .toList();
  }

  @override
  Future<void> saveHabitSystem(String uid, HabitSystemRecord system) async {
    _validateOwnerUid(uid);
    _validateSystemId(system.systemId);

    final docRef = _firestore.doc(
      FirestoreUserPaths.habitSystem(uid, system.systemId),
    );
    await docRef.set(system.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteHabitSystem(String uid, String systemId) async {
    _validateOwnerUid(uid);
    _validateSystemId(systemId);

    await _firestore
        .doc(FirestoreUserPaths.habitSystem(uid, systemId))
        .delete();
  }

  @override
  Stream<List<HabitSystemRecord>> watchHabitSystems(String uid) {
    _validateOwnerUid(uid);
    return _firestore
        .collection(FirestoreUserPaths.habitSystems(uid))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    HabitSystemRecord.fromMap(doc.data(), documentId: doc.id),
              )
              .toList(),
        );
  }
}

class FakeHabitSystemRepository implements HabitSystemRepository {
  final Map<String, Map<String, HabitSystemRecord>> _storage = {};
  final _controllers = <String, StreamController<List<HabitSystemRecord>>>{};

  StreamController<List<HabitSystemRecord>> _getController(String uid) {
    return _controllers.putIfAbsent(
      uid,
      () => StreamController<List<HabitSystemRecord>>.broadcast(),
    );
  }

  void _notify(String uid) {
    final list = (_storage[uid]?.values.toList() ?? [])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _getController(uid).add(list);
  }

  @override
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid) async {
    final list = (_storage[uid]?.values.toList() ?? [])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> saveHabitSystem(String uid, HabitSystemRecord system) async {
    final userMap = _storage.putIfAbsent(uid, () => {});
    userMap[system.systemId] = system;
    _notify(uid);
  }

  @override
  Future<void> deleteHabitSystem(String uid, String systemId) async {
    _storage[uid]?.remove(systemId);
    _notify(uid);
  }

  @override
  Stream<List<HabitSystemRecord>> watchHabitSystems(String uid) {
    final controller = _getController(uid);
    _notify(uid);
    return controller.stream;
  }
}

final fakeHabitSystemRepositoryProvider = Provider<FakeHabitSystemRepository>(
  (ref) => FakeHabitSystemRepository(),
);

final habitSystemRepositoryProvider = Provider<HabitSystemRepository>((ref) {
  if (ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase) {
    return FirestoreHabitSystemRepository();
  }
  return ref.watch(fakeHabitSystemRepositoryProvider);
});
