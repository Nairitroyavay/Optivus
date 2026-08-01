## 2026-07-29T09:28:28Z
You are teamwork_preview_worker assigned to execute the MANDATORY INITIAL AUDIT for Optivus Phase 4.6.2 Final Corrective Closure (Generation 2 Replacement).

# Working Directory
Your agent working directory is: `/Users/roy/optivus2/Optivus/.agents/worker_phase462_initial_audit_gen2`
Project root: `/Users/roy/optivus2/Optivus`

# DO NOT EDIT PRODUCTION CODE YET
This step is strictly READ-ONLY for production code (`lib/`, `android/`, `firestore.rules`). You will write documentation files in `docs/` and metadata files in your `.agents/` directory.

# MANDATORY INITIAL AUDIT STEPS

1. **Git Baseline**:
   Run and record output for:
   - `git branch --show-current`
   - `git rev-parse HEAD`
   - `git status --short`
   - `git diff --stat`

2. **Audit Historical Reports**:
   - Inspect all existing Phase 4.x reports in `docs/` (e.g. `docs/phase_4_6_final_audit.md`, `docs/phase_4_6_release_ready.md`, `docs/phase_4_5...`, etc.).
   - Edit older/contradictory reports to add `HISTORICAL — NOT AUTHORITATIVE` header at top if they claim PASS or complete status that is superseded by Phase 4.6.2.

3. **Trace Real Production Path**:
   Trace and document the complete real execution path across `lib/`:
   Application startup → Firebase initialization → Signup → Profile creation → Email verification → Login → Profile and settings restoration → Onboarding → Final draft persistence → Draft read-back verification → Completion bundle persistence → Bundle verification → Routine reconciliation → Routine verification → Routine History projection → Routine History verification → Habit reconciliation → Habit verification → Controller reload → Frontend-state verification → Profile finalization → Router transition → Home → Cold restart → Sign out → Sign in → Account switch → Recovery.

4. **Firestore Serializer vs Rule vs Emulator Fixture Audit**:
   Compare every production Firestore serializer (`toFirestore()`, `fromFirestore()`, model parsers) against `firestore.rules` and emulator test fixtures (`test/`, `emulator/`).
   Specifically check:
   - Profile serializer & rules
   - Region-localization serializer & rules
   - App-preferences serializer & rules
   - Onboarding draft serializer & rules
   - Completion bundle serializer & rules
   - Completion job serializer & rules
   - Routine, History, Habit serializers & rules
   Check field name mismatches, enum string vs int mismatches, missing validation, allowed/denied unknown fields, ownership fields.

5. **Deep Code Analysis for Known P0/P1 Areas**:
   - Search for unresolved symbols or broken references (especially around recovery actions).
   - Search for incomplete drafts being force-marked complete.
   - Search for missing drafts producing fabricated completed onboarding.
   - Search for final draft stage completing before durable write and read-back.
   - Search for profile finalization occurring without verified state.
   - Search for coarse completion stages or missing completion-accounting fields.
   - Search for raw `e.toString()` persistence or swallowed exceptions `catch (_) {}`.
   - Search for active completion work surviving sign-out or cross-account state leakage.
   - Search for mixed Routine creation/repair missing History events.
   - Search for swallowed Firebase initialization failures.
   - Search for release build / signing configurations.

6. **Sequential Baseline Command Execution**:
   Run the following baseline commands sequentially and record exact outputs/errors:
   - `flutter pub get`
   - `dart format --output=none --set-exit-if-changed .`
   - `flutter analyze`
   - `flutter test`
   - Firestore emulator test command (e.g. check `package.json` or `scripts/` or `test/` for how emulator tests are run, run npm test or firebase emulator test script if available)
   - `flutter build apk --debug`

7. **Generate `docs/phase_4_6_2_initial_audit.md`**:
   Create and populate `/Users/roy/optivus2/Optivus/docs/phase_4_6_2_initial_audit.md` with:
   - Executive Summary
   - Git Baseline Record
   - Status of Historical Reports (marked HISTORICAL — NOT AUTHORITATIVE)
   - Complete Production Path Trace & Analysis
   - Firestore Contract Matrix (Serializer vs Rule vs Fixture)
   - Catalog of Discovered P0/P1/P2/P3 Issues with fields:
     Issue ID, Severity, Status (NOT_VERIFIED), Production Path, Symptom, Reproduction, Root Cause, Required Invariant, Workstream Category (A, B, C, D, or E).
   - Baseline Command Output & Build Results
   - Immediate Remediation Plan broken down by Workstream (A through E)

8. **Deliver Handoff**:
   Write `.agents/worker_phase462_initial_audit_gen2/handoff.md` and send a message back to parent orchestrator with the full summary of audit results and path to `docs/phase_4_6_2_initial_audit.md`.
