import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/conflict_banner.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';

const _ownerUid = 'local-development-user';

class _CompleterRoutineNotifier extends RoutineNotifier {
  Completer<RoutineWriteResult>? nextWriteCompleter;

  _CompleterRoutineNotifier(Ref ref)
    : super(
        FakeRoutineRepository(),
        FakeRoutineHistoryRepository(),
        FakeRoutineTransactionRepository(),
        ref,
      );

  void seed(RoutineState value) {
    state = value;
  }

  @override
  Future<RoutineWriteResult> markFlexible(String itemId) async {
    if (nextWriteCompleter != null) {
      return nextWriteCompleter!.future;
    }
    return super.markFlexible(itemId);
  }
}

void main() {
  testWidgets('disables close button and prevents pop during pending write', (
    tester,
  ) async {
    final itemA = _item('item-a', 'Task A', 9 * 60, 10 * 60);
    final itemB = _item('item-b', 'Task B', 9 * 30, 10 * 30);

    final conflict = RoutineConflict(
      id: 'conflict-a-b',
      type: RoutineConflictType.timeOverlap,
      itemId: itemA.id,
      otherItemId: itemB.id,
      title: 'Task A overlaps with Task B',
      message: 'Task A and Task B overlap in time',
      startMinute: 9 * 30,
      endMinute: 10 * 60,
      blocking: false,
      canKeepBoth: true,
    );

    late _CompleterRoutineNotifier notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineNotifierProvider.overrideWith((ref) {
            notifier = _CompleterRoutineNotifier(ref);
            notifier.seed(
              RoutineState(
                items: [itemA, itemB],
                conflicts: [conflict],
                selectedDay: DateTime(2026, 7, 24),
              ),
            );
            return notifier;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () =>
                      showRoutineConflictResolverSheet(context, ref),
                  child: const Text('Open Resolver'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Resolver'));
    await tester.pumpAndSettle();

    expect(find.text('1 conflict found'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Verify PopScope canPop is true before action
    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsOneWidget);
    var popScopeWidget = tester.widget<PopScope>(popScopeFinder);
    expect(popScopeWidget.canPop, isTrue);

    // Set completer so write stays pending
    final completer = Completer<RoutineWriteResult>();
    notifier.nextWriteCompleter = completer;

    // Tap "Mark flexible" to initiate in-flight write
    await tester.tap(find.text('Mark flexible'));
    await tester.pump(); // Start async operation

    // Re-query PopScope to verify canPop is false while pending
    popScopeWidget = tester.widget<PopScope>(popScopeFinder);
    expect(popScopeWidget.canPop, isFalse);

    // Attempting to tap close button while pending should do nothing
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    // Sheet is still open
    expect(find.text('1 conflict found'), findsOneWidget);

    // Complete the pending write with saved outcome
    completer.complete(const RoutineWriteResult.saved());
    await tester.pumpAndSettle();

    // Now sheet is closed
    expect(find.text('1 conflict found'), findsNothing);
  });
}

RoutineItem _item(String id, String title, int start, int end) {
  return RoutineItem(
    id: id,
    userId: _ownerUid,
    title: title,
    startMinute: start,
    endMinute: end,
    repeatDays: const [1],
    blockType: RoutineBlockType.flexibleTask,
  );
}
