import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/screens/onboarding_recovery_screen.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  group('Empirical Verification: Fingerprint Check in completeOnboarding', () {
    test(
      'Fingerprint match returns noOp, fingerprint mismatch triggers re-projection',
      () async {
        final db = FakeRoutineDatabase();
        final repo = FakeOnboardingRepository(routineDatabase: db);
        const uid = 'emp-user-fingerprint';

        // 1. Initial draft & bundle
        final draft1 = OnboardingDraft(uid: uid).copyWith(
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
        );
        final bundle1 = OnboardingCompletionService.buildBundle(draft1);
        final plan1 = RoutineOnboardingProjection.build(bundle1);

        // First projection
        final result1 = await repo.completeOnboarding(
          finalDraft: draft1,
          bundle: bundle1,
        );
        expect(result1.outcome, equals(RoutineProjectionOutcome.projected));
        expect(
          result1.receipt.sourceBundleFingerprint,
          equals(plan1.fingerprint),
        );

        // Repeat projection with identical fingerprint -> expect noOp
        final result2 = await repo.completeOnboarding(
          finalDraft: draft1,
          bundle: bundle1,
        );
        expect(result2.outcome, equals(RoutineProjectionOutcome.noOp));
        expect(
          result2.receipt.sourceBundleFingerprint,
          equals(plan1.fingerprint),
        );

        // 2. Modify draft (add a good habit) to alter fingerprint
        final draft2 = draft1.copyWith(
          goodHabits: [
            const GoodHabitDraft(
              id: 'gh-emp-1',
              habitKey: 'meditation',
              displayName: 'Daily Meditation',
              durationMinutes: 15,
            ),
          ],
        );
        final bundle2 = OnboardingCompletionService.buildBundle(draft2);
        final plan2 = RoutineOnboardingProjection.build(bundle2);

        expect(plan2.fingerprint, isNot(equals(plan1.fingerprint)));

        // Call completeOnboarding with modified fingerprint
        final result3 = await repo.completeOnboarding(
          finalDraft: draft2,
          bundle: bundle2,
        );

        // Empirical check: Must return projected (NOT noOp) and update fingerprint
        expect(result3.outcome, equals(RoutineProjectionOutcome.projected));
        expect(
          result3.receipt.sourceBundleFingerprint,
          equals(plan2.fingerprint),
        );
      },
    );
  });

  group('Empirical Verification: Router Redirect for needsAction', () {
    testWidgets(
      'Router redirects needsAction to /onboarding/recovery and renders OnboardingRecoveryScreen',
      (tester) async {
        final profile =
            UserProfile.empty(
              uid: 'emp-failed-user',
              email: 'emp-failed@ex.com',
            ).copyWith(
              onboardingInputCompleted: true,
              onboardingProjectionStatus: 'failed',
            );

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              (ref) => _EmpiricalFakeAuthNotifier(
                const AuthState(
                  user: AuthUser(
                    uid: 'emp-failed-user',
                    email: 'emp-failed@ex.com',
                    emailVerified: true,
                  ),
                  status: AuthFlowStatus.needsAction,
                  error: RecoverableError(
                    category: RecoverableErrorCategory.recoveryRequired,
                    publicMessage:
                        'Empirical verification error in restoration',
                    severity: RecoverableErrorSeverity.error,
                    isBlocking: true,
                    retryAction: RecoverableRetryAction.restartRecovery,
                    retrySafe: false,
                    diagnosticCode:
                        DiagnosticCodes.recoveryDurableStateConflict,
                  ),
                ),
              ),
            ),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()..loadSeedData(profile),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, child) {
                return MaterialApp.router(
                  routerConfig: ref.watch(routerProvider),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Empirical check: OnboardingRecoveryScreen MUST be rendered
        expect(find.byType(OnboardingRecoveryScreen), findsOneWidget);
      },
    );
  });
}

class _EmpiricalFakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _EmpiricalFakeAuthNotifier(super.state);

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}

  @override
  Future<void> checkEmailVerification() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<bool> signInWithGoogle() async => false;

  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}

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

  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
}
