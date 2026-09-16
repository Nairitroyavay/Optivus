import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';
import 'package:optivus/models/routine_item.dart';

void main() {
  group('Gate N: Moved-In Occurrence Make Tiny Contract', () {
    late ProviderContainer container;
    late RoutineNotifier notifier;

    final tuesday = DateTime(2026, 9, 15);
    final wednesday = DateTime(2026, 9, 16);

    setUp(() {
      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
      notifier = container.read(routineNotifierProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('Moved-in occurrence Make Tiny retains source occurrenceDate and targets displayDate', () async {
      // 1. Base item on Tuesday (60 min flexible task: 9:00 - 10:00 AM)
      final tuesdayItem = RoutineItem(
        id: 'habit_run',
        title: 'Morning Run',
        date: tuesday,
        startMinute: 540,
        endMinute: 600,
        repeatDays: const [],
        repeatRule: 'once',
        blockType: RoutineBlockType.flexibleTask,
      );

      notifier.state = notifier.state.copyWith(
        items: [tuesdayItem],
        selectedDay: tuesday,
      );

      // 2. Move Tuesday occurrence to Wednesday at 11:00 AM (660-720)
      final moveResult = await notifier.moveItem(
        itemId: tuesdayItem.id,
        date: wednesday,
        startMinute: 660,
        durationMinutes: 60,
        occurrenceDate: tuesday,
      );
      expect(moveResult.closesUserFlow, isTrue);

      // Verify Wednesday projection shows moved-in entry
      final wednesdayEntries = RoutineOccurrenceProjector.entriesForDay(
        notifier.state.items,
        notifier.state.occurrences,
        wednesday,
      );
      expect(wednesdayEntries.length, 1);
      final movedEntry = wednesdayEntries.first;
      expect(movedEntry.templateId, tuesdayItem.id);
      expect(movedEntry.kind, RoutineDayEntryKind.movedIn);
      expect(movedEntry.occurrenceDateKey, routineLocalDateKey(tuesday));
      expect(movedEntry.displayDateKey, routineLocalDateKey(wednesday));
      expect(movedEntry.item.startMinute, 660);

      // Verify Tuesday projection has moved away
      final tuesdayEntries = RoutineOccurrenceProjector.entriesForDay(
        notifier.state.items,
        notifier.state.occurrences,
        tuesday,
      );
      expect(tuesdayEntries.isEmpty, isTrue);

      // 3. Make Tiny version on the moved-in occurrence on Wednesday
      final actionContext = RoutineActionContext.fromDayEntry(movedEntry);
      expect(actionContext.occurrenceDate, tuesday);
      expect(actionContext.displayDate, wednesday);

      final tinyResult = await notifier.makeTinyVersion(
        movedEntry.item,
        actionContext: actionContext,
      );
      expect(tinyResult.closesUserFlow, isTrue);

      // 4. Verify Wednesday projection now reflects the tiny version
      final updatedWedEntries = RoutineOccurrenceProjector.entriesForDay(
        notifier.state.items,
        notifier.state.occurrences,
        wednesday,
      );
      expect(updatedWedEntries.length, 1);
      final tinyEntry = updatedWedEntries.first;
      expect(tinyEntry.templateId, tuesdayItem.id);
      expect(tinyEntry.item.title, '[Tiny] Morning Run');
      expect(tinyEntry.item.durationMinutes, 10); // clamped to 10 min
      expect(tinyEntry.item.startMinute, 660);
      expect(tinyEntry.occurrenceDateKey, routineLocalDateKey(tuesday));

      // 5. Verify Tuesday projection has NO ghost duplicate entries
      final updatedTueEntries = RoutineOccurrenceProjector.entriesForDay(
        notifier.state.items,
        notifier.state.occurrences,
        tuesday,
      );
      expect(updatedTueEntries.isEmpty, isTrue);
    });

    test('Make tiny directly preserves template duration seed when invoked on repeated weekly item', () async {
      final weeklyItem = RoutineItem(
        id: 'weekly_gym',
        title: 'Gym Workout',
        startMinute: 600,
        endMinute: 660,
        repeatDays: const [DateTime.tuesday, DateTime.thursday],
        repeatRule: 'weekly',
        blockType: RoutineBlockType.flexibleTask,
      );

      notifier.state = notifier.state.copyWith(
        items: [weeklyItem],
        selectedDay: tuesday,
      );

      final result = await notifier.makeTinyVersion(
        weeklyItem,
        occurrenceDate: tuesday,
      );
      expect(result.closesUserFlow, isTrue);

      final tuesdayEntries = RoutineOccurrenceProjector.entriesForDay(
        notifier.state.items,
        notifier.state.occurrences,
        tuesday,
      );
      expect(tuesdayEntries.length, 1);
      expect(tuesdayEntries.first.item.title, '[Tiny] Gym Workout');
      expect(tuesdayEntries.first.item.durationMinutes, 10);
    });
  });
}
