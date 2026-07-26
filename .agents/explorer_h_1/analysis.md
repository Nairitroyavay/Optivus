# Group H (Issues 33–42): Recovery-Screen UI & State Repair Deep-Dive Analysis Report

## Executive Summary
This report provides a comprehensive, evidence-based investigation of the Recovery-Screen UI and State Repair subsystem in Optivus (Group H: Issues 33, 34, 35, 36, and 40). 

Our deep-dive inspection revealed several critical gaps and implementation flaws across `lib/features/recovery/`, `lib/state/auth_state.dart`, `lib/core/router/app_router.dart`, and related completion services:
1. **Issue 33**: Incomplete failure classification during backend restore (missing `missingDraftAndBundle` detection, indiscriminate mapping of generic errors to `networkTimeout`, and unhandled job retry states).
2. **Issue 34**: Display bug in `OnboardingRecoveryScreen` reading `authState.failureReason` instead of `authState.onboardingFailureReason` (causing the error Chip to never render), raw enum string formatting, and complete omission of action descriptions.
3. **Issue 35**: Unimplemented recovery action polymorphic methods (empty stubs in `onboarding_recovery_models.dart`), missing `SynthesizeBundleAction` execution handler in `AuthNotifier`, and missing integration with `OnboardingCompletionService.recoverCompletionState`.
4. **Issue 36**: `RetryCompletionJobAction` calls `retryBackendRestore()` which only re-reads failing Firestore records without executing `RoutineOnboardingEventProjector` or `OnboardingFrontendHydrationService`, locking the application in a retry failure loop.
5. **Issue 40**: Router navigation lock loopholes when `userProfile.onboardingCompleted` is true but backend restore failed without setting `backendRestoreFailed`, and lack of user sign-out capability from the recovery screen.

---

## Detailed Findings & Root Cause Analysis

### Issue 33: System Recovery Scaffold Trigger Conditions on Corruption Error

#### Observations
1. In `lib/state/auth_state.dart` (lines 647–743), `_loadOrCreateBackendUserState` checks artifact integrity when `profile.onboardingCompleted == true`:
   - If `bundle == null || bundle.uid != user.uid`:
     ```dart
     // Line 648
     throw const _RoutineProjectionRestoreException(
       'Routine setup recovery is required because the completion snapshot is missing.',
       reason: OnboardingFailureReason.missingBundle,
       actions: [
         RebuildBundleFromDraftAction(),
         RestartOnboardingInputAction(),
       ],
     );
     ```
   - If receipt validation fails (`!validation.isValid`):
     ```dart
     // Line 677
     throw _RoutineProjectionRestoreException(
       'Routine setup recovery is required because its projection receipt is invalid: ${validation.failureReason}',
       reason: OnboardingFailureReason.projectionReceiptMismatch,
       actions: const [
         RetryCompletionJobAction(),
         RebuildBundleFromDraftAction(),
       ],
     );
     ```
   - If projected receipt is null, status != 'completed', cursor != totalCount, or fingerprint mismatch:
     ```dart
     // Line 702
     throw const _RoutineProjectionRestoreException(
       'Routine setup recovery is required because History projection did not complete.',
       reason: OnboardingFailureReason.habitsProjectionFailed,
       actions: [
         RetryCompletionJobAction(),
         RebuildBundleFromDraftAction(),
       ],
     );
     ```
   - Generic catch block (`auth_state.dart:733`):
     ```dart
     } catch (_) {
       if (!_isCurrentRestore(restoreGeneration)) return;
       state = state.copyWith(
         user: user,
         status: AuthFlowStatus.backendRestoreFailed,
         errorMessage:
             'Could not restore setup. Check your connection and try again.',
         onboardingFailureReason: OnboardingFailureReason.networkTimeout,
         recoveryActions: const [RetryCompletionJobAction()],
       );
     }
     ```
2. In `lib/core/router/app_router.dart`:
   - Lines 92–96: `if (authState.backendRestoreFailed)` redirects to `/onboarding/recovery`.
   - Lines 127–133: `if (onboardingInputCompleted && !onboardingCompleted)` redirects to `/onboarding/recovery`.

