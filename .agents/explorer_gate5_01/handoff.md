# Gate 5 Audit Report: Error Unification, Verify Email & Static Invariants

**Agent**: `explorer_gate5_01`  
**Working Directory**: `/Users/avayroy/Optivus/.agents/explorer_gate5_01`  
**Date**: 2026-09-09  
**Handoff Type**: Hard (Task Complete)

---

## Executive Summary

This read-only investigation audits Error Unification, Verify Email failure/presentation contracts, and Static Invariants (R1, R2, R3, R6) for Optivus Gate 5 final closure. 

Key discoveries:
1. **Provider / Symbol Renames (R1)**: Confirmed 0 active usages of `mockUserProfileProvider`, `mockOnboardingProvider`, and `backendRestoreFailed` in `lib/` and `test/`. However, no static regression test exists to prevent their reintroduction.
2. **Session Destination Authority (R2)**: `SessionDestinationResolver` is the sole destination authority. `AuthNotifier.statusFor()` is purely a credential-level coarse classifier; `RouterNotifier` exclusively listens to `authProvider` and routes on `AuthState.sessionDestination`.
3. **Verify Email Parallel Taxonomy Defect (R3)**: `VerificationLifecycleState` introduces a parallel enum `VerificationMessageKind` and string `String? message`, conflicting with the canonical `RecoverableError` architecture. `showAccountError(String message)` takes an untyped string, and `verify_email_screen.dart:63` swallows the typed `AuthState.error` from `AuthNotifier.logout()` to inject a hardcoded string (`Couldn't sign out. Please try again.`).
4. **Report / Enum Matrix Parity Defect (R3)**: `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section G lists non-existent categories (`rateLimit`, `backend`) and an action (`waitAndRetry`), and misdocuments mappings for `too-many-requests`, `email-already-in-use`, and `user-not-found`/`wrong-password`.
5. **Static Invariants Enforcement (R6)**: No centralized static test currently guards the architectural invariants (R1, R2, R3, R6) across `lib/` and `test/`.

---

## Mandatory Pre-Editing Audit Table

| AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX |
|---|---|---|---|---|---|---|---|
| **Verify Email State Failure Taxonomy** | `VerificationLifecycleState` in `lib/state/verification_lifecycle_state.dart` | `state.messageKind` (`VerificationMessageKind?`) and `state.message` (`String?`) | `USER_SCOPED_AUTO_DISPOSE` | `autoDispose` on screen exit; `_expectedUid` check on `AuthState` change; `_stopSession()` on sign out | Parallel failure taxonomy (`VerificationMessageKind`) and string error authority (`String? message`), bypassing `RecoverableError`. `copyWith` lacks independent `clearError` and `clearSuccessMessage` flags. | Replace `VerificationMessageKind` and `String? message` with `RecoverableError? error` and `String? successMessage`. Add `clearError` and `clearSuccessMessage` to `copyWith`. Map failures through `AuthErrorMapper.mapVerifyEmailError()`. | Static architecture test verifying 0 `VerificationMessageKind` and 0 `messageKind` in `lib/` and `test/`. Unit tests in `test/verify_email_redesign_test.dart`. |
| **Verify Email Screen Logout Error** | `VerifyEmailScreen._logout()` in `lib/views/screens/verify_email_screen.dart:63` | Screen-local controller error message via `showAccountError` | `SESSION_UI_RESET` | `controller.clearMessage()`, screen unmount | In `_logout()`, `catch (_)` swallows the typed `RecoverableError` stored in `AuthState.error` by `AuthNotifier.logout()` and hardcodes `'Couldn\'t sign out. Please try again.'`. | Replace hardcoded string in `_logout()` catch block by reading the canonical typed error from `ref.read(authProvider).error` and passing it to typed `showAccountError(RecoverableError error)` (or letting UI read `auth.error`). | Static architecture test banning `'Couldn\'t sign out. Please try again.'` string literal. Widget test in `test/verify_email_redesign_test.dart` asserting canonical message `'We couldn\'t sign you out. You are still signed in. Please try again.'`. |
| **Verify Email Presentation API** | `VerificationLifecycleController.showAccountError()` in `lib/state/verification_lifecycle_state.dart:446` | `state.message` and `state.messageKind` | `USER_SCOPED_AUTO_DISPOSE` | Screen unmount / `autoDispose` | `showAccountError(String message)` takes a raw `String`, creating an untyped error entrypoint into the lifecycle controller. | Replace with `void showAccountError(RecoverableError error)` that sets `state = state.copyWith(error: error, clearSuccessMessage: true)`. | Static architecture test banning `void showAccountError(String` signature. |
| **Verify Email Message Region** | `VerifyEmailScreen` lines 90–106 and `_StableMessageRegion` lines 524–568 in `verify_email_screen.dart` | Rendered message derived from `lifecycle.messageKind` and `lifecycle.message` | `SESSION_UI_RESET` | Widget rebuild | UI switches on `lifecycle.messageKind != VerificationMessageKind.success` and renders `lifecycle.message`, preserving parallel failure taxonomy. | Update `VerifyEmailScreen` to pass `error: lifecycle.error?.publicMessage ?? (deliveryFailed ? auth.errorMessage : null)` and `success: lifecycle.successMessage` to `_StableMessageRegion`. | Widget tests in `test/verify_email_redesign_test.dart` verifying error and success rendering from `lifecycle.error` and `lifecycle.successMessage`. |
| **Auth Flow Status vs Destination Authority** | `AuthNotifier.statusFor()` in `lib/state/auth_state.dart:910` vs `SessionDestinationResolver` in `lib/services/session_destination_resolver.dart:55` | `AuthState.status` (`AuthFlowStatus`) | `USER_SCOPED_RESET` | `AuthSessionResetCoordinator.resetIdentityBoundary()` + `_authOperationGeneration` | Conceptual ambiguity: `statusFor()` only classifies credential facts (`signedOut`, `signedInEmailUnverified`, `signedInOnboardingComplete`, `signedInOnboardingIncomplete`), but must never decide dynamic runtime session destinations (`resumeOnboarding`, `finishOnboarding`, `reconnect`, `needsAction`). | Document invariant in `auth_state.dart` and `session_destination_resolver.dart`. Enforce statically that `app_router.dart` consumes `AuthState.sessionDestination` exclusively. | Static architecture test verifying `RouterNotifier` listens only to `authProvider`, router redirect reads only `authState.sessionDestination`, and 0 router dependencies exist on profile/onboarding/completion providers. |
| **Structured Error Report Parity** | `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section G | None (Documentation artifact) | `NOT_USER_SCOPED` | N/A | Section G claims nonexistent enum values `RecoverableErrorCategory.rateLimit`, `RecoverableErrorCategory.backend`, and `RecoverableRetryAction.waitAndRetry`. In addition, `email-already-in-use` is mislabeled `validation` instead of `authentication`, and `user-not-found` is mislabeled `reauthenticate` instead of `retry`. | Reconcile Section G of `GATE_5_AUTH_CLEANUP_REPORT.md` to reflect the 12 actual `RecoverableErrorCategory` and 11 actual `RecoverableRetryAction` enums and actual `AuthErrorMapper` / `ReconstructionErrorMapper` mappings. | Static documentation verification test or code audit assertion checking report matrix against enum declarations. |
| **Mock Provider & Retired Symbol Invariants** | Codebase wide references to `mockUserProfileProvider`, `mockOnboardingProvider`, `backendRestoreFailed` | None (Symbols retired) | `NOT_USER_SCOPED` | N/A | Symbols have 0 active usages in `lib/` and `test/`, but there is no static enforcement test guarding against accidental reintroduction. | Create `test/gate5_static_architecture_test.dart` asserting 0 matches of `mockUserProfileProvider`, `mockOnboardingProvider`, and `backendRestoreFailed` across all files in `lib/`. | New test `test/gate5_static_architecture_test.dart` (test passes on clean tree; will fail if symbol is added). |
| **Auth Operation Domain Error Authority** | `login_screen.dart:153` and `signup_screen.dart:269, 322` | `_errorMsg` (`String?`) in local screen state | `SESSION_UI_RESET` | Form field listeners clear `_errorMsg` on text input | Potential risk of UI code handling auth failures with arbitrary strings instead of `RecoverableError`. Currently Login and Signup correctly delegate operation catches to `AuthErrorMapper.map(error).publicMessage`. | Preserve form validation strings for synchronous UI checks, but retain strict rule that all asynchronous operations delegate failure mapping through `AuthErrorMapper`. | Unit tests in `test/ah_f003_google_auth_test.dart` and `test/gate5_auth_session_isolation_test.dart`. |

---

## 1. Observation

### 1.1 Provider Renaming & Retired Symbol Invariants (R1)
- Search for `mockUserProfileProvider`:
  - `lib/`: 0 results
  - `test/`: 0 results
- Search for `mockOnboardingProvider`:
  - `lib/`: 0 results
  - `test/`: 0 results
- Search for `backendRestoreFailed`:
  - `lib/`: 0 results
  - `test/`: 0 results
- Observation: Both provider renames are completely adopted. `backendRestoreFailed` is completely retired.

### 1.2 Router Dependencies and Destination Policy (R2)
- In `lib/core/router/app_router.dart`:
  ```dart
  // Lines 25-31:
  class RouterNotifier extends ChangeNotifier {
    final Ref _ref;

    RouterNotifier(this._ref) {
      _ref.listen(authProvider, (previous, next) => notifyListeners());
    }
  }
  ```
  `RouterNotifier` listens **only** to `authProvider`. There are 0 dependencies on `userProfileProvider`, `onboardingStateProvider`, completion providers, or reconstruction providers.
- In `lib/core/router/app_router.dart`:
  ```dart
  // Lines 36-40:
  String? optivusAuthRedirect({required AuthState authState, required Uri uri}) {
    final isSignedOutRoute =
        uri.path == '/login' || uri.path.startsWith('/signup') || uri.path == '/';
    final destination = authState.sessionDestination;
  ```
  Router redirect consumes `authState.sessionDestination`.
- In `lib/state/auth_state.dart`:
  ```dart
  // Lines 172-181:
  SessionDestination get sessionDestination {
    return resolveAuthSessionDestination(
      status: status,
      userUid: user?.uid,
      resumeStep: resumeStep,
      completionRunId: completionRunId,
      startupReasonCode: startupReasonCode,
      reconstructionResult: reconstructionResult,
    );
  }
  ```
  `AuthState.sessionDestination` delegates to `resolveAuthSessionDestination`.
- In `lib/state/auth_state.dart`:
  ```dart
  // Lines 910-918:
  static AuthFlowStatus statusFor(AuthUser? user, bool onboardingCompleted) {
    if (user == null) return AuthFlowStatus.signedOut;
    if (_needsEmailVerification(user)) {
      return AuthFlowStatus.signedInEmailUnverified;
    }
    return onboardingCompleted
        ? AuthFlowStatus.signedInOnboardingComplete
        : AuthFlowStatus.signedInOnboardingIncomplete;
  }
  ```
  `statusFor()` is purely a static helper classifying credential-level status. It does not decide destination, step, runId, or recovery.

### 1.3 Verify Email State and Presentation Defects (R3)
- In `lib/state/verification_lifecycle_state.dart`:
  ```dart
  // Lines 10-16:
  enum VerificationMessageKind {
    network,
    rateLimited,
    sessionExpired,
    firebaseFailure,
    success,
  }

  // Lines 28-29:
  final String? message;
  final VerificationMessageKind? messageKind;

  // Lines 446-453:
  void showAccountError(String message) {
    if (!_disposed) {
      state = state.copyWith(
        message: message,
        messageKind: VerificationMessageKind.firebaseFailure,
      );
    }
  }
  ```
  `VerificationMessageKind` creates a parallel taxonomy.
- In `lib/views/screens/verify_email_screen.dart`:
  ```dart
  // Lines 55-66:
  Future<void> _logout() async {
    if (ref.read(authProvider).isLoading) return;
    final controller = ref.read(verificationLifecycleProvider.notifier)
      ..clearMessage();
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      if (mounted) {
        controller.showAccountError('Couldn\'t sign out. Please try again.');
      }
    }
  }
  ```
  Notice:
  1. `catch (_)` swallows the real failure.
  2. In `lib/state/auth_state.dart:610-618`, `logout()` publishes:
     ```dart
     final mapped = AuthErrorMapper.map(error);
     state = state.copyWith(
       error: mapped.copyWith(
         publicMessage:
             'We couldn\'t sign you out. You are still signed in. Please try again.',
       ),
     );
     rethrow;
     ```
  3. `verify_email_screen.dart:63` overrides this with the hardcoded string `'Couldn\'t sign out. Please try again.'`.
  4. In `test/verify_email_redesign_test.dart:780`, the test expects this hardcoded string rather than the canonical error.
- In `lib/views/screens/verify_email_screen.dart`:
  ```dart
  // Lines 90-106:
  final isError =
      lifecycle.messageKind != null &&
      lifecycle.messageKind != VerificationMessageKind.success;
  final deliveryFailed =
      auth.verificationEmailSendStatus == VerificationEmailSendStatus.failed;
  ...
  final messageError = isError
      ? lifecycle.message
      : deliveryFailed
      ? auth.errorMessage
      : null;
  ```
  Presentation logic relies on `messageKind` rather than checking `lifecycle.error`.

### 1.4 RecoverableError Enum Discrepancy in GATE_5_AUTH_CLEANUP_REPORT.md
- In `lib/core/errors/recoverable_error.dart`:
  - Categories (12 total):
    `validation`, `network`, `authentication`, `permission`, `upload`, `aiTimeout`, `aiQuota`, `aiMalformedResponse`, `cloudPersistence`, `conflict`, `recoveryRequired`, `completionRetry`.
    **Note**: Neither `rateLimit` nor `backend` exists.
  - Actions (11 total):
    `none`, `retry`, `retryUpload`, `retryGeneration`, `retrySave`, `reauthenticate`, `openSettings`, `chooseAnother`, `returnToStep`, `resumeCompletion`, `restartRecovery`.
    **Note**: `waitAndRetry` does not exist.
- In `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section G:
  ```markdown
  | `email-already-in-use` | `AUTH_EMAIL_ALREADY_IN_USE` | `validation` | `none` | `false` |
  | `too-many-requests` | `AUTH_TOO_MANY_REQUESTS` | `rateLimit` | `waitAndRetry` | `true` |
  | Server reconstruction failure | `AUTH_RECONSTRUCTION_FAILED` | `backend` | `retry` | `true` |
  | `user-not-found` | `AUTH_USER_NOT_FOUND` | `authentication` | `reauthenticate` | `false` |
  | `wrong-password` | `AUTH_WRONG_PASSWORD` | `authentication` | `reauthenticate` | `false` |
  ```
- In `lib/core/errors/auth_error_mapper.dart`:
  - `too-many-requests` maps to:
    `category: RecoverableErrorCategory.authentication`  
    `retryAction: RecoverableRetryAction.none`  
    `retrySafe: false`  
    `diagnosticCode: DiagnosticCodes.authRateLimited`
  - `email-already-in-use` maps to:
    `category: RecoverableErrorCategory.authentication`  
    `retryAction: RecoverableRetryAction.reauthenticate`  
    `retrySafe: false`  
    `diagnosticCode: DiagnosticCodes.authEmailInUse`
  - `user-not-found` / `wrong-password` maps to:
    `category: RecoverableErrorCategory.authentication`  
    `retryAction: RecoverableRetryAction.retry`  
    `retrySafe: true`  
    `diagnosticCode: DiagnosticCodes.authInvalidCredentials`
  - Server reconstruction failure maps through `ReconstructionErrorMapper`:
    - `fromBootstrapException`: `network` (`retryAction: retry`) or `authentication` (`retryAction: reauthenticate`)
    - `fromRecoveryReason`: `recoveryRequired` (`retryAction: restartRecovery`)

---

## 2. Logic Chain

1. **Premise**: Optivus architectural rules mandate a single typed error model (`RecoverableError`) and forbid parallel failure taxonomies in feature controllers.
2. **Observation**: `VerificationLifecycleState` declares `VerificationMessageKind` with values `network`, `rateLimited`, `sessionExpired`, `firebaseFailure`, `success`, and exposes `String? message`.
3. **Inference**: This parallel taxonomy bypasses `RecoverableError`, duplicates categorization, and prevents presentation code from uniformly accessing `RecoverableError.publicMessage`, `diagnosticCode`, `retryAction`, and `severity`.
4. **Conclusion**: `VerificationMessageKind` and `String? message` must be removed from `VerificationLifecycleState` and replaced with:
   ```dart
   final RecoverableError? error;
   final String? successMessage;
   ```
5. **Premise**: `AuthNotifier.logout()` publishes a typed `RecoverableError` with `publicMessage: 'We couldn\'t sign you out. You are still signed in. Please try again.'` to `AuthState.error`.
6. **Observation**: `verify_email_screen.dart:63` calls `controller.showAccountError('Couldn\'t sign out. Please try again.')`, ignoring `ref.read(authProvider).error`.
7. **Inference**: Hardcoding error strings in UI widgets breaks error source-of-truth, prevents localization/diagnostic tracking, and introduces inconsistent error messages.
8. **Conclusion**: `_logout()` must read `ref.read(authProvider).error` and pass it to a typed `showAccountError(RecoverableError error)` method, or the screen must render `auth.error?.publicMessage`.
9. **Premise**: Architectural documentation must reflect the exact compilable source truth.
10. **Observation**: `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section G lists non-existent enum members (`rateLimit`, `backend`, `waitAndRetry`) and inaccurate mappings.
11. **Conclusion**: Section G must be updated with the exact enum values from `recoverable_error.dart` and exact mapping logic from `auth_error_mapper.dart`.
12. **Premise**: Requirements R1, R2, R3, R6 specify static architectural invariants that must be verified by automated tests.
13. **Observation**: No centralized static architecture test exists in `test/` enforcing these constraints.
14. **Conclusion**: A dedicated test `test/gate5_static_architecture_test.dart` must be added to enforce these invariants permanently.

---

## 3. Caveats

- **Scope Boundary**: As a read-only explorer subagent, no production code edits have been made in this phase.
- **Form Validation Strings in Login/Signup**: `login_screen.dart` and `signup_screen.dart` contain local validation strings (e.g. `'Please enter your email address.'`) for synchronous pre-submit client checks. These are presentation/form state, not domain operation failures, and do not violate `RecoverableError` authority because all asynchronous network/auth failures in both screens delegate exclusively to `AuthErrorMapper.map(error)`.
- **Pre-existing tests asserting old strings**: `test/verify_email_redesign_test.dart` lines 780 and 1094–1165 currently assert `VerificationMessageKind` and the literal `'Couldn\'t sign out. Please try again.'`. When the implementation agent fixes the production contract, these test assertions must be updated to expect the new typed contract and canonical message.

---

## 4. Conclusion & Recommended Implementation Plan

### Recommended Implementation Steps for the Implementer

#### Step 1: Update `VerificationLifecycleState` (`lib/state/verification_lifecycle_state.dart`)
1. Remove `enum VerificationMessageKind`.
2. Update `VerificationLifecycleState`:
   ```dart
   class VerificationLifecycleState {
     final bool foreground;
     final bool checking;
     final bool resendInFlight;
     final bool verificationConfirmed;
     final DateTime? nextResendAllowedAt;
     final DateTime? nextVerificationCheckAllowedAt;
     final int resendSecondsRemaining;
     final int verificationThrottleStreak;
     final int resendThrottleStreak;
     final RecoverableError? error;
     final String? successMessage;
     ...
   ```
3. Update `copyWith`:
   - Replace `bool clearMessage = false` with `bool clearError = false` and `bool clearSuccessMessage = false`.
4. In `_performCheck`:
   - Catch block maps error with `AuthErrorMapper.mapVerifyEmailError(error, isResend: false)`.
   - Sets `state = state.copyWith(error: mapped, clearSuccessMessage: true)`.
5. In `_performResend`:
   - Success sets `successMessage: 'Sent again. Check Spam or Promotions if it doesn\'t arrive.'`, `clearError: true`.
   - Failure sets `error: mapped`, `clearSuccessMessage: true`.
6. Update `showAccountError`:
   ```dart
   void showAccountError(RecoverableError error) {
     if (!_disposed) {
       state = state.copyWith(error: error, clearSuccessMessage: true);
     }
   }
   ```
7. Add `clearError()` and `clearSuccessMessage()` methods to controller.

#### Step 2: Update `VerifyEmailScreen` (`lib/views/screens/verify_email_screen.dart`)
1. In `_logout()`:
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
2. In `build()`:
   - Compute error and success directly:
     ```dart
     final deliveryFailed =
         auth.verificationEmailSendStatus == VerificationEmailSendStatus.failed;
     final activeError = lifecycle.error ?? (deliveryFailed ? auth.error : null);
     final messageError = activeError?.publicMessage;
     final successMessage = activeError == null ? lifecycle.successMessage : null;
     ```
   - Pass `error: messageError` and `success: successMessage` to `_StableMessageRegion`.

#### Step 3: Update `test/verify_email_redesign_test.dart`
1. Line 780: update expectation to `'We couldn\'t sign you out. You are still signed in. Please try again.'`.
2. Lines 1094–1165: update assertions to verify `lifecycle.error?.diagnosticCode`, `lifecycle.error?.category`, and `lifecycle.successMessage` instead of `lifecycle.messageKind`.

#### Step 4: Add `test/gate5_static_architecture_test.dart`
Create a static scanner test verifying:
1. `mockUserProfileProvider`: 0 occurrences in `lib/`
2. `mockOnboardingProvider`: 0 occurrences in `lib/`
3. `backendRestoreFailed`: 0 occurrences in `lib/`
4. `VerificationMessageKind`: 0 occurrences in `lib/` and `test/`
5. `messageKind`: 0 occurrences in `lib/state/verification_lifecycle_state.dart` and `lib/views/screens/verify_email_screen.dart`
6. `showAccountError(String`: 0 occurrences in `lib/`
7. `RouterNotifier`: listens only to `authProvider`
8. `optivusAuthRedirect`: consumes `authState.sessionDestination`
9. `AuthSessionResetCoordinator`: is called by `AuthNotifier` for identity resets.

#### Step 5: Update `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section G
Update the table to reflect:
```markdown
| Exception / Condition | Diagnostic Code | Category | Retry Action | Retry Safe |
|---|---|---|---|---|
| `network-request-failed` | `NETWORK_UNAVAILABLE` | `network` | `retry` | `true` |
| `user-not-found` / `wrong-password` | `AUTH_INVALID_CREDENTIALS` | `authentication` | `retry` | `true` |
| `email-already-in-use` | `AUTH_EMAIL_IN_USE` | `authentication` | `reauthenticate` | `false` |
| `too-many-requests` | `AUTH_RATE_LIMITED` | `authentication` | `none` | `false` |
| Verify Email rate limited | `VERIFY_EMAIL_RATE_LIMITED` | `authentication` | `none` | `false` |
| Verify Email session expired | `VERIFY_EMAIL_SESSION_EXPIRED` | `authentication` | `reauthenticate` | `false` |
| Server reconstruction network failure | `NETWORK_UNAVAILABLE` | `network` | `retry` | `true` |
| Server reconstruction auth failure | `AUTH_SESSION_EXPIRED` | `authentication` | `reauthenticate` | `false` |
| Server reconstruction recovery required | `RECOVERY_*` | `recoveryRequired` | `restartRecovery` | `false` |
```

---

## 5. Verification Method

To independently verify these findings:

1. **Check 0 Mock / Retired Symbols**:
   ```bash
   grep -rn "mockUserProfileProvider" lib/ test/
   grep -rn "mockOnboardingProvider" lib/ test/
   grep -rn "backendRestoreFailed" lib/ test/
   ```
   Expected: 0 matches.

2. **Check VerificationMessageKind in current source**:
   ```bash
   grep -rn "VerificationMessageKind" lib/ test/
   ```
   Expected: 14 matches in `lib/state/verification_lifecycle_state.dart`, 1 match in `lib/views/screens/verify_email_screen.dart`, 6 matches in `test/verify_email_redesign_test.dart`.

3. **Check Hardcoded Logout Error in verify_email_screen.dart**:
   ```bash
   grep -rn "Couldn't sign out. Please try again." lib/ test/
   ```
   Expected: 1 match in `lib/views/screens/verify_email_screen.dart:63`, 1 match in `test/verify_email_redesign_test.dart:780`.

4. **Check RouterNotifier single listener**:
   Inspect `lib/core/router/app_router.dart:28-30` to verify `_ref.listen(authProvider, ...)`.

5. **Run Existing Gate 5 Tests**:
   ```bash
   flutter test test/gate5_auth_session_isolation_test.dart
   flutter test test/verify_email_redesign_test.dart
   ```
   (Note: `verify_email_redesign_test.dart` passes today with the old `messageKind` assertions, but will fail once the static test and typed model are introduced, requiring the test updates outlined in Step 3).
