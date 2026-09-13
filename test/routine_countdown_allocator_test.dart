import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/services/routine_countdown_allocator.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

void main() {
  RoutineItem item({
    int startMinute = 8 * 60,
    int endMinute = 10 * 60,
    bool overnight = false,
  }) {
    return RoutineItem(
      id: 'task',
      userId: 'user_1',
      title: 'Task',
      startMinute: startMinute,
      endMinute: endMinute,
      crossesMidnight: overnight,
      endsNextDay: overnight,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      blockType: RoutineBlockType.flexibleTask,
    );
  }

  int durationFor(DateTime actualStart) {
    return RoutineCountdownAllocator.allocate(
      template: item(),
      occurrenceDateKey: '2026-09-16',
      actualStart: actualStart,
    )!.durationSeconds;
  }

  test('allocates scheduled remaining duration for same-day task', () {
    expect(durationFor(DateTime(2026, 9, 16, 7, 30)), 7200);
    expect(durationFor(DateTime(2026, 9, 16, 8)), 7200);
    expect(durationFor(DateTime(2026, 9, 16, 9)), 3600);
    expect(durationFor(DateTime(2026, 9, 16, 9, 59)), 60);
    expect(durationFor(DateTime(2026, 9, 16, 10)), 7200);
    expect(durationFor(DateTime(2026, 9, 16, 11)), 7200);
  });

  test('allocates overnight task across the next day', () {
    final allocation = RoutineCountdownAllocator.allocate(
      template: item(startMinute: 23 * 60, endMinute: 7 * 60, overnight: true),
      occurrenceDateKey: '2026-09-16',
      actualStart: DateTime(2026, 9, 17, 1),
    );

    expect(allocation!.durationSeconds, 6 * 60 * 60);
  });

  test('moved occurrence uses moved date and moved start/end', () {
    final existing = RoutineOccurrenceRecord(
      id: 'occurrence',
      ownerUid: 'user_1',
      routineItemId: 'task',
      occurrenceDateKey: '2026-09-16',
      status: RoutineStatus.moved,
      source: 'routine',
      action: 'move',
      operationKey: 'move',
      movedToDateKey: '2026-09-18',
      movedStartMinute: 12 * 60,
      movedEndMinute: 13 * 60,
      createdAt: DateTime.utc(2026, 9, 16),
      updatedAt: DateTime.utc(2026, 9, 16),
    );

    final allocation = RoutineCountdownAllocator.allocate(
      template: item(),
      occurrenceDateKey: '2026-09-16',
      actualStart: DateTime(2026, 9, 18, 12, 30),
      existing: existing,
    );

    expect(allocation!.durationSeconds, 30 * 60);
  });

  test('moved overnight occurrence allocates across its target midnight', () {
    final existing = RoutineOccurrenceRecord(
      id: 'overnight-occurrence',
      ownerUid: 'user_1',
      routineItemId: 'task',
      occurrenceDateKey: '2026-09-16',
      status: RoutineStatus.moved,
      source: 'routine',
      action: 'reschedule',
      operationKey: 'move-overnight',
      movedToDateKey: '2026-09-20',
      movedStartMinute: 23 * 60,
      movedEndMinute: 6 * 60 + 30,
      createdAt: DateTime.utc(2026, 9, 16),
      updatedAt: DateTime.utc(2026, 9, 16),
    );

    final allocation = RoutineCountdownAllocator.allocate(
      template: item(),
      occurrenceDateKey: '2026-09-16',
      actualStart: DateTime(2026, 9, 21, 1),
      existing: existing,
    );

    expect(allocation!.durationSeconds, 5 * 60 * 60 + 30 * 60);
  });

  test('unversioned legacy occurrence maps to schema v1', () {
    final record = RoutineOccurrenceRecord.fromMap({
      'id': 'occurrence',
      'ownerUid': 'user_1',
      'routineItemId': 'task',
      'occurrenceDateKey': '2026-09-16',
      'status': 'active',
      'source': 'routine',
      'action': 'start',
      'operationKey': 'op',
      'createdAt': DateTime.utc(2026, 9, 16),
      'updatedAt': DateTime.utc(2026, 9, 16),
    });

    expect(record.schemaVersion, 1);
  });
}
