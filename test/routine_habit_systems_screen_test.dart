import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/screens/routine_habit_systems_screen.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'helpers/fake_habit_systems_repository.dart';
import 'package:optivus/state/auth_state.dart';

class MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  MockAuthNotifier()
    : super(
        const AuthState(
          status: AuthFlowStatus.signedInOnboardingComplete,
          user: AuthUser(
            uid: 'mock-user-123',
            email: 'test@test.com',
            emailVerified: true,
          ),
        ),
      );

  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'RoutineHabitSystemsScreen renders empty state truthfully and supports system creation',
    (tester) async {
      final fakeRepo = FakeHabitSystemsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
            authProvider.overrideWith((ref) => MockAuthNotifier()),
            habitSystemsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(body: RoutineHabitSystemsScreen(onBack: () {})),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Habit Systems'), findsOneWidget);
      expect(find.text('GOOD HABITS'), findsOneWidget);
      expect(find.text('BAD HABITS'), findsOneWidget);

      // Verify truthful empty state (no Meditation / Reading fake fallback)
      expect(
        find.text('No active Good Habit systems. Create one to get started.'),
        findsOneWidget,
      );

      // Tap Create New Habit System
      await tester.tap(find.text('Create New Habit System'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Create Habit System'), findsOneWidget);
    },
  );

  testWidgets('RoutineHabitSystemsScreen renders existing habit systems', (
    tester,
  ) async {
    final fakeRepo = FakeHabitSystemsRepository();
    final now = DateTime.now().toUtc();
    final system = HabitSystemRecord(
      systemId: 'habitsys_1',
      ownerUid: 'mock-user-123',
      title: 'Morning Skill Reps',
      description: '30m coding reps',
      category: RoutineCategory.habit,
      systemType: HabitSystemType.goodHabit,
      status: HabitSystemStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    await fakeRepo.createSystem(system: system, operationId: 'test_op');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          authProvider.overrideWith((ref) => MockAuthNotifier()),
          habitSystemsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(body: RoutineHabitSystemsScreen(onBack: () {})),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Morning Skill Reps'), findsOneWidget);

    // Tap system row to open action sheet
    await tester.tap(find.text('Morning Skill Reps'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Pause system'), findsOneWidget);
    expect(find.text('Manage Linked Routines'), findsOneWidget);
    expect(find.text('Archive system'), findsOneWidget);
    expect(find.text('Delete system'), findsOneWidget);
  });
}
