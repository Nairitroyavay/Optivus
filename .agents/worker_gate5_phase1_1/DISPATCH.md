# Task Assignment: Phase 1 Structured Error Unification & Static Architecture (R1, R2, R3, R6)

Your working directory is: `/Users/avayroy/Optivus/.agents/worker_gate5_phase1_1`
You are a worker agent (`teamwork_preview_worker`).

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- MANDATORY: Read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
- Read `/Users/avayroy/Optivus/.agents/orchestrator_gate5_1/AUDIT_TABLE.md`.
- Read `/Users/avayroy/Optivus/.agents/explorer_gate5_01/handoff.md` and `/Users/avayroy/Optivus/.agents/explorer_gate5_03/handoff.md`.

## Exclusive Write Ownership
You own and may edit ONLY these files:
- `lib/state/verification_lifecycle_state.dart`
- `lib/views/screens/verify_email_screen.dart`
- `test/verify_email_redesign_test.dart`
- `test/gate5_static_architecture_test.dart`

Do NOT edit any other file without explicit orchestration authorization.

## Instructions
1. **Update `VerificationLifecycleState` (`lib/state/verification_lifecycle_state.dart`)**:
   - Delete `enum VerificationMessageKind` completely.
   - Remove `final String? message;` and `final VerificationMessageKind? messageKind;`.
   - Add:
     ```dart
     final RecoverableError? error;
     final String? successMessage;
     ```
   - Keep all operational state:
     - `foreground`, `checking`, `resendInFlight`, `verificationConfirmed`
     - `nextResendAllowedAt`, `nextVerificationCheckAllowedAt`
     - `resendSecondsRemaining`, `verificationThrottleStreak`, `resendThrottleStreak`
   - In `copyWith`, add independent `bool clearError = false` and `bool clearSuccessMessage = false`.
   - In `_performCheck`: catch block maps error via `AuthErrorMapper.mapVerifyEmailError(error, isResend: false)` and sets `state = state.copyWith(error: mapped, clearSuccessMessage: true)`.
   - In `_performResend`:
     - Success sets `successMessage: 'Sent again. Check Spam or Promotions if it doesn\'t arrive.'` and `clearError: true`.
     - Failure maps error via `AuthErrorMapper.mapVerifyEmailError(error, isResend: true)` and sets `state = state.copyWith(error: mapped, clearSuccessMessage: true)`.
   - Replace `showAccountError(String message)` with `void showAccountError(RecoverableError error)`:
     ```dart
     void showAccountError(RecoverableError error) {
       if (!_disposed) {
         state = state.copyWith(error: error, clearSuccessMessage: true);
       }
     }
     ```
   - Add helper methods `clearError()` and `clearSuccessMessage()`.

2. **Update `VerifyEmailScreen` (`lib/views/screens/verify_email_screen.dart`)**:
   - In `_logout()`:
     ```dart
     Future<void> _logout() async {
       if (ref.read(authProvider).isLoading) return;
       final controller = ref.read(verificationLifecycleProvider.notifier)
         ..clearError()
         ..clearSuccessMessage();
       try {
         await ref.read(authProvider.notifier).logout();
       } catch (_) {
         if (mounted) {
           final authError = ref.read(authProvider).error;
           if (authError != null) {
             controller.showAccountError(authError);
           }
         }
       }
     }
     ```
   - In `build()`:
     - Compute active error and success message:
       ```dart
       final deliveryFailed =
           auth.verificationEmailSendStatus == VerificationEmailSendStatus.failed;
       final activeError = lifecycle.error ?? (deliveryFailed ? auth.error : null);
       final messageError = activeError?.publicMessage;
       final successMessage = activeError == null ? lifecycle.successMessage : null;
       ```
     - Pass `error: messageError` and `success: successMessage` to `_StableMessageRegion`.
     - Eliminate any switches or checks on legacy `messageKind`.

3. **Update `test/verify_email_redesign_test.dart`**:
   - Update line 780 to expect `'We couldn\'t sign you out. You are still signed in. Please try again.'`.
   - Update lines 1094–1165 and any other tests asserting on `messageKind` or `VerificationMessageKind` to assert on `lifecycle.error` (e.g. `diagnosticCode`, `category`, `publicMessage`) and `lifecycle.successMessage`.

4. **Implement `test/gate5_static_architecture_test.dart`**:
   - Test all R6 invariants:
     - 0 active occurrences of `mockUserProfileProvider` in `lib/`
     - 0 active occurrences of `mockOnboardingProvider` in `lib/`
     - 0 active occurrences of `backendRestoreFailed` in `lib/`
     - `RouterNotifier` listens only to `authProvider`
     - Router redirect reads `AuthState.sessionDestination` and does NOT choose destination from profile/onboarding/completion providers
     - Verify Email: 0 `VerificationMessageKind`, 0 `messageKind`, 0 `showAccountError(String`, 0 hard-coded `'Couldn\'t sign out. Please try again.'` string literal
     - Auth identity reset delegates through `AuthSessionResetCoordinator`
     - Session inventory: all providers in Gate-5 inventory have valid classification.

5. **Verification**:
   - Run `dart format --output=none --set-exit-if-changed lib/state/verification_lifecycle_state.dart lib/views/screens/verify_email_screen.dart test/verify_email_redesign_test.dart test/gate5_static_architecture_test.dart`
   - Run `flutter analyze lib/state/verification_lifecycle_state.dart lib/views/screens/verify_email_screen.dart test/verify_email_redesign_test.dart test/gate5_static_architecture_test.dart`
   - Run `flutter test test/verify_email_redesign_test.dart test/gate5_static_architecture_test.dart`
   - Run all Gate 5 focused tests to ensure zero regressions.

Write your handoff report to `/Users/avayroy/Optivus/.agents/worker_gate5_phase1_1/handoff.md` including exact commands run and results.

## 2026-09-09T04:11:53Z
You are worker_gate5_phase1_1. Your working directory is /Users/avayroy/Optivus/.agents/worker_gate5_phase1_1.
Read your instructions in /Users/avayroy/Optivus/.agents/worker_gate5_phase1_1/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
Exclusive write ownership:
- lib/state/verification_lifecycle_state.dart
- lib/views/screens/verify_email_screen.dart
- test/verify_email_redesign_test.dart
- test/gate5_static_architecture_test.dart
Implement Phase 1: Structured Error Unification & Static Architecture (R1, R2, R3, R6).
Run format, analyze, and tests.
Write your handoff report to /Users/avayroy/Optivus/.agents/worker_gate5_phase1_1/handoff.md and report back via send_message.

