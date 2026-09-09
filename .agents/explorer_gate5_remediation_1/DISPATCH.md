# Task Assignment: Forensic Audit Remediation Explorer

Your working directory is: `/Users/avayroy/Optivus/.agents/explorer_gate5_remediation_1`
You are an exploration agent (`teamwork_preview_explorer`).

## Mandatory Inputs & Rules
- MANDATORY: Read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` before starting work.
- You MUST address the specific integrity violations identified by the Forensic Auditor.
- You MUST NOT recommend strategies that circumvent the audit.

## Full Evidence Report from Forensic Auditor (`auditor_gate5_1`)
The full, verbatim report is located at:
`/Users/avayroy/Optivus/.agents/auditor_gate5_1/handoff.md`

### Summary of Violations from Auditor:
1. **Check 4 (Build & Run) Concurrent Test Execution Failure**:
   When running the 13 Gate 5 test suites concurrently:
   `flutter test --reporter compact test/gate5_auth_session_isolation_test.dart test/ah_f004_auth_identity_isolation_test.dart test/ah_f003_google_auth_test.dart test/workstream_d_auth_async_isolation_test.dart test/onboarding_session_destination_test.dart test/onboarding_routing_test.dart test/onboarding_restore_test.dart test/verify_email_redesign_test.dart test/ah_f020_recoverable_error_model_test.dart test/ah_f011_no_production_mock_leakage_test.dart test/routine_phase4_4_ownership_test.dart test/gate5_static_architecture_test.dart test/gate5_auth_reconstruction_race_test.dart`
   Fails at `test/gate5_auth_reconstruction_race_test.dart:399` in `TEST A`:
   `Expected: true, Actual: <false>` for `expect(source.hasPendingLoad(_userB.uid), isTrue);`.
   Root cause: Line 375 uses a fixed `await pumpEventQueue(times: 20);`. Under heavy isolate concurrency, 20 microtask pumps are exhausted before `loadForUser` completes its platform channel catch and calls `source.load(_userB.uid)`.
2. **Report Attestation Discrepancy**:
   `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section K omitted `test/gate5_auth_reconstruction_race_test.dart` (8 tests) and claimed 248/248 passed, when the true total is 256 tests and the concurrent suite fails.

## Your Task
1. Investigate the failure in `test/gate5_auth_reconstruction_race_test.dart` around line 375.
   - Formulate the exact, resilient mechanism to await `source.hasPendingLoad(_userB.uid)` without brittle fixed-iteration counts (e.g. `while (!source.hasPendingLoad(_userB.uid)) await pumpEventQueue(times: 10);` or `await _waitForPendingLoad(source, _userB.uid)` with timeout) so that all 13 suites pass 100% concurrently without flakiness.
2. Investigate `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` Section K and Section P:
   - Provide exact diff to add `gate5_auth_reconstruction_race_test.dart` (8 tests passed, 0 failed, 0 skipped) to the Section K table and update Total Gate 5 Focused to 256 passed, and Section P to 256 passed.

## 2026-09-09T04:44:55Z
<USER_REQUEST>
You are explorer_gate5_remediation_1. Your working directory is /Users/avayroy/Optivus/.agents/explorer_gate5_remediation_1.
Read your instructions in /Users/avayroy/Optivus/.agents/explorer_gate5_remediation_1/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
MANDATORY: Read /Users/avayroy/Optivus/.agents/auditor_gate5_1/handoff.md for the full, verbatim evidence report from the Forensic Auditor.
Investigate the concurrent test failure in test/gate5_auth_reconstruction_race_test.dart:399 and the test count omission in docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md.
Formulate the exact, minimal fix specification for the Worker.
Write your handoff report to /Users/avayroy/Optivus/.agents/explorer_gate5_remediation_1/handoff.md and report back via send_message.
</USER_REQUEST>
