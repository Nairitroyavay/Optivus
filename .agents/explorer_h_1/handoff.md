# Handoff Report: Explorer 1 (Group H: Recovery-Screen UI & State Repair)

## 1. Observation

Direct observations from inspection of `/Users/roy/optivus2/Optivus`:

### Observation 1.1: Issue 33 & Issue 35 - Missing `missingDraftAndBundle` detection and empty action implementations
- **File**: `lib/state/auth_state.dart` (lines 648–656)
  ```dart
  if (bundle == null || bundle.uid != user.uid) {
    throw const _RoutineProjectionRestoreException(
      'Routine setup recovery is required because the completion snapshot is missing.',
      reason: OnboardingFailureReason.missingBundle,
      actions: [
        RebuildBundleFromDraftAction(),
        RestartOnboardingInputAction(),
      ],
    );
  }
  ```
  `auth_state.dart` unconditionally sets `OnboardingFailureReason.missingBundle` without checking whether draft exists (`onboardingRepository.fetchDraft`). `OnboardingFailureReason.missingDraftAndBundle` is never thrown in the codebase.
- **File**: `lib/features/recovery/models/onboarding_recovery_models.dart` (lines 26–76)
  Subclasses `RetryCompletionJobAction`, `RebuildBundleFromDraftAction`, `SynthesizeBundleAction`, `RestartOnboardingInputAction` all declare empty `Future<void> execute(Ref ref, String uid) async {}` stubs.
- **File**: `lib/state/auth_state.dart` (lines 913–934)
  `executeRecoveryAction` does NOT handle `SynthesizeBundleAction`. When `SynthesizeBundleAction` is tapped, it falls through to `retryBackendRestore()`, which fails with `missingBundle` repeatedly.

### Observation 1.2: Issue 34 - UI Bug reading wrong failure reason property and ignoring descriptions
- **File**: `lib/features/recovery/screens/onboarding_recovery_screen.dart` (lines 10–12, 40–45, 56–68)
  Line 11: `final failureReason = authState.failureReason;`
  `AuthState` has `AuthFailureReason? failureReason` and `OnboardingFailureReason? onboardingFailureReason`. Backend restore errors populate `onboardingFailureReason`. Thus `authState.failureReason` is null during onboarding recovery, and the condition `if (failureReason != null)` evaluates to false (the reason Chip is never rendered).
  Line 43: `Chip(label: Text('Reason: ${failureReason.name}'))` formats raw enum names.
  Lines 56–68: Render `Text(action.label)` and completely ignore `action.description`.

### Observation 1.3: Issue 36 - `RetryCompletionJobAction` fails to re-project routine events
- **File**: `lib/state/auth_state.dart` (line 933)
  `RetryCompletionJobAction` invokes `retryBackendRestore()`, which runs `_loadOrCreateBackendUserState(user)`.
  When `profile.onboardingCompleted == true`, `_loadOrCreateBackendUserState` only calls `routineRepo.fetchProjectionReceipt(...)` and `routineRepo.fetchRoutineItems(...)`. It NEVER calls `RoutineOnboardingEventProjector().projectCreatedEvents(...)` or `OnboardingFrontendHydrationService().hydrate(...)`.
  Therefore, if a receipt was stuck at `status: 'pending'`, retrying setup re-reads the same stuck receipt from Firestore and fails validation immediately.

### Observation 1.4: Issue 40 - Router navigation lock loopholes & missing sign-out
- **File**: `lib/core/router/app_router.dart` (lines 78–144)
  If `userProfile.onboardingCompleted == true`, but backend restore failed without setting `authState.status = AuthFlowStatus.backendRestoreFailed`, line 136 routes the user to `/app?tab=0` or permits sub-routes, bypassing recovery.
  `OnboardingRecoveryScreen` contains no logout/sign-out button, trapping users when repair fails.

---

## 2. Logic Chain

