import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/views/screens/app_shell.dart';
import 'package:optivus/views/screens/loading_screen.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/views/screens/welcome_screen.dart';

void main() {
  testWidgets(
    'signed-out users stay on Welcome for onboarding, app, and deep links',
    (tester) async {
      final harness = await _pumpRouter(
        tester,
        authState: const AuthState(status: AuthFlowStatus.signedOut),
        onboardingCompleted: false,
      );

      _expectDestination(harness, '/', WelcomeScreen);

      for (final protectedLocation in const [
        '/onboarding',
        '/app?tab=2',
        '/tracker/money',
      ]) {
        await harness.go(tester, protectedLocation);
        _expectDestination(harness, '/', WelcomeScreen);
        expect(find.byType(OnboardingFlow), findsNothing);
        expect(find.byType(AppShell), findsNothing);
      }
    },
  );

  testWidgets(
    'unverified users are held at verification for setup and app routes',
    (tester) async {
      final harness = await _pumpRouter(
        tester,
        authState: const AuthState(
          user: AuthUser(
            uid: 'unverified-user',
            email: 'unverified@example.com',
            emailVerified: false,
          ),
          status: AuthFlowStatus.signedInEmailUnverified,
        ),
        onboardingCompleted: false,
      );

      _expectDestination(harness, '/verify-email', VerifyEmailScreen);

      for (final protectedLocation in const [
        '/onboarding',
        '/app?tab=0',
        '/goals/detail',
      ]) {
        await harness.go(tester, protectedLocation);
        _expectDestination(harness, '/verify-email', VerifyEmailScreen);
        expect(find.byType(OnboardingFlow), findsNothing);
        expect(find.byType(AppShell), findsNothing);
      }
    },
  );

  testWidgets('unresolved verified-user restoration renders only Loading', (
    tester,
  ) async {
    final harness = await _pumpRouter(
      tester,
      authState: const AuthState(
        user: AuthUser(
          uid: 'restoring-user',
          email: 'restoring@example.com',
          emailVerified: true,
        ),
        status: AuthFlowStatus.restoringOnboarding,
      ),
      onboardingCompleted: false,
    );

    _expectDestination(harness, '/loading', LoadingScreen);
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.byType(AppShell), findsNothing);

    await harness.go(tester, '/app?tab=4');
    _expectDestination(harness, '/loading', LoadingScreen);
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.byType(AppShell), findsNothing);
    }
  });

  testWidgets(
    'verified incomplete users enter onboarding and cannot enter the app',
    (tester) async {
      final harness = await _pumpRouter(
        tester,
        authState: const AuthState(
          user: AuthUser(
            uid: 'incomplete-user',
            email: 'incomplete@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
        onboardingCompleted: false,
      );

      _expectDestination(harness, '/onboarding', OnboardingFlow);

      await harness.go(tester, '/app?tab=5');
      _expectDestination(harness, '/onboarding', OnboardingFlow);
      expect(find.byType(AppShell), findsNothing);
    },
  );

  testWidgets(
    'verified completed users enter the app and cannot re-enter onboarding',
    (tester) async {
      final harness = await _pumpRouter(
        tester,
        authState: const AuthState(
          user: AuthUser(
            uid: 'complete-user',
            email: 'complete@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingComplete,
        ),
        onboardingCompleted: true,
      );

      _expectDestination(harness, '/app', AppShell);

      await harness.go(tester, '/onboarding');
      _expectDestination(harness, '/app', AppShell);
      expect(find.byType(OnboardingFlow), findsNothing);
    },
  );

  testWidgets('logout returns a completed user to Welcome', (tester) async {
    final harness = await _pumpRouter(
      tester,
      authState: const AuthState(
        user: AuthUser(
          uid: 'logout-user',
          email: 'logout@example.com',
          emailVerified: true,
        ),
        status: AuthFlowStatus.signedInOnboardingComplete,
      ),
      onboardingCompleted: true,
    );
    _expectDestination(harness, '/app', AppShell);

    await harness.container.read(authProvider.notifier).logout();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    _expectDestination(harness, '/', WelcomeScreen);
    expect(find.byType(AppShell), findsNothing);
  });
}

class _RouterHarness {
  const _RouterHarness(this.container);

  final ProviderContainer container;

  GoRouter get router => container.read(routerProvider);

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_RouterHarness> _pumpRouter(
  WidgetTester tester, {
  required AuthState authState,
  required bool onboardingCompleted,
}) async {
  final profile = UserProfile.empty(
    uid: authState.user?.uid ?? '',
    email: authState.user?.email ?? '',
    displayName: authState.user?.displayName ?? '',
  ).copyWith(onboardingCompleted: onboardingCompleted);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith((ref) => _TestAuthNotifier(authState)),
      mockUserProfileProvider.overrideWith(
        (ref) => MockUserProfileNotifier()..loadSeedData(profile),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          return MaterialApp.router(routerConfig: ref.watch(routerProvider));
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return _RouterHarness(container);
}

void _expectDestination(
  _RouterHarness harness,
  String expectedPath,
  Type visibleScreen,
) {
  expect(
    harness.router.routerDelegate.currentConfiguration.uri.path,
    expectedPath,
  );
  expect(find.byType(visibleScreen), findsOneWidget);
}

class _TestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _TestAuthNotifier(super.state);

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}

  @override
  Future<void> checkEmailVerification() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthFlowStatus.signedOut);
  }

  @override
  Future<void> markOnboardingComplete(AuthUser user) async {}

  @override
  Future<void> markOnboardingIncomplete(AuthUser user) async {}

  @override
  Future<void> resendEmailVerification() async {}

  @override
  Future<void> retryBackendRestore() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signup(String name, String email, String password) async {}

  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
}
