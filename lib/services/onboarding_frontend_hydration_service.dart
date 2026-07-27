import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/app_state.dart';

typedef OptivusProviderReader = T Function<T>(ProviderListenable<T> provider);

class OnboardingFrontendHydrationResult {
  final List<String> routineItemIds;
  final List<String> mockRoutineItemIds;
  final List<String> goalIds;
  final List<String> expectedHabitSystemIds;
  final List<String> appliedHabitSystemIds;
  final List<String> failedHabitSystemIds;

  const OnboardingFrontendHydrationResult({
    required this.routineItemIds,
    required this.mockRoutineItemIds,
    required this.goalIds,
    this.expectedHabitSystemIds = const [],
    this.appliedHabitSystemIds = const [],
    this.failedHabitSystemIds = const [],
  });

  bool get changed =>
      routineItemIds.isNotEmpty ||
      mockRoutineItemIds.isNotEmpty ||
      goalIds.isNotEmpty ||
      expectedHabitSystemIds.isNotEmpty ||
      appliedHabitSystemIds.isNotEmpty ||
      failedHabitSystemIds.isNotEmpty;
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

  Future<OnboardingFrontendHydrationResult> hydrate({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) async {
    final projection = RoutineOnboardingProjection.build(bundle);
    final routineItems = projection.items;
    final habitSystemProjections = HabitSystemOnboardingProjection.build(
      bundle,
      routineItems,
    );
    final expectedHabitSystemIds = habitSystemProjections
        .map((system) => system.systemId)
        .toSet();
    final firebaseMode =
        read(optivusBackendModeProvider) == OptivusBackendMode.firebase;
    final routineBefore = read(
      routineNotifierProvider,
    ).items.map((item) => item.id).toSet();

    read(mockUserProfileProvider.notifier).applyOnboardingBundle(bundle);
    final mockRoutineIds = firebaseMode
        ? const <String>[]
        : read(mockRoutineProvider.notifier).mergeMissing(routineItems);
    await read(routineNotifierProvider.notifier).loadForOwner(bundle.uid);
    await const RoutineOnboardingEventProjector().projectCreatedEvents(
      read: read,
      bundle: bundle,
    );
    final receipt = await read(
      routineRepositoryProvider,
    ).fetchProjectionReceipt(bundle.uid, projection.projectionId);
    if (receipt != null && receipt.status == 'completed') {
      read(mockUserProfileProvider.notifier).completeOnboarding();
    }
    final routineIds = read(routineNotifierProvider).items
        .map((item) => item.id)
        .where((id) => !routineBefore.contains(id))
        .toList(growable: false);
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
      failedHabitSystemIds = result.failedSystemIds;
      _verifyHabitProjectionWriteResult(result, expectedHabitSystemIds);
      final persistedSystems = await repo.fetchHabitSystems(bundle.uid);
      _verifyProjectedHabitSystemsPersisted(
        persistedSystems,
        expectedHabitSystemIds,
      );
    }

    await read(habitSystemsNotifierProvider.notifier).loadForOwner(bundle.uid);
    _verifyProjectedHabitSystemsVisible(read, expectedHabitSystemIds);

    return OnboardingFrontendHydrationResult(
      routineItemIds: routineIds,
      mockRoutineItemIds: mockRoutineIds,
      goalIds: goalIds,
      expectedHabitSystemIds: expectedHabitSystemIds.toList()..sort(),
      appliedHabitSystemIds: appliedHabitSystemIds,
      failedHabitSystemIds: failedHabitSystemIds,
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
    Set<String> expectedSystemIds,
  ) {
    final persistedIds = systems.map((system) => system.systemId).toSet();
    final missingIds = expectedSystemIds.difference(persistedIds).toList()
      ..sort();
    if (missingIds.isNotEmpty) {
      throw HabitSystemProjectionFailureException(
        code: 'habit_system_projection_persistence_missing',
        expectedSystemIds: expectedSystemIds.toList()..sort(),
        missingSystemIds: missingIds,
      );
    }
  }

  void _verifyProjectedHabitSystemsVisible(
    OptivusProviderReader read,
    Set<String> expectedSystemIds,
  ) {
    if (expectedSystemIds.isEmpty) return;
    final visibleIds = read(
      habitSystemsNotifierProvider,
    ).systems.map((system) => system.systemId).toSet();
    final missingIds = expectedSystemIds.difference(visibleIds).toList()
      ..sort();
    if (missingIds.isNotEmpty) {
      throw HabitSystemProjectionFailureException(
        code: 'habit_system_projection_controller_missing',
        expectedSystemIds: expectedSystemIds.toList()..sort(),
        missingSystemIds: missingIds,
      );
    }
  }
}