#### Gaps & Flaws
- **Missing `missingDraftAndBundle` Trigger**: When `bundle` is null (line 648), `auth_state.dart` assumes the draft exists and offers `RebuildBundleFromDraftAction()`. It never checks `onboardingRepository.fetchDraft(user.uid)`. If draft is ALSO missing/corrupted, `missingDraftAndBundle` should be set as `onboardingFailureReason`, offering `SynthesizeBundleAction()` or `RestartOnboardingInputAction()`.
- **Indiscriminate Error Classification**: The generic catch block maps every non-`_RoutineProjectionRestoreException` to `OnboardingFailureReason.networkTimeout`. Format exceptions, state errors, or Firestore schema errors are misclassified as network timeouts instead of `OnboardingFailureReason.unhandledException`.
- **Interrupted Job State Gap**: When `userProfile.onboardingInputCompleted == true` and `onboardingCompleted == false`, `app_router.dart` routes the user to `/onboarding/recovery`. However, `authState.recoveryActions` is empty and `authState.status` is `signedInOnboardingIncomplete`. The UI fallback button calls `retryBackendRestore()`, which does not resume `OnboardingCompletionJobService`.

---

### Issue 34: Recovery Action Typed Error Presentation and User Messaging

#### Observations
1. In `lib/features/recovery/screens/onboarding_recovery_screen.dart`:
   - Line 10–12:
     ```dart
     final authState = ref.watch(authProvider);
     final failureReason = authState.failureReason;
     final actions = authState.recoveryActions;
     ```
   - Lines 40–46:
     ```dart
     if (failureReason != null) ...[
       const SizedBox(height: 12),
       Chip(
         label: Text('Reason: ${failureReason.name}'),
         backgroundColor: Colors.amber.shade100,
       ),
     ],
     ```
   - Lines 56–68:
     ```dart
     ...actions.map((action) {
       return Padding(
         padding: const EdgeInsets.only(bottom: 12.0),
         child: ElevatedButton(
           onPressed: () {
             ref
                 .read(authProvider.notifier)
                 .executeRecoveryAction(action);
           },
           child: Text(action.label),
         ),
       );
     })
     ```

#### Gaps & Flaws
- **CRITICAL UI BUG — Reading Wrong Property**: `AuthState` contains TWO failure reason fields: `AuthFailureReason? failureReason` and `OnboardingFailureReason? onboardingFailureReason`. Line 11 of `onboarding_recovery_screen.dart` reads `authState.failureReason`. Onboarding recovery errors populate `onboardingFailureReason`, leaving `failureReason` as `null`. As a result, `failureReason != null` is ALWAYS `false`, and the error Chip is **NEVER rendered**!
- **Raw Technical Enum Formatting**: Rendering `${failureReason.name}` displays raw camelCase strings (e.g. `projectionReceiptMismatch`, `habitsProjectionFailed`). End users receive cryptically formatted technical strings.
- **Omitted Action Descriptions**: `OnboardingRecoveryAction` models define `label` and `description` (e.g., `'Reconstruct your onboarding plan from saved form inputs and retry.'`), but `OnboardingRecoveryScreen` only renders `Text(action.label)` and ignores `description` entirely. Users cannot understand what actions perform.
- **Lack of Categorized Failure Messaging**: The title remains static (`"Setup Verification Incomplete"`) regardless of whether the error is a transient timeout, corrupt receipt, or missing bundle.

---

### Issue 35: Draft Profile Repair Action Execution from Recovery UI

#### Observations
1. In `lib/features/recovery/models/onboarding_recovery_models.dart` (lines 26–76):
   - All subclasses of `OnboardingRecoveryAction` (`RetryCompletionJobAction`, `RebuildBundleFromDraftAction`, `SynthesizeBundleAction`, `RestartOnboardingInputAction`) define empty `execute(Ref ref, String uid) async {}` bodies.
