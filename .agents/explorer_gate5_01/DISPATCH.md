# Task Assignment: Error Unification, Verify Email & Static Invariants Audit

Your working directory is: `/Users/avayroy/Optivus/.agents/explorer_gate5_01`
You are an read-only exploration agent (`teamwork_preview_explorer`).

## Instructions
1. First, read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
2. Read:
   - `AGENTS.md`
   - `docs/OPTIVUS_STRICT_TASK_RULES.md`
   - `docs/ARCHITECTURE.md`
   - `docs/TECHNICAL_DEBT.md`
   - `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`
   - `lib/core/errors/recoverable_error.dart`
   - `lib/core/errors/auth_error_mapper.dart`
   - `lib/core/errors/reconstruction_error_mapper.dart`
   - `lib/core/errors/completion_error_mapper.dart`
   - `lib/core/errors/diagnostic_codes.dart`
   - `lib/state/verification_lifecycle_state.dart`
   - `lib/views/screens/verify_email_screen.dart`
   - `lib/views/screens/login_screen.dart`
   - `lib/views/screens/signup_screen.dart`
   - `lib/services/session_destination_resolver.dart`
   - `lib/core/router/app_router.dart`
   - `lib/state/auth_state.dart`
   - `lib/state/auth_flow_status.dart`
3. Search and audit:
   - `mockUserProfileProvider` and `mockOnboardingProvider` occurrences in `lib/` vs `test/`
   - `backendRestoreFailed` occurrences in `lib/` vs `test/`
   - `VerificationMessageKind`, `messageKind`, `String? message` in `VerificationLifecycleState` and `verify_email_screen.dart`
   - `showAccountError` in login/signup
   - Hard-coded logout error in `verify_email_screen.dart`
   - `AuthNotifier.statusFor()` implementation vs `SessionDestinationResolver`
   - Exact current enum values in `RecoverableError` and `AuthErrorMapper` vs what's in `GATE_5_AUTH_CLEANUP_REPORT.md`
4. Formulate rows for the mandatory pre-editing audit table:
   `AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX`
5. Write your findings to `/Users/avayroy/Optivus/.agents/explorer_gate5_01/handoff.md` and send a message when done.

## 2026-09-09T04:04:14Z
You are explorer_gate5_01. Your working directory is /Users/avayroy/Optivus/.agents/explorer_gate5_01.
Read your instructions in /Users/avayroy/Optivus/.agents/explorer_gate5_01/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
Focus on Error Unification, Verify Email, and Static Invariants (R1, R2, R3, R6).
Produce your audit report and your rows for the mandatory pre-editing audit table:
AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX
Write your handoff report to /Users/avayroy/Optivus/.agents/explorer_gate5_01/handoff.md and report back via send_message.
