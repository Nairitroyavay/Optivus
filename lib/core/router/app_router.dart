import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/auth_choice_screen.dart';
import '../../views/screens/verify_email_screen.dart';
import '../../views/screens/loading_screen.dart';
import '../../views/screens/app_shell.dart';
import '../../features/recovery/screens/onboarding_recovery_screen.dart';
import '../../features/recovery/screens/onboarding_startup_status_screens.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../state/auth_state.dart';
import '../../app/app_navigation_controller.dart';
import '../../features/tracker/providers/tracker_navigation_provider.dart';
import '../../features/profile/providers/profile_navigation_provider.dart';
import '../../features/routine/providers/routine_navigation_provider.dart';
import '../../features/coach/providers/coach_navigation_provider.dart';
import '../../features/goals/providers/goals_navigation_provider.dart';
import '../../features/home/providers/home_navigation_provider.dart';
import '../../services/session_destination_resolver.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

@visibleForTesting
String? optivusAuthRedirect({required AuthState authState, required Uri uri}) {
  final isSignedOutRoute =
      uri.path == '/login' || uri.path.startsWith('/signup') || uri.path == '/';
  final destination = authState.sessionDestination;

  return switch (destination.kind) {
    SessionDestinationKind.resolving =>
      (isSignedOutRoute && authState.user == null) || uri.path == '/loading'
          ? null
          : '/loading',
    SessionDestinationKind.signedOut => isSignedOutRoute ? null : '/',
    SessionDestinationKind.verifyEmail =>
      uri.path == '/verify-email' ? null : '/verify-email',
    SessionDestinationKind.freshOnboarding ||
    SessionDestinationKind.resumeOnboarding =>
      uri.path == '/onboarding' ? null : '/onboarding',
    SessionDestinationKind.finishOnboarding =>
      uri.path == '/onboarding/finishing' ? null : '/onboarding/finishing',
    SessionDestinationKind.reconnect =>
      uri.path == '/onboarding/reconnect' ? null : '/onboarding/reconnect',
    SessionDestinationKind.needsAction =>
      uri.path == '/onboarding/needs-action'
          ? null
          : '/onboarding/needs-action',
    SessionDestinationKind.home =>
      isSignedOutRoute ||
              uri.path == '/loading' ||
              uri.path.startsWith('/onboarding') ||
              uri.path == '/verify-email'
          ? '/app?tab=0'
          : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  String openTrackerDetail(TrackerDetailView detail) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).goToTracker();
      ref.read(trackerDetailViewRequestProvider.notifier).state =
          TrackerDetailTarget.view(detail);
    });
    return '/app?tab=2';
  }

  String openHomeDetail(HomeDetailTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).goToHome();
      ref.read(homeDetailViewRequestProvider.notifier).state = target;
    });
    return '/app?tab=0';
  }

  String openProfileDetail(ProfileDetailView detail) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).goToProfile();
      ref.read(profileDetailViewRequestProvider.notifier).state =
          ProfileDetailTarget(view: detail);
    });
    return '/app?tab=5';
  }

  String openRoutineDetail(RoutineDetailTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).goToRoutine();
      ref.read(routineDetailViewRequestProvider.notifier).state = target;
    });
    return '/app?tab=1';
  }

  String openCoachDetail(CoachDetailView detail) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).goToCoach();
      ref.read(coachDetailViewRequestProvider.notifier).state = detail;
    });
    return '/app?tab=3';
  }

  String openGoalsDetail(GoalsDetailTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).goToGoals();
      ref.read(goalsDetailViewRequestProvider.notifier).state = target;
    });
    return '/app?tab=4';
  }

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/loading',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      return optivusAuthRedirect(authState: authState, uri: state.uri);
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const AuthChoiceScreen(),
      ),
      GoRoute(
        path: '/signup/create',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlow(),
      ),
      GoRoute(
        path: '/onboarding/finishing',
        builder: (context, state) => const FinishingOnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding/reconnect',
        builder: (context, state) => const OnboardingReconnectScreen(),
      ),
      GoRoute(
        path: '/onboarding/needs-action',
        builder: (context, state) => const OnboardingRecoveryScreen(),
      ),
      GoRoute(
        path: '/onboarding/recovery',
        redirect: (context, state) => '/onboarding/needs-action',
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) {
          final requestedTab = int.tryParse(
            state.uri.queryParameters['tab'] ?? '',
          );
          return AppShell(initialIndex: requestedTab ?? 0);
        },
      ),
      GoRoute(path: '/home', redirect: (context, state) => '/app'),
      GoRoute(
        path: '/home/mission',
        redirect: (context, state) =>
            openHomeDetail(const HomeDetailTarget.mission()),
      ),
      GoRoute(
        path: '/tracker/money',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.money),
      ),
      GoRoute(
        path: '/tracker/fitness',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.fitness),
      ),
      GoRoute(
        path: '/tracker/screen-time',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.screenTime),
      ),
      GoRoute(
        path: '/tracker/meditation',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.meditation),
      ),
      GoRoute(
        path: '/tracker/hydration',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.hydration),
      ),
      GoRoute(
        path: '/tracker/settings',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.trackerSettings),
      ),
      GoRoute(
        path: '/tracker/activation',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.trackerActivation),
      ),
      GoRoute(
        path: '/tracker/history',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.trackerHistory),
      ),
      GoRoute(
        path: '/tracker/focus',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.focusTimer),
      ),
      GoRoute(
        path: '/tracker/bad-habit',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.badHabit),
      ),
      GoRoute(
        path: '/tracker/sleep',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.sleep),
      ),
      GoRoute(
        path: '/tracker/nutrition',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.nutrition),
      ),
      GoRoute(
        path: '/tracker/global-money-setup',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.globalMoneySetup),
      ),
      GoRoute(
        path: '/tracker/usage-access',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.usageAccessSetup),
      ),
      GoRoute(
        path: '/tracker/health-connect',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.healthConnectSetup),
      ),
      GoRoute(
        path: '/tracker/location-mapbox',
        redirect: (context, state) =>
            openTrackerDetail(TrackerDetailView.locationMapboxSetup),
      ),
      GoRoute(
        path: '/profile/edit',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.editProfile),
      ),
      GoRoute(
        path: '/profile/system-setup',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.systemSetup),
      ),
      GoRoute(
        path: '/profile/notifications',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.notificationSettings),
      ),
      GoRoute(
        path: '/profile/permissions',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.permissionsDataSources),
      ),
      GoRoute(
        path: '/profile/connected-services',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.connectedServices),
      ),
      GoRoute(
        path: '/profile/preferences',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.appPreferences),
      ),
      GoRoute(
        path: '/profile/region',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.regionLocalization),
      ),
      GoRoute(
        path: '/profile/privacy',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.privacySecurity),
      ),
      GoRoute(
        path: '/profile/data-control',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.dataControl),
      ),
      GoRoute(
        path: '/profile/export',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.exportData),
      ),
      GoRoute(
        path: '/profile/delete-selected-data',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.deleteSelectedData),
      ),
      GoRoute(
        path: '/profile/delete-account',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.deleteAccountRequest),
      ),
      GoRoute(
        path: '/profile/archived-identities',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.archivedIdentities),
      ),
      GoRoute(
        path: '/profile/report-bug',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.reportBug),
      ),
      GoRoute(
        path: '/profile/help',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.helpCenter),
      ),
      GoRoute(
        path: '/profile/about',
        redirect: (context, state) =>
            openProfileDetail(ProfileDetailView.aboutVersion),
      ),
      GoRoute(
        path: '/routine/base-timeline',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(
            view: RoutineDetailView.baseTimeline,
          ),
        ),
      ),
      GoRoute(
        path: '/routine/classes',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.classesSetup),
        ),
      ),
      GoRoute(
        path: '/routine/work',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.workSetup),
        ),
      ),
      GoRoute(
        path: '/routine/eating',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.eatingSetup),
        ),
      ),
      GoRoute(
        path: '/routine/fixed',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.fixedSetup),
        ),
      ),
      GoRoute(
        path: '/routine/skin-care',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.skinCareSetup),
        ),
      ),
      GoRoute(
        path: '/routine/import-review',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.baseTimeline),
        ),
      ),
      GoRoute(
        path: '/routine/settings',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.routineSettings),
        ),
      ),
      GoRoute(
        path: '/routine/habit-systems',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.habitSystems),
        ),
      ),
      GoRoute(
        path: '/routine/history',
        redirect: (context, state) => openRoutineDetail(
          const RoutineDetailTarget(view: RoutineDetailView.routineHistory),
        ),
      ),
      GoRoute(
        path: '/coach/history',
        redirect: (context, state) =>
            openCoachDetail(CoachDetailView.sessionHistory),
      ),
      GoRoute(
        path: '/coach/settings',
        redirect: (context, state) =>
            openCoachDetail(CoachDetailView.coachSettings),
      ),
      GoRoute(
        path: '/coach/new-session',
        redirect: (context, state) =>
            openCoachDetail(CoachDetailView.newSession),
      ),
      GoRoute(
        path: '/coach/privacy-data',
        redirect: (context, state) =>
            openCoachDetail(CoachDetailView.privacyData),
      ),
      GoRoute(
        path: '/goals/add',
        redirect: (context, state) => openGoalsDetail(
          const GoalsDetailTarget(view: GoalsDetailView.addGoal),
        ),
      ),
      GoRoute(
        path: '/goals/detail',
        redirect: (context, state) => openGoalsDetail(
          const GoalsDetailTarget(view: GoalsDetailView.goalDetail),
        ),
      ),
      GoRoute(
        path: '/goals/weekly-review',
        redirect: (context, state) => openGoalsDetail(
          const GoalsDetailTarget(view: GoalsDetailView.weeklyReview),
        ),
      ),
      GoRoute(
        path: '/goals/archived',
        redirect: (context, state) => openGoalsDetail(
          const GoalsDetailTarget(view: GoalsDetailView.archivedGoals),
        ),
      ),
      GoRoute(
        path: '/goals/settings',
        redirect: (context, state) => openGoalsDetail(
          const GoalsDetailTarget(view: GoalsDetailView.goalSettings),
        ),
      ),
    ],
  );
});
