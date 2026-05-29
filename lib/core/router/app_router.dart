import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/loading_screen.dart';
import '../../views/screens/app_shell.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../state/auth_state.dart';
import '../../state/app_state.dart';
import '../../features/tracker/money/money_system_screen.dart';
import '../../features/tracker/screen_time/screen_time_screen.dart';
import '../../features/tracker/meditation/meditation_tracker_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) => notifyListeners());
    _ref.listen(mockUserProfileProvider, (previous, next) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/loading',
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      final isAuthRoute =
          state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/' ||
          state.uri.path == '/loading';

      // Still loading (auth check not complete / mock delay)
      if (authState.isLoading) return null;

      // 1. Not signed in -> restricted to auth routes
      if (!authState.isLoggedIn) {
        return isAuthRoute ? null : '/';
      }

      // 2. Signed in but onboarding not complete -> restricted to onboarding
      final onboardingCompleted = ref
          .read(mockUserProfileProvider)
          .onboardingCompleted;
      if (!onboardingCompleted || authState.onboardingIncomplete) {
        if (state.uri.path != '/onboarding') return '/onboarding';
        return null;
      }

      // 3. Signed in & onboarding complete -> redirect away from auth/onboarding
      if (isAuthRoute || state.uri.path == '/onboarding') {
        return '/app?tab=0';
      }

      return null;
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
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlow(),
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
        path: '/tracker/money',
        builder: (context, state) => const MoneySystemScreen(),
      ),
      GoRoute(
        path: '/tracker/screen-time',
        builder: (context, state) => const ScreenTimeScreen(),
      ),
      GoRoute(
        path: '/tracker/meditation',
        builder: (context, state) => const MeditationTrackerScreen(),
      ),
    ],
  );
});
