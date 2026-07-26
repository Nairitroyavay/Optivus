# Review & Handoff Report — Group H (Issues 33–42: Recovery-Screen UI & State Repair)

## Review Summary

**Verdict**: **REQUEST_CHANGES**
**Overall Risk Assessment**: HIGH

Comprehensive review and adversarial critic analysis of Group H implementations (`lib/features/recovery/`, `lib/state/auth_state.dart`, `lib/core/router/app_router.dart`, and `test/group_h_issues_33_to_42_test.dart`). While static analysis (`flutter analyze`) passes and unit tests in `group_h_issues_33_to_42_test.dart` pass, critical facade implementations and structural defects were identified that require resolution before approval.

---

## 1. Observation

Direct observations from codebase inspection, tool command executions, and verbatim code quotes:

### Verification Tool Commands & Outputs:
1. `flutter analyze`:
   ```
   Analyzing Optivus...
   info • The private field _sourceEpoch could be 'final' • lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart:1386:7
   warning • The '!' will have no effect because the receiver can't be null • lib/services/skin_care_ai_client.dart:450:68
   2 issues found. (0 errors in Group H files)
   ```
2. `flutter test test/group_h_issues_33_to_42_test.dart`:
   ```
   00:01 +11: All tests passed!
   ```

### Code Observations:

- **Observation A (Empty Dummy Methods on Action Models)**:
  `lib/features/recovery/models/onboarding_recovery_models.dart`:
  Line 14-26 defines:
  ```dart
  abstract class OnboardingRecoveryAction {
    ...
    Future<void> execute(Ref ref, String uid);
  }
  ```
  Lines 38, 51, 64, 77, 90 implement `execute` across all subclasses:
  ```dart
  // Line 38 (RetryCompletionJobAction):
  @override
  Future<void> execute(Ref ref, String uid) async {}

  // Line 51 (RebuildBundleFromDraftAction):
  @override
  Future<void> execute(Ref ref, String uid) async {}

  // Line 64 (SynthesizeBundleAction):
  @override
  Future<void> execute(Ref ref, String uid) async {}

  // Line 77 (RestartOnboardingInputAction):
  @override
  Future<void> execute(Ref ref, String uid) async {}

  // Line 90 (ForceResyncProjectionsAction):
  @override
  Future<void> execute(Ref ref, String uid) async {}
  ```

- **Observation B (Hardcoded Stage Telemetry in UI)**:
  `lib/features/recovery/screens/onboarding_recovery_screen.dart`:
  Lines 128-151:
  ```dart
  PartialFailureStatusBanner(
    stageStatuses: const {
      'persistDraft': true,
      'persistBundle': true,
      'projectRoutines': false,
      'projectHabits': false,
      'updateProfile': false,
    },
    currentStage: 'projectRoutines',
    projectedItemCount: 2,
    failedItemCount: 1,
    onResume: ...
  )
  ```

- **Observation C (Unused Enum Cases in `auth_state.dart`)**:
  `lib/features/recovery/models/onboarding_recovery_models.dart`:
  Lines 9-10 define `projectionReceiptMismatch` and `habitsProjectionFailed`.
  In `lib/state/auth_state.dart`, lines 705–754 set `OnboardingFailureReason.projectionFailed` for all projection/receipt failures. Neither `projectionReceiptMismatch` nor `habitsProjectionFailed` is ever set or thrown in `auth_state.dart`.

- **Observation D (Superficial Unit Test Assertions)**:
  `test/group_h_issues_33_to_42_test.dart`:
  - Lines 21-34 (Issue 33): Only asserts `OnboardingFailureReason.missingDraftAndBundle != null`. Does not test `AuthNotifier` throwing behavior.
  - Lines 107-116 (Issue 36): Only asserts `action.actionId == 'force_resync_projections'`. Does not test resync execution.
  - Lines 191-209 (Issue 40): Only asserts `router != null`. Does not test routing redirects under failed projection status.

---

## 2. Logic Chain

