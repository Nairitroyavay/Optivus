import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/screens/routine_history_screen.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

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
  testWidgets(
    'shows valid history while surfacing corrupt entries separately',
    (tester) async {
      await tester.pumpWidget(
        _historyHarness(
          RoutineState(
            items: const [],
            selectedDay: DateTime.now(),
            events: [
              _event(
                id: 'evt-valid-completed',
                title: 'Workout',
                type: RoutineEventType.completed,
              ),
            ],
            corruptEvents: [
              RoutineCorruptEvent(
                'evt-bad',
                const FormatException('bad event'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Workout'), findsOneWidget);
      expect(
        find.textContaining('Some history entries are unavailable (1)'),
        findsOneWidget,
      );
      expect(find.textContaining('Unknown task'), findsNothing);
    },
  );

  testWidgets('deduplicates event IDs across lifecycle sections', (
    tester,
  ) async {
    final duplicate = _event(
      id: 'evt-same-completed',
      title: 'Read',
      type: RoutineEventType.completed,
    );

    await tester.pumpWidget(
      _historyHarness(
        RoutineState(
          items: const [],
          selectedDay: DateTime.now(),
          events: [
            duplicate,
            duplicate.copyWith(occurredAt: duplicate.occurredAt),
          ],
        ),
      ),
    );

    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('renders each lifecycle event exactly once', (tester) async {
    final events = [
      for (final type in RoutineEventType.values)
        _event(id: 'evt-${type.name}', title: 'Row ${type.name}', type: type),
    ];

    await tester.pumpWidget(
      _historyHarness(
        RoutineState(
          items: const [],
          selectedDay: DateTime.now(),
          events: events,
        ),
      ),
    );

    for (final type in RoutineEventType.values) {
      expect(find.text('Row ${type.name}'), findsOneWidget);
    }
  });
}

Widget _historyHarness(RoutineState state) {
  return ProviderScope(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
      routineNotifierProvider.overrideWith((ref) {
        return _SeededRoutineNotifier(ref)..seed(state);
      }),
    ],
    child: MaterialApp(
      home: Scaffold(body: RoutineHistoryScreen(onBack: () {})),
    ),
  );
}

RoutineEventRecord _event({
  required String id,
  required String title,
  required RoutineEventType type,
}) {
  final now = DateTime.now().toUtc();
  final occurrenceType = {
    RoutineEventType.started,
    RoutineEventType.completed,
    RoutineEventType.skipped,
    RoutineEventType.missed,
    RoutineEventType.moved,
    RoutineEventType.rescheduled,
    RoutineEventType.undone,
  }.contains(type);
  return RoutineEventRecord(
    eventId: id,
    ownerUid: 'user-a',
    routineItemId: 'item-${type.name}',
    occurrenceId: occurrenceType ? 'occ-${type.name}' : null,
    occurrenceDateKey: occurrenceType ? '2026-07-24' : null,
    eventType: type,
    operationKey: 'op-${type.name}',
    source: type == RoutineEventType.started ? 'tracker' : 'app',
    occurredAt: now,
    itemSnapshot: {
      'id': 'item-${type.name}',
      'title': title,
      'startMinute': 9 * 60,
      'durationMinutes': 30,
      'blockType': RoutineBlockType.flexibleTask.name,
      'trackerTaskType': TrackerType.none.name,
      'hardBlock': false,
    },
  );
}
