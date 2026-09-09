import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/app_state.dart';

typedef OptivusProviderReader = T Function<T>(ProviderListenable<T> provider);

class OnboardingFrontendHydrationResult {
  final List<String> routineItemIds;
  final List<String> mockRoutineItemIds;
  final List<String> goalIds;
  final List<String> expectedHabitSystemIds;
  final List<String> appliedHabitSystemIds;
  final List<String> createdHabitSystemIds;
  final List<String> existingHabitSystemIds;
  final List<String> repairedHabitSystemIds;
  final List<String> failedHabitSystemIds;
  final List<String> expectedHistoryIds;
  final List<String> appliedHistoryIds;
  final List<String> failedHistoryIds;

  const OnboardingFrontendHydrationResult({
    required this.routineItemIds,
    required this.mockRoutineItemIds,
    required this.goalIds,
    this.expectedHabitSystemIds = const [],
    this.appliedHabitSystemIds = const [],
    this.createdHabitSystemIds = const [],
    this.existingHabitSystemIds = const [],
    this.repairedHabitSystemIds = const [],
    this.failedHabitSystemIds = const [],
    this.expectedHistoryIds = const [],
    this.appliedHistoryIds = const [],
    this.failedHistoryIds = const [],
  });

  bool get changed =>
      routineItemIds.isNotEmpty ||
      mockRoutineItemIds.isNotEmpty ||
      goalIds.isNotEmpty ||
      expectedHabitSystemIds.isNotEmpty ||
      appliedHabitSystemIds.isNotEmpty ||
      createdHabitSystemIds.isNotEmpty ||
      existingHabitSystemIds.isNotEmpty ||
      repairedHabitSystemIds.isNotEmpty ||
      failedHabitSystemIds.isNotEmpty ||
      expectedHistoryIds.isNotEmpty ||
      appliedHistoryIds.isNotEmpty ||
      failedHistoryIds.isNotEmpty;
}

class HabitSystemProjectionFailureException implements Exception {
  final String code;
  final List<String> expectedSystemIds;
  final List<String> appliedSystemIds;
  final List<String> failedSystemIds;
  final List<String> missingSystemIds;

  const HabitSystemProjectionFailureException({
    required this.code,
    this.expectedSystemIds = const [],
    this.appliedSystemIds = const [],
    this.failedSystemIds = const [],
    this.missingSystemIds = const [],
  });

  @override
  String toString() => 'HabitSystemProjectionFailureException($code)';
}

class OnboardingFrontendHydrationService {
  const OnboardingFrontendHydrationService();

