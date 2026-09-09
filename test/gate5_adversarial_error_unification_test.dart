import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/verification_lifecycle_state.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';

class _AdvTestAuthRepo
    implements AuthRepository, AuthProfileEnrichmentRepository {
  AuthUser? user;
  int reloadCount = 0;
  int sendEmailCount = 0;
  int signOutCount = 0;
  Object? reloadError;
  Object? resendError;
  Object? signOutError;
  Completer<void>? resendGate;
  Completer<void>? reloadGate;
  final authEvents = StreamController<AuthUser?>.broadcast();

  _AdvTestAuthRepo({required this.user});

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => authEvents.stream;

  @override
  Future<AuthUser> signIn(String email, String password) async => user!;

  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => user!;

  @override
  Future<AuthUser> signInAnonymously() async => user!;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => user!;

  @override
  Future<void> sendEmailVerification() async {
    sendEmailCount++;
    await resendGate?.future;
    if (resendError case final error?) throw error;
  }

  @override
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCount++;
    await reloadGate?.future;
    if (reloadError case final error?) throw error;
    return user;
  }

  @override
  Future<String?> currentIdToken() async => 'adv-fake-token';

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCount++;
    if (signOutError case final error?) throw error;
    user = null;
  }
}

class _AdvMutableClock {
  DateTime value = DateTime(2026, 6, 1, 12, 0, 0);
  DateTime call() => value;
  void advance(Duration duration) => value = value.add(duration);
}

const _testUser = AuthUser(
  uid: 'adv-user-42',
  email: 'adv-tester@example.com',
  emailVerified: false,
);

class _TestAdvAuthNotifier extends AuthNotifier {
  _TestAdvAuthNotifier(super.repository, super.ref, AuthState initialState) {
    state = initialState;
  }
}

Widget _buildAdvScreen({
  required _AdvTestAuthRepo repo,
  AuthState? state,
  DateTime Function()? now,
  VerificationLifecyclePolicy policy = const VerificationLifecyclePolicy(),
}) {
  final authState =
      state ??
      const AuthState(
        user: _testUser,
        status: AuthFlowStatus.signedInEmailUnverified,
        verificationEmailSendStatus: VerificationEmailSendStatus.sent,
      );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authProvider.overrideWith(
        (ref) => _TestAdvAuthNotifier(repo, ref, authState),
      ),
      verificationLifecyclePolicyProvider.overrideWithValue(policy),
      if (now != null) verificationClockProvider.overrideWithValue(now),
      userProfileProvider.overrideWith(
        (ref) => UserProfileNotifier()
          ..loadSeedData(
            UserProfile.empty(
              uid: authState.user?.uid ?? '',
              email: authState.user?.email ?? '',
            ),
          ),
      ),
    ],
    child: const MaterialApp(home: VerifyEmailScreen()),
  );
}

