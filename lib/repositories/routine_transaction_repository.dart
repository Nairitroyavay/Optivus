import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';

class RoutineCorruptEvent {
  final String eventId;
  final Object error;

  RoutineCorruptEvent(this.eventId, this.error);
}

class RoutineEventFeed {
  final List<RoutineEventRecord> validEvents;
  final List<RoutineCorruptEvent> corruptEvents;

  RoutineEventFeed({required this.validEvents, this.corruptEvents = const []});
}

abstract class RoutineTransactionRepository {
  Future<void> commitWrite({
    required String uid,
    RoutineItem? setItem,
    List<RoutineItem>? setItems,
    String? deleteItemId,
    RoutineOccurrenceRecord? setOccurrence,
    String? deleteOccurrenceId,
    RoutineEventRecord? addEvent,
    List<RoutineEventRecord>? addEvents,
    List<ConflictAcceptance>? setConflictAcceptances,
  });

  Future<void> commitProjectionEventBatch({
    required String uid,
    required RoutineProjectionReceipt fromReceipt,
    required RoutineProjectionReceipt toReceipt,
    required List<RoutineEventRecord> addEvents,
  });

  Stream<RoutineEventFeed> watchEvents(String uid);
}

class FirestoreRoutineTransactionRepository
    implements RoutineTransactionRepository {
  final FirebaseFirestore? _injectedFirestore;
  final RoutineTemplateFirestoreCodec _itemCodec;
  final RoutineOccurrenceFirestoreCodec _occurrenceCodec;
  final RoutineProjectionReceiptFirestoreCodec _receiptCodec;

  FirestoreRoutineTransactionRepository({
    FirebaseFirestore? firestore,
    RoutineTemplateFirestoreCodec itemCodec =
        const RoutineTemplateFirestoreCodec(),
    RoutineOccurrenceFirestoreCodec occurrenceCodec =
        const RoutineOccurrenceFirestoreCodec(),
    RoutineProjectionReceiptFirestoreCodec receiptCodec =
        const RoutineProjectionReceiptFirestoreCodec(),
  }) : _injectedFirestore = firestore,
       _itemCodec = itemCodec,
       _occurrenceCodec = occurrenceCodec,
       _receiptCodec = receiptCodec;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  bool _isDeepEqual(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!_isDeepEqual(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_isDeepEqual(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Timestamp && b is Timestamp) {
      return a.microsecondsSinceEpoch == b.microsecondsSinceEpoch;
    }
    return a == b;
  }

  @override
  Future<void> commitWrite({
    required String uid,
    RoutineItem? setItem,
    List<RoutineItem>? setItems,
    String? deleteItemId,
    RoutineOccurrenceRecord? setOccurrence,
    String? deleteOccurrenceId,
    RoutineEventRecord? addEvent,
    List<RoutineEventRecord>? addEvents,
    List<ConflictAcceptance>? setConflictAcceptances,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final eventsToWrite = [?addEvent, ...?addEvents];
      final missingEvents = <RoutineEventRecord>[];

      // Idempotency: verify ALL events exist with matching content.
      if (eventsToWrite.isNotEmpty) {
        for (final event in eventsToWrite) {
          final eventDocRef = _firestore.doc(
            FirestoreUserPaths.routineEvent(uid, event.eventId),
          );
          final eventDoc = await transaction.get(eventDocRef);
          if (!eventDoc.exists) {
            missingEvents.add(event);
          } else {
            final existingData = eventDoc.data();
            final incomingData = RoutineEventFirestoreCodec.toFirestore(event);
            if (!_isDeepEqual(existingData, incomingData)) {
              throw StateError(
                'Event ${event.eventId} exists with different content.',
              );
            }
          }
        }
      }

      final itemsToWrite = [?setItem, ...?setItems];

      for (final acceptance in setConflictAcceptances ?? const []) {
        if (acceptance.ownerUid != uid || acceptance.acceptanceId.isEmpty) {
          throw ArgumentError('Conflict acceptance owner or ID is invalid.');
        }
        final docRef = _firestore.doc(
          FirestoreUserPaths.conflictAcceptance(uid, acceptance.acceptanceId),
        );
        transaction.set(docRef, acceptance.toFirestoreMap());
      }

      for (final item in itemsToWrite) {
        final docRef = _firestore.doc(
          FirestoreUserPaths.routineItem(uid, item.id),
        );
        final data = _itemCodec.toFirestore(
          ownerUid: uid,
          item: item.copyWith(userId: uid),
        );
        data['updatedAt'] = FieldValue.serverTimestamp();
        transaction.set(docRef, data);
      }

      if (deleteItemId != null) {
        final docRef = _firestore.doc(
          FirestoreUserPaths.routineItem(uid, deleteItemId),
        );
        transaction.delete(docRef);
      }

      if (setOccurrence != null) {
        final docRef = _firestore.doc(
          FirestoreUserPaths.routineHistoryEvent(uid, setOccurrence.id),
        );
        final data = _occurrenceCodec.toFirestore(setOccurrence);
        transaction.set(docRef, data);
      }

      if (deleteOccurrenceId != null) {
        final docRef = _firestore.doc(
          FirestoreUserPaths.routineHistoryEvent(uid, deleteOccurrenceId),
        );
        transaction.delete(docRef);
      }

      for (final event in missingEvents) {
        final eventDocRef = _firestore.doc(
          FirestoreUserPaths.routineEvent(uid, event.eventId),
        );
        final eventData = RoutineEventFirestoreCodec.toFirestore(event);
        transaction.set(eventDocRef, eventData);
      }
    });
  }

  @override
  Future<void> commitProjectionEventBatch({
    required String uid,
    required RoutineProjectionReceipt fromReceipt,
    required RoutineProjectionReceipt toReceipt,
    required List<RoutineEventRecord> addEvents,
  }) async {
    validateOwnerUid(uid);
    _receiptCodec.toFirestore(fromReceipt);
    _receiptCodec.toFirestore(toReceipt);
    if (fromReceipt.ownerUid != uid ||
        toReceipt.ownerUid != uid ||
        fromReceipt.id != toReceipt.id ||
        fromReceipt.sourceBundleFingerprint !=
            toReceipt.sourceBundleFingerprint ||
        fromReceipt.projectedItemIds.join('\u001f') !=
            toReceipt.projectedItemIds.join('\u001f') ||
        fromReceipt.cursor > toReceipt.cursor) {
      throw StateError('Invalid Routine projection receipt transition.');
    }

    await _firestore.runTransaction((transaction) async {
      final receiptRef = _firestore.doc(
        FirestoreUserPaths.routineProjection(uid, fromReceipt.id),
      );
      final receiptSnapshot = await transaction.get(receiptRef);
      if (!receiptSnapshot.exists || receiptSnapshot.data() == null) {
        throw StateError('Routine projection receipt is missing.');
      }
      final currentReceipt = _receiptCodec.fromFirestore(
        documentId: receiptSnapshot.id,
        data: receiptSnapshot.data()!,
      );
      final currentCursor = currentReceipt.cursor;
      final targetAlreadyReached =
          currentReceipt.status == toReceipt.status &&
          currentReceipt.cursor == toReceipt.cursor;
      final canAdvance =
          currentReceipt.status == 'pending' &&
          currentReceipt.cursor == fromReceipt.cursor &&
          currentReceipt.sourceBundleFingerprint ==
              fromReceipt.sourceBundleFingerprint &&
          currentReceipt.projectedItemIds.join('\u001f') ==
              fromReceipt.projectedItemIds.join('\u001f');
      if (!targetAlreadyReached && !canAdvance) {
        throw StateError(
          'Routine projection receipt changed before event batch commit '
          '(cursor $currentCursor).',
        );
      }

      final missingEvents = <RoutineEventRecord>[];
      for (final event in addEvents) {
        final eventRef = _firestore.doc(
          FirestoreUserPaths.routineEvent(uid, event.eventId),
        );
        final eventSnapshot = await transaction.get(eventRef);
        final incomingData = RoutineEventFirestoreCodec.toFirestore(event);
        if (!eventSnapshot.exists) {
          missingEvents.add(event);
          continue;
        }
        if (!_isDeepEqual(eventSnapshot.data(), incomingData)) {
          throw StateError(
            'Event ${event.eventId} exists with different content.',
          );
        }
      }

      for (final event in missingEvents) {
        final eventRef = _firestore.doc(
          FirestoreUserPaths.routineEvent(uid, event.eventId),
        );
        transaction.set(
          eventRef,
          RoutineEventFirestoreCodec.toFirestore(event),
        );
      }

      if (!targetAlreadyReached) {
        final receiptData = _receiptCodec.toFirestore(toReceipt);
        receiptData['createdAt'] = receiptSnapshot.data()!['createdAt'];
        receiptData['updatedAt'] = FieldValue.serverTimestamp();
        if (toReceipt.status == 'completed') {
          receiptData['completedAt'] = FieldValue.serverTimestamp();
        }
        transaction.set(receiptRef, receiptData);
      }
    });
  }

  @override
  Stream<RoutineEventFeed> watchEvents(String uid) {
    return _firestore
        .collection(FirestoreUserPaths.routineEvents(uid))
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final validEvents = <RoutineEventRecord>[];
          final corruptEvents = <RoutineCorruptEvent>[];
          for (final doc in snapshot.docs) {
            try {
              validEvents.add(
                RoutineEventFirestoreCodec.fromFirestore(doc.id, doc.data()),
              );
            } catch (e) {
              corruptEvents.add(RoutineCorruptEvent(doc.id, e));
            }
          }
          return RoutineEventFeed(
            validEvents: validEvents,
            corruptEvents: corruptEvents,
          );
        });
  }
}

