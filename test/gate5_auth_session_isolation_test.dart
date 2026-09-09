import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

const _userA = AuthUser(
  uid: 'gate5-a',
  email: 'a@example.com',
  emailVerified: true,
);
const _userB = AuthUser(
  uid: 'gate5-b',
  email: 'b@example.com',
  emailVerified: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical Auth session destination and router matrix', () {
    const authenticatedUid = 'gate5-user';
    final cases = <AuthFlowStatus, (SessionDestinationKind, String)> {
      AuthFlowStatus.loading: (SessionDestinationKind.resolving, '/loading'),
      AuthFlowStatus.signedOut: (SessionDestinationKind.signedOut, '/'),
      AuthFlowStatus.signedInEmailUnverified: (
        SessionDestinationKind.verifyEmail,
        '/verify-email',
      ),
      AuthFlowStatus.signedInOnboardingIncomplete: (
        SessionDestinationKind.freshOnboarding,
        '/onboarding',
      ),
      AuthFlowStatus.finishingOnboarding: (
        SessionDestinationKind.finishOnboarding,
        '/onboarding/finishing',
      ),
      AuthFlowStatus.signedInOnboardingComplete: (
        SessionDestinationKind.home,
        '/app?tab=0',
      ),
      AuthFlowStatus.reconnectRequired: (
        SessionDestinationKind.reconnect,
        '/onboarding/reconnect',
      ),
      AuthFlowStatus.needsAction: (
        SessionDestinationKind.needsAction,
        '/onboarding/needs-action',
      ),
    };

    for (final entry in cases.entries) {
      final signedOut = entry.key == AuthFlowStatus.signedOut;
      final state = AuthState(
        user: signedOut
            ? null
            : const AuthUser(uid: authenticatedUid, emailVerified: true),
        status: entry.key,
      );
      expect(state.sessionDestination.kind, entry.value.$1);
      expect(
        optivusAuthRedirect(authState: state, uri: Uri.parse('/login')),
        entry.value.$2 == '/'
            ? isNull
            : entry.value.$2,
      );
    }

    const resumeState = AuthState(
      user: AuthUser(uid: authenticatedUid, emailVerified: true),
      status: AuthFlowStatus.signedInOnboardingIncomplete,
      resumeStep: 7,
    );
    expect(
      resumeState.sessionDestination,
      isA<SessionDestination>().having(
        (value) => value.resumeStep,
        'resumeStep',
        7,
      ),
    );
  });

  test('destination presentation mapping round-trips semantically', () {
    const destinations = <SessionDestination>[
      SessionDestination.resolving(),
      SessionDestination.signedOut(),
      SessionDestination.verifyEmail(),
      SessionDestination.freshOnboarding(),
      SessionDestination.resumeOnboarding(6),
      SessionDestination.finishOnboarding(runId: 'run-5'),
      SessionDestination.home(),
      SessionDestination.reconnect(reasonCode: 'offline'),
      SessionDestination.needsAction('durable_conflict'),
    ];

    for (final destination in destinations) {
      final status = authFlowStatusForDestination(destination);
      final resolved = resolveAuthSessionDestination(
        status: status,
        userUid: destination.kind == SessionDestinationKind.signedOut
            ? null
            : 'gate5-user',
        resumeStep: destination.resumeStep,
        completionRunId: destination.runId,
        startupReasonCode: destination.reasonCode,
        reconstructionResult: null,
      );
      expect(resolved.kind, destination.kind);
      expect(resolved.resumeStep, destination.resumeStep);
      expect(resolved.runId, destination.runId);
      expect(resolved.reasonCode, destination.reasonCode);
    }
  });

  test('AuthErrorMapper parity exposes safe structured fields', () {
    final cases = <Object, String>{
      Exception('invalid-credential'): DiagnosticCodes.authInvalidCredentials,
      Exception('invalid-email'): DiagnosticCodes.authInvalidEmail,
      Exception('weak-password'): DiagnosticCodes.authWeakPassword,
      Exception('email-already-in-use'): DiagnosticCodes.authEmailInUse,
      Exception('account-exists-with-different-credential'):
          DiagnosticCodes.authAccountCollision,
      Exception('too-many-requests'): DiagnosticCodes.authRateLimited,
      Exception('user-disabled'): DiagnosticCodes.authUserDisabled,
      const SocketException('secret host'): DiagnosticCodes.networkUnavailable,
      TimeoutException('RAW_SECRET_TIMEOUT'): DiagnosticCodes.networkTimeout,
      Exception('invalid-user-token'): DiagnosticCodes.authSessionExpired,
      Exception('requires-recent-login'):
          DiagnosticCodes.authRequiresRecentLogin,
      Exception('RAW_SECRET_UNKNOWN'): DiagnosticCodes.authUnknown,
    };

    for (final entry in cases.entries) {
      final mapped = AuthErrorMapper.map(entry.key);
      expect(mapped.diagnosticCode, entry.value);
      expect(mapped.publicMessage, isNotEmpty);
      expect(mapped.publicMessage, isNot(contains('RAW_SECRET')));
      expect(mapped.toString(), isNot(contains('RAW_SECRET')));
      expect(mapped.retryAction, isA<RecoverableRetryAction>());
    }
  });

  test('A to B clears A state before Auth first publishes B', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider);
    repository.emitUserForTesting(_userA);
    await pumpEventQueue(times: 30);

    container
        .read(userProfileProvider.notifier)
        .loadSeedData(UserProfile.empty(uid: _userA.uid));
    container
        .read(onboardingStateProvider.notifier)
        .loadSeedData(OnboardingDraft(uid: _userA.uid));
    container.read(mockGoalProvider.notifier).loadSeedData();
    container.read(appNavigationProvider.notifier).goToProfile();

    var observedB = false;
    final subscription = container.listen<AuthState>(authProvider, (_, next) {
      if (observedB || next.user?.uid != _userB.uid) return;
      observedB = true;
      expect(container.read(userProfileProvider).uid, isNot(_userA.uid));
      expect(container.read(onboardingStateProvider).draft.uid, isNot(_userA.uid));
      expect(container.read(mockGoalProvider), isEmpty);
      expect(container.read(appNavigationProvider), 0);
    });
    addTearDown(subscription.close);

    repository.emitUserForTesting(_userB);
    await pumpEventQueue(times: 30);
    expect(observedB, isTrue);
    expect(container.read(authProvider).user?.uid, _userB.uid);
    expect(container.read(userProfileProvider).uid, _userB.uid);
    expect(container.read(onboardingStateProvider).draft.uid, _userB.uid);
  });
}
