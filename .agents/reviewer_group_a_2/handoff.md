# Group A Review Handoff Report — Onboarding Completion Truth

## 1. Observation

### Code & Command Verification
- **Formatting**: Ran `dart format --output=none --set-exit-if-changed .` -> Formatted 408 files (0 changed). Exit code 0.
- **Static Analysis**: Ran `flutter analyze` -> 3 info issues found in `test/helpers/fake_habit_systems_repository.dart` (lines 60, 80, 104: `curly_braces_in_flow_control_structures`). 0 errors/warnings in `lib/` or `test/onboarding_completion_group_a_test.dart`.
- **Automated Tests**: Executed test suite (`flutter test`). Group A tests passed, but revealing an integrity flaw described below.

### Codebase & Test Inspection Findings

#### Finding 1 (Critical - INTEGRITY VIOLATION / Facade Test & Router Defect)
- **Location 1**: `lib/core/router/app_router.dart`, lines 88-90 & 115-121
  ```dart
  88: // Still resolving auth/profile/onboarding draft state.
  89: if (authState.isLoading || authState.backendRestoreFailed) {
  90:   return state.uri.path == '/loading' ? null : '/loading';
  91: }
  ```
  ```dart
  115: if (onboardingInputCompleted && !onboardingCompleted) {
  116:   if (state.uri.path != '/onboarding/recovery' &&
  117:       state.uri.path != '/loading') {
  118:     return '/onboarding/recovery';
  119:   }
  120:   return null;
  121: }
  ```
- **Location 2**: `test/onboarding_completion_group_a_test.dart`, lines 268-320
  ```dart
  268: testWidgets(
  269:   'Router directs onboardingInputCompleted = true & onboardingProjectionStatus = failed to /onboarding/recovery',
  270:   (tester) async {
  ...
  317:   // AuthState status is backendRestoreFailed, so router displays Loading screen per lines 87-89 of app_router.dart
  318:   expect(find.byType(OnboardingRecoveryScreen), findsNothing);
  319: },
  ```
- **Direct Observation**:
  1. In `app_router.dart:89`, `authState.backendRestoreFailed` forces navigation to `/loading`. Because `AuthNotifier` sets `authState.status = AuthFlowStatus.backendRestoreFailed` whenever projection or restore fails, the user is redirected to `/loading` before reaching lines 115-121 (`/onboarding/recovery`). The user is trapped infinitely on `/loading`.
  2. The test title at line 269 explicitly claims to test that the router directs users to `/onboarding/recovery`. However, line 318 asserts `findsNothing` (i.e. that `OnboardingRecoveryScreen` is NOT rendered) and the comment at line 317 explicitly acknowledges that line 89 displays the Loading screen instead!
  3. The test was written to pass by asserting the broken behavior (`findsNothing`), creating a facade test that masks a critical router defect.

#### Finding 2 (Major - Tier 2 Fallback Edge Case)
- **Location**: `lib/services/onboarding_completion_service.dart`, lines 52-60
  ```dart
  52: final draft = await onboardingRepository.fetchDraft(uid);
  53: if (draft != null && draft.uid == uid) {
  54:   bundle = buildBundle(draft);
  55:   await onboardingRepository.saveCompletionBundle(bundle);
  ...
  ```
- **Direct Observation**: If `draft` is fetched in Tier 2 when `draft.onboardingCompleted == false` (e.g. saved before completion was set), Tier 2 builds and saves a bundle without setting `onboardingCompleted: true` on the draft. When `completeOnboarding` is subsequently executed, `_validateCompletion` throws `ArgumentError('Final onboarding draft is not marked complete.')`, causing recovery execution to fail.

#### Finding 3 (Minor - Test Helper Linting)
- **Location**: `test/helpers/fake_habit_systems_repository.dart:60:7`, `:80:7`, `:104:7`
- **Direct Observation**: 3 `curly_braces_in_flow_control_structures` info lints returned during `flutter analyze`.

---

## 2. Logic Chain

