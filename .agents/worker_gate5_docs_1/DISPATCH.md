# Task Assignment: Phase 2/5 Documentation & Gate 5 Report Reconciliation

Your working directory is: `/Users/avayroy/Optivus/.agents/worker_gate5_docs_1`
You are a worker agent (`teamwork_preview_worker`).

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- MANDATORY: Read `/Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md` completely.
- Read `/Users/avayroy/Optivus/.agents/orchestrator_gate5_1/AUDIT_TABLE.md`.
- Read `/Users/avayroy/Optivus/.agents/explorer_gate5_01/handoff.md` (specifically Section 1.4: RecoverableError enum discrepancies in GATE_5_AUTH_CLEANUP_REPORT.md).
- Read `/Users/avayroy/Optivus/.agents/explorer_gate5_02/handoff.md` (specifically Section 5: Technical Debt & Architecture Reconciliation TD-039).
- Read `/Users/avayroy/Optivus/.agents/worker_gate5_phase1_1/handoff.md` (Phase 1 implementation details).

## Exclusive Write Ownership
You own and may edit ONLY these files:
- `docs/TECHNICAL_DEBT.md`
- `docs/ARCHITECTURE.md`
- `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`

Do NOT edit any source code or test files.

## Instructions
1. **Update `docs/TECHNICAL_DEBT.md`**:
   - Reconcile TD-039 (Authentication/session isolation):
     - Mark status as **Closed** in Gate 5.
     - Document that `AuthSessionResetCoordinator` acts as the centralized synchronous privacy boundary on `null → A`, `A → B`, and `logout` (`resetIdentityBoundary`), invalidating and resetting Routine, Habits, Home, Mind, Fitness, Profile, Tracker, Upload, and Region state.
     - Document that real reconstruction async race tests (Tests A, B, C, D) using controlled `ServerReconstructionSource` verify pipeline-level isolation under concurrent and late completions.

2. **Update `docs/ARCHITECTURE.md`**:
   - In Section 10.5 row 7 ("User-scoped providers survive the explicit logout reset"):
     - Update description and resolution: `AuthSessionResetCoordinator` now invalidates and resets feature-local Routine, Home, Fitness, Profile, Onboarding, Tracker, Upload, and Region state on logout and account switch.
     - Note that Gate 5 resolved the gap with verified automated tests.

3. **Update `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md`**:
   - **Section G (Error Authority Matrix)**:
     - Replace nonexistent enum categories (`rateLimit`, `backend`) and action (`waitAndRetry`) with the actual 12 `RecoverableErrorCategory` and 11 `RecoverableRetryAction` enum members in `lib/core/errors/recoverable_error.dart`.
     - Correct `email-already-in-use` category to `authentication` and action to `reauthenticate`.
     - Correct `user-not-found` and `wrong-password` action to `retry`.
     - Correct `too-many-requests` category to `authentication` and action to `none`.
     - Map server reconstruction failure through `ReconstructionErrorMapper` (`network` with `retry` or `authentication` with `reauthenticate` or `recoveryRequired` with `restartRecovery`).
   - Document the completion of R3: removal of `VerificationMessageKind`, replacement with `RecoverableError? error; String? successMessage;`, typed `showAccountError(RecoverableError)`, and removal of hardcoded logout error override.
   - Document the completion of R6: `test/gate5_static_architecture_test.dart` enforcing all architectural invariants.
   - Update TD-039 status and evidence.

4. **Verification**:
   - Verify that all three markdown files are internally consistent, accurately reflect the codebase, and have no remaining contradictions.
   - Write your handoff report to `/Users/avayroy/Optivus/.agents/worker_gate5_docs_1/handoff.md`.

## 2026-09-09T04:19:39Z
You are worker_gate5_docs_1. Your working directory is /Users/avayroy/Optivus/.agents/worker_gate5_docs_1.
Read your instructions in /Users/avayroy/Optivus/.agents/worker_gate5_docs_1/DISPATCH.md.
MANDATORY: Read /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md before starting work.
MANDATORY INTEGRITY WARNING: DO NOT CHEAT. All implementations must be genuine.
Exclusive write ownership:
- docs/TECHNICAL_DEBT.md
- docs/ARCHITECTURE.md
- docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md
Reconcile TD-039 status, ARCHITECTURE.md Section 10.5, and GATE_5_AUTH_CLEANUP_REPORT.md Section G error matrix.
Write your handoff report to /Users/avayroy/Optivus/.agents/worker_gate5_docs_1/handoff.md and report back via send_message.
