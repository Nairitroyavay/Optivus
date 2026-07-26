## 2026-07-26T12:10:13Z
<USER_REQUEST>
You are Explorer 1 for Group H (Issues 33–42: Recovery-Screen UI & State Repair).
Your working directory is /Users/roy/optivus2/Optivus/.agents/explorer_h_1.

Task:
Perform a deep-dive investigation of Group H issues:
- Issue 33: System recovery scaffold trigger conditions on corruption error
- Issue 34: Recovery action typed error presentation and user messaging
- Issue 35: Draft profile repair action execution from recovery UI
- Issue 36: Routine projection state force-resync from recovery UI
- Issue 40: Recovery screen navigation lock preventing unverified app entry

Investigate the codebase in /Users/roy/optivus2/Optivus:
1. Inspect `lib/features/recovery/`, `lib/core/router/app_router.dart`, `lib/state/auth_state.dart`, `lib/services/onboarding_completion_job_service.dart`, `lib/services/onboarding_completion_service.dart`.
2. Trace when system recovery scaffold is triggered on corruption/restore errors, how typed errors (`OnboardingFailureReason`, `OnboardingRecoveryAction`) are presented, how repair actions (`RetryCompletionJobAction`, `RebuildBundleFromDraftAction`, `SynthesizeBundleAction`, `RestartOnboardingInputAction`) execute, how force-resync works, and how router navigation locks user on recovery screen until state is repaired.
3. Identify root causes, gaps, required code changes, and test strategies.
4. Produce report in /Users/roy/optivus2/Optivus/.agents/explorer_h_1/analysis.md and deliver a handoff.md.
</USER_REQUEST>
