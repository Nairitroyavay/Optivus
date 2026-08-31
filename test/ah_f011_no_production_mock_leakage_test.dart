import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/home_tab.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/screens/tracker_history_screen.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/conflict_acceptance_repository.dart';
import 'package:optivus/repositories/goal_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/tracker_repository.dart';
import 'package:optivus/services/coach_ai_client.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  group('AH-F011 central fake-data policy', () {
    test(
      'missing, invalid, and unexpected-case modes fail toward Firebase',
      () {
        expect(
          OptivusBackendConfig.modeForName(''),
          OptivusBackendMode.firebase,
        );
        expect(
          OptivusBackendConfig.modeForName('unexpected'),
          OptivusBackendMode.firebase,
        );
        expect(
          OptivusBackendConfig.modeForName('FAKE'),
          OptivusBackendMode.firebase,
        );
        expect(
          OptivusBackendConfig.modeForName('fake'),
          OptivusBackendMode.fake,
        );
      },
    );

    test('debug + fake allows fake data', () {
      const policy = FakeBackendPolicy(
        isDebugBuild: true,
        backendMode: OptivusBackendMode.fake,
      );

      expect(policy.fakeDataAllowed, isTrue);
      expect(
        policy.selectBackend(firebase: () => 'firebase', fake: () => 'fake'),
        'fake',
      );
    });

    test('debug + Firebase forbids fake data and never calls fake factory', () {
      var fakeFactoryCalls = 0;
      const policy = FakeBackendPolicy(
        isDebugBuild: true,
        backendMode: OptivusBackendMode.firebase,
      );

      expect(policy.fakeDataAllowed, isFalse);
      expect(
        policy.selectBackend(
          firebase: () => 'firebase',
          fake: () {
            fakeFactoryCalls++;
            return 'fake';
          },
        ),
        'firebase',
      );
      expect(fakeFactoryCalls, 0);
    });

    test('non-debug + fake fails closed before fake factory construction', () {
      var fakeFactoryCalls = 0;
      const policy = FakeBackendPolicy(
        isDebugBuild: false,
        backendMode: OptivusBackendMode.fake,
      );

      expect(policy.fakeDataAllowed, isFalse);
      expect(
        () => policy.selectBackend(
          firebase: () => 'firebase',
          fake: () {
            fakeFactoryCalls++;
            return 'fake';
          },
        ),
        throwsStateError,
      );
      expect(fakeFactoryCalls, 0);
    });

    test('non-debug + Firebase forbids fake data', () {
      const policy = FakeBackendPolicy(
        isDebugBuild: false,
        backendMode: OptivusBackendMode.firebase,
      );

      expect(policy.fakeDataAllowed, isFalse);
      expect(
        policy.selectBackend(firebase: () => 'firebase', fake: () => 'fake'),
        'firebase',
      );
    });

    test('provider wiring also rejects non-debug fake configuration', () {
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
          optivusDebugBuildProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(routineRepositoryProvider),
        throwsA(anything),
      );
    });
  });

  group('AH-F011 backend wiring', () {
    test('debug fake intentionally wires fake repositories and demo state', () {
      final container = _container(OptivusBackendMode.fake);
      addTearDown(container.dispose);

      expect(
        container.read(routineRepositoryProvider),
        isA<FakeRoutineRepository>(),
      );
      expect(container.read(goalRepositoryProvider), isA<FakeGoalRepository>());
      expect(
        container.read(trackerRepositoryProvider),
        isA<FakeTrackerRepository>(),
      );
      expect(container.read(fitnessCenterProvider).containsDemoData, isTrue);

      container.read(mockRoutineProvider.notifier).loadSeedData();
      container.read(mockTrackerProvider.notifier).loadSeedData();
      container.read(mockGoalProvider.notifier).loadSeedData();
      container.read(mockMindNoteProvider.notifier).loadSeedData();
      container.read(mockCoachProvider.notifier).loadSeedData();
      expect(container.read(mockRoutineProvider), isNotEmpty);
      expect(container.read(mockTrackerProvider).trackerSessions, isNotEmpty);
      expect(container.read(mockGoalProvider), isNotEmpty);
      expect(container.read(mockMindNoteProvider), isNotEmpty);
      expect(container.read(mockCoachProvider), isNotEmpty);
    });

    test('debug Firebase never wires fake-only feature repositories', () {
      final container = _container(OptivusBackendMode.firebase);
      addTearDown(container.dispose);

      expect(
        container.read(routineRepositoryProvider),
        isA<FirestoreRoutineRepository>(),
      );
      expect(
        container.read(goalRepositoryProvider),
        isA<UnavailableFirebaseGoalRepository>(),
      );
      expect(
        container.read(trackerRepositoryProvider),
        isA<UnavailableFirebaseTrackerRepositories>(),
      );
      expect(
        container.read(routineImportAiClientProvider),
        isNot(isA<FakeRoutineImportAiClient>()),
      );
      expect(
        container.read(coachAiClientProvider),
        isNot(isA<FakeCoachAiClient>()),
      );
      expect(container.read(r2UploadClientProvider), isA<RealR2UploadClient>());
    });
  });

  group('AH-F011 Firebase initial, empty, and failure states', () {
    test('Firebase providers start empty and never flash seed content', () {
      final container = _container(OptivusBackendMode.firebase);
      addTearDown(container.dispose);

      expect(container.read(mockUserProfileProvider).displayName, isEmpty);
      expect(container.read(mockUserProfileProvider).email, isEmpty);
      expect(container.read(mockRoutineProvider), isEmpty);
      expect(container.read(mockGoalProvider), isEmpty);
      expect(container.read(mockTrackerProvider).trackerSessions, isEmpty);
      expect(container.read(mockTrackerProvider).fitnessActivities, isEmpty);
      expect(container.read(mockMindNoteProvider), isEmpty);
      expect(container.read(mockCoachProvider), isEmpty);
      expect(
        container.read(mockOnboardingProvider).draft.bodyBasics.heightCm,
        isNull,
      );
      expect(
        container.read(mockOnboardingProvider).draft.bodyBasics.weightKg,
        isNull,
      );
      expect(container.read(homeDashboardProvider).nowNextAction, isNull);
      expect(container.read(homeDashboardProvider).trackerPreviews, isEmpty);
      expect(container.read(fitnessCenterProvider).containsDemoData, isFalse);
      expect(container.read(fitnessCenterProvider).recentActivities, isEmpty);
      expect(container.read(fitnessCenterProvider).todayDistanceKm, 0);
      expect(container.read(regionSettingsProvider).userId, isEmpty);
      expect(resolveHomeIdentityFocus(null, ''), isNull);
      expect(
        resolveHomeIdentityFocus(null, 'Builder'),
        isA<IdentityFocus>()
            .having(
              (identity) => identity.primaryIdentity,
              'identity',
              'Builder',
            )
            .having((identity) => identity.primaryProof, 'proof', isEmpty),
      );

      expect(
        container.read(mockRoutineProvider.notifier).loadSeedData,
        throwsStateError,
      );
      expect(
        container.read(mockTrackerProvider.notifier).loadSeedData,
        throwsStateError,
      );
      expect(
        container.read(mockGoalProvider.notifier).loadSeedData,
        throwsStateError,
      );
      expect(
        container.read(mockMindNoteProvider.notifier).loadSeedData,
        throwsStateError,
      );
      expect(
        container.read(mockCoachProvider.notifier).loadSeedData,
        throwsStateError,
      );
    });

    test(
      'empty Firebase-mode routine fixture remains an empty collection',
      () async {
        final routine = FakeRoutineRepository();
        final history = FakeRoutineHistoryRepository();
        final container = _routineContainer(
          routineRepository: routine,
          historyRepository: history,
        );
        addTearDown(container.dispose);

        await container
            .read(routineNotifierProvider.notifier)
            .loadForOwner('real-uid');

        expect(container.read(routineNotifierProvider).items, isEmpty);
        expect(container.read(mockRoutineProvider), isEmpty);
      },
    );

    test(
      'routine network failure becomes error and never seed routines',
      () async {
        final container = _routineContainer(
          routineRepository: _FailingRoutineRepository(
            StateError('network-request-failed'),
          ),
          historyRepository: FakeRoutineHistoryRepository(),
        );
        addTearDown(container.dispose);

        await expectLater(
          container
              .read(routineNotifierProvider.notifier)
              .loadForOwner('real-uid'),
          throwsA(isA<StateError>()),
        );

        final state = container.read(routineNotifierProvider);
        expect(state.loading, isFalse);
        expect(state.error, contains('network-request-failed'));
        expect(state.items, isEmpty);
        expect(container.read(mockRoutineProvider), isEmpty);
      },
    );

    test(
      'permission and decode failures do not populate tracker or goals',
      () async {
        final container = _container(OptivusBackendMode.firebase);
        addTearDown(container.dispose);

        expect(
          () => container
              .read(trackerRepositoryProvider)
              .fetchSessions('real-uid'),
          throwsA(isA<FirebaseFeatureUnavailableException>()),
        );
        expect(
          () => container.read(goalRepositoryProvider).fetchGoals('real-uid'),
          throwsA(isA<FirebaseFeatureUnavailableException>()),
        );
        expect(container.read(mockTrackerProvider).trackerSessions, isEmpty);
        expect(container.read(mockGoalProvider), isEmpty);
      },
    );

    test('delayed routine load stays empty until real data arrives', () async {
      final repository = _DelayedRoutineRepository();
      final container = _routineContainer(
        routineRepository: repository,
        historyRepository: FakeRoutineHistoryRepository(),
      );
      addTearDown(container.dispose);

      final load = container
          .read(routineNotifierProvider.notifier)
          .loadForOwner('real-uid');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(routineNotifierProvider).loading, isTrue);
      expect(container.read(routineNotifierProvider).items, isEmpty);
      expect(container.read(mockRoutineProvider), isEmpty);

      repository.complete([_realRoutine]);
      await load;

      expect(container.read(routineNotifierProvider).items, [_realRoutine]);
    });

    test('failure then retry yields only the real routine', () async {
      final repository = _RetryRoutineRepository();
      final container = _routineContainer(
        routineRepository: repository,
        historyRepository: FakeRoutineHistoryRepository(),
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(routineNotifierProvider.notifier)
            .loadForOwner('real-uid'),
        throwsStateError,
      );
      expect(container.read(routineNotifierProvider).items, isEmpty);

      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner('real-uid');
      expect(container.read(routineNotifierProvider).items, [_realRoutine]);
      expect(container.read(mockRoutineProvider), isEmpty);
    });

    test(
      'Tracker snapshot never invents non-zero demo metrics when collections are empty',
      () {
        final container = _container(OptivusBackendMode.firebase);
        addTearDown(container.dispose);

        final trackerState = container.read(mockTrackerProvider);
        final snapshot = container.read(fitnessCenterProvider);
        expect(snapshot.todayDistanceKm, 0.0);
        expect(snapshot.todayCalories, 0);
        expect(snapshot.bestPaceLabel, '—');
        expect(snapshot.activeMinutesThisWeek, 0);
        expect(snapshot.workoutStatus, 'No activity');
        expect(snapshot.recentActivities, isEmpty);
        expect(trackerState.hydrationLogs, isEmpty);
        expect(trackerState.fitnessActivities, isEmpty);
        expect(trackerState.screenTimeApps, isEmpty);
        expect(trackerState.savingsEntries, isEmpty);
        expect(
          buildTrackerHistoryEntries(
            trackerState,
            container.read(regionSettingsProvider),
          ),
          isEmpty,
        );
      },
    );

    test(
      'HomeMindNoteNotifier starts empty in Firebase mode and never leaks backend rewrite note',
      () {
        final firebaseContainer = _container(OptivusBackendMode.firebase);
        addTearDown(firebaseContainer.dispose);
        expect(firebaseContainer.read(homeMindNoteProvider), isEmpty);

        final fakeContainer = _container(OptivusBackendMode.fake);
        addTearDown(fakeContainer.dispose);
        expect(fakeContainer.read(homeMindNoteProvider), isNotEmpty);
        expect(
          fakeContainer.read(homeMindNoteProvider).first.content,
          contains('Go or stick to Node.js'),
        );
      },
    );

    test(
      'UserProfile and BodyBasics start with genuine empty defaults and no Roy/170/70',
      () {
        final container = _container(OptivusBackendMode.firebase);
        addTearDown(container.dispose);

        final profile = container.read(mockUserProfileProvider);
        expect(profile.displayName, isNot(contains('Roy')));
        expect(profile.displayName, isEmpty);
        expect(profile.email, isEmpty);

        final onboarding = container.read(mockOnboardingProvider);
        expect(onboarding.draft.bodyBasics.heightCm, isNull);
        expect(onboarding.draft.bodyBasics.weightKg, isNull);
        expect(onboarding.draft.badHabits, isEmpty);
        expect(onboarding.draft.goodHabits, isEmpty);
      },
    );
  });
}