1. **From Observation A**: `OnboardingRecoveryAction` establishes a polymorphic contract requiring subclasses to implement `execute(Ref ref, String uid)`. All 5 concrete implementations (`RetryCompletionJobAction`, `RebuildBundleFromDraftAction`, `SynthesizeBundleAction`, `RestartOnboardingInputAction`, `ForceResyncProjectionsAction`) override `execute` with an empty function body `async {}`. If any client code calls `action.execute(ref, uid)`, it performs a no-op. Instead, execution logic was placed in `AuthNotifier.executeRecoveryAction(action)` via `if (action is ...)` type checking. Defining abstract contract methods and populating all implementations with empty no-ops constitutes a facade contract violation.
2. **From Observation B**: `PartialFailureStatusBanner` was created to render 5-stage onboarding completion pipeline progress (Issue 42). However, in `OnboardingRecoveryScreen`, the parameters passed to `PartialFailureStatusBanner` are hardcoded constants (`persistDraft: true`, `persistBundle: true`, `projectRoutines: false`, `projectedItemCount: 2`, `failedItemCount: 1`). Regardless of whether the failure cause is `missingDraftAndBundle`, `networkTimeout`, or `corruptedBundle`, the banner displays identical static progress, presenting inaccurate status telemetry to users.
3. **From Observation C**: `OnboardingFailureReason` contains `projectionReceiptMismatch` and `habitsProjectionFailed`, but `AuthNotifier` maps all receipt mismatches and habit projection failures to `OnboardingFailureReason.projectionFailed`. This leaves `projectionReceiptMismatch` and `habitsProjectionFailed` as dead enum cases.
4. **From Observation D**: The unit test suite in `test/group_h_issues_33_to_42_test.dart` passes 11/11 tests, but several tests (Issues 33, 36, 40) only check object non-nullability or string properties without validating actual class methods, state transitions, or router redirects.

---

## 3. Findings & Challenges

### Findings

#### [Critical] Finding 1: INTEGRITY VIOLATION / Facade Implementation — Hardcoded Job Telemetry & Empty Dummy Methods
- **What**: 
  1. `PartialFailureStatusBanner` invocation in `OnboardingRecoveryScreen` passes hardcoded constant maps and counts (`persistDraft: true`, `persistBundle: true`, `projectRoutines: false`, 2 projected, 1 failed).
  2. All 5 concrete subclasses of `OnboardingRecoveryAction` override `execute(Ref ref, String uid)` with empty dummy bodies (`async {}`).
- **Where**: 
  - `lib/features/recovery/screens/onboarding_recovery_screen.dart`: lines 128–151
  - `lib/features/recovery/models/onboarding_recovery_models.dart`: lines 38, 51, 64, 77, 90
- **Why**: 
  1. Passing hardcoded state into the partial failure status banner causes the recovery UI to display fake, static job telemetry regardless of the real failure reason.
  2. Defining an abstract method `execute` and providing empty no-op implementations across all concrete classes breaks object-oriented polymorphism. Any caller invoking `action.execute(ref, uid)` will experience a silent failure to execute recovery.
- **Suggestion**: 
  1. Derive job stage status dynamically from `authState` / `userProfile` or failure reason (or make `stageStatuses` optional and construct state based on `onboardingFailureReason`).
  2. Have `action.execute(ref, uid)` delegate directly to `ref.read(authProvider.notifier).executeRecoveryAction(this)` or move action logic into `execute()`.

#### [Major] Finding 2: Unused Enum Values for Specific Failure Causes
- **What**: `OnboardingFailureReason.projectionReceiptMismatch` and `OnboardingFailureReason.habitsProjectionFailed` are defined but never set in `auth_state.dart`.
- **Where**: `lib/features/recovery/models/onboarding_recovery_models.dart`: lines 9-10; `lib/state/auth_state.dart`: lines 705–754.
- **Why**: `AuthNotifier` collapses all projection and receipt errors into `OnboardingFailureReason.projectionFailed`, reducing diagnostic precision.
- **Suggestion**: Assign `projectionReceiptMismatch` when `RoutineProjectionReceiptValidator` returns invalid receipt, and `habitsProjectionFailed` when habits projection fails.

