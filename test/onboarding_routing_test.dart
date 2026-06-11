import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  testWidgets('Router redirects to onboarding if onboarding is incomplete', (tester) async {
    final mockAuth = const AuthState(
      user: AuthUser(uid: 'test-uid', email: 'test@example.com'),
      status: AuthFlowStatus.signedInOnboardingIncomplete,
    );

    final mockUserProfile = UserProfile.empty(
      uid: 'test-uid',
      email: 'test@example.com',
      displayName: 'Test User',
    ).copyWith(onboardingCompleted: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockAuth)),
          mockUserProfileProvider.overrideWith((ref) => MockUserProfileNotifier()..loadSeedData(mockUserProfile)),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/onboarding');
  });

  testWidgets('Router redirects to app if onboarding is complete', (tester) async {
    final mockAuth = const AuthState(
      user: AuthUser(uid: 'test-uid', email: 'test@example.com'),
      status: AuthFlowStatus.signedInOnboardingComplete,
    );

    final mockUserProfile = UserProfile.empty(
      uid: 'test-uid',
      email: 'test@example.com',
      displayName: 'Test User',
    ).copyWith(onboardingCompleted: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockAuth)),
          mockUserProfileProvider.overrideWith((ref) => MockUserProfileNotifier()..loadSeedData(mockUserProfile)),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/app');
  });
}

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(AuthState state) : super(state);

  @override
  Future<void> checkEmailVerification() async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}

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
}
