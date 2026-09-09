import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gate 7: Static Architecture & Boundary Enforcement', () {
    test(
      'zero mockRoutineProvider usages in lib/features/routine/',
      () {
        final routineDir = Directory('lib/features/routine');
        expect(routineDir.existsSync(), isTrue);

        final dartFiles = routineDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final violations = <String>[];
        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          if (content.contains('mockRoutineProvider')) {
            violations.add('${file.path}: references mockRoutineProvider');
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Production Routine features must never reference mockRoutineProvider',
        );
      },
    );

    test('habitRepositoryProvider has zero active callers in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final callers = <String>[];
      for (final file in dartFiles) {
        if (file.path.endsWith('habit_repository.dart')) continue;
        final content = file.readAsStringSync();
        if (content.contains('habitRepositoryProvider') ||
            content.contains('UnavailableFirebaseHabitRepository')) {
          callers.add('${file.path}: calls legacy habitRepositoryProvider');
        }
      }

      expect(
        callers,
        isEmpty,
        reason:
            'Legacy habitRepositoryProvider is retired in Gate 7 and must have zero callers in lib/',
      );
    });

    test(
      'routineNotifierProvider is the authoritative provider used in lib/features/routine/',
      () {
        final viewportFile =
            File('lib/features/routine/widgets/routine_timeline_viewport.dart');
        final tabFile = File('lib/features/routine/routine_tab.dart');

        expect(viewportFile.existsSync(), isTrue);
        expect(tabFile.existsSync(), isTrue);

        final viewportContent = viewportFile.readAsStringSync();
        final tabContent = tabFile.readAsStringSync();

        expect(
          viewportContent.contains('routineNotifierProvider'),
          isTrue,
          reason: 'RoutineTimelineViewport must consume routineNotifierProvider',
        );
        expect(
          tabContent.contains('routineNotifierProvider'),
          isTrue,
          reason: 'RoutineTab must consume routineNotifierProvider',
        );
      },
    );

    test('habitSystemsNotifierProvider is the authoritative habit provider', () {
      final habitScreen =
          File('lib/features/routine/screens/routine_habit_systems_screen.dart');
      expect(habitScreen.existsSync(), isTrue);

      final content = habitScreen.readAsStringSync();
      expect(
        content.contains('habitSystemsNotifierProvider'),
        isTrue,
        reason:
            'RoutineHabitSystemsScreen must consume habitSystemsNotifierProvider',
      );
    });
  });
}
