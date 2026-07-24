import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/routine_event_record.dart';

void main() {
  group('RoutineEventFirestoreCodec', () {
    final now = DateTime.utc(2025, 1, 6, 12);
    final event = RoutineEventRecord(
      eventId: 'evt_1',
      ownerUid: 'user_1',
      routineItemId: 'item_1',
      occurrenceId: 'occ_1',
      occurrenceDateKey: '2025-01-06',
      eventType: RoutineEventType.completed,
      operationKey: 'op_1',
      source: 'manual',
      occurredAt: now,
      itemSnapshot: _snapshot(),
    );

    test('toFirestore returns correct map', () {
      final data = RoutineEventFirestoreCodec.toFirestore(event);
      expect(data['schemaVersion'], 1);
      expect(data['eventId'], 'evt_1');
      expect(data['ownerUid'], 'user_1');
      expect(data['routineItemId'], 'item_1');
      expect(data['occurrenceId'], 'occ_1');
      expect(data['occurrenceDateKey'], '2025-01-06');
      expect(data['eventType'], 'completed');
      expect(data['operationKey'], 'op_1');
      expect(data['source'], 'manual');
      expect(data['itemSnapshot'], _snapshot());
      expect(data['occurredAt'], isA<Timestamp>());
    });

    test('fromFirestore parses data correctly', () {
      final docData = <String, dynamic>{
        'schemaVersion': 1,
        'ownerUid': 'user_1',
        'routineItemId': 'item_1',
        'occurrenceId': 'occ_1',
        'occurrenceDateKey': '2025-01-06',
        'eventType': 'completed',
        'operationKey': 'op_1',
        'source': 'manual',
        'eventId': 'evt_1',
        'occurredAt': Timestamp.fromDate(now),
        'itemSnapshot': _snapshot(),
      };

      final parsed = RoutineEventFirestoreCodec.fromFirestore('evt_1', docData);

      expect(parsed.eventId, 'evt_1');
      expect(parsed.ownerUid, 'user_1');
      expect(parsed.routineItemId, 'item_1');
      expect(parsed.occurrenceId, 'occ_1');
      expect(parsed.occurrenceDateKey, '2025-01-06');
      expect(parsed.eventType, RoutineEventType.completed);
      expect(parsed.operationKey, 'op_1');
      expect(parsed.source, 'manual');
      expect(parsed.occurredAt, now);
      expect(parsed.itemSnapshot, _snapshot());
    });

    test('rejects missing and malformed required snapshot fields', () {
      for (final field in [
        'id',
        'title',
        'startMinute',
        'durationMinutes',
        'blockType',
        'trackerTaskType',
        'hardBlock',
      ]) {
        final snapshot = Map<String, dynamic>.from(_snapshot())..remove(field);
        expect(
          () => RoutineEventFirestoreCodec.toFirestore(
            event.copyWith(itemSnapshot: snapshot),
          ),
          throwsFormatException,
          reason: 'missing $field should be corrupt',
        );
      }

      for (final snapshot in [
        {..._snapshot(), 'id': 'other-item'},
        {..._snapshot(), 'title': ''},
        {..._snapshot(), 'startMinute': 1440},
        {..._snapshot(), 'durationMinutes': 0},
        {..._snapshot(), 'blockType': 'unknown'},
        {..._snapshot(), 'trackerTaskType': 'unknown'},
        {..._snapshot(), 'hardBlock': 'false'},
        {..._snapshot(), 'extra': true},
      ]) {
        expect(
          () => RoutineEventFirestoreCodec.toFirestore(
            event.copyWith(itemSnapshot: snapshot),
          ),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, dynamic> _snapshot() {
  return {
    'id': 'item_1',
    'title': 'Test Item',
    'startMinute': 600,
    'durationMinutes': 60,
    'blockType': 'flexibleTask',
    'trackerTaskType': 'none',
    'hardBlock': false,
  };
}