  /// Read-only durable verification used by completion terminalization.
  Future<void> verifyPersistedHabitSystems({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) async {
    final routineItems = RoutineOnboardingProjection.build(bundle).items;
    final expected = HabitSystemOnboardingProjection.build(
      bundle,
      routineItems,
    );
    if (expected.isEmpty) return;
    final persisted = await read(
      habitSystemsRepositoryProvider,
    ).fetchHabitSystems(bundle.uid);
    _verifyProjectedHabitSystemsPersisted(persisted, expected);
  }

  Future<void> restoreVerifiedFrontendState({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) async {
    if (bundle.uid.trim().isEmpty) {
      throw ArgumentError('Cannot restore onboarding with empty bundle.uid.');
    }
    await Future.wait<void>([
      read(routineNotifierProvider.notifier).loadForOwner(bundle.uid),
      read(habitSystemsNotifierProvider.notifier).loadForOwner(bundle.uid),
    ]);
    // Goals, tracker, coach preferences and notification preferences are
    // transitional local owners.  A verified completion bundle is their
    // read-only cold-start source until each feature has a durable owner.
    // These merge/update operations are deterministic and intentionally do
    // not replay durable Routine or Habit System projections.
    read(mockGoalProvider.notifier).mergeMissing(bundle.identityGoalSystems);
    read(mockTrackerProvider.notifier).applyOnboardingBundle(bundle);
    read(
      mockCoachPreferencesProvider.notifier,
    ).updatePreferences(bundle.coachPreferences);
    read(
      mockNotificationPreferencesProvider.notifier,
    ).updatePreferences(bundle.notificationPreferences);
    verifyFrontendState(read: read, bundle: bundle);
  }

  Future<OnboardingFrontendHydrationResult> hydrate({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) async {
    if (bundle.uid.trim().isEmpty) {
      throw ArgumentError('Cannot hydrate onboarding with empty bundle.uid.');
    }
    final projection = RoutineOnboardingProjection.build(bundle);
    final routineItems = projection.items;
    final habitSystemProjections = HabitSystemOnboardingProjection.build(
      bundle,
      routineItems,
    );
    final expectedHabitSystemIds = habitSystemProjections
        .map((system) => system.systemId)
        .toSet();
    final firebaseMode = !read(fakeDataAllowedProvider);
    read(userProfileProvider.notifier).applyOnboardingBundle(bundle);
    final mockRoutineIds = firebaseMode
        ? const <String>[]
        : read(mockRoutineProvider.notifier).mergeMissing(routineItems);
    final goalIds = read(
      mockGoalProvider.notifier,
    ).mergeMissing(bundle.identityGoalSystems);
    read(mockTrackerProvider.notifier).applyOnboardingBundle(bundle);
    read(
      mockCoachPreferencesProvider.notifier,
    ).updatePreferences(bundle.coachPreferences);
    read(
      mockNotificationPreferencesProvider.notifier,
    ).updatePreferences(bundle.notificationPreferences);

    var appliedHabitSystemIds = const <String>[];
    var createdHabitSystemIds = const <String>[];
    var existingHabitSystemIds = const <String>[];
    var repairedHabitSystemIds = const <String>[];
    var failedHabitSystemIds = const <String>[];
    if (habitSystemProjections.isNotEmpty) {
      final projectionId =
          habitSystemProjections.first.onboardingProjectionId ??
          'proj_onboard_hs_v1_${bundle.uid}';
      final repo = read(habitSystemsRepositoryProvider);
      final result = await repo.reconcileProjectedSystems(
        ownerUid: bundle.uid,
        projectionId: projectionId,
        systems: habitSystemProjections,
      );
      appliedHabitSystemIds = result.appliedSystemIds;
      createdHabitSystemIds = result.createdSystemIds;
      existingHabitSystemIds = result.existingSystemIds;
      repairedHabitSystemIds = result.repairedSystemIds;
      failedHabitSystemIds = result.failedSystemIds;
      _verifyHabitProjectionWriteResult(result, expectedHabitSystemIds);
    }

    return OnboardingFrontendHydrationResult(
      // Remote controller hydration is owned by the later single
      // reloadControllers checkpoint. Keeping this phase projection-only
      // avoids loading the routine controller before all outputs exist.
      routineItemIds: const [],
      mockRoutineItemIds: mockRoutineIds,
      goalIds: goalIds,
      expectedHabitSystemIds: expectedHabitSystemIds.toList()..sort(),
      appliedHabitSystemIds: appliedHabitSystemIds,
      createdHabitSystemIds: createdHabitSystemIds,
      existingHabitSystemIds: existingHabitSystemIds,
      repairedHabitSystemIds: repairedHabitSystemIds,
      failedHabitSystemIds: failedHabitSystemIds,
      expectedHistoryIds: const [],
      appliedHistoryIds: const [],
      failedHistoryIds: const [],
    );
  }

  void _verifyHabitProjectionWriteResult(
    HabitSystemWriteResult result,
    Set<String> expectedSystemIds,
  ) {
    final appliedIds = result.appliedSystemIds.toSet();
    final missingAppliedIds = expectedSystemIds.difference(appliedIds).toList()
      ..sort();
    if (!result.success ||
        result.failedSystemIds.isNotEmpty ||
        missingAppliedIds.isNotEmpty) {
      throw HabitSystemProjectionFailureException(
        code: 'habit_system_projection_write_failed',
        expectedSystemIds: expectedSystemIds.toList()..sort(),
        appliedSystemIds: result.appliedSystemIds,
        failedSystemIds: result.failedSystemIds,
        missingSystemIds: missingAppliedIds,
      );
    }
  }

  void _verifyProjectedHabitSystemsPersisted(
    List<HabitSystemRecord> systems,
    List<HabitSystemRecord> expectedSystems,
  ) {
    final expectedSystemIds = expectedSystems
        .map((system) => system.systemId)
        .toSet();
    final persistedById = {
      for (final system in systems) system.systemId: system,
    };
    final persistedIds = persistedById.keys.toSet();
    final missingIds = expectedSystemIds.difference(persistedIds).toList()
      ..sort();
    final invalidIds = <String>[
      for (final expected in expectedSystems)
        if (persistedById[expected.systemId] != null &&
            !_matchesExpectedHabit(persistedById[expected.systemId]!, expected))
          expected.systemId,
    ]..sort();
    if (missingIds.isNotEmpty || invalidIds.isNotEmpty) {
      throw HabitSystemProjectionFailureException(
        code: 'habit_system_projection_persistence_invalid',
        expectedSystemIds: expectedSystemIds.toList()..sort(),
        missingSystemIds: [...missingIds, ...invalidIds]..sort(),
      );
    }
  }

  Future<void> reloadControllers({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) async {
    await read(routineNotifierProvider.notifier).loadForOwner(bundle.uid);
    await read(habitSystemsNotifierProvider.notifier).loadForOwner(bundle.uid);
  }

  void verifyFrontendState({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) {
    final projection = RoutineOnboardingProjection.build(bundle);
    final expectedRoutineIds = projection.items.map((item) => item.id).toSet();
    final visibleRoutineIds = read(
      routineNotifierProvider,
    ).items.map((item) => item.id).toSet();
    final missingRoutineIds = expectedRoutineIds.difference(visibleRoutineIds);
    if (missingRoutineIds.isNotEmpty) {
      throw StateError(
        'Routine controller is missing verified onboarding data.',
      );
    }
    final expectedSystems = HabitSystemOnboardingProjection.build(
      bundle,
      projection.items,
    );
    final expectedSystemIds = expectedSystems
        .map((system) => system.systemId)
        .toSet();
    if (expectedSystemIds.isEmpty) return;
    final visibleSystems = read(habitSystemsNotifierProvider).systems;
    final visibleById = {
      for (final system in visibleSystems) system.systemId: system,
    };
    final visibleIds = visibleById.keys.toSet();
    final missingIds = expectedSystemIds.difference(visibleIds).toList()
      ..sort();
    final invalidIds = <String>[
      for (final expected in expectedSystems)
        if (visibleById[expected.systemId] != null &&
            !_matchesExpectedHabit(visibleById[expected.systemId]!, expected))
          expected.systemId,
    ]..sort();
    if (missingIds.isNotEmpty || invalidIds.isNotEmpty) {
      throw HabitSystemProjectionFailureException(
        code: 'habit_system_projection_controller_invalid',
        expectedSystemIds: expectedSystemIds.toList()..sort(),
        missingSystemIds: [...missingIds, ...invalidIds]..sort(),
      );
    }
  }

  bool _matchesExpectedHabit(
    HabitSystemRecord actual,
    HabitSystemRecord expected,
  ) {
    return actual.systemId == expected.systemId &&
        actual.ownerUid == expected.ownerUid &&
        actual.title == expected.title &&
        actual.description == expected.description &&
        actual.category == expected.category &&
        actual.systemType == expected.systemType &&
        actual.status == expected.status &&
        actual.linkedRoutineIds.toSet().containsAll(
          expected.linkedRoutineIds,
        ) &&
        expected.linkedRoutineIds.toSet().containsAll(
          actual.linkedRoutineIds,
        ) &&
        actual.source == 'onboarding' &&
        actual.onboardingSourceId == expected.onboardingSourceId &&
        actual.onboardingProjectionId == expected.onboardingProjectionId &&
        actual.sourceFingerprint == expected.sourceFingerprint &&
        actual.schemaVersion == expected.schemaVersion;
  }
}
