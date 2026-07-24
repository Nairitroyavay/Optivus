import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';

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
  });

  Stream<List<RoutineEventRecord>> watchEvents(String uid);
}

class FirestoreRoutineTransactionRepository
    implements RoutineTransactionRepository {
  final FirebaseFirestore? _injectedFirestore;
  final RoutineTemplateFirestoreCodec _itemCodec;
  final RoutineOccurrenceFirestoreCodec _occurrenceCodec;

  FirestoreRoutineTransactionRepository({
    FirebaseFirestore? firestore,
    RoutineTemplateFirestoreCodec itemCodec =
        const RoutineTemplateFirestoreCodec(),
    RoutineOccurrenceFirestoreCodec occurrenceCodec =
        const RoutineOccurrenceFirestoreCodec(),
  }) : _injectedFirestore = firestore,
       _itemCodec = itemCodec,
       _occurrenceCodec = occurrenceCodec;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

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
  }) async {
    await _firestore.runTransaction((transaction) async {
      final eventsToWrite = [?addEvent, ...?addEvents];

      // Idempotency: verify ALL events exist with matching operation keys.
      if (eventsToWrite.isNotEmpty) {
        bool allEventsExist = true;
        for (final event in eventsToWrite) {
          final eventDocRef = _firestore.doc(
            FirestoreUserPaths.routineEvent(uid, event.eventId),
          );
          final eventDoc = await transaction.get(eventDocRef);
          if (!eventDoc.exists) {
            allEventsExist = false;
            break;
          }
          // Verify the existing event matches our operation
          final existingData = eventDoc.data();
          if (existingData != null &&
              existingData['operationKey'] != event.operationKey) {
            throw StateError(
              'Event ${event.eventId} exists with a different operation key. '
              'Expected ${event.operationKey}, found ${existingData['operationKey']}.',
            );
          }
        }
        if (allEventsExist) {
          // All events already processed with matching operation keys — truly idempotent.
          return;
        }
      }

      final itemsToWrite = [?setItem, ...?setItems];

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

      for (final event in eventsToWrite) {
        final eventDocRef = _firestore.doc(
          FirestoreUserPaths.routineEvent(uid, event.eventId),
        );
        final eventData = RoutineEventFirestoreCodec.toFirestore(event);
        transaction.set(eventDocRef, eventData);
      }
    });
  }

  @override
  Stream<List<RoutineEventRecord>> watchEvents(String uid) {
    return _firestore
        .collection(FirestoreUserPaths.routineEvents(uid))
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => RoutineEventFirestoreCodec.fromFirestore(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }
}

class FakeRoutineTransactionRepository implements RoutineTransactionRepository {
  final RoutineRepository? _routineRepository;
  final RoutineHistoryRepository? _historyRepository;
  final Map<String, List<RoutineEventRecord>> _events = {};
  final Map<String, StreamController<List<RoutineEventRecord>>> _controllers =
      {};
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
  }) async {
    final completer = Completer<void>();
    final previousMutex = _mutex;
    _mutex = completer.future;

    try {
      await previousMutex;

      final itemsToWrite = [?setItem, ...?setItems];
      final eventsToWrite = [?addEvent, ...?addEvents];

      await onBeforeMutation?.call();

      final futures = <Future<void>>[];

      for (final item in itemsToWrite) {
        if (_routineRepository != null) {
          futures.add(
            _routineRepository.updateRoutineItem(uid, item).catchError((
              Object e,
            ) async {
              if (e.toString().contains('Routine item does not exist.')) {
                return await _routineRepository.createRoutineItem(uid, item);
              } else {
                throw e;
              }
            }),
          );
        }
      }

      if (deleteItemId != null && _routineRepository != null) {
        futures.add(_routineRepository.deleteRoutineItem(uid, deleteItemId));
      }

      if (setOccurrence != null && _historyRepository != null) {
        futures.add(_historyRepository.appendHistory(uid, setOccurrence));
      }

      if (deleteOccurrenceId != null && _historyRepository != null) {
        futures.add(_historyRepository.deleteHistory(uid, deleteOccurrenceId));
      }

      // Execute all underlying writes FIRST.
      await Future.wait(futures);
      await onAfterMutation?.call();

      // Publish events only AFTER writes succeed.
      if (eventsToWrite.isNotEmpty) {
        final list = List<RoutineEventRecord>.from(_events[uid] ?? []);
        bool changed = false;
        for (final event in eventsToWrite) {
          if (!list.any((e) => e.eventId == event.eventId)) {
            list.insert(0, event);
            changed = true;
          }
        }
        if (changed) {
          _events[uid] = list;
          _controllers[uid]?.add(list);
        }
      }
      await onAfterEvents?.call();
    } finally {
      completer.complete();
    }
  }

  @override
  Stream<List<RoutineEventRecord>> watchEvents(String uid) {
    if (!_controllers.containsKey(uid)) {
      _controllers[uid] =
          StreamController<List<RoutineEventRecord>>.broadcast();
    }
    // Yield the initial value immediately when listening
    Future.microtask(() {
      if (_controllers[uid] != null && _controllers[uid]!.hasListener) {
        _controllers[uid]!.add(_events[uid] ?? []);
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