void main() {
  group('Adversarial Error Unification & State Isolation Tests', () {
    test(
      'Hypothesis 1: copyWith clearError and clearSuccessMessage are strictly independent',
      () {
        const sampleError1 = RecoverableError(
          category: RecoverableErrorCategory.network,
          publicMessage: 'Network error 1',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.networkUnavailable,
        );
        const sampleError2 = RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Rate limit error 2',
          severity: RecoverableErrorSeverity.warning,
          isBlocking: true,
          retryAction: RecoverableRetryAction.none,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.verifyEmailRateLimited,
        );

        const state = VerificationLifecycleState(
          error: sampleError1,
          successMessage: 'Success msg 1',
        );

        // 1. clearError only
        final stateClearError = state.copyWith(clearError: true);
        expect(stateClearError.error, isNull);
        expect(stateClearError.successMessage, 'Success msg 1');

        // 2. clearSuccessMessage only
        final stateClearSuccess = state.copyWith(clearSuccessMessage: true);
        expect(stateClearSuccess.error, sampleError1);
        expect(stateClearSuccess.successMessage, isNull);

        // 3. Clear both simultaneously
        final stateClearBoth = state.copyWith(
          clearError: true,
          clearSuccessMessage: true,
        );
        expect(stateClearBoth.error, isNull);
        expect(stateClearBoth.successMessage, isNull);

        // 4. Overriding error while clearError is false
        final stateNewError = state.copyWith(error: sampleError2);
        expect(stateNewError.error, sampleError2);
        expect(stateNewError.successMessage, 'Success msg 1');

        // 5. Passing new error takes precedence even if clearError is true
        final stateOverride = state.copyWith(
          clearError: true,
          error: sampleError2,
        );
        expect(stateOverride.error, sampleError2);
        expect(stateOverride.successMessage, 'Success msg 1');

        // 6. Passing new successMessage takes precedence even if clearSuccessMessage is true
        final stateOverrideSuccess = state.copyWith(
          clearSuccessMessage: true,
          successMessage: 'New success',
        );
        expect(stateOverrideSuccess.error, sampleError1);
        expect(stateOverrideSuccess.successMessage, 'New success');

        // 7. No-op copyWith preserves both fields
        final statePreserved = state.copyWith();
        expect(statePreserved.error, sampleError1);
        expect(statePreserved.successMessage, 'Success msg 1');
      },
    );

    testWidgets(
      'Hypothesis 2: showAccountError clears successMessage and sets typed error',
      (tester) async {
        final clock = _AdvMutableClock();
        final repo = _AdvTestAuthRepo(user: _testUser);
        await tester.pumpWidget(_buildAdvScreen(repo: repo, now: clock.call));
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VerifyEmailScreen)),
        );
        final controller = container.read(
          verificationLifecycleProvider.notifier,
        );

        // Seed a successMessage via resend
        await controller.resend();
        expect(
          container.read(verificationLifecycleProvider).successMessage,
          isNotNull,
        );
        expect(container.read(verificationLifecycleProvider).error, isNull);

        // Now call showAccountError with typed error
        const accountError = RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Account switch failure',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authMissingUser,
        );
        controller.showAccountError(accountError);

        final afterError = container.read(verificationLifecycleProvider);
        expect(afterError.error, accountError);
        expect(afterError.successMessage, isNull);

        // Clear the error: successMessage must NOT return
        controller.clearError();
        final afterClear = container.read(verificationLifecycleProvider);
        expect(afterClear.error, isNull);
        expect(afterClear.successMessage, isNull);
      },
    );

    testWidgets(
      'Hypothesis 3: Rapid concurrent resend requests collapse into single in-flight call',
      (tester) async {
        final clock = _AdvMutableClock();
        final repo = _AdvTestAuthRepo(user: _testUser)
          ..resendGate = Completer<void>();

        await tester.pumpWidget(_buildAdvScreen(repo: repo, now: clock.call));
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VerifyEmailScreen)),
        );
        final controller = container.read(
          verificationLifecycleProvider.notifier,
        );

        // Fire 10 concurrent resend requests in parallel while gate is open
        final futures = List.generate(10, (_) => controller.resend());

        expect(
          container.read(verificationLifecycleProvider).resendInFlight,
          isTrue,
        );
        expect(repo.sendEmailCount, 1);

        // Complete the in-flight gate
        repo.resendGate!.complete();
        await Future.wait(futures);

        expect(
          container.read(verificationLifecycleProvider).resendInFlight,
          isFalse,
        );
        expect(repo.sendEmailCount, 1);
        expect(
          container.read(verificationLifecycleProvider).resendSecondsRemaining,
          60,
        );
        expect(
          container.read(verificationLifecycleProvider).successMessage,
          'Sent again. Check Spam or Promotions if it doesn\'t arrive.',
        );
      },
    );

    testWidgets(
      'Hypothesis 4: Rate limit streaks cap at maximum throttle and reset upon success',
      (tester) async {
        final clock = _AdvMutableClock();
        final repo = _AdvTestAuthRepo(user: _testUser)
          ..resendError = AuthErrorMapper.map(Exception('too-many-requests'));

        await tester.pumpWidget(_buildAdvScreen(repo: repo, now: clock.call));
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VerifyEmailScreen)),
        );
        final controller = container.read(
          verificationLifecycleProvider.notifier,
        );

        // Policy throttle delays: [120, 240, 480, 900] -> clamped to 900
        final expectedSeconds = [120, 240, 480, 900, 900, 900];

        for (int i = 0; i < expectedSeconds.length; i++) {
          await controller.resend();
          final state = container.read(verificationLifecycleProvider);
          expect(state.resendThrottleStreak, i + 1);
          expect(state.resendSecondsRemaining, expectedSeconds[i]);
          expect(
            state.error?.diagnosticCode,
            DiagnosticCodes.verifyEmailRateLimited,
          );
          expect(state.successMessage, isNull);

          // Advance clock past throttle deadline and pump 1 second to advance timer
          clock.advance(Duration(seconds: expectedSeconds[i]));
          await tester.pump(const Duration(seconds: 1));
        }

        // Recover: Next resend succeeds
        repo.resendError = null;
        await controller.resend();
        final recovered = container.read(verificationLifecycleProvider);
        expect(recovered.resendThrottleStreak, 0);
        expect(recovered.resendSecondsRemaining, 60);
        expect(recovered.error, isNull);
        expect(recovered.successMessage, isNotNull);
      },
    );

    testWidgets(
      'Hypothesis 5: Expired session immediately halts all further polling',
      (tester) async {
        final clock = _AdvMutableClock();
        final repo = _AdvTestAuthRepo(user: _testUser)
          ..reloadError = AuthErrorMapper.map(Exception('auth-token-expired'));

        await tester.pumpWidget(_buildAdvScreen(repo: repo, now: clock.call));
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VerifyEmailScreen)),
        );
        final controller = container.read(
          verificationLifecycleProvider.notifier,
        );

        final state = container.read(verificationLifecycleProvider);
        expect(state.error?.category, RecoverableErrorCategory.authentication);
        expect(state.error?.retryAction, RecoverableRetryAction.reauthenticate);
        expect(
          state.error?.diagnosticCode,
          DiagnosticCodes.verifyEmailSessionExpired,
        );

        final initialReloadCount = repo.reloadCount;

        // Attempt manual check or resume
        await controller.checkNow(manual: true);
        controller.resume();

        // Advance clock significantly
        clock.advance(const Duration(minutes: 30));
        await tester.pump(const Duration(seconds: 1));

        // Assert reload count did not increase
        expect(repo.reloadCount, initialReloadCount);
      },
    );

    testWidgets(
      'Hypothesis 6: VerifyEmailScreen handles delivery failures and null errors cleanly',
      (tester) async {
        final repo = _AdvTestAuthRepo(user: _testUser);
        // Case A: Delivery failed without an active error
        const failedStateNoErr = AuthState(
          user: _testUser,
          status: AuthFlowStatus.signedInEmailUnverified,
          verificationEmailSendStatus: VerificationEmailSendStatus.failed,
          error: null,
        );

        await tester.pumpWidget(
          _buildAdvScreen(repo: repo, state: failedStateNoErr),
        );
        await tester.pump();

        expect(
          find.text('We couldn\'t send the verification link'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('verify-email-message-empty')),
          findsOneWidget,
        );

        // Clean unmount before Case B
        await tester.pumpWidget(const SizedBox.shrink());

        // Case B: Delivery failed with typed RecoverableError
        const typedDeliveryError = RecoverableError(
          category: RecoverableErrorCategory.network,
          publicMessage: 'Check your internet connection and try again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.networkUnavailable,
        );
        const failedStateWithErr = AuthState(
          user: _testUser,
          status: AuthFlowStatus.signedInEmailUnverified,
          verificationEmailSendStatus: VerificationEmailSendStatus.failed,
          error: typedDeliveryError,
        );

        await tester.pumpWidget(
          _buildAdvScreen(repo: repo, state: failedStateWithErr),
        );
        await tester.pump();

        expect(
          find.text('Check your internet connection and try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Hypothesis 7: VerifyEmailScreen prioritizes error over success if both exist',
      (tester) async {
        final repo = _AdvTestAuthRepo(user: _testUser);
        await tester.pumpWidget(_buildAdvScreen(repo: repo));
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VerifyEmailScreen)),
        );
        final controller = container.read(
          verificationLifecycleProvider.notifier,
        );

        // Trigger resend to get success message
        await controller.resend();
        await tester.pump();
        expect(
          find.text(
            'Sent again. Check Spam or Promotions if it doesn\'t arrive.',
          ),
          findsOneWidget,
        );

        // Directly publish an error via showAccountError
        const testErr = RecoverableError(
          category: RecoverableErrorCategory.cloudPersistence,
          publicMessage: 'Simulated backend outage',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.firestoreDraftWriteFailed,
        );
        controller.showAccountError(testErr);
        await tester.pump();

        // Error must be visible, success message must be gone
        expect(find.text('Simulated backend outage'), findsOneWidget);
        expect(
          find.text(
            'Sent again. Check Spam or Promotions if it doesn\'t arrive.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Hypothesis 8: VerifyEmailScreen handles unexpected logout exceptions gracefully',
      (tester) async {
        final repo = _AdvTestAuthRepo(user: _testUser)
          ..signOutError = StateError(
            'Unexpected memory corruption in native auth plugin',
          );

        await tester.pumpWidget(_buildAdvScreen(repo: repo));
        await tester.pump();

        final signOutButton = find.byKey(const Key('verify-email-sign-out'));
        await tester.ensureVisible(signOutButton);
        await tester.tap(signOutButton);
        await tester.pump(const Duration(milliseconds: 300));

        // App remains on VerifyEmailScreen and displays mapped error without crashing
        expect(find.text('Verify your email'), findsOneWidget);
        expect(
          find.text(
            'We couldn\'t sign you out. You are still signed in. Please try again.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Hypothesis 9: VerifyEmailScreen displays fallback when email is null or empty',
      (tester) async {
        const userWithoutEmail = AuthUser(
          uid: 'no-email-user',
          email: '',
          emailVerified: false,
        );
        final repo = _AdvTestAuthRepo(user: userWithoutEmail);
        const stateNoEmail = AuthState(
          user: userWithoutEmail,
          status: AuthFlowStatus.signedInEmailUnverified,
          verificationEmailSendStatus: VerificationEmailSendStatus.sent,
        );

        await tester.pumpWidget(
          _buildAdvScreen(repo: repo, state: stateNoEmail),
        );
        await tester.pump();

        expect(find.text('Email address unavailable'), findsOneWidget);
      },
    );
  });
}
