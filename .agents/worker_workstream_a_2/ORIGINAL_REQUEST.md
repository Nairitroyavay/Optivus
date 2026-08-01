## 2026-07-29T04:10:51Z
You are worker_workstream_a_2 assigned to execute Workstream A: Compilation and Recovery Invariants for Optivus Phase 4.6.2 Final Corrective Closure.

# Working Directories
- Project Root: /Users/roy/optivus2/Optivus
- Your Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_workstream_a_2

# MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

# YOUR TASKS
1. Set up your agent directory at `/Users/roy/optivus2/Optivus/.agents/worker_workstream_a_2` with `BRIEFING.md` and `progress.md`.
2. Fix all compilation and analyzer errors across `lib/` and `test/`:
   a. `lib/main.dart`: Add missing import for `OptivusAppEnvironmentConfig`.
   b. `lib/services/onboarding_completion_job_service.dart`: Fix invalid static member access on instance types `readbackDraft.schemaVersion` and `readbackBundle.schemaVersion`.
   c. `lib/features/recovery/models/onboarding_recovery_models.dart`: Define class `SynthesizeBundleAction` extending `OnboardingRecoveryAction`, and add `tier3Synthesized` enum value to `OnboardingRecoveryTier`.
   d. `lib/state/auth_state.dart`: Add missing imports for `onboardingCompletionJobServiceProvider` and `onboardingCompletionJobProvider`.
   e. Verify all test files (`test/challenger_p46_m3_2_adversarial_test.dart`, `test/group_h_adversarial_stress_test.dart`, `test/group_h_issues_33_to_42_test.dart`, `test/group_k_issues_63_to_68_test.dart`, `test/onboarding_completion_group_a_test.dart`, `test/work_package_c_remediation_test.dart`) compile cleanly without errors.
3. Fix Unsafe Recovery Behavior in `AuthNotifier.executeRecoveryAction` (`lib/state/auth_state.dart`):
   - Inspect `RebuildBundleFromDraftAction`.
   - Invariant: Recovery must NEVER fabricate completed onboarding or force-mark incomplete drafts (`onboardingCompleted: false`) complete (`onboardingCompleted: true`).
   - If draft is incomplete, resume onboarding flow at first missing step rather than force-marking completion.
   - If draft is valid and complete, durably write bundle and perform read-back verification before finalizing.
4. Run `flutter analyze` using `run_command` in `/Users/roy/optivus2/Optivus` to confirm 0 analyzer errors and 0 analyzer warnings across the repository.
5. Run targeted tests: `flutter test test/onboarding_completion_group_a_test.dart` (and related recovery tests).
6. Document each resolved issue using the 18-step Issue Execution Loop format (Issue ID, Severity, Status, Production path, Symptom, Reproduction, Root cause, Required invariant, Files inspected, Files changed, Tests added/changed, Firestore impact, Migration impact, Commands executed, Exact results, Remaining risks, Final verdict).
7. Write `handoff.md` in `/Users/roy/optivus2/Optivus/.agents/worker_workstream_a_2/handoff.md` and send completion report back to Lead Orchestrator via `send_message`.
