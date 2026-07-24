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
      itemSnapshot: {'id': 'item_1', 'title': 'Test Item'},
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
      expect(data['itemSnapshot'], {'id': 'item_1', 'title': 'Test Item'});
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
        'itemSnapshot': {'id': 'item_1', 'title': 'Test Item'},
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
      expect(parsed.itemSnapshot, {'id': 'item_1', 'title': 'Test Item'});
    });
  });
}
