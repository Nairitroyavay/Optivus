# Handoff Report — Group A Stress-Test & Empirical Verification

## Observation

1. **Static Analysis Result**:
   - Command: `flutter analyze`
   - Result: 3 info lints (`curly_braces_in_flow_control_structures` in `test/helpers/fake_habit_systems_repository.dart`). No errors or warnings found in implementation files (`lib/`).
   
2. **Existing Automated Test Suite Result**:
   - Command: `flutter test test/onboarding_completion_group_a_test.dart`
   - Result: 11/11 tests passed (00:09 runtime). All unit tests covering Issues 1 through 6 executed cleanly.

3. **Codebase Inspection**:
   - **`FirestoreOnboardingRepository.completeOnboarding` (`lib/repositories/onboarding_repository.dart:173-283`)**:
     ```dart
     190: return await _firestore.runTransaction((transaction) async {
     ...
     206: if (receiptSnapshot.exists &&
     207:     draftSnapshot.exists &&
     208:     bundleSnapshot.exists &&
     209:     profileSnapshot.exists) {
     210:   final receiptData = receiptSnapshot.data();
     211:   final profileData = profileSnapshot.data();
     212:   if (receiptData != null && profileData != null) {
     213:     final receipt = _receiptCodec.fromFirestore(
     214:       documentId: receiptSnapshot.id,
     215:       data: receiptData,
     216:     );
     217:     final inputCompleted =
     218:         profileData['onboardingInputCompleted'] as bool? ??
     219:         profileData['onboardingCompleted'] as bool? ??
     220:         false;
     221:     if (inputCompleted) {
     222:       return RoutineProjectionResult(
     223:         outcome: RoutineProjectionOutcome.noOp,
     224:         receipt: receipt,
     225:       );
     226:     }
     227:   }
     228: }
     ```
   - **`OnboardingCompletionJobService.runCompletionJob` (`lib/services/onboarding_completion_job_service.dart:25-151`)**:
     ```dart
     32: var job = OnboardingCompletionJob(
     33:   jobId: 'current',
     34:   uid: uid,
     35:   status: OnboardingJobStatus.inProgress,
     36:   stage: OnboardingCompletionStage.init,
     37:   stagesCompleted: const {},
     38:   retryCount: 0,
     39:   createdAt: now,
     40:   updatedAt: now,
     41: );
     43: await _saveJobStatus(job);
     ```
   - **`AuthState._loadOrCreateBackendUserState` (`lib/state/auth_state.dart:548-559`)**:
     ```dart
     548: if (receipt == null ||
     549:     receipt.sourceBundleFingerprint != plan.fingerprint) {
     550:   throw const _RoutineProjectionRestoreException(
     551:     'Routine setup recovery is required because its projection '
     552:     'receipt is missing or does not match.',
     553:     reason: OnboardingFailureReason.projectionReceiptMismatch,
     554:     actions: [
     555:       RetryCompletionJobAction(),
     556:       RebuildBundleFromDraftAction(),
     557:     ],
     558:   );
     559: }
     ```
   - **`OnboardingCompletionService.recoverCompletionState` (`lib/services/onboarding_completion_service.dart:36-84`)**:
     Provides 4-tier fallback: Tier 1 (`tier1BundleFound`), Tier 2 (`tier2RebuiltFromDraft`), Tier 3 (`tier3Synthesized`), Tier 4 (`tier4ResetRequired`).
   - **`app_router.dart` (`lib/core/router/app_router.dart:106-130`)**:
     Redirects based on `onboardingInputCompleted` vs `onboardingCompleted`.

4. **Added Stress Test Suite**:
   - File: `/Users/roy/optivus2/Optivus/test/onboarding_completion_group_a_stress_test.dart`
   - Added tests covering:
     - Multi-stage job resumption after failure injection during atomic projection.
     - Tier 1 fallback rejection of bundle with mismatched UID.
     - Tier 2 bundle reconstruction with complex habit/goal/spend data.
     - Deterministic 64-character SHA256 fingerprint generation in `RoutineOnboardingProjection`.

---

## Logic Chain

1. **Observation 1 & 2**: Static analysis and existing Group A test suite confirm that the baseline Group A code compiles cleanly and passes all basic functional unit tests.
2. **Observation 3 (Vulnerability 1 - Stale Fingerprint Early-Return Loop)**:
   - Line 206-227 of `FirestoreOnboardingRepository`: When `completeOnboarding` executes inside a Firestore transaction, if `receiptSnapshot.exists`, `draftSnapshot.exists`, `bundleSnapshot.exists`, `profileSnapshot.exists`, and `inputCompleted == true`, it immediately returns `RoutineProjectionOutcome.noOp` with `receipt`.
   - Critical Gap: It does NOT check whether `receipt.sourceBundleFingerprint == plan.fingerprint`.
   - Impact Scenario: If a user modifies their draft or triggers `RebuildBundleFromDraftAction()`, `plan.fingerprint` changes. When `completeOnboarding` is called during recovery, `FirestoreOnboardingRepository` sees that `receiptSnapshot.exists` and early-returns `noOp` with the OLD stale receipt. `AuthState` then compares the returned receipt's fingerprint with `plan.fingerprint`, detects `projectionReceiptMismatch`, and throws `_RoutineProjectionRestoreException`. User recovery attempts (`RetryCompletionJobAction` / `RebuildBundleFromDraftAction`) will continuously call `completeOnboarding`, which continuously returns the stale receipt. This creates an **infinite recovery loop in `backendRestoreFailed`**.
