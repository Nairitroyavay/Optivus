# Task Assignment: Forensic Audit Remediation Worker

Your working directory is: `/Users/avayroy/Optivus/.agents/worker_gate5_remediation_1`
You are a worker agent (`teamwork_preview_worker`).

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- MANDATORY: Read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
- Read `/Users/avayroy/Optivus/.agents/auditor_gate5_1/handoff.md` (Forensic Auditor failure evidence).
- Read `/Users/avayroy/Optivus/.agents/explorer_gate5_remediation_1/handoff.md` (Remediation Explorer fix specifications).

## Exclusive Write Ownership
You own and may edit ONLY these two files:
- `test/gate5_auth_reconstruction_race_test.dart`
- `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`

## Instructions
1. **In `test/gate5_auth_reconstruction_race_test.dart`**:
   - Add `waitForPendingLoad` to `CompleterServerReconstructionSource` (around line 59):
     ```dart
     /// Resiliently pumps the event queue until [load] has been entered for [uid]
     /// and is awaiting completer resolution.
     Future<void> waitForPendingLoad(
       String uid, {
       Duration timeout = const Duration(seconds: 5),
     }) async {
       final stopwatch = Stopwatch()..start();
       while (!hasPendingLoad(uid)) {
         if (stopwatch.elapsed > timeout) {
           throw TimeoutException(
             'Timed out waiting for pending load for $uid after ${stopwatch.elapsed}',
           );
         }
         await pumpEventQueue(times: 5);
       }
     }
     ```
   - In `TEST A` (around line 375), replace:
     ```dart
     authRepo.emitUserForTesting(_userB);
     await pumpEventQueue(times: 20);
     ```
     with:
     ```dart
     authRepo.emitUserForTesting(_userB);
     await source.waitForPendingLoad(_userB.uid);
     ```
   - In `TEST A (Home destination)` (around line 470), replace:
     ```dart
     authRepo.emitUserForTesting(_userB);
     await pumpEventQueue(times: 20);
     expect(source.hasPendingLoad(_userB.uid), isTrue);
     ```
     with:
     ```dart
     authRepo.emitUserForTesting(_userB);
     await source.waitForPendingLoad(_userB.uid);
     expect(source.hasPendingLoad(_userB.uid), isTrue);
     ```
   - Also update initial Account A load wait lines (`line 359`, `line 465`, `line 534`, `line 587`, `line 640`, `line 678`, `line 813`) to use `await source.waitForPendingLoad(_userA.uid);` for uniform test resilience.

2. **In `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`**:
   - Section K (`Commands run:`): add `test/gate5_auth_reconstruction_race_test.dart` to the list of test files.
   - Section K (Table): add `gate5_auth_reconstruction_race_test.dart` row with `8 | 0 | 0`, and update `**Total Gate 5 Focused**` to `**256** | **0** | **0**`.
   - Section O (Line 352): update test file citation to `test/gate5_auth_reconstruction_race_test.dart`.
   - Section P (Final Verdict Table): update `Gate 5 focused test suite` count to `256 passed, 0 failed`.

3. **Verification**:
   - Run `dart format --output=none --set-exit-if-changed test/gate5_auth_reconstruction_race_test.dart`
   - Run `flutter analyze test/gate5_auth_reconstruction_race_test.dart`
   - Run the full concurrent 13-suite command:
     ```bash
     flutter test --reporter compact \
       test/gate5_auth_session_isolation_test.dart \
       test/ah_f004_auth_identity_isolation_test.dart \
       test/ah_f003_google_auth_test.dart \
       test/workstream_d_auth_async_isolation_test.dart \
       test/onboarding_session_destination_test.dart \
       test/onboarding_routing_test.dart \
       test/onboarding_restore_test.dart \
       test/verify_email_redesign_test.dart \
       test/ah_f020_recoverable_error_model_test.dart \
       test/ah_f011_no_production_mock_leakage_test.dart \
       test/routine_phase4_4_ownership_test.dart \
       test/gate5_static_architecture_test.dart \
       test/gate5_auth_reconstruction_race_test.dart
     ```
     Ensure all 256 tests pass concurrently without failures!
   - Write your handoff report to `/Users/avayroy/Optivus/.agents/worker_gate5_remediation_1/handoff.md`.

## 2026-09-09T04:49:25Z
You are worker_gate5_remediation_1. Your working directory is /Users/avayroy/Optivus/.agents/worker_gate5_remediation_1.
Read your instructions in /Users/avayroy/Optivus/.agents/worker_gate5_remediation_1/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
Exclusive write ownership:
- test/gate5_auth_reconstruction_race_test.dart
- docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md
Implement the exact remediation specifications to fix the concurrent test failure and documentation discrepancy.
Run format, analyze, and the full concurrent 13-suite test run.
Write your handoff report to /Users/avayroy/Optivus/.agents/worker_gate5_remediation_1/handoff.md and report back via send_message.
