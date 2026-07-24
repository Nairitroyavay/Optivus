import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/app_state.dart';

typedef OptivusProviderReader = T Function<T>(ProviderListenable<T> provider);

class OnboardingFrontendHydrationResult {
  final List<String> routineItemIds;
  final List<String> mockRoutineItemIds;
  final List<String> goalIds;

  const OnboardingFrontendHydrationResult({
    required this.routineItemIds,
    required this.mockRoutineItemIds,
    required this.goalIds,
  });

  bool get changed =>
      routineItemIds.isNotEmpty ||
      mockRoutineItemIds.isNotEmpty ||
      goalIds.isNotEmpty;
}

class OnboardingFrontendHydrationService {
  const OnboardingFrontendHydrationService();

  Future<OnboardingFrontendHydrationResult> hydrate({
    required OptivusProviderReader read,
    required OnboardingCompletionBundle bundle,
  }) async {
    final projection = RoutineOnboardingProjection.build(bundle);
    final routineItems = projection.items;
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

    return OnboardingFrontendHydrationResult(
      routineItemIds: routineIds,
      mockRoutineItemIds: mockRoutineIds,
      goalIds: goalIds,
    );
  }
}
