import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';

typedef OptivusProviderReader = T Function<T>(ProviderListenable<T> provider);

class RecoveryCacheManager {
  const RecoveryCacheManager();

  Future<void> clearCachePreservingDirtyEdits({
    required OptivusProviderReader read,
    required String uid,
  }) async {
    final currentDraft = read(mockOnboardingProvider).draft;
    final dirtySteps = List<bool>.from(currentDraft.stepDirty);
    final hasUnpushedEdits = dirtySteps.contains(true);

    OnboardingDraft? preservedDraft;
    if (hasUnpushedEdits && currentDraft.uid == uid) {
      preservedDraft = currentDraft;
    }

    // Clear stale memory repositories while preserving dirty draft edits
    read(routineNotifierProvider.notifier).resetForSignedOut();
    read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
    read(mockTrackerProvider.notifier).resetEmpty();
    read(mockGoalProvider.notifier).resetEmpty();
    read(mockMindNoteProvider.notifier).resetEmpty();
    read(mockCoachProvider.notifier).resetEmpty();

    if (preservedDraft != null) {
      read(mockOnboardingProvider.notifier).loadSeedData(preservedDraft);
    } else {
      read(mockOnboardingProvider.notifier).reset(uid);
    }
  }
}

final recoveryCacheManagerProvider = Provider(
  (ref) => const RecoveryCacheManager(),
);
