import 'dart:async';

import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';

class FakeHabitSystemsRepository implements HabitSystemsRepository {
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
  Future<HabitSystemWriteResult> createSystem({
    required HabitSystemRecord system,
    required String operationId,
  }) async {
    final uid = system.ownerUid;
    final userMap = _storage.putIfAbsent(uid, () => {});
    if (userMap.containsKey(system.systemId)) {
      final existing = userMap[system.systemId]!;
      if (existing.title == system.title && existing.source == system.source) {
        return HabitSystemWriteResult.success(existing);
      }
      return const HabitSystemWriteResult.failure('System already exists');
    }
    userMap[system.systemId] = system;
    _notify(uid);
    return HabitSystemWriteResult.success(system);
  }

  @override
  Future<HabitSystemWriteResult> updateSystem({
    required HabitSystemRecord system,
    required int expectedVersion,
    required String operationId,
  }) async {
    final uid = system.ownerUid;
    for (final entry in _storage.entries) {
      final existing = entry.value[system.systemId];
      if (existing != null && existing.ownerUid != uid) {
        throw const HabitSystemWriteConflict('Owner UID mismatch');
      }
    }
    final userMap = _storage.putIfAbsent(uid, () => {});
    final current = userMap[system.systemId];
    if (current == null) {
      return const HabitSystemWriteResult.failure('Not found');
    }
    if (current.ownerUid != system.ownerUid) {
      throw const HabitSystemWriteConflict('Owner UID mismatch');
    }
    if (current.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    final next = system.copyWith(version: expectedVersion + 1);
    userMap[system.systemId] = next;
    _notify(uid);
    return HabitSystemWriteResult.success(next);
  }

  @override
  Future<HabitSystemWriteResult> archiveSystem(
    String uid,
    String systemId,
    int expectedVersion,
    String operationId,
  ) async {
    final userMap = _storage.putIfAbsent(uid, () => {});
    final current = userMap[systemId];
    if (current == null) {
      return const HabitSystemWriteResult.failure('Not found');
    }
    if (current.ownerUid != uid) {
      throw const HabitSystemWriteConflict('Owner UID mismatch');
    }
    if (current.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    final next = current.copyWith(
      status: HabitSystemStatus.archived,
      archivedAt: DateTime.now().toUtc(),
      version: expectedVersion + 1,
    );
    userMap[systemId] = next;
    _notify(uid);
    return HabitSystemWriteResult.success(next);
  }

  @override
  Future<HabitSystemWriteResult> restoreSystem(
    String uid,
    String systemId,
    int expectedVersion,
    String operationId,
  ) async {
    final userMap = _storage.putIfAbsent(uid, () => {});
    final current = userMap[systemId];
    if (current == null) {
      return const HabitSystemWriteResult.failure('Not found');
    }
    if (current.ownerUid != uid) {
      throw const HabitSystemWriteConflict('Owner UID mismatch');
    }
    if (current.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    final next = current.copyWith(
      status: HabitSystemStatus.active,
      clearArchivedAt: true,
      version: expectedVersion + 1,
    );
    userMap[systemId] = next;
    _notify(uid);
    return HabitSystemWriteResult.success(next);
  }

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystem(
    HabitSystemRecord system,
  ) async {
    final uid = system.ownerUid;
    final userMap = _storage.putIfAbsent(uid, () => {});
    final existing = userMap[system.systemId];
    if (existing != null && existing.ownerUid != system.ownerUid) {
      throw const HabitSystemWriteConflict('Owner UID mismatch');
    }
    if (!userMap.containsKey(system.systemId)) {
      userMap[system.systemId] = system;
      _notify(uid);
    }
    return HabitSystemWriteResult.success(
      system,
      expectedSystemIds: [system.systemId],
      appliedSystemIds: [system.systemId],
      projectionStatus: 'completed',
    );
  }

  @override
  Future<HabitSystemWriteResult> reconcileProjectedSystems({
    required String ownerUid,
    required String projectionId,
    required List<HabitSystemRecord> systems,
  }) async {
    final userMap = _storage.putIfAbsent(ownerUid, () => {});
    final expectedSystemIds = systems.map((system) => system.systemId).toList();
    final createdSystemIds = <String>[];
    final existingSystemIds = <String>[];
    final repairedSystemIds = <String>[];
    final failedSystemIds = <String>[];
    for (final system in systems) {
      if (system.ownerUid != ownerUid) {
        throw ArgumentError('System ownerUid does not match target ownerUid.');
      }
      final existing = userMap[system.systemId];
      if (existing != null && existing.ownerUid != ownerUid) {
        throw const HabitSystemWriteConflict('Owner UID mismatch');
      }
      if (existing == null) {
        userMap[system.systemId] = system;
        createdSystemIds.add(system.systemId);
      } else if (!_sameProjectionIdentity(existing, system)) {
        failedSystemIds.add(system.systemId);
      } else if (_sameProjectedSystem(existing, system)) {
        existingSystemIds.add(system.systemId);
      } else {
        userMap[system.systemId] = system.copyWith(
          createdAt: existing.createdAt,
          version: existing.version + 1,
        );
        repairedSystemIds.add(system.systemId);
      }
    }
    _notify(ownerUid);
    final appliedSystemIds = <String>{
      ...createdSystemIds,
      ...existingSystemIds,
      ...repairedSystemIds,
    }.toList()..sort();
    if (failedSystemIds.isNotEmpty) {
      return HabitSystemWriteResult.failure(
        'Habit system projection failed closed',
        expectedSystemIds: expectedSystemIds,
        appliedSystemIds: appliedSystemIds,
        createdSystemIds: createdSystemIds,
        existingSystemIds: existingSystemIds,
        repairedSystemIds: repairedSystemIds,
        failedSystemIds: failedSystemIds,
        projectionStatus: 'partial',
      );
    }
    return HabitSystemWriteResult.success(
      systems.isNotEmpty ? systems.first : null,
      expectedSystemIds: expectedSystemIds,
      appliedSystemIds: appliedSystemIds,
      createdSystemIds: createdSystemIds,
      existingSystemIds: existingSystemIds,
      repairedSystemIds: repairedSystemIds,
      projectionStatus: 'completed',
    );
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

bool _sameProjectionIdentity(
  HabitSystemRecord actual,
  HabitSystemRecord expected,
) {
  return actual.ownerUid == expected.ownerUid &&
      actual.source == 'onboarding' &&
      actual.onboardingSourceId == expected.onboardingSourceId &&
      actual.onboardingProjectionId == expected.onboardingProjectionId &&
      actual.sourceFingerprint == expected.sourceFingerprint &&
      actual.schemaVersion == expected.schemaVersion;
}

bool _sameProjectedSystem(
  HabitSystemRecord actual,
  HabitSystemRecord expected,
) {
  return _sameProjectionIdentity(actual, expected) &&
      actual.title == expected.title &&
      actual.description == expected.description &&
      actual.category == expected.category &&
      actual.systemType == expected.systemType &&
      actual.status == expected.status &&
      actual.linkedRoutineIds.toSet().containsAll(expected.linkedRoutineIds) &&
      expected.linkedRoutineIds.toSet().containsAll(actual.linkedRoutineIds);
}
