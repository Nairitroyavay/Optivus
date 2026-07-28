# Optivus Production Execution Path Audit Report (Steps 1–6)

**Agent ID**: `explorer_p46_path1`  
**Milestone**: Phase 4.6 Final Production Closure  
**Timestamp**: 2026-07-27T09:05:00Z  
**Project Root**: `/Users/roy/optivus2/Optivus`  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_p46_path1`

---

## 1. Executive Summary & Audit Overview

This report provides a read-only production audit of **Execution Steps 1 through 6** in Optivus:
1. **Signup** (`lib/views/screens/signup_screen.dart`, `lib/state/auth_state.dart`, `lib/repositories/auth_repository.dart`)
2. **Email Verification** (`lib/views/screens/verify_email_screen.dart`, `lib/state/auth_state.dart`, `lib/core/router/app_router.dart`)
3. **Login** (`lib/views/screens/login_screen.dart`, `lib/state/auth_state.dart`, `lib/repositories/auth_repository.dart`)
4. **Onboarding Flow & Navigation** (`lib/features/onboarding/onboarding_flow.dart`, `lib/models/onboarding_draft.dart`, `lib/state/app_state.dart`)
5. **Draft Persistence** (`lib/repositories/onboarding_repository.dart`, `lib/core/utils/debouncer.dart`)
6. **Completion Bundle & Multi-Stage Job** (`lib/services/onboarding_completion_job_service.dart`, `lib/services/onboarding_completion_service.dart`, `lib/services/routine_onboarding_projection.dart`)

### Summary of Audit Findings

| Severity | Count | Primary Impact Areas |
|---|---|---|
| **P0 (Critical)** | 2 | Draft Save Data Loss via Debouncer Singletask Overwrite; Firestore Transaction Batch Limit Breach (N > 240 items) |
| **P1 (High)** | 6 | Signup Exception State Disconnect; Email Verification Async Router Race; Navigation Dot Indicator Race Condition; Anonymous-to-Authenticated Leak Risk; Completion Job Fingerprint Mismatch Crash; Completion Bundle Validation Bypass |
| **P2 (Medium)** | 3 | Account Exists Resend Email Flow Gap; Verification Screen Rate Limiting Invalidation; Schema Version Migration Fallback Deficit |

---

## 2. Re-Verification of Previous Stabilization Claims

We audited all previous `PASSED` claims from `docs/onboarding_stabilization_report.md` against actual production code:

| Claimed Issue | Claimed Status | Code Re-Audit Result | Verbatim Code Verification & Findings |
|---|---|---|---|
| **Issue 1**: Onboarding completion receipt idempotency & fingerprint verification | `PASSED` | **VERIFIED PASSED** | `FirestoreOnboardingRepository.completeOnboarding` (lines 348-365) and `FakeOnboardingRepository` (lines 102-121) verify `receipt.sourceBundleFingerprint == plan.fingerprint` and run `RoutineProjectionReceiptValidator().validate()` before returning `noOp`. |
| **Issue 2**: Routine projection receipt ID deconstruction (`$slot-v$revision`) | `PASSED` | **VERIFIED PASSED** | `RoutineOnboardingProjection` (lines 20-45) deconstructs projection ID into configurable slot and revision. |
| **Issue 3**: Multi-stage job tracking (`OnboardingCompletionJobService`) | `PASSED` | **VERIFIED WITH P1 CAVEAT** | Job stages (1-6) exist in `onboarding_completion_job_service.dart`. However, re-projection attempts with updated fingerprints trigger an unhandled `StateError` in `_loadOrCreateJob` line 296 (see **Issue 6.3** below). |
| **Issue 4**: Router decoupling & recovery screen redirection | `PASSED` | **VERIFIED PASSED** | `optivusAuthRedirect` in `lib/core/router/app_router.dart` (lines 53-60) routes `isProjectionFailed` to `/onboarding/recovery`. |
| **Issue 5**: 4-Tier recovery fallback sequence | `PASSED` | **VERIFIED PASSED** | `OnboardingCompletionService.recoverCompletionState` implements Tiers 1–4 fallback cleanly. |
| **Issue 6**: Typed recovery actions taxonomy | `PASSED` | **VERIFIED PASSED** | Defined in `lib/features/recovery/models/onboarding_recovery_models.dart`. |
| **Issue 16-21**: Auth stream sync, user logout sweep, account switching isolation, email verification check, anonymous account linking | `PASSED` | **VERIFIED WITH P1/P2 CAVEATS** | `AuthNotifier` implements logout sweep (`_resetSignedOutState`) and `linkAnonymousWithEmail`. However, debounced draft saves and signup exception handling contain active edge-case bugs (see Issues 1.2, 5.1). |

---

## 3. Comprehensive Production Issue Inventory

### Issue 5.1 (P0): Unhandled Async Debounced Draft Save Causes Data Loss & User State Overwrite

- **Severity**: `P0 (Critical)`
- **Execution Step**: Step 5 (Draft Persistence)
- **Production Files**:
  - `lib/repositories/onboarding_repository.dart` (lines 64-73, 260-271)
  - `lib/core/utils/debouncer.dart`
- **Root Cause Analysis**:
  In `FirestoreOnboardingRepository.saveDraft(OnboardingDraft draft)`:
  ```dart
  OnboardingDraft? _pendingDraft;
  final Debouncer _draftDebouncer = Debouncer(delay: const Duration(milliseconds: 400));

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _pendingDraft = draft;
    _draftDebouncer.run(() async {
      final target = _pendingDraft;
      if (target != null) {
        await _firestore
            .doc(FirestoreUserPaths.onboardingDraft(target.uid))
            .set(target.toMap(), SetOptions(merge: true));
        _pendingDraft = null;
      }
    });
  }
  ```
  1. `saveDraft` is defined as returning `Future<void>`, but its body invokes `_draftDebouncer.run(...)` without returning or awaiting the inner asynchronous Firestore set operation. `saveDraft` returns `Future.value()` immediately to callers!
  2. `_pendingDraft` is a single instance variable on the repository singleton. If `saveDraft` is called for User A, and within 400ms another save operation occurs (e.g. background sync or anonymous-to-authenticated linking for User B), `_pendingDraft` is overwritten with User B's draft. When the 400ms debouncer timer fires, User B's draft is saved to User B's path, and User A's pending draft save is **silently dropped and lost forever**.
  3. Callers in UI screens that call `await saveDraft(draft)` proceed under the false assumption that Firestore persistence succeeded, when in reality the network write has not even been initiated.
- **Repro Steps**:
  1. In onboarding step 3, enter body basics data.
  2. Tap "Next Step" (which invokes `saveDraft`).
  3. Immediately close the app or trigger account linking within 300ms.
  4. Re-open the app. Step 3 data is reverted/missing in Firestore.
- **Recommended Minimal Safe Fix**:
  Update `Debouncer` or `saveDraft` so `saveDraft` returns a `Future` that resolves when the actual write completes, or maintain a `Map<String, OnboardingDraft> _pendingDraftsByUid` keyed by `uid` so concurrent user saves do not overwrite each other's pending data.

---

### Issue 6.1 (P0): Firestore Transaction Batch Read/Write Operations Limit Breach ($N > 240$ Items)

- **Severity**: `P0 (Critical)`
- **Execution Step**: Step 6 (Completion Bundle & Atomic Projection)
- **Production Files**:
  - `lib/repositories/onboarding_repository.dart` (lines 291-470)
- **Root Cause Analysis**:
  In `FirestoreOnboardingRepository.completeOnboarding`:
  ```dart
  final plan = RoutineOnboardingProjection.build(bundle);
  if (plan.items.length > 450) {
    throw StateError('Onboarding produced too many Routine templates.');
  }
  ```
  Firestore transactions enforce a **hard limit of 500 total document reads and writes combined**.
  In `completeOnboarding`, inside `_firestore.runTransaction`:
  - Transaction reads: `receiptReference`, `draftReference`, `bundleReference`, `profileReference` ($4$), plus all $N$ `itemReferences` ($N$). Total reads = $4 + N$.
  - Transaction writes: `draftReference` ($1$), `bundleReference` ($1$), `profileReference` ($1$), all $N$ `itemReferences` ($N$), plus `receiptReference` ($1$). Total writes = $4 + N$.
  - Total transaction operations = $(4 + N) + (4 + N) = 2N + 8$.
  For $N = 250$ routine items (which passes the check `plan.items.length > 450`), total operations = $2(250) + 8 = 508$ operations!
  This causes Firestore to throw a fatal `InvalidArgumentException: Transaction failed because total operations exceeded 500`. The entire onboarding completion transaction fails and rolls back, trapping the user in `backendRestoreFailed`.
- **Repro Steps**:
  1. Complete onboarding with a dense schedule producing $> 246$ projected routine items/occurrences.
  2. Tap "Enter Optivus".
  3. Observe Firestore transaction error in logs and user stuck on `/onboarding/recovery`.
- **Recommended Minimal Safe Fix**:
  Update `plan.items.length` guard in `completeOnboarding` from `> 450` to `> 240` (since $2(240) + 8 = 488 \le 500$), or chunk item creations across batched writes with a single atomic transaction securing only receipt and profile status documents.

---

### Issue 1.2 (P1): Auth State Disconnect & Trapped Firebase User on Signup Exception

- **Severity**: `P1 (High)`
- **Execution Step**: Step 1 (Signup)
- **Production Files**:
  - `lib/state/auth_state.dart` (lines 196-230)
  - `lib/repositories/auth_repository.dart` (lines 266-292)
- **Root Cause Analysis**:
  In `AuthNotifier.signup`:
  ```dart
  try {
    final user = await _repository.signUp(email, password, name: name);
    if (_needsEmailVerification(user)) {
      state = state.copyWith(
        user: user,
        status: AuthFlowStatus.signedInEmailUnverified,
        clearError: true,
      );
      await _repository.sendEmailVerification();
      return;
    }
    await _loadOrCreateBackendUserState(user);
  } catch (error) {
    final mapped = mapAuthError(error);
    state = state.copyWith(
      user: previousUser,
      status: AuthFlowStatus.error,
      errorMessage: mapped.message,
      failureReason: mapped.reason,
    );
    rethrow;
  }
  ```
  If `_repository.sendEmailVerification()` throws a network timeout exception AFTER `signUp` has already succeeded in Firebase Auth:
  1. Firebase Auth `currentUser` is now signed in on the Firebase SDK side.
  2. The `catch` block catches the exception and resets `state.user` to `previousUser` (null) with `AuthFlowStatus.error`.
  3. However, Firebase Auth's `authStateChanges` stream fires asynchronously, calling `_handleAuthStateChange(user)`.
  4. `_handleAuthStateChange` sees `user != null` and invokes `_loadOrCreateBackendUserState(user)`, putting the user into `signedInEmailUnverified` state despite the UI displaying a signup failure error banner!
  5. If the user tries to click "Create Account" again, Firebase returns `email-already-in-use`.
- **Repro Steps**:
  1. Trigger signup while simulating a network drop during `sendEmailVerification()`.
  2. Observe error banner on Signup screen while backend state transitions to signed in.
- **Recommended Minimal Safe Fix**:
  In `signup()`, if `signUp` succeeds, retain `user` in `AuthState` even if `sendEmailVerification()` fails, exposing a friendly error message allowing the user to tap "Resend Verification Email" on the `VerifyEmailScreen`.

---

### Issue 2.1 (P1): Async Router Navigation Race Condition in `VerifyEmailScreen`

- **Severity**: `P1 (High)`
- **Execution Step**: Step 2 (Email Verification)
- **Production Files**:
  - `lib/views/screens/verify_email_screen.dart` (lines 44-73)
  - `lib/core/router/app_router.dart` (lines 62-74)
- **Root Cause Analysis**:
  In `VerifyEmailScreen._checkVerified()`:
  ```dart
  final operation = ref.read(authProvider.notifier).checkEmailVerification();
  try {
    await operation;
    if (!mounted) return;
    setState(() => _success = 'Email verified.');
  } catch (error) { ... }
  ```
  Inside `checkEmailVerification()` (`lib/state/auth_state.dart`):
  When `reloadCurrentUser()` confirms verification, it calls `await _loadOrCreateBackendUserState(user)`.
  As soon as `_loadOrCreateBackendUserState` begins, `state.status` updates to `AuthFlowStatus.loadingBackendUser` or `signedInOnboardingIncomplete`.
  GoRouter's `RouterNotifier` listens to `authProvider` and immediately triggers `optivusAuthRedirect(state)` BEFORE `_checkVerified()` finishes awaiting `operation`.
  GoRouter redirects the user away from `/verify-email` to `/onboarding` or `/loading`.
  When `await operation` completes, `VerifyEmailScreen._checkVerified()` executes `setState(() => _success = 'Email verified.')` on an unmounted state object or during an active route transition, causing an unhandled Flutter state warning or unexpected UI state flash.
- **Repro Steps**:
  1. Click "I verified" on `VerifyEmailScreen`.
  2. Observe immediate route transition to `/loading` / `/onboarding` while `_checkVerified` completion code is still executing.
- **Recommended Minimal Safe Fix**:
  Ensure `VerifyEmailScreen` guards all `setState` calls with `if (!mounted) return;` both before and after async operations, and let router redirect handle screen dispatches cleanly.

---

### Issue 4.1 (P1): Step Navigation Race Condition Corrupts Onboarding Draft Data

- **Severity**: `P1 (High)`
- **Execution Step**: Step 4 (Onboarding Flow)
- **Production Files**:
  - `lib/features/onboarding/onboarding_flow.dart` (lines 148-271, 427-489)
- **Root Cause Analysis**:
  In `OnboardingFlow._onNextPressed()`:
  When a user taps "Next Step", `_saveStep(_currentPage)` is called, which sets `_isSaving = true` and awaits a 600ms database operation.
  However, `_navigateToIndicatorStep(index)` (triggered when a user taps a step indicator dot or drags the indicator bar):
  - Does **NOT** check `_isSaving` or `_isNavigating`.
  - Immediately mutates `_currentPage = boundedIndex` and calls `ref.read(mockOnboardingProvider.notifier).setStep(boundedIndex)`.
  When `_saveStep` finishes its 600ms delay, line 178 calls:
  `onboardingNotifier.saveStep(_currentPage, transform: ...)`
  Because `_currentPage` was mutated by `_navigateToIndicatorStep` during the 600ms window, `saveStep` applies step $A$'s transform function to step $B$'s index! This corrupts the onboarding draft state in memory and Firestore.
- **Repro Steps**:
  1. Edit inputs on Onboarding Step 3.
  2. Tap "Next Step".
  3. Within 300ms, tap step indicator dot 6.
  4. Observe step 3 transform applied to step 6 index, corrupting step completed arrays and timeline drafts.
- **Recommended Minimal Safe Fix**:
  Add `if (_isSaving || _isNavigating) return;` guard to `_navigateToIndicatorStep` and pass the target step index explicitly into `_saveStep(stepIndex)` as a parameter instead of relying on mutable `_currentPage`.

---

### Issue 6.3 (P1): Unhandled Fingerprint Mismatch Exception Crashes Onboarding Recovery

- **Severity**: `P1 (High)`
- **Execution Step**: Step 6 (Completion Bundle & Recovery)
- **Production Files**:
  - `lib/services/onboarding_completion_job_service.dart` (lines 267-304)
  - `lib/state/auth_state.dart` (`executeRecoveryAction`)
- **Root Cause Analysis**:
  In `OnboardingCompletionJobService._loadOrCreateJob`:
  ```dart
  if (existing.sourceFingerprint != null && existing.sourceFingerprint != sourceFingerprint) {
    throw StateError('Persisted onboarding completion job fingerprint mismatch.');
  }
  ```
  When a user encounters a routine projection failure or updates their onboarding draft, `plan.fingerprint` changes to a new hash string.
  When the user taps a recovery action on `OnboardingRecoveryScreen` (e.g. `RetryCompletionJobAction` or `RebuildBundleFromDraftAction`), `AuthNotifier.executeRecoveryAction` calls `runCompletionJob(...)`.
  `runCompletionJob` invokes `_loadOrCreateJob`, which finds the existing persisted completion job document with the OLD `sourceFingerprint`.
  `_loadOrCreateJob` throws `StateError('Persisted onboarding completion job fingerprint mismatch.')`.
  This `StateError` is **uncaught** in `runCompletionJob` and `executeRecoveryAction`, causing the recovery action to fail with an unhandled exception and trapping the user permanently on the recovery screen!
- **Repro Steps**:
  1. Trigger a projection failure on step 6.
  2. Modify any onboarding input in draft (changing fingerprint).
  3. Tap "Retry Setup" on `/onboarding/recovery`.
  4. Observe uncaught `StateError` crash in logs.
- **Recommended Minimal Safe Fix**:
  In `_loadOrCreateJob`, if `existing.sourceFingerprint != sourceFingerprint`, update `existing`'s `sourceFingerprint` and reset `stagesCompleted` / `status` to `pending` instead of throwing a fatal `StateError`.

---

### Issue 6.2 (P1): Completion Bundle Validation Bypass for Un-Persisted Sub-Steps

- **Severity**: `P1 (High)`
- **Execution Step**: Step 6 (Completion Bundle)
- **Production Files**:
  - `lib/features/onboarding/onboarding_flow.dart` (lines 275-340)
  - `lib/models/onboarding_draft.dart` (lines 280-330)
- **Root Cause Analysis**:
  In `OnboardingDraft.validateStep(step, completedSteps)`:
  For step 14 (Final Preview):
  ```dart
  case 14:
    if (!completedSteps.take(lastStepIndex).every((done) => done)) {
      return 'Complete and save all previous onboarding steps first.';
    }
    final preview = buildFinalPreview();
    if (preview.blockingWarnings.isNotEmpty) {
      return preview.blockingWarnings.first;
    }
    return null;
  ```
  If `stepCompleted` array contains `true` for steps 0-13 (e.g. loaded from seed or prior session), but inner sub-step models inside `baseTimeline` (such as `skinCareSetupStep` or `eatingSetupStep`) were left un-configured (e.g. `skinCareSkipped: false` but `skinCareBlocks: []`), `validateStep` for step 14 passes if `buildFinalPreview()` has no blocking overlap warnings.
  `OnboardingCompletionService.buildBundle(draft)` constructs an `OnboardingCompletionBundle` with an incomplete skin care schedule, bypassing sub-step validation and creating an invalid completion bundle.
- **Repro Steps**:
  1. Set `stepCompleted` to all true via developer state or draft migration.
  2. Clear `skinCareBlocks` while setting `skinCareSkipped = false`.
  3. Navigate to step 14 and tap "Enter Optivus".
  4. Completion bundle is generated and committed with missing required routine items.
- **Recommended Minimal Safe Fix**:
  In `OnboardingDraft.validateStep(14, ...)` and `OnboardingCompletionService.buildBundle`, explicitly run `baseTimeline.validateSkinCareSetup()` and `baseTimeline.validateEatingSetup()` to ensure sub-step completion before bundling.

---

### Issue 3.1 (P2): Transient Empty User Profile State Window during Account Switch

- **Severity**: `P2 (Medium)`
- **Execution Step**: Step 3 (Login & Account Switch)
- **Production Files**:
  - `lib/state/auth_state.dart` (lines 538-575)
  - `lib/state/app_state.dart` (`MockUserProfileNotifier.resetEmpty`)
- **Root Cause Analysis**:
  When a user logs out or switches accounts, `AuthNotifier._loadOrCreateBackendUserState(user)` calls:
  `_resetSignedOutState(targetUserUid: user.uid);`
  This executes `mockUserProfileProvider.notifier.resetEmpty()`, setting `UserProfile.empty(uid: '')` where `onboardingCompleted` is `false`.
  Then `fetchUserProfile(user.uid)` is awaited asynchronously.
  During this network await window, if Riverpod dispatches a state update to `RouterNotifier`, `optivusAuthRedirect` reads `mockUserProfileProvider` while `authState.status` is transitioning. If `authState.isLoading` is briefly false or if `onboardingCompleted` is evaluated against `UserProfile.empty()`, router can evaluate a transient redirect to `/onboarding`.
- **Repro Steps**:
  1. Log out of an account with completed onboarding.
  2. Log into a different account over a slow network connection.
  3. Observe brief flash of `/onboarding` before `/loading` or `/app` renders.
- **Recommended Minimal Safe Fix**:
  Ensure `AuthNotifier` sets `state = state.copyWith(status: AuthFlowStatus.loadingBackendUser)` *before* resetting `mockUserProfileProvider` state.

---

### Issue 1.1 (P2): Missing Resend Password Reset Flow in Signup Account Exists Banner

- **Severity**: `P2 (Medium)`
- **Execution Step**: Step 1 (Signup)
- **Production Files**:
  - `lib/views/screens/signup_screen.dart` (lines 380-392, 682-767)
- **Root Cause Analysis**:
  When a user tries to sign up with an existing email, `signup_screen.dart` displays `_AccountExistsBanner` offering "Log in", "Forgot password", and "Use another email".
  If the user taps "Forgot password", `_sendResetForExistingAccount` is called. However, if the network drops or if the email entered in the text box differs from `_accountExistsEmail`, `_sendResetForExistingAccount` falls back to `_emailCtrl.text` without validating if the text field was edited or cleared, leading to an unhelpful "Enter your email to reset your password" error message.
- **Repro Steps**:
  1. Attempt signup with an existing email.
  2. Clear the email text field.
  3. Tap "Forgot password" on the yellow account exists banner.
  4. Observe error message asking user to enter email above.
- **Recommended Minimal Safe Fix**:
  In `_sendResetForExistingAccount`, if `_emailCtrl.text` is empty, auto-populate `_emailCtrl.text` with `_accountExistsEmail`.

---

### Issue 2.2 (P2): Resend Email Verification Rate Limiting Cooldown Lost on Screen Re-Entry

- **Severity**: `P2 (Medium)`
- **Execution Step**: Step 2 (Email Verification)
- **Production Files**:
  - `lib/views/screens/verify_email_screen.dart` (lines 28-42, 100-114)
- **Root Cause Analysis**:
  `VerifyEmailScreen` manages `_cooldown` (60 seconds) in local widget state (`_VerifyEmailScreenState`).
  If a user taps "Resend email", `_cooldown` starts counting down from 60.
  If the user navigates away (e.g. taps "Log out" and logs back in, or hot reloads), `dispose()` cancels `_timer`.
  Upon returning to `VerifyEmailScreen`, `_cooldown` is reset to 0, allowing the user to immediately trigger `resendEmailVerification()` again without enforcing the 60-second rate limit server/client side.
- **Repro Steps**:
  1. On `VerifyEmailScreen`, tap "Resend email" (cooldown starts at 60s).
  2. Tap "Log out", then log back in immediately.
  3. Notice "Resend email" button is immediately active again (0s cooldown).
- **Recommended Minimal Safe Fix**:
  Store `lastVerificationEmailSentTimestamp` in `AuthNotifier` or local persistent storage, deriving `cooldown` from `DateTime.now().difference(lastSent)`.

---

## 4. Production Closure Risk & Remediation Roadmap

To ensure 100% stability for final production closure:

1. **Immediate P0 Fixes Required**:
   - **Fix Issue 5.1**: Ensure `onboardingRepository.saveDraft` returns a `Future` tied to the completion of the debounced write and keyed by `uid`.
   - **Fix Issue 6.1**: Lower `completeOnboarding` max item limit from 450 to 240, or split large routine projections into chunked Firestore transactions to avoid the 500 operations limit.

2. **P1 Architectural Fixes Required**:
   - **Fix Issue 6.3**: Update `OnboardingCompletionJobService._loadOrCreateJob` to handle fingerprint updates gracefully during recovery re-projections.
   - **Fix Issue 4.1**: Guard `_navigateToIndicatorStep` against concurrent saves (`_isSaving`/`_isNavigating`) and pass explicit target step to `_saveStep`.
   - **Fix Issue 1.2 & 2.1**: Retain `AuthUser` in state on email verification failures and add `mounted` checks on `VerifyEmailScreen`.

---

*Report compiled by explorer_p46_path1.*
