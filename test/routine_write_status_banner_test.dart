import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/routine_write_status_banner.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

const _ownerUid = 'local-development-user';

class _SeededRoutineNotifier extends RoutineNotifier {
  _SeededRoutineNotifier(Ref ref)
    : super(
        FakeRoutineRepository(),
        FakeRoutineHistoryRepository(),
        FakeRoutineTransactionRepository(),
        ref,
      );

  void seed(RoutineState value) {
    state = value;
  }
}

void main() {
  testWidgets('shows and locally dismisses failed template intent', (
    tester,
  ) async {
    final item = _item('routine-a', 'Morning focus');

    await tester.pumpWidget(
      _harness(
        RoutineState(
          items: [item],
          selectedDay: DateTime(2026, 7, 24),
          failedIntentsByItemId: {
            item.id: RoutineWriteIntent(
              action: RoutineWriteAction.create,
              ownerUid: _ownerUid,
              itemId: item.id,
              operationId: 'create-op',
              attemptedItem: item,
              createdAt: DateTime.utc(2026, 7, 24),
              event: _event('create-op', item),
            ),
          },
        ),
      ),
    );

    expect(find.text('Routine item was not saved'), findsOneWidget);
    expect(find.textContaining('Morning focus'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(find.byType(RoutineWriteStatusBanner), findsOneWidget);
    expect(find.text('Routine item was not saved'), findsNothing);
  });

  testWidgets('shows and locally dismisses failed occurrence intent', (
    tester,
  ) async {
    final item = _item('routine-b', 'Hydration');
    final occurrence = _occurrence(item);

    await tester.pumpWidget(
      _harness(
        RoutineState(
          items: [item],
          selectedDay: DateTime(2026, 7, 24),
          failedOccurrenceIntentsById: {
            occurrence.id: RoutineOccurrenceWriteIntent(
              action: RoutineOccurrenceAction.complete,
              ownerUid: _ownerUid,
              occurrenceId: occurrence.id,
              operationId: 'occ-op',
              attemptedRecord: occurrence,
              createdAt: DateTime.utc(2026, 7, 24),
              event: _event(
                'occ-op',
                item,
                eventType: RoutineEventType.completed,
                occurrenceId: occurrence.id,
              ),
            ),
          },
        ),
      ),
    );

    expect(find.text('Routine action was not saved'), findsOneWidget);
    expect(find.textContaining('Hydration'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(find.text('Routine action was not saved'), findsNothing);
  });

  testWidgets('shows and locally dismisses failed batch intent', (
    tester,
  ) async {
    final imported = _item('imported-a', 'Imported class');

    await tester.pumpWidget(
      _harness(
        RoutineState(
          items: const [],
          selectedDay: DateTime(2026, 7, 24),
          failedBatchIntentsByOperationId: {
            'batch-op': RoutineBatchWriteIntent(
              ownerUid: _ownerUid,
              operationId: 'batch-op',
              action: RoutineWriteAction.batchCreate,
              attemptedItems: [imported],
              events: [_event('batch-op', imported)],
              createdAt: DateTime.utc(2026, 7, 24),
            ),
          },
        ),
      ),
    );

    expect(find.text('Routine import batch was not saved'), findsOneWidget);
    expect(find.textContaining('1 imported routine item'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    expect(find.text('Routine import batch was not saved'), findsNothing);
  });
}

Widget _harness(RoutineState state) {
  return ProviderScope(
    overrides: [
      routineNotifierProvider.overrideWith((ref) {
        return _SeededRoutineNotifier(ref)..seed(state);
      }),
    ],
    child: const MaterialApp(home: Scaffold(body: RoutineWriteStatusBanner())),
  );
}

RoutineItem _item(String id, String title) {
  return RoutineItem(
    id: id,
    userId: _ownerUid,
    title: title,
    startMinute: 9 * 60,
    endMinute: 10 * 60,
    repeatDays: const [1],
    blockType: RoutineBlockType.flexibleTask,
  );
}

RoutineOccurrenceRecord _occurrence(RoutineItem item) {
  return RoutineOccurrenceRecord(
    id: 'occ-${item.id}',
    ownerUid: _ownerUid,
    routineItemId: item.id,
    occurrenceDateKey: '2026-07-24',
    status: RoutineStatus.completed,
    source: 'routine',
    action: 'complete',
    operationKey: 'occ-op',
    createdAt: DateTime.utc(2026, 7, 24),
    updatedAt: DateTime.utc(2026, 7, 24),
  );
}

RoutineEventRecord _event(
  String operationId,
  RoutineItem item, {
  RoutineEventType eventType = RoutineEventType.created,
  String? occurrenceId,
}) {
  return RoutineEventRecord(
    eventId: 'evt-$operationId-${item.id}-${eventType.name}',
    ownerUid: _ownerUid,
    routineItemId: item.id,
    occurrenceId: occurrenceId,
    eventType: eventType,
    operationKey: operationId,
    source: 'app',
    occurredAt: DateTime.utc(2026, 7, 24),
    itemSnapshot: {
      'id': item.id,
      'title': item.title,
      'startMinute': item.startMinute,
      'durationMinutes': item.durationMinutes,
      'blockType': item.blockType.name,
      'trackerTaskType': item.trackerType.name,
      'hardBlock': item.hardBlock,
    },
  );
}
