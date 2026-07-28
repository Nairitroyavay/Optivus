import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';

class FirestoreHabitSystemsRepository implements HabitSystemsRepository {
  final FirebaseFirestore? _injectedFirestore;

  FirestoreHabitSystemsRepository({FirebaseFirestore? firestore})
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

  Map<String, dynamic> _systemToFirestoreMap(HabitSystemRecord system) {
    return {
      'systemId': system.systemId,
      'ownerUid': system.ownerUid,
      'title': system.title,
      'description': system.description,
      'category': system.category.name,
      'systemType': system.systemType.name,
      'status': system.status.name,
      'linkedRoutineIds': system.linkedRoutineIds,
      'source': system.source,
      if (system.onboardingSourceId != null)
        'onboardingSourceId': system.onboardingSourceId,
      if (system.onboardingProjectionId != null)
        'onboardingProjectionId': system.onboardingProjectionId,
      'schemaVersion': system.schemaVersion,
      'version': system.version,
    };
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

  @override
  Future<HabitSystemWriteResult> createSystem({
    required HabitSystemRecord system,
    required String operationId,
  }) async {
    _validateOwnerUid(system.ownerUid);
    _validateSystemId(system.systemId);

    final docRef = _firestore.doc(
      FirestoreUserPaths.habitSystem(system.ownerUid, system.systemId),
    );

    try {
      final success = await _firestore.runTransaction<bool>((tx) async {
        final snapshot = await tx.get(docRef);
        if (snapshot.exists) {
          // Idempotency: if it exists, check if it's the exact same system
          final existing = HabitSystemRecord.fromMap(
            snapshot.data()!,
            documentId: snapshot.id,
          );
          if (existing.title == system.title &&
              existing.source == system.source) {
            return true;
          }
          throw const HabitSystemWriteConflict('System ID already exists');
        }

        final data = _systemToFirestoreMap(system);
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        data['version'] = 1;
        tx.set(docRef, data);
        return true;
      });
      if (success) {
        return HabitSystemWriteResult.success(system);
      }
      return const HabitSystemWriteResult.failure('Failed to create');
    } on HabitSystemWriteConflict catch (e) {
      return HabitSystemWriteResult.failure(e.message);
    } catch (e) {
      return HabitSystemWriteResult.failure(e.toString());
    }
  }

  @override
  Future<HabitSystemWriteResult> updateSystem({
    required HabitSystemRecord system,
    required int expectedVersion,
    required String operationId,
  }) async {
    _validateOwnerUid(system.ownerUid);
    _validateSystemId(system.systemId);

    final docRef = _firestore.doc(
      FirestoreUserPaths.habitSystem(system.ownerUid, system.systemId),
    );

    try {
      final updatedSystem = await _firestore.runTransaction<HabitSystemRecord>((
        tx,
      ) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) {
          throw const HabitSystemWriteConflict('System not found');
        }

        final existing = HabitSystemRecord.fromMap(
          snapshot.data()!,
          documentId: snapshot.id,
        );
        if (existing.ownerUid != system.ownerUid) {
          throw const HabitSystemWriteConflict('Owner UID mismatch');
        }
        if (existing.version != expectedVersion) {
          throw const HabitSystemWriteConflict('Stale version');
        }

        final nextVersion = expectedVersion + 1;
        final nextSystem = system.copyWith(version: nextVersion);

        final data = _systemToFirestoreMap(nextSystem);
        data['updatedAt'] = FieldValue.serverTimestamp();
        tx.set(docRef, data);
        return nextSystem;
      });

      return HabitSystemWriteResult.success(updatedSystem);
    } on HabitSystemWriteConflict catch (e) {
      return HabitSystemWriteResult.failure(e.message);
    } catch (e) {
      return HabitSystemWriteResult.failure(e.toString());
    }
  }

  @override
  Future<HabitSystemWriteResult> archiveSystem(
    String uid,
    String systemId,
    int expectedVersion,
    String operationId,
  ) async {
    _validateOwnerUid(uid);
    _validateSystemId(systemId);

    final docRef = _firestore.doc(
      FirestoreUserPaths.habitSystem(uid, systemId),
    );

    try {
      final nextSystem = await _firestore.runTransaction<HabitSystemRecord>((
        tx,
      ) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) {
          throw const HabitSystemWriteConflict('System not found');
        }

        final existing = HabitSystemRecord.fromMap(
          snapshot.data()!,
          documentId: snapshot.id,
        );
        if (existing.ownerUid != uid) {
          throw const HabitSystemWriteConflict('Owner UID mismatch');
        }
        if (existing.version != expectedVersion) {
          throw const HabitSystemWriteConflict('Stale version');
        }

        final updated = existing.copyWith(
          status: HabitSystemStatus.archived,
          version: expectedVersion + 1,
        );
        final data = _systemToFirestoreMap(updated);
        data['updatedAt'] = FieldValue.serverTimestamp();
        data['archivedAt'] = FieldValue.serverTimestamp();
        tx.set(docRef, data);
        return updated;
      });
      return HabitSystemWriteResult.success(nextSystem);
    } on HabitSystemWriteConflict catch (e) {
      return HabitSystemWriteResult.failure(e.message);
    } catch (e) {
      return HabitSystemWriteResult.failure(e.toString());
    }
  }

  @override
  Future<HabitSystemWriteResult> restoreSystem(
    String uid,
    String systemId,
    int expectedVersion,
    String operationId,
  ) async {
    _validateOwnerUid(uid);
    _validateSystemId(systemId);

    final docRef = _firestore.doc(
      FirestoreUserPaths.habitSystem(uid, systemId),
    );

    try {
      final nextSystem = await _firestore.runTransaction<HabitSystemRecord>((
        tx,
      ) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) {
          throw const HabitSystemWriteConflict('System not found');
        }

        final existing = HabitSystemRecord.fromMap(
          snapshot.data()!,
          documentId: snapshot.id,
        );
        if (existing.ownerUid != uid) {
          throw const HabitSystemWriteConflict('Owner UID mismatch');
        }
        if (existing.version != expectedVersion) {
          throw const HabitSystemWriteConflict('Stale version');
        }

        final updated = existing.copyWith(
          status: HabitSystemStatus.active,
          clearArchivedAt: true,
          version: expectedVersion + 1,
        );
        final data = _systemToFirestoreMap(updated);
        data['updatedAt'] = FieldValue.serverTimestamp();
        tx.set(docRef, data);
        return updated;
      });
      return HabitSystemWriteResult.success(nextSystem);
    } on HabitSystemWriteConflict catch (e) {
      return HabitSystemWriteResult.failure(e.message);
    } catch (e) {
      return HabitSystemWriteResult.failure(e.toString());
    }
  }

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystem(
    HabitSystemRecord system,
  ) async {
    _validateOwnerUid(system.ownerUid);
    _validateSystemId(system.systemId);

    if (system.onboardingProjectionId == null) {
      return HabitSystemWriteResult.failure(
        'Missing projection ID',
        expectedSystemIds: [system.systemId],
        failedSystemIds: [system.systemId],
        projectionStatus: 'failed',
      );
    }

    final projectionRef = _firestore
        .collection('users')
        .doc(system.ownerUid)
        .collection('habitSystemProjections')
        .doc(system.onboardingProjectionId!);

    final docRef = _firestore.doc(
      FirestoreUserPaths.habitSystem(system.ownerUid, system.systemId),
    );

    try {
      await _firestore.runTransaction((tx) async {
        final sysSnap = await tx.get(docRef);
        final systemAlreadyExists = sysSnap.exists;

        if (systemAlreadyExists) {
          final existing = HabitSystemRecord.fromMap(
            sysSnap.data()!,
            documentId: sysSnap.id,
          );
          if (existing.ownerUid != system.ownerUid) {
            throw const HabitSystemWriteConflict('Owner UID mismatch');
          }
        } else {
          // We only write the system and create a receipt.
          final sysData = _systemToFirestoreMap(system);
          sysData['createdAt'] = FieldValue.serverTimestamp();
          sysData['updatedAt'] = FieldValue.serverTimestamp();
          sysData['version'] = 1;
          tx.set(docRef, sysData);
        }

        // Update/Create the receipt
        final projSnap = await tx.get(projectionRef);
        if (!projSnap.exists) {
          final receipt = {
            'projectionId': system.onboardingProjectionId,
            'ownerUid': system.ownerUid,
            'sourceVersion': '1',
            'expectedSystemIds': [system.systemId],
            'appliedSystemIds': [system.systemId],
            'failedSystemIds': const <String>[],
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'completedAt': FieldValue.serverTimestamp(),
            'schemaVersion': 1,
          };
          tx.set(projectionRef, receipt);
        } else {
          final existingApplied = List<String>.from(
            projSnap.data()?['appliedSystemIds'] ?? [],
          );
          if (!existingApplied.contains(system.systemId)) {
            existingApplied.add(system.systemId);
            tx.update(projectionRef, {
              'appliedSystemIds': existingApplied,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
      return HabitSystemWriteResult.success(
        system,
        expectedSystemIds: [system.systemId],
        appliedSystemIds: [system.systemId],
        projectionStatus: 'completed',
      );
    } catch (e) {
      return HabitSystemWriteResult.failure(
        'Habit system projection write failed',
        expectedSystemIds: [system.systemId],
        failedSystemIds: [system.systemId],
        projectionStatus: 'failed',
      );
    }
  }

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystems({
    required String ownerUid,
    required String projectionId,
    required List<HabitSystemRecord> systems,
  }) async {
    _validateOwnerUid(ownerUid);
    if (projectionId.trim().isEmpty || projectionId.contains('/')) {
      throw ArgumentError('Valid projection ID is required.');
    }
    for (final sys in systems) {
      if (sys.ownerUid != ownerUid) {
        throw ArgumentError('System ownerUid does not match target ownerUid.');
      }
      _validateSystemId(sys.systemId);
    }

    final projectionRef = _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('habitSystemProjections')
        .doc(projectionId);

    final expectedIds = systems.map((s) => s.systemId).toList();

    try {
      final outcome = await _firestore.runTransaction((tx) async {
        final projSnap = await tx.get(projectionRef);
        final systemSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final sys in systems) {
          final docRef = _firestore.doc(
            FirestoreUserPaths.habitSystem(ownerUid, sys.systemId),
          );
          final sysSnap = await tx.get(docRef);
          systemSnaps[sys.systemId] = sysSnap;
        }

        final appliedSystemIds = <String>[];
        final failedSystemIds = <String>[];

        for (final sys in systems) {
          final docRef = _firestore.doc(
            FirestoreUserPaths.habitSystem(ownerUid, sys.systemId),
          );
          final sysSnap = systemSnaps[sys.systemId];
          final exists = sysSnap != null && sysSnap.exists;

          if (exists) {
            final existing = HabitSystemRecord.fromMap(
              sysSnap.data()!,
              documentId: sysSnap.id,
            );
            if (existing.ownerUid != ownerUid) {
              failedSystemIds.add(sys.systemId);
              continue;
            }
            if (existing.linkedRoutineIds.isEmpty &&
                sys.linkedRoutineIds.isNotEmpty) {
              tx.update(docRef, {
                'linkedRoutineIds': sys.linkedRoutineIds,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } else {
            final sysData = _systemToFirestoreMap(sys);
            sysData['createdAt'] = FieldValue.serverTimestamp();
            sysData['updatedAt'] = FieldValue.serverTimestamp();
            sysData['version'] = 1;
            tx.set(docRef, sysData);
          }
          appliedSystemIds.add(sys.systemId);
        }

        final existingApplied = projSnap.exists
            ? List<String>.from(projSnap.data()?['appliedSystemIds'] ?? [])
            : <String>[];
        for (final id in appliedSystemIds) {
          if (!existingApplied.contains(id)) {
            existingApplied.add(id);
          }
        }

        final status = failedSystemIds.isNotEmpty ? 'partial' : 'completed';

        if (!projSnap.exists) {
          final receipt = {
            'projectionId': projectionId,
            'ownerUid': ownerUid,
            'sourceVersion': '1',
            'expectedSystemIds': expectedIds,
            'appliedSystemIds': existingApplied,
            'failedSystemIds': failedSystemIds,
            'status': status,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            if (status == 'completed')
              'completedAt': FieldValue.serverTimestamp(),
            'schemaVersion': 1,
          };
          tx.set(projectionRef, receipt);
        } else {
          tx.update(projectionRef, {
            'expectedSystemIds': expectedIds,
            'appliedSystemIds': existingApplied,
            'failedSystemIds': failedSystemIds,
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
            if (status == 'completed')
              'completedAt': FieldValue.serverTimestamp(),
          });
        }

        return _HabitProjectionBatchOutcome(
          appliedSystemIds: appliedSystemIds,
          failedSystemIds: failedSystemIds,
          status: status,
        );
      });
      if (outcome.failedSystemIds.isNotEmpty) {
        return HabitSystemWriteResult.failure(
          'Habit system projection partially failed',
          expectedSystemIds: expectedIds,
          appliedSystemIds: outcome.appliedSystemIds,
          failedSystemIds: outcome.failedSystemIds,
          projectionStatus: outcome.status,
        );
      }
      return HabitSystemWriteResult.success(
        systems.isNotEmpty ? systems.first : null,
        expectedSystemIds: expectedIds,
        appliedSystemIds: outcome.appliedSystemIds,
        projectionStatus: outcome.status,
      );
    } catch (e) {
      return HabitSystemWriteResult.failure(
        'Habit system projection batch failed',
        expectedSystemIds: expectedIds,
        failedSystemIds: expectedIds,
        projectionStatus: 'failed',
      );
    }
  }

  @override
  Future<void> deleteHabitSystem(String uid, String systemId) async {
    _validateOwnerUid(uid);
    _validateSystemId(systemId);
    await _firestore
        .doc(FirestoreUserPaths.habitSystem(uid, systemId))
        .delete();
  }
}

class _HabitProjectionBatchOutcome {
  final List<String> appliedSystemIds;
  final List<String> failedSystemIds;
  final String status;

  const _HabitProjectionBatchOutcome({
    required this.appliedSystemIds,
    required this.failedSystemIds,
    required this.status,
  });
}
