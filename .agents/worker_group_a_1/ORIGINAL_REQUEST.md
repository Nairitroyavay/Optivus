## 2026-07-25T13:27:36Z
You are worker_group_a_1 implementing Group A (Issues 1 through 6: Onboarding completion truth).

Your Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_group_a_1

Your task:
1. Initialize your working directory at /Users/roy/optivus2/Optivus/.agents/worker_group_a_1. Create progress.md and BRIEFING.md inside it.
2. Read the detailed handoff report from explorer_group_a_1 at `/Users/roy/optivus2/Optivus/.agents/explorer_group_a_1/handoff.md`.
3. Implement the fixes for Issues 1 through 6:
   - **Issue 1 (Unsafe receipt early return)**: Refactor `completeOnboarding()` in `FirestoreOnboardingRepository` (`lib/repositories/onboarding_repository.dart`) and `FakeOnboardingRepository` to validate bundle, draft, and profile patch existence alongside receipt fingerprint match before returning `noOp`.
   - **Issue 2 (Fixed projection ID)**: Deconstruct fixed `'onboarding-initial-v1'` string in `RoutineOnboardingProjection` (`lib/services/routine_onboarding_projection.dart`) into `slot`, `revision`, and `fingerprint`. Update `RoutineProjectionReceipt` model (`lib/models/routine_projection_receipt.dart`).
   - **Issue 3 (Completion job)**: Add `onboardingCompletionJob` path to `FirestoreUserPaths` (`lib/repositories/firestore_paths.dart`), create `OnboardingCompletionJob` model (`lib/models/onboarding_completion_job.dart`), and implement idempotent `OnboardingCompletionJobService` (`lib/services/onboarding_completion_job_service.dart`).
   - **Issue 4 (Profile fields & router alignment)**: Update `UserProfile` (`lib/models/user_profile.dart`) and `UserModel` (`lib/models/user_model.dart`) with `onboardingInputCompleted`, `onboardingProjectionStatus`, and `onboardingCompleted` (getter). Align router redirect in `app_router.dart` (`lib/core/router/app_router.dart`) and `AuthState` (`lib/state/auth_state.dart`).
   - **Issue 5 (Recovery sequence)**: Implement 4-tier recovery fallback `recoverCompletionState()` in `OnboardingCompletionService` / `AuthState` (`lib/services/onboarding_completion_service.dart`, `lib/state/auth_state.dart`).
   - **Issue 6 (Typed recovery actions)**: Define `OnboardingFailureReason` and executable `OnboardingRecoveryAction` taxonomy (`lib/features/recovery/models/onboarding_recovery_models.dart`) and integrate into `AuthState`.
4. Add comprehensive unit & integration tests for all 6 issues in `test/`.
5. Run formatting, analyzer, and tests:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
6. Update `docs/onboarding_stabilization_report.md` for Issues 1 through 6: set `Status: PASSED`, populate root cause, files changed, fix implemented, targeted tests, regression tests, runtime verification, re-audit result, evidence.
7. Write your handoff report to `/Users/roy/optivus2/Optivus/.agents/worker_group_a_1/handoff.md`.
8. Call `send_message` to report your completion back to parent (conversation ID `c0e4321c-6fa0-4db6-96ba-cc58168c5ffb`).
