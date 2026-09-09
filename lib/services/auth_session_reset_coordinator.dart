import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/utils/liquid_toast_manager.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/goals/providers/goals_navigation_provider.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/providers/home_navigation_provider.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Owns the synchronous in-memory privacy boundary for sign-out and UID
/// changes. Operation-specific generation counters remain with their owning
/// controllers; this coordinator only invalidates user/session-scoped state.
class AuthSessionResetCoordinator {
  AuthSessionResetCoordinator(this._ref);

  final Ref _ref;

  void resetIdentityBoundary({String? preserveOnboardingUid}) {
    _ref.read(authGenerationProvider.notifier).state++;
    _ref.invalidate(onboardingCompletionJobServiceProvider);
    _ref.invalidate(onboardingCompletionJobProvider);
    _ref.read(recoveryRetryControllerProvider.notifier).resetForSignedOut();
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(trackerSessionLinksProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
    _ref.read(userProfileProvider.notifier).resetForSignedOut();
    if (preserveOnboardingUid == null ||
        _ref.read(onboardingStateProvider).draft.uid != preserveOnboardingUid) {
      _ref.read(onboardingStateProvider.notifier).resetForSignedOut();
    }
    _ref.invalidate(onboardingClassTimelineProvider);
    _ref.invalidate(onboardingWorkTimelineProvider);
    _ref.read(profileSettingsProvider.notifier).resetForSignedOut();
    _ref.read(homeDashboardProvider.notifier).resetForSignedOut();
    _ref.read(fitnessCenterProvider.notifier).resetForSignedOut();
    _ref.read(trackerSettingsProvider.notifier).resetForSignedOut();
    _ref.read(routineImportAiControllerProvider.notifier).resetForSignedOut();
    _ref.read(uploadControllerProvider.notifier).resetForSignedOut();
    _ref.invalidate(onboardingUploadInteractionProvider);
    _ref.read(restoredUploadsProvider.notifier).resetForSignedOut();
    _ref.read(aiRoutineSuggestionsEnabledProvider.notifier).state = true;
    _ref.read(conflictResolverEnabledProvider.notifier).state = true;
    _ref.read(routineNotificationsEnabledProvider.notifier).state = true;
    _ref.read(appNavigationProvider.notifier).resetForSignedOut();
    _ref.read(toastQueueProvider.notifier).resetForSignedOut();
    _ref.read(homeDetailViewRequestProvider.notifier).state =
        const HomeDetailTarget.none();
    _ref.read(trackerDetailViewRequestProvider.notifier).state =
        TrackerDetailTarget.none;
    _ref.read(profileDetailViewRequestProvider.notifier).state =
        ProfileDetailTarget.none;
    _ref.read(routineDetailViewRequestProvider.notifier).state =
        RoutineDetailTarget.none;
    _ref.read(coachDetailViewRequestProvider.notifier).state =
        CoachDetailView.none;
    _ref.read(goalsDetailViewRequestProvider.notifier).state =
        GoalsDetailTarget.none;
    _ref.read(regionSettingsProvider.notifier).resetForSignedOut();
    resetFeatureStateForHydration();
  }

  /// Clears feature projections before a known owner is hydrated. Profile and
  /// Onboarding are intentionally excluded because their owner-scoped seed or
  /// draft has already been selected by the caller.
  void resetFeatureStateForHydration() {
    _ref.read(mockRoutineProvider.notifier).resetForSignedOut();
    _ref.read(mockTrackerProvider.notifier).resetForSignedOut();
    _ref.read(mockGoalProvider.notifier).resetForSignedOut();
    _ref.read(mockMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(homeMindNoteProvider.notifier).resetForSignedOut();
    _ref.read(mockCoachProvider.notifier).resetForSignedOut();
    _ref.read(mockCoachPreferencesProvider.notifier).resetForSignedOut();
    _ref.read(mockNotificationPreferencesProvider.notifier).resetForSignedOut();
    _ref.read(mockPermissionProvider.notifier).resetForSignedOut();
  }

  /// Clears canonical projection state before authoritative backend hydration.
  /// Used during same-owner reconstruction so incoming backend records do not
  /// merge with stale in-memory projections.
  void prepareForAuthoritativeHydration() {
    _ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    _ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
  }
}

final authSessionResetCoordinatorProvider = Provider(
  AuthSessionResetCoordinator.new,
);
