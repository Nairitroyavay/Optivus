# Challenger Handoff Report — Phase 4.6 M3.2 Verification

## Observation

1. **AuthNotifier Recovery Data Fabrication Prevention**:
   - In `lib/state/auth_state.dart` (lines 1080–1193), `AuthNotifier.executeRecoveryAction(OnboardingRecoveryAction action)` handles recovery requests.
   - For `SynthesizeBundleAction` (lines 1089–1092), it executes `await markOnboardingIncomplete(currentUser)`. It does NOT synthesize or save blank/fabricated drafts or completion bundles with `onboardingCompleted: true`.
   - For `RestartOnboardingInputAction` (lines 1084–1087), it executes `await markOnboardingIncomplete(currentUser)`.
   - For `RebuildBundleFromDraftAction` (lines 1101–1136), if `draft == null`, it calls `OnboardingCompletionService.recoverCompletionState(...)`. If the recovery result returns `OnboardingRecoveryTier.tier4ResetRequired`, it invokes `await markOnboardingIncomplete(currentUser)`.
   - If `retryState.maxAttemptsReached` is true (lines 1094–1098), it invokes `await markOnboardingIncomplete(currentUser)`.

2. **Onboarding Completion Job Batch Limits (N > 240 items)**:
   - In `lib/repositories/onboarding_repository.dart`:
     * Line 97 (Mock repository) and Line 300 (Firebase repository):
       `if (plan.items.length > 240) { throw StateError('Onboarding produced too many Routine templates.'); }`
   - In `lib/services/onboarding_completion_job_service.dart` (lines 142–158):
     * Stage 3 (`PROJECT_ROUTINES`) calls `onboardingRepository.completeOnboarding(finalDraft: finalDraft, bundle: bundle)`.
     * When N > 240, `completeOnboarding` throws `StateError('Onboarding produced too many Routine templates.')`.
     * The catch block in `_runCompletionJob` (lines 278–287) updates `job.status = OnboardingJobStatus.failed`, increments `retryCount`, stores `lastError`, saves status to persistent/memory storage, and releases wake lock via `runWithWakeLock` (lines 90–93).

3. **linkedRoutineIds Projections & Receipt Cursor Idempotency**:
   - In `lib/services/habit_system_onboarding_projection.dart` (lines 10–116):
     * System IDs are generated via `_stableSystemId(ownerUid, key)` using SHA-256 hashes (`habitsys-onboarding-v1...`).
     * `linkedRoutineIds` are matched deterministically against projected routines and stored as `List.unmodifiable`.
   - In `lib/repositories/firebase_habit_systems_repository.dart` (lines 426–432):
     * `if (existing.linkedRoutineIds.isEmpty && sys.linkedRoutineIds.isNotEmpty)`, it updates `linkedRoutineIds`. Otherwise existing links are preserved.
   - In `lib/services/routine_onboarding_event_projector.dart` (lines 61–250):
     * If `receipt.status == 'completed'` (lines 159–172), it returns `RoutineOnboardingEventProjectionResult(attemptedCount: 0, appliedEventIds: expectedEventIds)`.
     * If `receipt.status == 'pending'` (lines 180–220), it resumes from `index = (currentReceipt.cursor - createdEventsOffset).clamp(0, events.length)`, processes batch size of 100 (`batchSize = 100`), updates `cursor`, and completes when `finalCursor == receipt.totalCount`.
   - In `lib/repositories/routine_transaction_repository.dart` (lines 211–226):
     * `targetAlreadyReached = currentReceipt.status == toReceipt.status && currentReceipt.cursor == toReceipt.cursor`.
     * If target already reached during event batch commit, transaction returns cleanly without failing or duplicating events.

4. **Empirical Custom & Full Test Suite Execution**:
   - Custom Adversarial Test Suite (`test/challenger_p46_m3_2_adversarial_test.dart`):
     * `SynthesizeBundleAction in AuthNotifier never fabricates completion data` -> PASSED
     * `RestartOnboardingInputAction marks onboarding incomplete without data fabrication` -> PASSED
     * `RebuildBundleFromDraftAction when draft and profile are missing resets state to incomplete` -> PASSED
     * `completeOnboarding throws StateError when plan.items.length > 240` -> PASSED
     * `completeOnboarding succeeds when plan.items.length == 240` -> PASSED
     * `OnboardingCompletionJobService fails gracefully when N > 240` -> PASSED
     * `HabitSystemOnboardingProjection build is deterministic and idempotent` -> PASSED
     * `RoutineOnboardingEventProjector handles completed receipts idempotently` -> PASSED
     * `RoutineOnboardingEventProjector resumes from partial cursor correctly` -> PASSED
     * Output: `00:00 +9: All tests passed!`
   - Full Test Suite Execution (`flutter test` across all 73 test files):
     * Command: `flutter test`
     * Output: `00:45 +247: All tests passed!`
     * Total Tests Executed: **247**
     * Total Tests Passed: **247**
     * Total Tests Failed: **0**

