## 2026-07-25T13:47:25Z
You are worker_group_a_remediation fixing the review and challenge findings for Group A (Issues 1 through 6).

Your Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_group_a_remediation

Your tasks:
1. Initialize your working directory at /Users/roy/optivus2/Optivus/.agents/worker_group_a_remediation. Create progress.md and BRIEFING.md inside it.
2. Implement the following 4 remediation fixes for Group A:
   - **Fix 1 (Fingerprint check in completeOnboarding)**:
     In `FirestoreOnboardingRepository.completeOnboarding()` (`lib/repositories/onboarding_repository.dart`) and `FakeOnboardingRepository`, when `receiptSnapshot.exists` is true, verify `receipt.sourceBundleFingerprint == plan.fingerprint` before early returning `RoutineProjectionOutcome.noOp`. If fingerprint differs (e.g. draft was rebuilt), execute reconciliation/re-projection instead of returning stale receipt.
   - **Fix 2 (Router redirect for backendRestoreFailed)**:
     In `app_router.dart` (`lib/core/router/app_router.dart`), fix `authState.backendRestoreFailed` handling so it directs to `/onboarding/recovery` (rendering `OnboardingRecoveryScreen`), allowing users to execute typed recovery actions instead of trapping them on `/loading`.
   - **Fix 3 (Tier 2 draft completion flag)**:
     In `OnboardingCompletionService.recoverCompletionState()` (`lib/services/onboarding_completion_service.dart`), when executing Tier 2 recovery from `onboardingDraft`, ensure the draft has `onboardingCompleted: true` before building `completionBundle`.
   - **Fix 4 (Test suite update)**:
     In `test/onboarding_completion_group_a_test.dart` and `test/onboarding_completion_group_a_stress_test.dart`, update tests to verify that `backendRestoreFailed` routes to `/onboarding/recovery` and displays `OnboardingRecoveryScreen`.
3. Execute verification:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
4. Update `docs/onboarding_stabilization_report.md` for Issues 1 through 6 with the remediation details.
5. Write your complete handoff report to `/Users/roy/optivus2/Optivus/.agents/worker_group_a_remediation/handoff.md`.
6. Call `send_message` to report your completion back to parent (conversation ID `c0e4321c-6fa0-4db6-96ba-cc58168c5ffb`).