2. In `lib/state/auth_state.dart` (lines 913–934):
   ```dart
   Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {
     final currentUser = state.user ?? _repository.currentUser;
     if (currentUser == null) return;
     if (action is RestartOnboardingInputAction) {
       await markOnboardingIncomplete(currentUser);
       return;
     }
     if (action is RebuildBundleFromDraftAction) {
       final draft = await _ref
           .read(onboardingRepositoryProvider)
           .fetchDraft(currentUser.uid);
       if (draft != null) {
         final bundle = OnboardingCompletionService.buildBundle(draft);
         await _ref
             .read(onboardingRepositoryProvider)
             .saveCompletionBundle(bundle);
       }
       await retryBackendRestore();
       return;
     }
     await retryBackendRestore();
   }
   ```

#### Gaps & Flaws
- **Unused Polymorphic Interface**: `OnboardingRecoveryAction.execute(ref, uid)` is an empty stub. `AuthNotifier` relies on type checking (`if (action is ...)`), violating OOP design principles.
- **Missing `SynthesizeBundleAction` Execution**: `SynthesizeBundleAction` is not handled in `executeRecoveryAction`. It falls through to `retryBackendRestore()`, which fails with `missingBundle` again. It fails to synthesize a baseline bundle from `userProfile` (Tier 3 in `OnboardingCompletionService`).
- **Fragile `RebuildBundleFromDraftAction`**: If `fetchDraft` returns `null`, `executeRecoveryAction` silently calls `retryBackendRestore()`, failing repeatedly without informing the user or falling back to Tier 3/4 recovery.
- **Bypassing Tiered Recovery Service**: `OnboardingCompletionService.recoverCompletionState` contains 4-tier recovery logic (Tier 1: bundle, Tier 2: draft rebuild, Tier 3: synthesize, Tier 4: reset), but `AuthNotifier.executeRecoveryAction` does not utilize this service.

---

### Issue 36: Routine Projection State Force-Resync from Recovery UI

#### Observations
1. In `lib/services/routine_onboarding_event_projector.dart` and `lib/services/onboarding_frontend_hydration_service.dart`:
   - `RoutineOnboardingEventProjector` projects routine creation events and updates receipt status from `pending` -> `completed`.
   - `OnboardingFrontendHydrationService.hydrate` executes `projectCreatedEvents` and verifies receipt status before setting profile onboarding complete.
2. In `lib/state/auth_state.dart` (lines 660–711):
   - If receipt validation fails (`projectionReceiptMismatch` or `habitsProjectionFailed`), `_loadOrCreateBackendUserState` sets recovery actions `[RetryCompletionJobAction(), RebuildBundleFromDraftAction()]`.
   - When user taps `RetryCompletionJobAction`, `executeRecoveryAction` invokes `retryBackendRestore()`.

#### Gaps & Flaws
- **No Force-Resync / Event Projection Execution**: `retryBackendRestore()` only re-runs `_loadOrCreateBackendUserState(user)`. If `profile.onboardingCompleted == true`, `_loadOrCreateBackendUserState` only reads `fetchProjectionReceipt` and `fetchRoutineItems` from `routineRepository`.
- **Infinite Retry Failure Loop**: `retryBackendRestore()` NEVER calls `RoutineOnboardingEventProjector().projectCreatedEvents(...)`, `OnboardingFrontendHydrationService().hydrate(...)`, or `OnboardingCompletionJobService().runCompletionJob(...)`. It re-reads the same stuck/invalid receipt from Firestore, throws `_RoutineProjectionRestoreException`, and fails continuously.

---

### Issue 40: Recovery Screen Navigation Lock Preventing Unverified App Entry

#### Observations
1. In `lib/core/router/app_router.dart` (lines 78–144):
   - `redirect` checks `authState.backendRestoreFailed` -> redirects to `/onboarding/recovery`.
   - Checks `onboardingInputCompleted && !onboardingCompleted` -> redirects to `/onboarding/recovery`.
   - Checks `!onboardingInputCompleted || authState.onboardingIncomplete` -> redirects to `/onboarding`.