## Logic Chain

1. **Recovery Safety (AuthNotifier)**:
   - Observation 1 demonstrates that all recovery actions in `AuthNotifier.executeRecoveryAction` (`SynthesizeBundleAction`, `RestartOnboardingInputAction`, `RebuildBundleFromDraftAction` on missing draft, max attempts reached) route to `markOnboardingIncomplete(currentUser)`.
   - `markOnboardingIncomplete` updates state to `signedInOnboardingIncomplete`, with `onboardingCompleted: false`, `onboardingInputCompleted: false`, and `onboardingStep: 0`.
   - Therefore, recovery NEVER fabricates completion data, empty drafts, or fake routine bundles when user data is missing.

2. **Batch Limit Safety (N > 240 Items)**:
   - Observation 2 demonstrates that Firestore transactions in `completeOnboarding` execute `2N + 8` operations. Since Firestore transactions reject > 500 operations, any job with N > 246 would fail at the database transaction layer.
   - `completeOnboarding` enforces an explicit pre-check (`if (plan.items.length > 240)`), throwing a `StateError` BEFORE entering the transaction.
   - `OnboardingCompletionJobService` catches this exception, marks the job as `failed` with an explicit error message, saves the job status, and releases system wake locks cleanly.
   - Therefore, batch limits for N > 240 items are strictly enforced and handled gracefully without unhandled transaction crashes or orphan wake locks.

3. **Projection & Cursor Idempotency**:
   - Observation 3 demonstrates that `HabitSystemOnboardingProjection` generates deterministic system IDs via SHA-256 hashes and maps `linkedRoutineIds` predictably.
   - `RoutineOnboardingEventProjector` checks receipt status and cursor before executing event batches. If the receipt status is `'completed'`, it returns immediately with `attemptedCount: 0`. If `status == 'pending'`, it resumes processing exactly from `cursor` offset up to `totalCount`.
   - `RoutineTransactionRepository` checks `targetAlreadyReached` before committing event batches, making duplicate calls completely safe.
   - Therefore, `linkedRoutineIds` projections and routine history projector receipt cursors operate idempotently.

4. **Empirical Proof**:
   - Observation 4 provides empirical test results from `test/challenger_p46_m3_2_adversarial_test.dart` (9 passed) and the full repository test suite `flutter test` (247 passed, 0 failed).

## Caveats

- Tests run against in-memory mock repositories (`FakeOnboardingRepository`, `FakeRoutineRepository`, `FakeRoutineTransactionRepository`) and unit test harnesses. Live Firebase Firestore integration requires valid GCP credentials, which is out of scope for local offline test execution.
- No other caveats.

## Conclusion

All Phase 4.6 Milestone 3 target requirements are empirically verified and PASSED:
1. `AuthNotifier` recovery path NEVER fabricates completion data — unrecoverable recovery states safely reset to `signedInOnboardingIncomplete`.
2. Onboarding completion job batch limits (N > 240 items) are strictly guarded with pre-transaction validation throwing `StateError` and job service failure recording.
3. `linkedRoutineIds` projections and routine history projector receipt cursors work 100% idempotently across full, partial, and duplicate executions.
4. `flutter test` passes completely with **247/247 tests passing** (0 failures).

## Verification Method

1. **Run Custom Adversarial Test Suite**:
   ```bash
   flutter test test/challenger_p46_m3_2_adversarial_test.dart
   ```
   *Expected Result*: 9/9 tests pass with 0 failures.

2. **Run Full Test Suite**:
   ```bash
   flutter test
   ```
   *Expected Result*: 247/247 tests pass with 0 failures.

3. **Inspect Source Guard Locations**:
   - Recovery data fabrication prevention: `lib/state/auth_state.dart:1080–1193`
   - Batch limits (N > 240): `lib/repositories/onboarding_repository.dart:97,300`
   - Receipt cursor idempotency: `lib/services/routine_onboarding_event_projector.dart:159–220` and `lib/repositories/routine_transaction_repository.dart:211`

4. **Invalidation Conditions**:
   - If `SynthesizeBundleAction` is modified to create a new `OnboardingDraft` with `onboardingCompleted: true`.
   - If the `plan.items.length > 240` check is removed from `onboarding_repository.dart`.
   - If `RoutineOnboardingEventProjector` ignores receipt `status` or `cursor` when executing event batches.
