import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
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
    final routineItems = routineItemsForHydration(
      bundle,
    ).map((item) => item.copyWith(userId: bundle.uid)).toList(growable: false);

    read(mockUserProfileProvider.notifier).applyOnboardingBundle(bundle);
    final mockRoutineIds = read(
      mockRoutineProvider.notifier,
    ).mergeMissing(routineItems);
    final routineIds = await read(
      routineNotifierProvider.notifier,
    ).addMissingItems(routineItems);
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

  List<RoutineItem> routineItemsForHydration(
    OnboardingCompletionBundle bundle,
  ) {
    if (bundle.routineItemsForApp.isNotEmpty) {
      return bundle.routineItemsForApp;
    }
    return bundle.baseTimelineBlocks.map(_routineItemFromBlock).toList();
  }

  RoutineItem _routineItemFromBlock(TimelineBlockDraft block) {
    final blockType = block.blockType == TimelineBlockDraft.hardBlockKey
        ? RoutineBlockType.hardBlock
        : RoutineBlockType.softBlock;
    return RoutineItem(
      id: block.id,
      title: block.title.trim().isEmpty ? 'Onboarding block' : block.title,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      crossesMidnight: block.crossesMidnight,
      endsNextDay: block.endsNextDay,
      repeatDays: block.repeatDays,
      location: block.location,
      blockType: blockType,
      category: _categoryForSection(block.section),
      source: RoutineSource.onboarding,
      priority: blockType == RoutineBlockType.hardBlock
          ? RoutinePriority.mustDo
          : RoutinePriority.goodToDo,
      hardBlock: blockType == RoutineBlockType.hardBlock,
      notes: block.source,
      mealCategory: block.mealCategory,
      dishes: block.dishes,
      caloriesEstimate: block.calories,
      proteinEstimate: block.protein,
      skincareProducts: block.skincareProducts,
      steps: block.skincareProducts,
    );
  }

  RoutineCategory _categoryForSection(String section) {
    return switch (section) {
      'classes' => RoutineCategory.classBlock,
      'job_work_business' => RoutineCategory.job,
      'eating' => RoutineCategory.eating,
      'skin_care' => RoutineCategory.skinCare,
      'fixed' => RoutineCategory.fixed,
      _ => RoutineCategory.fixed,
    };
  }
}