ProviderContainer _container(OptivusBackendMode mode) {
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(mode),
      optivusDebugBuildProvider.overrideWithValue(true),
      regionSettingsRepositoryProvider.overrideWithValue(
        FakeRegionSettingsRepository(),
      ),
    ],
  );
}

ProviderContainer _routineContainer({
  required RoutineRepository routineRepository,
  required RoutineHistoryRepository historyRepository,
}) {
  final transactionRepository = FakeRoutineTransactionRepository(
    routineRepository: routineRepository,
    historyRepository: historyRepository,
  );
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
      optivusDebugBuildProvider.overrideWithValue(true),
      regionSettingsRepositoryProvider.overrideWithValue(
        FakeRegionSettingsRepository(),
      ),
      routineRepositoryProvider.overrideWithValue(routineRepository),
      routineHistoryRepositoryProvider.overrideWithValue(historyRepository),
      routineTransactionRepositoryProvider.overrideWithValue(
        transactionRepository,
      ),
      conflictAcceptanceRepositoryProvider.overrideWithValue(
        _EmptyConflictRepository(),
      ),
    ],
  );
}

final _realRoutine = RoutineItem(
  id: 'server-routine',
  userId: 'real-uid',
  title: 'Real user routine',
  startMinute: 600,
  endMinute: 630,
  blockType: RoutineBlockType.flexibleTask,
  category: RoutineCategory.habit,
  source: RoutineSource.manual,
);

class _EmptyConflictRepository implements ConflictAcceptanceRepository {
  @override
  Future<List<ConflictAcceptance>> fetchForOwner(String uid) async => const [];

  @override
  Future<void> upsert(String uid, ConflictAcceptance acceptance) async {}
}

class _FailingRoutineRepository implements RoutineRepository {
  _FailingRoutineRepository(this.error);

  final Object error;

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async => throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedRoutineRepository extends _FailingRoutineRepository {
  _DelayedRoutineRepository() : super(StateError('unused'));

  final Completer<List<RoutineItem>> _completer = Completer();

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) => _completer.future;

  void complete(List<RoutineItem> items) => _completer.complete(items);
}

class _RetryRoutineRepository extends _FailingRoutineRepository {
  _RetryRoutineRepository() : super(StateError('unavailable'));

  var calls = 0;

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    calls++;
    if (calls == 1) throw StateError('unavailable');
    return [_realRoutine];
  }
}