1. **Premise**: In `auth_state.dart`, `_loadOrCreateBackendUserState` is responsible for restoring user onboarding artifacts and checking bundle, receipt, and projection status.
2. **Step 1 (Issue 33)**: When a bundle is missing, `auth_state.dart:648` immediately throws `missingBundle` with `RebuildBundleFromDraftAction()`. Because it does not query `fetchDraft`, if the draft is missing, the system misclassifies the failure and offers an action (`RebuildBundleFromDraftAction`) that will fail.
3. **Step 2 (Issue 34)**: In `onboarding_recovery_screen.dart:11`, `ref.watch(authProvider).failureReason` is read. Since recovery failures set `onboardingFailureReason` in `AuthState`, `failureReason` is null, causing the UI to omit the failure reason Chip entirely.
4. **Step 3 (Issue 35)**: Tapping `SynthesizeBundleAction` in the UI executes `AuthNotifier.executeRecoveryAction`. Because `executeRecoveryAction` lacks an `if (action is SynthesizeBundleAction)` branch, it falls through to `retryBackendRestore()`, which fails again because no bundle was synthesized.
5. **Step 4 (Issue 36)**: Tapping `RetryCompletionJobAction` calls `retryBackendRestore()`. Since `retryBackendRestore()` only re-queries `fetchProjectionReceipt` without executing `RoutineOnboardingEventProjector` or `OnboardingFrontendHydrationService`, the stuck `pending` receipt is never advanced to `completed`, creating an infinite retry failure loop.
6. **Step 5 (Issue 40)**: `app_router.dart` redirects based on `authState.backendRestoreFailed` or `!onboardingCompleted`. If `userProfile.onboardingCompleted` is true but hydration failed in background without setting `backendRestoreFailed`, `app_router.dart` allows navigation into `/app`, bypassing recovery lock.

---

## 3. Caveats

- **Firebase vs Fake Backend**: Investigation focused primarily on `OptivusBackendMode.firebase` mode, where backend restore and projection receipt validation occur. Fake mode defaults to loading seed data.
- **Uninvestigated Area**: Group H issues 37–39 and 41–42 belong to peer explorers in Group H and were not in scope for this deep-dive.

---

## 4. Conclusion

The Group H Recovery-Screen UI & State Repair subsystem contains 5 primary defect areas across trigger conditions, error presentation, repair action execution, force-resync, and router locking. Detailed root causes and code locations have been identified:
- Fix `auth_state.dart` to check draft presence before throwing `missingBundle` (setting `missingDraftAndBundle` if draft is null).
- Fix `onboarding_recovery_screen.dart` to read `authState.onboardingFailureReason`, render user-friendly messages, display `action.description`, and add a Sign-Out option.
- Implement `SynthesizeBundleAction` in `executeRecoveryAction` to construct baseline bundles from `userProfile` (Tier 3 recovery).
- Update `RetryCompletionJobAction` in `executeRecoveryAction` to invoke `OnboardingFrontendHydrationService` / `RoutineOnboardingEventProjector` to advance pending routine projection receipts before re-evaluating restore state.
- Tighten `app_router.dart` navigation lock to prevent unhydrated app entry.

---

## 5. Verification Method

To independently verify these findings:
1. **Inspect Code Locations**:
   - `lib/features/recovery/screens/onboarding_recovery_screen.dart:10-45` (confirm line 11 reads `failureReason` instead of `onboardingFailureReason`).
   - `lib/state/auth_state.dart:648-705` (confirm missing draft check is absent when bundle is null, and `executeRecoveryAction` lacks `SynthesizeBundleAction` handler).
   - `lib/features/recovery/models/onboarding_recovery_models.dart:26-76` (confirm empty `execute` stubs).
   - `lib/core/router/app_router.dart:92-136` (confirm redirect logic evaluation order).
2. **Run Flutter Tests**:
   - Execute `flutter test test/onboarding_restore_test.dart` and `flutter test test/onboarding_routing_test.dart`.