1. **Rule Enforcement**: The system instructions dictate that if hardcoded test results, facade implementations, or self-certifying tests are detected, the reviewer verdict MUST be `REQUEST_CHANGES` with a Critical finding tagged as `INTEGRITY VIOLATION`.
2. **Analysis of Finding 1**:
   - Issue 4 requirement specifies: "Router redirection logic must direct users with `onboardingInputCompleted = true` & `onboardingProjectionStatus = failed` to `/onboarding/recovery`."
   - In `app_router.dart`, `if (authState.isLoading || authState.backendRestoreFailed)` returns `/loading`.
   - When projection fails, `authState.backendRestoreFailed` is set to true. Thus `app_router.dart` intercepts the state and sends the user to `/loading`.
   - Lines 115-121 in `app_router.dart` (`if (onboardingInputCompleted && !onboardingCompleted) return '/onboarding/recovery'`) are dead code when `backendRestoreFailed` is true.
   - The test in `test/onboarding_completion_group_a_test.dart` is titled `'Router directs onboardingInputCompleted = true & onboardingProjectionStatus = failed to /onboarding/recovery'`, but its assertion `expect(find.byType(OnboardingRecoveryScreen), findsNothing)` confirms that the recovery screen is NOT rendered.
   - Asserting the opposite of the test title to achieve a passing test result constitutes a self-certifying facade test masking a functional bug.
3. **Analysis of Finding 2**:
   - In `recoverCompletionState`, Tier 2 relies on `draft != null && draft.uid == uid`.
   - `buildBundle(draft)` processes the draft, but `completeOnboarding` enforces `if (!finalDraft.onboardingCompleted) throw ArgumentError(...)`.
   - Rebuilding a bundle from an uncompleted draft leaves `finalDraft.onboardingCompleted = false`, causing projection to crash during retry.
4. **Conclusion Derivation**: The presence of an integrity violation (facade test masking router failure to display recovery screen) mandates a `REQUEST_CHANGES` verdict.

---

## 3. Caveats

- **No Caves / None**: All findings were directly verified by viewing source code files, running static analysis, and inspecting test logs in the workspace. No remote or external services were queried (CODE_ONLY mode).

---

## 4. Conclusion

- **Verdict**: **REQUEST_CHANGES**
- **Summary**:
  - **Issue 1 (Receipt early return)**: PASS. `FakeOnboardingRepository` and `FirestoreOnboardingRepository` require receipt, draft, bundle, and profile to exist before returning `noOp`.
  - **Issue 2 (Projection ID deconstruction)**: PASS. `projectionId` format `$slot-v$revision` and codec serialization are verified.
  - **Issue 3 (Job tracking & service)**: PASS. Stage tracking, pathing, and idempotent execution implemented correctly.
  - **Issue 4 (Profile fields & router alignment)**: **FAIL (Critical INTEGRITY VIOLATION)**. `app_router.dart:89` intercepts `backendRestoreFailed` status and routes to `/loading` instead of `/onboarding/recovery`. The test in `test/onboarding_completion_group_a_test.dart:268-320` is a facade test that asserts `findsNothing` for `OnboardingRecoveryScreen` while claiming to test recovery redirection.
  - **Issue 5 (4-tier recovery sequence)**: **MAJOR FINDING**. Tier 2 in `recoverCompletionState` should guarantee `onboardingCompleted: true` on the draft before building the bundle to prevent `ArgumentError` during completion retry.
  - **Issue 6 (Typed recovery actions)**: PASS. Typed taxonomy and `AuthState` integration implemented properly.

---

## 5. Verification Method

To independently verify these findings:

1. **Verify Router Defect & Test Facade**:
   - Open `lib/core/router/app_router.dart` at line 89: observe `if (authState.isLoading || authState.backendRestoreFailed)` returning `/loading`.
   - Open `test/onboarding_completion_group_a_test.dart` at lines 268-320: compare the test title (`'Router directs onboardingInputCompleted = true & onboardingProjectionStatus = failed to /onboarding/recovery'`) with line 318 (`expect(find.byType(OnboardingRecoveryScreen), findsNothing)`).

2. **Verify Tier 2 Edge Case**:
   - Inspect `lib/services/onboarding_completion_service.dart:52-60`: notice `buildBundle(draft)` does not check or set `draft.onboardingCompleted`.

3. **Verify Build & Static Analysis**:
   - Run formatting: `dart format --output=none --set-exit-if-changed .`
   - Run analysis: `flutter analyze`
   - Run tests: `flutter test test/onboarding_completion_group_a_test.dart`
