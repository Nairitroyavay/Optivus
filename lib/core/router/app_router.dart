import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../views/screens/welcome_screen.dart';
import '../../views/screens/login_screen.dart';
import '../../views/screens/signup_screen.dart';
import '../../views/screens/loading_screen.dart';
import '../../views/screens/app_shell.dart';
import '../../features/onboarding/onboarding_flow.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/loading',
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
