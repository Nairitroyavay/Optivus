import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';

class RoutineOccurrenceFirestoreCodec {
  const RoutineOccurrenceFirestoreCodec();

  static const Set<String> allowedFields = {
    'id',
    'ownerUid',
    'routineItemId',
    'occurrenceDateKey',
    'status',
    'source',
    'action',
    'operationKey',
    'movedToDateKey',
    'movedStartMinute',
    'movedEndMinute',
    'completedSubtaskIndexes',
    'note',
    'displayTitleOverride',
    'undoToPlannedAllowed',
    'onboardingProjectionId',
    'onboardingSourceItemId',
    'sourceFingerprint',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };

  Map<String, dynamic> toFirestore(RoutineOccurrenceRecord record) {
    validateOwnerUid(record.ownerUid);
    validateDocumentId(record.id);
    validateDocumentId(record.routineItemId);
    if (record.schemaVersion != RoutineOccurrenceRecord.currentSchemaVersion) {
      throw ArgumentError('Unsupported Routine occurrence schema.');
    }
    parseRoutineLocalDateKey(record.occurrenceDateKey);
    if (record.movedToDateKey != null) {
      parseRoutineLocalDateKey(record.movedToDateKey!);
    }
    if (!_durableOccurrenceStatuses.contains(record.status)) {
      throw ArgumentError('Invalid durable Routine occurrence status.');
    }
    if (!_occurrenceSources.contains(record.source) ||
        !_occurrenceActions.contains(record.action)) {
      throw ArgumentError('Invalid Routine occurrence source/action.');
    }
    if (record.source == 'onboarding' &&
        (record.onboardingProjectionId?.trim().isEmpty != false ||
            record.onboardingSourceItemId?.trim().isEmpty != false ||
            record.sourceFingerprint?.length != 64)) {
      throw ArgumentError('Onboarding History metadata is incomplete.');
    }
    if (record.operationKey.trim().isEmpty ||
        record.operationKey.length > 256) {
      throw ArgumentError('Invalid Routine occurrence operation key.');
    }
    _validateMove(record);
    final uniqueSubtasks = record.completedSubtaskIndexes.toSet();
    if (uniqueSubtasks.length != record.completedSubtaskIndexes.length ||
        uniqueSubtasks.any((index) => index < 0 || index > 99)) {
      throw ArgumentError('Invalid completed Routine subtask indexes.');
    }

    return {
      'id': record.id,
      'ownerUid': record.ownerUid,
      'routineItemId': record.routineItemId,
      'occurrenceDateKey': record.occurrenceDateKey,
      'status': record.status.name,
      'source': record.source,
      'action': record.action,
      'operationKey': record.operationKey,
      if (record.movedToDateKey != null)
        'movedToDateKey': record.movedToDateKey,
      if (record.movedStartMinute != null)
        'movedStartMinute': record.movedStartMinute,
      if (record.movedEndMinute != null)
        'movedEndMinute': record.movedEndMinute,
      'completedSubtaskIndexes': record.completedSubtaskIndexes,
      if (record.note?.trim().isNotEmpty == true) 'note': record.note!.trim(),
      if (record.displayTitleOverride?.trim().isNotEmpty == true)
        'displayTitleOverride': record.displayTitleOverride!.trim(),
      'undoToPlannedAllowed': record.undoToPlannedAllowed,
      if (record.onboardingProjectionId != null)
        'onboardingProjectionId': record.onboardingProjectionId,
      if (record.onboardingSourceItemId != null)
        'onboardingSourceItemId': record.onboardingSourceItemId,
      if (record.sourceFingerprint != null)
        'sourceFingerprint': record.sourceFingerprint,
      'createdAt': Timestamp.fromDate(record.createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(record.updatedAt.toUtc()),
      'schemaVersion': record.schemaVersion,
    };
  }

  RoutineOccurrenceRecord fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    validateDocumentId(documentId);
    final id = data['id'] as String? ?? '';
    if (id != documentId) {
      throw const FormatException('Routine occurrence ID mismatch.');
    }
    final statusName = data['status'];
    RoutineStatus? status;
    if (statusName is String) {
      for (final candidate in _durableOccurrenceStatuses) {
        if (candidate.name == statusName) {
          status = candidate;
          break;
        }
      }
    }
    if (status == null) {
      throw const FormatException('Invalid Routine occurrence status.');
    }
    final record = RoutineOccurrenceRecord(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      routineItemId: data['routineItemId'] as String? ?? '',
      occurrenceDateKey: data['occurrenceDateKey'] as String? ?? '',
      status: status,
      source: data['source'] as String? ?? '',
      action: data['action'] as String? ?? '',
      operationKey: data['operationKey'] as String? ?? '',
      movedToDateKey: data['movedToDateKey'] as String?,
      movedStartMinute: (data['movedStartMinute'] as num?)?.toInt(),
      movedEndMinute: (data['movedEndMinute'] as num?)?.toInt(),
      completedSubtaskIndexes:
          (data['completedSubtaskIndexes'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList(growable: false) ??
          const [],
      note: data['note'] as String?,
      displayTitleOverride: data['displayTitleOverride'] as String?,
      undoToPlannedAllowed: data['undoToPlannedAllowed'] as bool? ?? false,
      onboardingProjectionId: data['onboardingProjectionId'] as String?,
      onboardingSourceItemId: data['onboardingSourceItemId'] as String?,
      sourceFingerprint: data['sourceFingerprint'] as String?,
      createdAt:
          readRoutineDateTime(data['createdAt']) ??
          (throw const FormatException(
            'Routine occurrence createdAt is required.',
          )),
      updatedAt:
          readRoutineDateTime(data['updatedAt']) ??
          (throw const FormatException(
            'Routine occurrence updatedAt is required.',
          )),
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 0,
    );
    toFirestore(record);
    return record;
  }

  void _validateMove(RoutineOccurrenceRecord record) {
    final hasAnyMove =
        record.movedToDateKey != null ||
        record.movedStartMinute != null ||
        record.movedEndMinute != null;
    if (record.status == RoutineStatus.moved && !hasAnyMove) {
      throw ArgumentError('Moved Routine occurrence requires move fields.');
    }
    if (!hasAnyMove) return;
    if (record.movedToDateKey == null ||
        record.movedStartMinute == null ||
        record.movedEndMinute == null ||
        record.movedStartMinute! < 0 ||
        record.movedStartMinute! > 1439 ||
        record.movedEndMinute! < 1 ||
        record.movedEndMinute! > 1440 ||
        record.movedEndMinute! <= record.movedStartMinute!) {
      throw ArgumentError('Invalid Routine occurrence move range.');
    }
  }
}

const _durableOccurrenceStatuses = {
  RoutineStatus.active,
  RoutineStatus.inTracker,
  RoutineStatus.completed,
  RoutineStatus.skipped,
  RoutineStatus.missed,
  RoutineStatus.moved,
};

const _occurrenceSources = {
  'routine',
  'tracker',
  'checkIn',
  'money',
  'system',
  'onboarding',
};

const _occurrenceActions = {
  'start',
  'startTracker',
  'complete',
  'skip',
  'miss',
  'move',
  'reschedule',
  'checkIn',
  'toggleSubtask',
  'makeTiny',
  'project',
  'repair',
};

String stableRoutineOccurrenceId({
  required String ownerUid,
  required String routineItemId,
  required String occurrenceDateKey,
}) {
  validateOwnerUid(ownerUid);
  validateDocumentId(routineItemId);
  parseRoutineLocalDateKey(occurrenceDateKey);
  final digest = sha256.convert(
    utf8.encode(
      'routine-occurrence-v1\u001f$ownerUid\u001f'
      '$routineItemId\u001f$occurrenceDateKey',
    ),
  );
  return 'occ_${digest.toString().substring(0, 40)}';
}

abstract class RoutineHistoryRepository {
  Future<List<RoutineOccurrenceRecord>> fetchHistory(String uid);

  Future<void> appendHistory(String uid, RoutineOccurrenceRecord record);
  Future<void> deleteHistory(String uid, String occurrenceId);
}

class FakeRoutineHistoryRepository implements RoutineHistoryRepository {
  final Map<String, Map<String, RoutineOccurrenceRecord>> _history = {};

  @override
  Future<List<RoutineOccurrenceRecord>> fetchHistory(String uid) async {
    validateOwnerUid(uid);
    final records =
        _history[uid]?.values.toList() ?? <RoutineOccurrenceRecord>[];
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<RoutineOccurrenceRecord>.unmodifiable(records);
  }

  @override
  Future<void> appendHistory(String uid, RoutineOccurrenceRecord record) async {
    const codec = RoutineOccurrenceFirestoreCodec();
    if (record.ownerUid != uid) {
      throw ArgumentError('Routine occurrence owner mismatch.');
    }
    final existing = _history[uid]?[record.id];
    if (existing?.operationKey == record.operationKey) {
      return;
    }
    codec.toFirestore(record);
    _history.putIfAbsent(uid, () => {})[record.id] = record;
  }

  @override
  Future<void> deleteHistory(String uid, String occurrenceId) async {
    validateOwnerUid(uid);
    validateDocumentId(occurrenceId);
    _history[uid]?.remove(occurrenceId);
  }
}

class FirestoreRoutineHistoryRepository implements RoutineHistoryRepository {
  final FirebaseFirestore? _injectedFirestore;
  final RoutineOccurrenceFirestoreCodec _codec;

  FirestoreRoutineHistoryRepository({
    FirebaseFirestore? firestore,
    RoutineOccurrenceFirestoreCodec codec =
        const RoutineOccurrenceFirestoreCodec(),
  }) : _injectedFirestore = firestore,
       _codec = codec;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<List<RoutineOccurrenceRecord>> fetchHistory(String uid) async {
    validateOwnerUid(uid);
    final snapshot = await _firestore
        .collection(FirestoreUserPaths.routineHistory(uid))
        .get();
    final records = snapshot.docs
        .map(
          (doc) => _codec.fromFirestore(documentId: doc.id, data: doc.data()),
        )
        .toList(growable: false);
    return [...records]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> appendHistory(String uid, RoutineOccurrenceRecord record) async {
    if (record.ownerUid != uid) {
      throw ArgumentError('Routine occurrence owner mismatch.');
    }
    final reference = _firestore.doc(
      FirestoreUserPaths.routineHistoryEvent(uid, record.id),
    );
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists &&
          existing.data()?['operationKey'] == record.operationKey) {
        return;
      }
      final data = _codec.toFirestore(record);
      data['createdAt'] = existing.exists
          ? existing.data()!['createdAt']
          : FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      transaction.set(reference, data);
    });
  }

  @override
  Future<void> deleteHistory(String uid, String occurrenceId) async {
    validateOwnerUid(uid);
    validateDocumentId(occurrenceId);
    final reference = _firestore.doc(
      FirestoreUserPaths.routineHistoryEvent(uid, occurrenceId),
    );
    await reference.delete();
  }
}

final routineHistoryRepositoryProvider = Provider<RoutineHistoryRepository>((
  ref,
) {
  if (ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase) {
    return FirestoreRoutineHistoryRepository();
  }
  return FakeRoutineHistoryRepository();
});
