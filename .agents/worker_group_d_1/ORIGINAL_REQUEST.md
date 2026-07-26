## 2026-07-25T15:00:00Z
You are the Worker subagent for Group D (Issues 16–21: Authentication & account lifecycle) of Optivus Onboarding Stabilization.

Working directory: /Users/roy/optivus2/Optivus/.agents/worker_group_d_1
Handoff path: /Users/roy/optivus2/Optivus/.agents/worker_group_d_1/handoff.md
Explorer handoff report: /Users/roy/optivus2/Optivus/.agents/explorer_group_d_1/handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope: Implement Group D (Issues 16, 17, 18, 19, 20, 21)
1. Issue 16: Auth state stream synchronization across Riverpod and GoRouter
   - Fix `AuthNotifier` constructor to remove duplicate microtask `_handleAuthStateChange` invocation.
   - Align GoRouter `redirect` logic in `app_router.dart` to use `authState.status` and `userProfile` deterministically without transient redirect loops.

2. Issue 17: User sign-out state invalidation for all cached feature controllers
   - Add `resetForSignedOut()` methods to `HomeDashboardNotifier`, `HomeMindNoteNotifier`, `FitnessCenterNotifier`, `TrackerSettingsNotifier`, `RoutineImportAiController`, `UploadController`, `AppNavigationController`, and navigation detail request providers.
   - Update `AuthNotifier._resetSignedOutState()` and `_resetUserScopedMockState()` to execute comprehensive sign-out sweep across all feature controllers.

3. Issue 18: Account switching data leak prevention across user scopes
   - Execute immediate atomic `_resetSignedOutState()` at the start of `_loadOrCreateBackendUserState` before starting remote async fetches.
   - Add explicit `_ownerUid` matching guards across all feature controllers to reject cross-user mutations.

4. Issue 19: Typed auth failure mapping for network interruptions and invalid tokens
   - Introduce `AuthFailureReason` enum and `AuthFailureException` class.
   - Update `friendlyAuthError` in `auth_error_mapper.dart` and `AuthRepository` implementations to throw/map typed `AuthFailureException`.
   - Add `failureReason: AuthFailureReason?` to `AuthState` for programmatic UI failure handling.

5. Issue 20: Email verification step enforcement before post-onboarding navigation
   - Enforce `!_needsEmailVerification(user)` in `AuthNotifier.markOnboardingComplete`, `OnboardingFlow._completeOnboarding()`, and GoRouter `redirect`.
   - Prevent unverified email/password users from completing onboarding or entering `/app?tab=0`.

6. Issue 21: Anonymous-to-authenticated account link state preservation
   - Add `signInAnonymously()` and `linkAnonymousWithEmail(String email, String password, {String? name})` contracts to `AuthRepository`, `FirebaseAuthRepository`, and `FakeAuthRepository`.
   - Implement `OnboardingAccountMigrationService` to migrate anonymous draft profile, routine projections, habit systems, and preferences to newly linked account UID without data loss.

7. Testing & Verification:
   - Create `test/group_d_issues_16_to_21_test.dart` covering all 6 issues with unit and widget tests.
   - Run `dart format --output=none --set-exit-if-changed .` (or apply `dart format .` as needed).
   - Run `flutter analyze` to ensure 0 errors, 0 warnings, 0 lints.
   - Run `flutter test test/group_d_issues_16_to_21_test.dart` and `flutter test`.

8. Living Report Update:
   - Update `docs/onboarding_stabilization_report.md` for Issues 16, 17, 18, 19, 20, 21:
     Set Status: `PASSED`, and fill out Root Cause, Files Inspected, Files Changed, Fix Implemented, Targeted Tests, Regression Tests, Runtime Verification, Re-audit Result, and Evidence for all 6 issues.

9. Write your handoff report to `/Users/roy/optivus2/Optivus/.agents/worker_group_d_1/handoff.md` and send a message back to the orchestrator.
