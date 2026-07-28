## 2026-07-27T09:11:40Z
<USER_REQUEST>
You are worker_phase46_pkgA for Phase 4.6 Final Production Closure of Optivus.

Working Directory for your artifacts: /Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgA
Project Root: /Users/roy/optivus2/Optivus

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Task:
Remediate Work Package A (Auth, Account Switch, Cold Restart & State Isolation):
1. PATH3-14-01 (P0): In `lib/state/auth_state.dart` line 538, do NOT call `_resetSignedOutState` before fetching backend user state. Ensure pre-fetch reset is removed so local cached state is not wiped on network hiccups.
2. PATH3-15-01 (P0): In `lib/state/auth_state.dart` (`logout()` / `_resetSignedOutState`), `lib/features/recovery/services/recovery_retry_controller.dart`, and `lib/features/profile/profile_tab.dart`: ensure full state purge on logout. Cancel `RecoveryRetryController` timer, reset `_activeDetail` in `_ProfileTabState`, clear Riverpod user-scoped provider streams, and reset sub-navigation request states to `.none()`.
3. PATH3-16-01 (P0): In `lib/state/auth_state.dart`, prevent cross-account data leaks when switching users on the same device. Invalidate/reset all user-dependent memory states on auth state transition whenever `user.uid` changes.
4. FINDING-P1-03 (P1): In `lib/state/auth_state.dart` (`signup()`), retain `user` in `AuthState` if `signUp` succeeds even if `sendEmailVerification()` throws, preventing auth state disconnect and trapped user.
5. PATH3-16-02 (P1): In `lib/state/auth_state.dart` (`linkAnonymousWithEmail`), pass a flag to `_loadOrCreateBackendUserState` so `_resetSignedOutState` does not wipe newly migrated memory state.
6. FINDING-P1-08 (P2): Set `state = state.copyWith(status: AuthFlowStatus.loadingBackendUser)` *before* resetting user profile state in account switch.

Instructions:
- Follow 11-step execution loop: Trace -> Reproduce -> Root Cause -> Design Minimal Safe Fix -> Review Migration Impact -> Implement -> Format -> Analyze -> Targeted Test -> Regression Test -> Re-audit.
- Run `dart format .` on modified files, `flutter analyze`, and `flutter test` for affected targets.
- Write your complete remediation report and evidence to `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgA/changes_pkgA.md` and write a handoff report at `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgA/handoff.md`.
- Send a message to orchestrator when finished.
</USER_REQUEST>
