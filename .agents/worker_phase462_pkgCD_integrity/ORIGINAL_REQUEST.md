## 2026-07-29T04:15:55Z
You are teamwork_preview_worker assigned to Workstream C & D: Completion Accounting, Recovery Safety, Async & Account Isolation for Optivus Phase 4.6.2 Final Corrective Closure.

# Working Directory
Your agent working directory is: `/Users/roy/optivus2/Optivus/.agents/worker_phase462_pkgCD_integrity`
Project root: `/Users/roy/optivus2/Optivus`

# OBJECTIVE
Implement completion job accounting, fix unsafe recovery forced-completion logic, invalidate static in-flight job state on sign-out, replace raw exception strings with structured failures, and remove dangerous silent exception suppression.

# MANDATORY INSTRUCTION CONSTRAINTS
- DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
- Follow the Issue Execution Loop for every issue:
  READ -> TRACE -> REPRODUCE -> IDENTIFY ROOT CAUSE -> DEFINE INVARIANT -> MINIMAL SAFE FIX -> REVIEW FIRESTORE & MIGRATION IMPACT -> IMPLEMENT -> FORMAT -> ANALYZE -> RUN TESTS -> RE-READ CODE -> UPDATE REPORT -> PASS.

# TASKS TO COMPLETE

1. **Populate Job Accounting Fields in `OnboardingCompletionJobService`**:
   - File: `lib/services/onboarding_completion_job_service.dart`
   - In `_runCompletionJob` / stage handlers, populate `expectedHistoryIds`, `appliedHistoryIds`, and `failedHistoryIds` on `OnboardingCompletionJob` using real event IDs from `RoutineOnboardingEventProjector` / reconciliation outputs instead of leaving them empty `[]`.

2. **Fix Unsafe Forced-Completion in Recovery (`auth_state.dart`)**:
   - File: `lib/state/auth_state.dart`
   - Inspect `executeRecoveryAction` handling of `RebuildBundleFromDraftAction`.
   - Invariant: Recovery must NEVER fabricate completed onboarding or force-mark an incomplete draft as `onboardingCompleted: true` without validating that mandatory onboarding fields exist.
   - Implement validation of draft completeness before bundle rebuild. If draft is incomplete, keep `onboardingCompleted: false` and resume onboarding at the correct incomplete step.

3. **In-Flight Job Cache Clearing on Sign-Out**:
   - File: `lib/services/onboarding_completion_job_service.dart`
   - Add a static method `resetForSignedOut()` (or `clearInFlightJobs()`) that clears `_inFlight` map.
   - File: `lib/state/auth_state.dart`
   - Call `OnboardingCompletionJobService.resetForSignedOut()` inside `_resetSignedOutState()` (and on sign-out) to prevent in-flight job leakage across account switches.

4. **Structured Failure Persistence & Exception Logging**:
   - File: `lib/services/onboarding_completion_job_service.dart`
   - Replace raw `e.toString()` written into `job.lastError` with sanitized, structured failure descriptions.
   - File: `lib/state/auth_state.dart` & `onboarding_completion_job_service.dart`
   - Inspect silent `catch (_) {}` blocks (e.g. in `_loadOrCreateBackendUserState`, `executeRecoveryAction`, `_saveJobStatus`) and ensure exceptions are properly logged/handled or rethrown where appropriate.

5. **Format, Analyze & Test**:
   - Run `dart format .`
   - Run `flutter analyze` — ensure zero issues.
   - Run `flutter test` — ensure all tests pass cleanly.

6. **Handoff**:
   - Write `.agents/worker_phase462_pkgCD_integrity/handoff.md` detailing changes, root cause fixes, and test results.
   - Send message back to parent orchestrator.
