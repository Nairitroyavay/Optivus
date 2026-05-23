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

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
    _ref.listen(mockUserProfileProvider, (_, __) => notifyListeners());
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
      final isAuth = authState.isLoggedIn;
      
      final isAuthRoute = state.uri.path == '/login' || 
                          state.uri.path == '/signup' || 
                          state.uri.path == '/' || 
                          state.uri.path == '/loading';

      // Still loading (auth check not complete / mock delay)
      if (authState.isLoading) return null;

      // 1. Not signed in -> restricted to auth routes
      if (!isAuth) {
        return isAuthRoute ? null : '/';
      }

      // 2. Signed in but onboarding not complete -> restricted to onboarding
      final onboardingCompleted = ref.read(mockUserProfileProvider).onboardingCompleted;
      if (!onboardingCompleted) {
        if (state.uri.path != '/onboarding') return '/onboarding';
        return null;
      }

      // 3. Signed in & onboarding complete -> redirect away from auth/onboarding
      if (isAuthRoute || state.uri.path == '/onboarding') {
        return '/app';
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
          return AppShell(initialIndex: requestedTab ?? 1);
        },
      ),
      GoRoute(path: '/home', redirect: (context, state) => '/app'),
    ],
  );
});