#### [Minor] Finding 3: Redundant Card Title and Button Text in Action List
- **What**: In `OnboardingRecoveryScreen`, each recovery action card displays `action.label` as the card title and also as the button label (`child: Text(action.label)`).
- **Where**: `lib/features/recovery/screens/onboarding_recovery_screen.dart`: lines 193 & 224.
- **Why**: Repetitive UI label rendering reduces visual clarity.
- **Suggestion**: Use dynamic or action-oriented button text (e.g. "Run Action" or "Execute").

#### [Minor] Finding 4: Test Assertion Depth Gaps
- **What**: Unit tests for Issues 33, 36, and 40 in `test/group_h_issues_33_to_42_test.dart` check enum existence and string equality rather than executing notifier/router logic.
- **Where**: `test/group_h_issues_33_to_42_test.dart`: lines 20-35, 107-116, 191-209.
- **Why**: Superficial assertions reduce test suite reliability.
- **Suggestion**: Add assertions that invoke `AuthNotifier._loadOrCreateBackendUserState()` with mock drafts/bundles and test router redirect output for `/app`.

---

## 4. Verified Claims

- `flutter analyze` runs cleanly with 0 errors in Group H code → VERIFIED
- `flutter test test/group_h_issues_33_to_42_test.dart` passes all 11 tests → VERIFIED
- `RecoveryCacheManager` preserves `stepDirty` flags during cache reset → VERIFIED (`test/group_h_issues_33_to_42_test.dart`: lines 118–138)
- `DiagnosticBundleService` redacts email and user display name PII via regex → VERIFIED (`diagnostic_bundle_service.dart`: lines 12–26)
- `RecoveryRetryController` correctly calculates exponential backoff ($2, 4, 8, 16, 32, 60\text{s}$) and caps attempts at 5 → VERIFIED (`recovery_retry_controller.dart`: lines 40–81)
- Responsive layout in `OnboardingRecoveryScreen` wraps body in `SingleChildScrollView` + `SafeArea` + `LayoutBuilder` → VERIFIED (`onboarding_recovery_screen.dart`: lines 74–86)

---

## 5. Coverage Gaps

- **Dynamic Job Stage Telemetry**: `PartialFailureStatusBanner` currently receives static hardcoded values. Risk: Medium. Recommendation: Connect to real status data or infer from failure reason.
- **Router Redirect Match Testing**: `routerProvider` redirect behavior for `/app` was tested via container initialization rather than full location matching. Risk: Low. Recommendation: Add location redirect test.

---

## 6. Caveats

- No external network access was used (`CODE_ONLY` mode).
- Standard build tools (`flutter analyze` and `flutter test`) were executed directly.

---

## 7. Conclusion

Group H has implemented strong foundational components (`RecoveryRetryController`, `DiagnosticBundleService`, `RecoveryCacheManager`, `OnboardingCompletionService` recovery tiers, responsive scaffold layout). However, because `OnboardingRecoveryAction` subclasses contain empty dummy `execute()` methods and `OnboardingRecoveryScreen` passes hardcoded dummy stage telemetry to `PartialFailureStatusBanner`, the review verdict is **REQUEST_CHANGES** due to Critical INTEGRITY VIOLATION findings.

---

## 8. Verification Method

To verify resolution of issues after changes are made:
1. Execute analysis & tests:
   ```bash
   flutter analyze
   flutter test test/group_h_issues_33_to_42_test.dart
   ```
2. Inspect `lib/features/recovery/models/onboarding_recovery_models.dart`: Confirm `execute()` in action subclasses delegates to notifier or contains logic.
3. Inspect `lib/features/recovery/screens/onboarding_recovery_screen.dart`: Confirm `PartialFailureStatusBanner` parameters are dynamically populated.
