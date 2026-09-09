# Task Assignment: Auth Reconstruction, Race Tests & Regression Suite Audit

Your working directory is: `/Users/avayroy/Optivus/.agents/explorer_gate5_03`
You are a read-only exploration agent (`teamwork_preview_explorer`).

## Instructions
1. First, read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
2. Read:
   - `AGENTS.md`
   - `docs/OPTIVUS_STRICT_TASK_RULES.md`
   - `docs/ARCHITECTURE.md`
   - `lib/services/server_reconstructor.dart`
   - `lib/services/onboarding_frontend_hydration_service.dart`
   - `lib/state/auth_state.dart`
   - `lib/state/auth_generation.dart`
   - `lib/repositories/auth_repository.dart`
3. Audit existing tests:
   - `test/gate5_auth_session_isolation_test.dart`
   - `test/ah_f004_auth_identity_isolation_test.dart`
   - `test/ah_f003_google_auth_test.dart`
   - `test/workstream_d_auth_async_isolation_test.dart`
   - `test/onboarding_session_destination_test.dart`
   - `test/onboarding_routing_test.dart`
   - `test/onboarding_restore_test.dart`
   - `test/verify_email_redesign_test.dart`
   - `test/ah_f020_recoverable_error_model_test.dart`
   - `test/ah_f011_no_production_mock_leakage_test.dart`
   - `test/routine_phase4_4_ownership_test.dart`
   - Cross-gate regression tests for Gate 1, 2, 3, 4.
4. Deeply analyze R5 requirements for real reconstruction race tests:
   - TEST A: A reconstruction completes after B
   - TEST B: A reconstruction completes after sign-out
   - TEST C: Failed logout preserves Account A
   - TEST D: Same UID refresh
   Investigate how `ServerReconstructionSource` / `serverReconstructorProvider` / `AuthNotifier` can be driven with `Completer` objects in tests to create this real, controlled async race condition without relying on mock delays or UI delays.
5. Deeply analyze R6 static architecture enforcement test:
   What tests currently exist for R6 invariants? How to structure the static architecture test to verify all R6 invariants cleanly?
6. Formulate rows for the mandatory pre-editing audit table:
   `AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX`
7. Write your findings to `/Users/avayroy/Optivus/.agents/explorer_gate5_03/handoff.md` and send a message when done.

## 2026-09-09T04:04:14Z

You are explorer_gate5_03. Your working directory is /Users/avayroy/Optivus/.agents/explorer_gate5_03.
Read your instructions in /Users/avayroy/Optivus/.agents/explorer_gate5_03/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
Focus on Auth Reconstruction Pipeline, Real Race Tests, and Regression Suites (R5, R6, Gates 1-5).
Analyze the design of Test A, B, C, D using Completer-based ServerReconstructionSource.
Audit existing tests and regression suites.
Produce your audit report and your rows for the mandatory pre-editing audit table:
AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX
Write your handoff report to /Users/avayroy/Optivus/.agents/explorer_gate5_03/handoff.md and report back via send_message.
