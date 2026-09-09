# Task Assignment: Session Reset, Provider Inventory & TD-039 Audit

Your working directory is: `/Users/avayroy/Optivus/.agents/explorer_gate5_02`
You are a read-only exploration agent (`teamwork_preview_explorer`).

## Instructions
1. First, read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
2. Read:
   - `AGENTS.md`
   - `docs/OPTIVUS_STRICT_TASK_RULES.md`
   - `docs/ARCHITECTURE.md`
   - `docs/TECHNICAL_DEBT.md` (specifically TD-039)
   - `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`
   - `lib/services/auth_session_reset_coordinator.dart`
   - All providers referenced by `AuthSessionResetCoordinator`
   - `lib/state/app_state.dart`
   - `lib/state/region_settings_provider.dart`
   - `lib/state/upload_state.dart`
   - `lib/state/routine_import_ai_state.dart`
   - `lib/features/onboarding/**`
   - `lib/features/uploads/**`
   - `lib/features/home/providers/**`
   - `lib/features/tracker/providers/**`
   - `lib/features/tracker/fitness/providers/**`
   - `lib/features/profile/providers/**`
   - `lib/features/routine/**`
   - `lib/features/coach/providers/**`
   - `lib/features/goals/providers/**`
3. Repository-wide search for all Provider declarations:
   - `Provider<`, `StateProvider<`, `StateNotifierProvider<`, `NotifierProvider<`, `AsyncNotifierProvider<`, `FutureProvider<`, `StreamProvider<`
4. Exhaustively classify every provider into one of:
   - `USER_SCOPED_RESET`
   - `USER_SCOPED_UID_KEYED`
   - `USER_SCOPED_AUTO_DISPOSE`
   - `USER_SCOPED_GENERATION_FENCED`
   - `SESSION_UI_RESET`
   - `GLOBAL_CONFIG`
   - `DERIVED`
   - `REPOSITORY_UID_SCOPED`
   - `NOT_USER_SCOPED`
5. For EVERY user-scoped owner, answer the 6 questions with concrete source code evidence:
   1. Can Account A data live in this owner?
   2. What happens synchronously when A → B?
   3. Can an Account-A async callback complete after B?
   4. What prevents that callback writing into B?
   5. Does logout clear it?
   6. Does same-UID token refresh preserve it?
6. Specifically audit and classify:
   `skinCareFlowControllerProvider`, `step7ActionBridgeProvider`, `onboardingStep7PrimaryActionProvider`, `verificationLifecycleProvider`, `onboardingCompletionJobServiceProvider`, `onboardingCompletionJobProvider`, `onboardingUploadInteractionProvider`, `routineImportAiControllerProvider`, `uploadControllerProvider`, `restoredUploadsProvider`, `regionSettingsProvider`, `homeDashboardProvider`, `fitnessCenterProvider`, `trackerSettingsProvider`, `trackerSessionLinksProvider`, `profileSettingsProvider`, all six detail-view request providers, and UID-sensitive repository providers.
7. Reconcile `docs/TECHNICAL_DEBT.md` (TD-039 status) and `docs/ARCHITECTURE.md` with source evidence to eliminate documentation contradictions.
8. Formulate rows for the mandatory pre-editing audit table:
   `AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX`
9. Write your findings to `/Users/avayroy/Optivus/.agents/explorer_gate5_02/handoff.md` and send a message when done.

## 2026-09-09T04:04:14Z
You are explorer_gate5_02. Your working directory is /Users/avayroy/Optivus/.agents/explorer_gate5_02.
Read your instructions in /Users/avayroy/Optivus/.agents/explorer_gate5_02/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
Focus on Session Reset, Exhaustive Provider Inventory, and TD-039 (R4).
Exhaustively audit and classify every mutable user/session state owner in lib/state and lib/features.
Answer the 6 questions for each user-scoped owner with source evidence.
Produce your audit report and your rows for the mandatory pre-editing audit table:
AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX
Write your handoff report to /Users/avayroy/Optivus/.agents/explorer_gate5_02/handoff.md and report back via send_message.