class FakeRoutineTransactionRepository implements RoutineTransactionRepository {
  final RoutineRepository? _routineRepository;
  final RoutineHistoryRepository? _historyRepository;
  final Map<String, List<RoutineEventRecord>> _events = {};
  final Map<String, StreamController<RoutineEventFeed>> _controllers = {};
  Future<void> _mutex = Future.value();

  /// Test hook: if set, called before mutations. Throw to simulate pre-mutation failure.
  Future<void> Function()? onBeforeMutation;

  /// Test hook: if set, called after mutations but before events. Throw to simulate partial failure.
  Future<void> Function()? onAfterMutation;

  /// Test hook: if set, called after events. Throw to simulate post-commit failure.
  Future<void> Function()? onAfterEvents;

  FakeRoutineTransactionRepository({
    RoutineRepository? routineRepository,
    RoutineHistoryRepository? historyRepository,
  }) : _routineRepository = routineRepository,
       _historyRepository = historyRepository;

  bool _deepEqual(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!_deepEqual(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var index = 0; index < a.length; index++) {
        if (!_deepEqual(a[index], b[index])) return false;
      }
      return true;
    }
    if (a is Timestamp && b is Timestamp) {
      return a.microsecondsSinceEpoch == b.microsecondsSinceEpoch;
    }
    return a == b;
  }

  bool _eventsEqual(RoutineEventRecord a, RoutineEventRecord b) {
    return _deepEqual(
      RoutineEventFirestoreCodec.toFirestore(a),
      RoutineEventFirestoreCodec.toFirestore(b),
    );
  }

  void _publishEvents(String uid, List<RoutineEventRecord> list) {
    _events[uid] = list;
    _controllers[uid]?.add(RoutineEventFeed(validEvents: list));
  }

  @override
  Future<void> commitWrite({
    required String uid,
    RoutineItem? setItem,
    List<RoutineItem>? setItems,
    String? deleteItemId,
    RoutineOccurrenceRecord? setOccurrence,
    String? deleteOccurrenceId,
    RoutineEventRecord? addEvent,
    List<RoutineEventRecord>? addEvents,
    List<ConflictAcceptance>? setConflictAcceptances,
  }) async {
    final completer = Completer<void>();
    final previousMutex = _mutex;
    _mutex = completer.future;

    try {
      await previousMutex;

      final itemsToWrite = [?setItem, ...?setItems];
      final eventsToWrite = [?addEvent, ...?addEvents];

      final initialItems = _routineRepository != null
          ? await _routineRepository.fetchRoutineItems(uid)
          : <RoutineItem>[];
      final initialOccurrences = _historyRepository != null
          ? await _historyRepository.fetchHistory(uid)
          : <RoutineOccurrenceRecord>[];
      final initialEvents = List<RoutineEventRecord>.from(_events[uid] ?? []);
      final fakeDatabase = _routineRepository is FakeRoutineRepository
          ? (_routineRepository).database
          : null;
      final initialAcceptances = Map<String, ConflictAcceptance>.from(
        fakeDatabase?.acceptancesByUid[uid] ?? const {},
      );

      try {
        await onBeforeMutation?.call();

        final futures = <Future<void>>[];

        for (final item in itemsToWrite) {
          final routineRepository = _routineRepository;
          if (routineRepository != null) {
            futures.add(
              routineRepository.updateRoutineItem(uid, item).catchError((
                Object e,
              ) async {
                if (e.toString().contains('Routine item does not exist.')) {
                  return await routineRepository.createRoutineItem(uid, item);
                } else {
                  throw e;
                }
              }),
            );
          }
        }

        final routineRepository = _routineRepository;
        if (deleteItemId != null && routineRepository != null) {
          futures.add(routineRepository.deleteRoutineItem(uid, deleteItemId));
        }

        final historyRepository = _historyRepository;
        if (setOccurrence != null && historyRepository != null) {
          futures.add(historyRepository.appendHistory(uid, setOccurrence));
        }

        if (deleteOccurrenceId != null && historyRepository != null) {
          futures.add(historyRepository.deleteHistory(uid, deleteOccurrenceId));
        }

        // Execute all underlying writes FIRST.
        await Future.wait(futures);
        if (fakeDatabase != null) {
          final ownerAcceptances = fakeDatabase.acceptancesByUid.putIfAbsent(
            uid,
            () => {},
          );
          for (final acceptance in setConflictAcceptances ?? const []) {
            if (acceptance.ownerUid != uid || acceptance.acceptanceId.isEmpty) {
              throw ArgumentError(
                'Conflict acceptance owner or ID is invalid.',
              );
            }
            ownerAcceptances[acceptance.acceptanceId] = acceptance;
          }
        }
        await onAfterMutation?.call();

        // Publish events only AFTER writes succeed.
        if (eventsToWrite.isNotEmpty) {
          final list = List<RoutineEventRecord>.from(_events[uid] ?? []);
          bool changed = false;
          for (final event in eventsToWrite) {
            final existing = list
                .where((candidate) => candidate.eventId == event.eventId)
                .firstOrNull;
            if (existing == null) {
              list.insert(0, event);
              changed = true;
            } else if (!_eventsEqual(existing, event)) {
              throw StateError(
                'Event ${event.eventId} exists with different content.',
              );
            }
          }
          await onAfterEvents?.call();
          if (changed) {
            _publishEvents(uid, list);
          }
        } else {
          await onAfterEvents?.call();
        }
      } catch (error) {
        if (!error.toString().contains('_SKIP_ROLLBACK')) {
          // Rollback items
          if (_routineRepository is FakeRoutineRepository) {
            final repo = _routineRepository;
            repo.database.itemsByUid[uid] = {
              for (final item in initialItems) item.id: item,
            };
          }
          if (fakeDatabase != null) {
            fakeDatabase.acceptancesByUid[uid] = initialAcceptances;
          }

          // Rollback occurrences
          final historyRepository = _historyRepository;
          if (historyRepository != null) {
            if (setOccurrence != null) {
              final old = initialOccurrences
                  .where((o) => o.id == setOccurrence.id)
                  .firstOrNull;
              if (old != null) {
                await historyRepository.appendHistory(uid, old);
              } else {
                await historyRepository.deleteHistory(uid, setOccurrence.id);
              }
            }
            if (deleteOccurrenceId != null) {
              final old = initialOccurrences
                  .where((o) => o.id == deleteOccurrenceId)
                  .firstOrNull;
              if (old != null) {
                await historyRepository.appendHistory(uid, old);
              }
            }
          }

          // Rollback events
          _publishEvents(uid, initialEvents);
        }

        rethrow;
      }
    } finally {
      completer.complete();
    }
  }

  @override
  Future<void> commitProjectionEventBatch({
    required String uid,
    required RoutineProjectionReceipt fromReceipt,
    required RoutineProjectionReceipt toReceipt,
    required List<RoutineEventRecord> addEvents,
  }) async {
    final completer = Completer<void>();
    final previousMutex = _mutex;
    _mutex = completer.future;

    try {
      await previousMutex;
      validateOwnerUid(uid);
      const receiptCodec = RoutineProjectionReceiptFirestoreCodec();
      receiptCodec.toFirestore(fromReceipt);
      receiptCodec.toFirestore(toReceipt);
      final routineRepository = _routineRepository;
      if (routineRepository is! FakeRoutineRepository) {
        throw StateError('Fake Routine database is required for projection.');
      }

      final initialEvents = List<RoutineEventRecord>.from(_events[uid] ?? []);
      final initialReceipts = Map<String, RoutineProjectionReceipt>.from(
        routineRepository.database.receiptsByUid[uid] ?? const {},
      );

      try {
        await onBeforeMutation?.call();

        final receipts = routineRepository.database.receiptsByUid.putIfAbsent(
          uid,
          () => {},
        );
        final current = receipts.putIfAbsent(fromReceipt.id, () => fromReceipt);
        final targetAlreadyReached =
            current.status == toReceipt.status &&
            current.cursor == toReceipt.cursor;
        final canAdvance =
            current.status == 'pending' &&
            current.cursor == fromReceipt.cursor &&
            current.sourceBundleFingerprint ==
                fromReceipt.sourceBundleFingerprint &&
            current.projectedItemIds.join('\u001f') ==
                fromReceipt.projectedItemIds.join('\u001f');
        if (!targetAlreadyReached && !canAdvance) {
          throw StateError('Routine projection receipt changed before retry.');
        }

        final list = List<RoutineEventRecord>.from(_events[uid] ?? []);
        var changed = false;
        for (final event in addEvents) {
          final existing = list
              .where((candidate) => candidate.eventId == event.eventId)
              .firstOrNull;
          if (existing == null) {
            list.insert(0, event);
            changed = true;
          } else if (!_eventsEqual(existing, event)) {
            throw StateError(
              'Event ${event.eventId} exists with different content.',
            );
          }
        }

        await onAfterMutation?.call();
        receipts[toReceipt.id] = toReceipt;
        await onAfterEvents?.call();
        if (changed) {
          list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
          _publishEvents(uid, list);
        }
      } catch (error) {
        if (!error.toString().contains('_SKIP_ROLLBACK')) {
          routineRepository.database.receiptsByUid[uid] = initialReceipts;
          _publishEvents(uid, initialEvents);
        }
        rethrow;
      }
    } finally {
      completer.complete();
    }
  }

  @override
  Stream<RoutineEventFeed> watchEvents(String uid) {
    if (!_controllers.containsKey(uid)) {
      _controllers[uid] = StreamController<RoutineEventFeed>.broadcast();
    }
    // Yield the initial value immediately when listening
    Future.microtask(() {
      if (_controllers[uid] != null && _controllers[uid]!.hasListener) {
        _controllers[uid]!.add(
          RoutineEventFeed(validEvents: _events[uid] ?? []),
        );
      }
    });
    return _controllers[uid]!.stream;
  }
}

final routineTransactionRepositoryProvider =
    Provider<RoutineTransactionRepository>((ref) {
      if (ref.watch(optivusBackendModeProvider) ==
          OptivusBackendMode.firebase) {
        return FirestoreRoutineTransactionRepository();
      }
      return FakeRoutineTransactionRepository(
        routineRepository: ref.watch(routineRepositoryProvider),
        historyRepository: ref.watch(routineHistoryRepositoryProvider),
      );
    });
