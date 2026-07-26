import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/routine/services/routine_conflict_engine.dart';

void main() {
  group('RoutineConflictEngine', () {
    final baseItem = RoutineItem(
      id: 'task',
      userId: 'test_uid',
      title: 'Task',
      category: RoutineCategory.habit,
      blockType: RoutineBlockType.flexibleTask,
      startMinute: 600, // 10:00 AM
      endMinute: 660, // 11:00 AM
      repeatDays: [DateTime.monday],
    );

    test('detects no conflicts for non-overlapping tasks', () {
      final item2 = baseItem.copyWith(
        id: 'task2',
        title: 'Task 2',
        startMinute: 700, // 11:40 AM
        endMinute: 760, // 12:40 PM
      );
      final conflicts = RoutineConflictEngine.detect(
        [baseItem, item2],
        DateTime(2025, 1, 6), // A Monday
      );
      expect(conflicts, isEmpty);
    });

    test('detects timeOverlap for overlapping tasks', () {
      final item2 = baseItem.copyWith(
        id: 'task2',
        title: 'Task 2',
        startMinute: 630, // 10:30 AM
        endMinute: 690, // 11:30 AM
      );
      final conflicts = RoutineConflictEngine.detect([
        baseItem,
        item2,
      ], DateTime(2025, 1, 6));
      expect(conflicts.length, 1);
      expect(
        conflicts.every((c) => c.type == RoutineConflictType.timeOverlap),
        isTrue,
      );
    });

    test('detects overnightConflict correctly', () {
      final nightTask = baseItem.copyWith(
        id: 'night1',
        title: 'Night Task',
        startMinute: 1380, // 11:00 PM
        endMinute: 60, // 1:00 AM next day
      );
      final lateTask = baseItem.copyWith(
        id: 'late1',
        title: 'Late Task',
        startMinute: 1410, // 11:30 PM
        endMinute: 120, // 2:00 AM
      );
      final conflicts = RoutineConflictEngine.detect([
        nightTask,
        lateTask,
      ], DateTime(2025, 1, 6));
      expect(conflicts.length, 1);
      expect(
        conflicts.any(
          (c) =>
              c.type == RoutineConflictType.timeOverlap ||
              c.type == RoutineConflictType.overnightConflict,
        ),
        isTrue,
      );
    });

    test('detects duplicateRoutine', () {
      final item2 = baseItem.copyWith(id: 'task2');
      final conflicts = RoutineConflictEngine.detect([
        baseItem,
        item2,
      ], DateTime(2025, 1, 6));
      expect(
        conflicts.any((c) => c.type == RoutineConflictType.duplicateRoutine),
        isTrue,
      );
    });

    test('detects unavailableTime for strict blocks', () {
      final classTask = baseItem.copyWith(
        id: 'class1',
        title: 'Class Task',
        category: RoutineCategory.classBlock,
      );
      final overlap = baseItem.copyWith(
        id: 'overlap1',
        title: 'Overlap Task',
        category: RoutineCategory.classBlock,
      );
      final conflicts = RoutineConflictEngine.detect([
        classTask,
        overlap,
      ], DateTime(2025, 1, 6));
      expect(
        conflicts.any(
          (c) =>
              (c.itemId == 'overlap1' || c.otherItemId == 'overlap1') &&
              c.type == RoutineConflictType.unavailableTime,
        ),
        isTrue,
      );
    });
  });
}