#### Gaps & Flaws
- **State Desynchronization Loophole**: If `userProfile.onboardingCompleted == true` in database, but backend restore failed without setting `authState.status = AuthFlowStatus.backendRestoreFailed` (e.g. due to state corruption or uncaught async error), `app_router.dart` line 136 sees `onboardingCompleted == true` and permits entry into `/app?tab=0` or sub-routes (`/tracker/fitness`), exposing unhydrated/corrupt state.
- **Trapped User / Missing Sign-Out**: `OnboardingRecoveryScreen` provides no "Sign Out" or "Reset Account" button. If recovery repair fails, users are permanently locked on `/onboarding/recovery`.
- **Inverted Redirect Evaluation Priority**: In `app_router.dart`, `if (authState.backendRestoreFailed)` is evaluated before `if (!authState.isLoggedIn)`. If sign-out fails to clear `backendRestoreFailed`, unauthenticated users remain stuck on `/onboarding/recovery`.

---

## Required Code Changes & Fixes

### 1. `lib/features/recovery/models/onboarding_recovery_models.dart`
- Implement `execute(Ref ref, String uid)` in each `OnboardingRecoveryAction` subclass or delegate execution to `AuthNotifier`.

### 2. `lib/features/recovery/screens/onboarding_recovery_screen.dart`
- Fix property read: Change `final failureReason = authState.failureReason;` to `final onboardingReason = authState.onboardingFailureReason;`.
- Format enum reason into user-friendly title/description string.
- Render `action.description` under or beside each `ElevatedButton`.
- Add a "Sign Out" button calling `ref.read(authProvider.notifier).logout()`.

### 3. `lib/state/auth_state.dart`
- Update `_loadOrCreateBackendUserState`:
  - When `bundle == null`, fetch draft first. If draft is also null, throw `_RoutineProjectionRestoreException` with `reason: OnboardingFailureReason.missingDraftAndBundle` and actions `[SynthesizeBundleAction(), RestartOnboardingInputAction()]`.
  - In generic `catch (e)` block: map unknown non-network exceptions to `OnboardingFailureReason.unhandledException`.
- Update `executeRecoveryAction`:
  - `SynthesizeBundleAction`: Fetch profile, synthesize draft and bundle via `OnboardingCompletionService.buildBundle(...)`, save draft & bundle, then run hydration/restore.
  - `RebuildBundleFromDraftAction`: Handle null draft case by falling back to `SynthesizeBundleAction` or `RestartOnboardingInputAction`.
  - `RetryCompletionJobAction` / Projection Resync: Execute `OnboardingFrontendHydrationService().hydrate(...)` or `OnboardingCompletionJobService().runCompletionJob(...)` to re-run event projector and repair receipt state before calling `retryBackendRestore()`.

### 4. `lib/core/router/app_router.dart`
- Ensure `!authState.isLoggedIn` check takes precedence over `authState.backendRestoreFailed`.
- Validate that users with invalid routine projection state cannot bypass `/onboarding/recovery`.

---

## Test Strategies

1. **Unit Tests (`test/group_h_issues_33_to_42_test.dart`)**:
   - Verify `missingDraftAndBundle` reason when both bundle and draft are absent.
   - Verify `executeRecoveryAction` for `SynthesizeBundleAction` creates fallback bundle and completes restore.
   - Verify `RetryCompletionJobAction` invokes event projector and updates projection receipt from `pending` -> `completed`.
2. **Widget Tests (`test/onboarding_recovery_screen_test.dart`)**:
   - Verify `OnboardingRecoveryScreen` displays `onboardingFailureReason` chip correctly.
   - Verify action descriptions are rendered on screen.
   - Verify Sign Out button executes logout.
3. **Router Integration Tests (`test/onboarding_routing_test.dart`)**:
   - Verify navigation lock keeps user on `/onboarding/recovery` for all corrupted states and prevents direct URL navigation to `/app` or sub-routes.
