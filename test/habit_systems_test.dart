import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/habit_system_repository.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';

void main() {
  group('HabitSystemRecord model tests', () {
    test('toMap and fromMap round-trip', () {
      final now = DateTime.now().toUtc();
      final record = HabitSystemRecord(
        systemId: 'habitsys_1',
        ownerUid: 'user_1',
        title: 'Morning Meditation',
        description: '10m daily mindfulness',
        category: RoutineCategory.meditation,
        systemType: HabitSystemType.goodHabit,
        status: HabitSystemStatus.active,
        linkedRoutineIds: const ['routine_1', 'routine_2'],
        source: 'user',
        createdAt: now,
        updatedAt: now,
      );

      final map = record.toMap();
      final restored = HabitSystemRecord.fromMap(map);

      expect(restored.systemId, 'habitsys_1');
      expect(restored.ownerUid, 'user_1');
      expect(restored.title, 'Morning Meditation');
      expect(restored.description, '10m daily mindfulness');
      expect(restored.category, RoutineCategory.meditation);
      expect(restored.systemType, HabitSystemType.goodHabit);
      expect(restored.status, HabitSystemStatus.active);
      expect(restored.linkedRoutineIds, const ['routine_1', 'routine_2']);
      expect(restored.source, 'user');
    });

    test('copyWith updates state correctly', () {
      final now = DateTime.now().toUtc();
      final record = HabitSystemRecord(
        systemId: 'habitsys_1',
        ownerUid: 'user_1',
        title: 'Initial Title',
        category: RoutineCategory.habit,
        systemType: HabitSystemType.goodHabit,
        createdAt: now,
        updatedAt: now,
      );

      final paused = record.copyWith(status: HabitSystemStatus.paused);
      expect(paused.status, HabitSystemStatus.paused);
      expect(paused.isPaused, true);

      final archived = record.copyWith(
        status: HabitSystemStatus.archived,
        archivedAt: now,
      );
      expect(archived.status, HabitSystemStatus.archived);
      expect(archived.isArchived, true);

      final restored = archived.copyWith(
        status: HabitSystemStatus.active,
        clearArchivedAt: true,
      );
      expect(restored.status, HabitSystemStatus.active);
      expect(restored.archivedAt, isNull);
    });
  });

  group('HabitSystemsNotifier CRUD and auth lifecycle', () {
    late ProviderContainer container;
    late FakeHabitSystemRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeHabitSystemRepository();
      container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          fakeHabitSystemRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'create, update, pause, resume, archive, restore, and delete system',
      () async {
        final notifier = container.read(habitSystemsNotifierProvider.notifier);
        await notifier.loadForOwner('user_123');

        var state = container.read(habitSystemsNotifierProvider);
        expect(state.systems, isEmpty);

        // Create
        final success = await notifier.createSystem(
          title: 'Daily Reading',
          description: 'Read 20 pages',
          category: RoutineCategory.habit,
          systemType: HabitSystemType.goodHabit,
        );
        expect(success, true);

        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems.length, 1);
        final created = state.systems.first;
        expect(created.title, 'Daily Reading');
        expect(created.isActive, true);

        // Pause
        await notifier.pauseSystem(created.systemId);
        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems.first.isPaused, true);
        expect(state.pausedSystems.length, 1);

        // Resume
        await notifier.resumeSystem(created.systemId);
        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems.first.isActive, true);

        // Link Routine
        await notifier.linkRoutine(created.systemId, 'routine_abc');
        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems.first.linkedRoutineIds, contains('routine_abc'));

        // Unlink Routine
        await notifier.unlinkRoutine(created.systemId, 'routine_abc');
        state = container.read(habitSystemsNotifierProvider);
        expect(
          state.systems.first.linkedRoutineIds,
          isNot(contains('routine_abc')),
        );

        // Archive
        await notifier.archiveSystem(created.systemId);
        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems.first.isArchived, true);
        expect(state.archivedSystems.length, 1);

        // Restore
        await notifier.restoreSystem(created.systemId);
        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems.first.isActive, true);

        // Delete
        await notifier.deleteSystem(created.systemId);
        state = container.read(habitSystemsNotifierProvider);
        expect(state.systems, isEmpty);
      },
    );

    test('sign-out resets state and clears cache', () async {
      final notifier = container.read(habitSystemsNotifierProvider.notifier);
      await notifier.loadForOwner('user_123');
      await notifier.createSystem(
        title: 'Check-in',
        category: RoutineCategory.badHabit,
        systemType: HabitSystemType.badHabit,
      );

      var state = container.read(habitSystemsNotifierProvider);
      expect(state.systems.length, 1);

      notifier.resetForSignedOut();
      state = container.read(habitSystemsNotifierProvider);
      expect(state.systems, isEmpty);
      expect(state.loading, false);
      expect(state.error, isNull);
    });
  });

  group('HabitSystemOnboardingProjection tests', () {
    test('builds HabitSystemRecords from OnboardingCompletionBundle', () {
      final now = DateTime.now().toUtc();
      final bundle = OnboardingCompletionBundle(
        uid: 'user_onb',
        createdAt: now,
        updatedAt: now,
        userProfilePatch: const {},
        baseTimelineBlocks: const [],
        finalTimelineItems: const [],
        routineItemsForApp: const [],
        goodHabitTemplates: const [
          GoodHabitTemplateBundle(
            id: 'gh_1',
            systemKey: 'meditation',
            title: 'Daily Meditation',
            durationMinutes: 10,
            frequency: 'daily',
            bestTime: 'morning',
            priority: 'must_do',
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
          ),
        ],
        badHabitCheckIns: const [
          BadHabitCheckInBundle(
            id: 'bh_1',
            habitKey: 'smoking',
            displayName: 'Cigarettes',
            dailySpend: 10,
            lostTimeMinutes: 5,
            badHabitCheckInEnabled: true,
            moneySavedTrackerEnabled: true,
          ),
        ],
        identityGoalSystems: const [],
        notificationPreferences: NotificationPreferences(
          morningStart: true,
          nextTask: true,
          eating: true,
          badHabitCheckIn: true,
          savings: true,
          nightReflection: true,
          intensity: NotificationIntensity.medium,
        ),
        coachPreferences: CoachPreferences(name: 'Coach', style: 'Supportive'),
        moneyGoal: null,
        uploadedAssetReferences: const [],
        warnings: const [],
        duplicateSystemKeysMerged: const [],
      );

      final routineItems = [
        RoutineItem(
          id: 'routine_med',
          userId: 'user_onb',
          title: 'Daily Meditation',
          startMinute: 480,
          endMinute: 490,
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
        ),
      ];

      final habitSystems = HabitSystemOnboardingProjection.build(
        bundle,
        routineItems,
      );
      expect(habitSystems.length, 2);

      final good = habitSystems.firstWhere(
        (s) => s.systemType == HabitSystemType.goodHabit,
      );
      expect(good.title, 'Daily Meditation');
      expect(good.linkedRoutineIds, contains('routine_med'));

      final bad = habitSystems.firstWhere(
        (s) => s.systemType == HabitSystemType.badHabit,
      );
      expect(bad.title, 'Cigarettes System');
    });
  });
}