3. **Observation 3 (Vulnerability 2 - Job Service Resume Overwrites In-Progress Stages)**:
   - Line 32-43 of `OnboardingCompletionJobService`: `runCompletionJob` initializes `job` with `stagesCompleted: const {}` and immediately saves it to Firestore via `_saveJobStatus(job)` at line 43.
   - Impact: If a job fails at Stage 4 and `runCompletionJob` is invoked to retry/resume, it overwrites the Firestore job document with `stagesCompleted: {}` before evaluating Stage 1. Although downstream stages are idempotent, any monitoring listener reading `/onboardingCompletionJobs/current` will see completed stages reset to uncompleted.

---

## Caveats

1. **Firebase Live Transaction Stress**: Firebase live network operations were verified via unit/fake repositories (`FakeOnboardingRepository`, `FakeProfileRepository`). Live Firestore emulator concurrency tests were not run because local environment network mode is `CODE_ONLY`.
2. **No Implementation Changes Made**: Per challenger instructions ("Review-only — do NOT modify implementation code"), no edits were made to `lib/`.

---

## Conclusion

Group A implementation successfully resolves the core requirements for Issues 1 through 6:
- Idempotent multi-stage job execution framework (`OnboardingCompletionJobService`).
- Correct slot (`onboarding-initial`) and revision (`1`) projection ID deconstruction (`RoutineOnboardingProjection`).
- Decoupled profile truth fields (`onboardingInputCompleted`, `onboardingProjectionStatus`, `onboardingCompleted`).
- Robust 4-tier recovery fallback hierarchy (`OnboardingCompletionService.recoverCompletionState`).
- Structured typed recovery actions (`OnboardingRecoveryAction`).

**Adversarial Findings / Recommended Fixes**:
1. **[MEDIUM] `FirestoreOnboardingRepository` & `FakeOnboardingRepository` missing fingerprint check during early return**: In `completeOnboarding()`, add `&& receiptData['sourceBundleFingerprint'] == plan.fingerprint` to the early-return condition in line 220 so that fingerprint mismatches trigger a re-projection write instead of returning stale `noOp`.
2. **[LOW] `OnboardingCompletionJobService` job status overwrite on resume**: Fetch existing job document from repository/Firestore (if present) before setting `stagesCompleted: const {}` so existing stage completion status is preserved across retries.

---

## Verification Method

1. **Run Static Analysis**:
   ```bash
   flutter analyze
   ```
   *Expected*: Passes with 0 errors/warnings (3 info lints in test helper files).

2. **Run Group A Unit & Stress Test Suites**:
   ```bash
   flutter test test/onboarding_completion_group_a_test.dart
   flutter test test/onboarding_completion_group_a_stress_test.dart
   ```
   *Expected*: All tests pass 100%.

---

## Adversarial Challenge Report

### Challenge Summary
**Overall risk assessment**: MEDIUM

### Challenges

#### [Medium] Challenge 1: Stale Receipt Fingerprint Causes Infinite Recovery Loop
- **Assumption challenged**: Early return on `receiptSnapshot.exists` is sufficient for idempotency.
- **Attack scenario**: A user's routine projection receipt exists in Firestore, but their draft or completion bundle is updated or rebuilt via `RebuildBundleFromDraftAction`. `completeOnboarding` early-returns `noOp` with the existing receipt without verifying if `sourceBundleFingerprint` matches `plan.fingerprint`. `AuthState` detects `projectionReceiptMismatch` and fails auth restore. Clicking retry or rebuild repeats the exact same sequence infinitely.
- **Blast radius**: User is stuck permanently on `backendRestoreFailed` screen and cannot enter the main app without manual database intervention.
- **Mitigation**: Update line 220 in `FirestoreOnboardingRepository.completeOnboarding` to require `receiptData['sourceBundleFingerprint'] == plan.fingerprint` before early-returning `RoutineProjectionOutcome.noOp`.

#### [Low] Challenge 2: Job Service Resets Stage History in Firestore on Job Retry
- **Assumption challenged**: Creating a new `OnboardingCompletionJob` with empty `stagesCompleted` is safe on every call to `runCompletionJob`.
- **Attack scenario**: Job fails during Stage 4. Retry is invoked. `runCompletionJob` overwrites `/onboardingCompletionJobs/current` with `stagesCompleted: {}`, erasing record of Stages 1-3 completion in remote Firestore.
- **Blast radius**: Firestore job state UI/telemetry shows stage regression, though backend logic remains idempotent.
- **Mitigation**: In `runCompletionJob`, fetch existing job document from Firestore if available and merge `stagesCompleted`.
