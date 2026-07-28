## 2026-07-27T14:41:40Z
<USER_REQUEST>
You are worker_phase46_pkgD for Phase 4.6 Final Production Closure of Optivus.

Working Directory for your artifacts: /Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgD
Project Root: /Users/roy/optivus2/Optivus

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Task:
Remediate Work Package D (Routing, Home Screen, Recovery & Diagnostics):
1. PATH3-12-01 (P0): In `lib/core/router/app_router.dart` (`optivusAuthRedirect`), fix route guard ambiguity between `isProjectionFailed`, `onboardingIncomplete`, and `onboardingInputCompleted` to eliminate infinite redirect loops between `/onboarding` and `/onboarding/recovery`. Ensure `isProjectionFailed` / `!onboardingCompleted` checks have clear non-overlapping precedence.
2. PATH3-17-01 (P0): In `lib/state/auth_state.dart` (`executeRecoveryAction`) and `lib/features/recovery/screens/onboarding_recovery_screen.dart`: remove fake data fabrication in `SynthesizeBundleAction` (do not fabricate blank onboarding drafts with `onboardingCompleted: true`). In `executeRecoveryAction`, cap retry attempts and gracefully handle validation errors to break infinite recovery loops.
3. FINDING-P1-06 (P1): In `lib/services/onboarding_completion_job_service.dart` (`_loadOrCreateJob`), when `existing.sourceFingerprint != sourceFingerprint`, update `sourceFingerprint` and reset status to pending instead of throwing uncaught fatal `StateError`.
4. PATH3-12-02 (P1): In `lib/core/router/app_router.dart`, defer state mutations inside GoRouter `redirect` callbacks using post-frame callbacks or controller routing.
5. PATH3-12-03 (P1): In `lib/views/screens/app_shell.dart`, synchronize `appNavigationProvider` tab index consistently with query parameter `?tab=N`.
6. PATH3-13-01 (P1): In `lib/features/home/home_tab.dart`, remove hardcoded email check for `test@optivus.dev` -> 'Nairit' and connect `homeDashboardProvider` to real profile/Firestore state in Firebase mode.
7. PATH3-17-02 (P1): In `lib/features/recovery/services/diagnostic_bundle_service.dart`, enhance `redactPii` to sanitize local system paths (`/Users/...`, `/data/...`) and internal auth tokens.
8. PATH3-13-02 (P2): In `lib/features/home/widgets/today_check_in_card.dart`, dispatch repository save calls (`routineRepository.saveOccurrence` / `trackerRepository.saveLog`) in Firebase mode.

Instructions:
- Follow 11-step execution loop: Trace -> Reproduce -> Root Cause -> Design Minimal Safe Fix -> Review Migration Impact -> Implement -> Format -> Analyze -> Targeted Test -> Regression Test -> Re-audit.
- Run `dart format .` on modified files, `flutter analyze`, and `flutter test` for affected targets.
- Write your complete remediation report and evidence to `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgD/changes_pkgD.md` and write a handoff report at `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgD/handoff.md`.
- Send a message to orchestrator when finished.
</USER_REQUEST>
