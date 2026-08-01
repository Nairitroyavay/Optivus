## 2026-07-29T09:41:09Z
You are teamwork_preview_worker assigned to Workstream A & B: Compilation, Type Safety, Symbols, and Recovery Contracts for Optivus Phase 4.6.2 Final Corrective Closure.

# Working Directory
Your agent working directory is: `/Users/roy/optivus2/Optivus/.agents/worker_phase462_pkgA_compilation`
Project root: `/Users/roy/optivus2/Optivus`

# OBJECTIVE
Resolve all 20 static analysis errors and compilation blockers across `lib/` and `test/` so that `flutter analyze` passes with zero errors and `flutter test` compiles cleanly.

# MANDATORY INSTRUCTION CONSTRAINTS
- DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
- Follow the Issue Execution Loop for every issue:
  READ -> TRACE -> REPRODUCE -> IDENTIFY ROOT CAUSE -> DEFINE INVARIANT -> MINIMAL SAFE FIX -> REVIEW FIRESTORE & MIGRATION IMPACT -> IMPLEMENT -> FORMAT -> ANALYZE -> RUN TESTS -> RE-READ CODE -> UPDATE REPORT -> PASS.

# TASKS TO COMPLETE

1. **Fix Missing Import in `lib/main.dart`**:
   - Locate definition of `OptivusAppEnvironmentConfig` (search `lib/` for class definition, e.g. `lib/config/` or `lib/services/`).
   - Add missing `import` statement in `lib/main.dart` so `OptivusAppEnvironmentConfig.requiresLiveServices` resolves.

2. **Fix Invalid Static Member Accesses in `lib/services/onboarding_completion_job_service.dart`**:
   - Inspect `OnboardingDraft` (in `lib/features/onboarding/models/onboarding_draft.dart`) and `OnboardingCompletionBundle` (in `lib/features/onboarding/models/onboarding_completion_bundle.dart`).
   - In `lib/services/onboarding_completion_job_service.dart`:
     - Change line 133 `readbackDraft.schemaVersion` to correct static accessor `OnboardingDraft.schemaVersion` or getter `readbackDraft.schemaVersion`.
     - Change line 154 `readbackBundle.schemaVersion` to correct static accessor `OnboardingCompletionBundle.schemaVersion` or getter `readbackBundle.schemaVersion`.

3. **Restore / Define `SynthesizeBundleAction` and `tier3Synthesized`**:
   - Inspect `lib/features/recovery/models/onboarding_recovery_models.dart`.
   - Restore or define `SynthesizeBundleAction` class extending `OnboardingRecoveryAction` (with proper JSON serialization / props / recovery tier).
   - Ensure `OnboardingRecoveryTier` enum contains `tier3Synthesized` (or restore its definition if removed).
   - Verify `auth_state.dart` (lines 754 & 772) references `SynthesizeBundleAction` correctly.

4. **Fix Missing Imports in `lib/state/auth_state.dart`**:
   - Import `lib/services/onboarding_completion_job_service.dart` (or provider file) in `lib/state/auth_state.dart` so `onboardingCompletionJobServiceProvider` and `onboardingCompletionJobProvider` are defined and resolved.

5. **Fix Broken Test File References**:
   - Check and fix compilation in:
     - `test/challenger_p46_m3_2_adversarial_test.dart`
     - `test/group_h_adversarial_stress_test.dart`
     - `test/group_h_issues_33_to_42_test.dart`
     - `test/group_k_issues_63_to_68_test.dart`
     - `test/onboarding_completion_group_a_test.dart`
     - `test/work_package_c_remediation_test.dart`
   - Ensure all test references to `SynthesizeBundleAction` and `tier3Synthesized` match the restored model definitions.

6. **Format, Analyze & Test**:
   - Run `dart format .`
   - Run `flutter analyze` and ensure 0 issues are reported.
   - Run `flutter test` and record test results.

7. **Handoff**:
   - Write `.agents/worker_phase462_pkgA_compilation/handoff.md` summarizing files changed, root causes fixed, and exact output of `flutter analyze` and `flutter test`.
   - Send message back to parent orchestrator with results.
