# Original User Request

## 2026-07-28T15:00:35Z

# Teamwork Project Prompt — Phase 4.6 Final Production Closure

> Status: Phase 4.6 — Final Production Closure
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Integrity mode: development

Complete a final production stabilization pass on the Optivus Flutter/Firebase application. Identify and fix every remaining production blocker, architectural gap, race condition, security issue, data integrity issue, and release blocker so the app is safe for real-device testing. Do not add new features or redesign working systems.

Working directory: /Users/roy/optivus2/Optivus
Integrity mode: development

## Requirements

### R1. Mandatory Initial Audit
Before modifying any production code:
- Read the onboarding architecture, completion job, authentication flow, routing, recovery, and Firestore rules.
- Read every existing Phase 4.x report under `docs/`.
- Compare reports against the actual production code.
- Ignore every previous PASSED status until independently verified.
- Create `docs/phase_4_6_final_audit.md` with every issue initially marked as NOT VERIFIED.

### R2. Audit Only the Real Production Path
Trace the real production execution path end-to-end:

Signup → Email Verification → Login → Onboarding → Draft Persistence → Completion Bundle → Routine Projection → Routine History Projection → Habit Projection → Controller Reload → Profile Finalization → Router Transition → Home Screen → Cold Restart → Sign Out → Sign In → Recovery

Never audit dead code or unused services. Never rely solely on unit tests.

Identify and resolve every remaining:
- Production blocker, architectural inconsistency, race condition, restart failure, sign-out hazard, account-switch hazard, recovery issue, projection issue, weak validation, security gap, Firestore inconsistency, migration issue, data integrity issue, duplicate logic, dead code, stale async update, release blocker.

Continue auditing until no remaining P0 or P1 production issues exist.

### R3. Production Safety Rules
Every implementation must be: deterministic, resumable, idempotent, owner-scoped, fingerprint verified, schema versioned, restart safe, account-switch safe, network safe, duplicate-action safe, migration safe.

Recovery must never: fabricate data, silently complete onboarding, or bypass validation.

Profile completion may occur only after ALL are verified: Draft persisted, Bundle persisted, Routine verified, History verified, Habit verified, Controller state verified, Frontend state verified.

### R4. Security & Data Integrity
Never weaken Firestore Rules, validation, security, or test coverage.
Never expose email, UID, token, health data, worker payloads, or sensitive user information.

### R5. Evidence-Based Fix Protocol
Always work in this order: Understand → Trace → Reproduce → Find Root Cause → Design Minimal Safe Fix → Review Migration Impact → Implement → Verify → Regression Test → Re-audit → Mark PASS.

Every completed issue must include: root cause, production path, files inspected, files changed, tests added, commands executed, migration impact, remaining risks, PASS/FAIL.

Separate CODE BLOCKERS (logic bugs, race conditions, missing validation) from ENVIRONMENT BLOCKERS (missing Android SDK, signing keys, Firebase credentials). Do not attempt to fix environment limitations in production code.

### R6. Verification & Final Reports
Every production change requires: Targeted Tests → Regression Tests → `flutter analyze` → Firestore Emulator Tests (if backend changes) → Repository Re-audit.

Create `docs/phase_4_6_release_ready.md` with: executive summary, every issue fixed, every issue discovered, production files changed, tests added, Firestore changes, migration impact, remaining technical debt, known limitations, risk assessment, release readiness score.

## Acceptance Criteria

### Automated Verification
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] Firestore Emulator tests pass (if backend changes were made)

### Build Verification
- [ ] Debug build succeeds (`flutter build apk --debug`)
- [ ] Release build succeeds or has a documented environment blocker

### Production Integrity
- [ ] `docs/phase_4_6_final_audit.md` is completed and reflects the actual codebase
- [ ] `docs/phase_4_6_release_ready.md` is completed with all required sections
- [ ] Zero remaining P0 issues
- [ ] Zero remaining P1 issues
- [ ] No known recovery loop exists in production code
- [ ] No duplicate projection exists in production code
- [ ] No stale async update exists in production code
- [ ] No account isolation issue exists in production code
- [ ] No data integrity issue exists in the audited production path

### Stop Conditions
Declare READY FOR REAL-DEVICE TESTING only when ALL of the above are true.
If any condition fails, continue the audit → fix → verify loop.
Remaining P2/P3 issues must be documented as technical debt but do not block testing.

## 2026-07-28T09:59:20Z

# Teamwork Project Prompt — Phase 4.6 Final Production Closure (Resumed)

> Status: Phase 4.6 — Final Production Closure
> Goal: Resume after interruption, complete adversarial review, verification, and final reports.
> Integrity mode: development

The previous teamwork instance completed the audit and remediation phases (Work Packages A-E) but was interrupted before completing the adversarial review, verification, and final reports. Pick up where the previous team left off.

Working directory: /Users/roy/optivus2/Optivus
Integrity mode: development

## Requirements

### R1. Context Recovery
- Review the `docs/phase_4_6_final_audit.md` generated by the previous run.
- Review the modified files from the previous run (e.g., auth state, onboarding services, tests).

### R2. Resume Adversarial Review
Dispatch reviewers, challengers, and a forensic auditor to stress-test the fixes from Work Packages A-E.

### R3. Verification & Final Reports
Every production change requires: Targeted Tests → Regression Tests → `flutter analyze` → Firestore Emulator Tests (if backend changes) → Repository Re-audit.

Create `docs/phase_4_6_release_ready.md` with: executive summary, every issue fixed, every issue discovered, production files changed, tests added, Firestore changes, migration impact, remaining technical debt, known limitations, risk assessment, release readiness score.

## Acceptance Criteria

### Automated Verification
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] Firestore Emulator tests pass (if backend changes were made)

### Build Verification
- [ ] Debug build succeeds (`flutter build apk --debug`)
- [ ] Release build succeeds or has a documented environment blocker

### Production Integrity
- [ ] `docs/phase_4_6_final_audit.md` is completed and reflects the actual codebase
- [ ] `docs/phase_4_6_release_ready.md` is completed with all required sections
- [ ] Zero remaining P0 issues
- [ ] Zero remaining P1 issues
- [ ] No known recovery loop exists in production code
- [ ] No duplicate projection exists in production code
- [ ] No stale async update exists in production code
- [ ] No account isolation issue exists in production code
- [ ] No data integrity issue exists in the audited production path

### Stop Conditions
Declare READY FOR REAL-DEVICE TESTING only when ALL of the above are true.
If any condition fails, continue the audit → fix → verify loop.
Remaining P2/P3 issues must be documented as technical debt but do not block testing.

## 2026-07-28T15:32:38Z

You are the Project Orchestrator (teamwork_preview_orchestrator) resuming Phase 4.6 Final Production Closure.

Working directory: /Users/roy/optivus2/Optivus/.agents/orchestrator
Original request: /Users/roy/optivus2/Optivus/.agents/ORIGINAL_REQUEST.md
Audit doc: /Users/roy/optivus2/Optivus/docs/phase_4_6_final_audit.md

Resume where the previous orchestrator left off:
1. Review .agents/orchestrator/plan.md and .agents/orchestrator/progress.md to understand the state. Work Packages A through E are completed.
2. Resume Milestone 3: Dispatch reviewers, challengers, and forensic auditor to stress-test the fixes.
3. Resume Milestone 4: Verification & Final Reports. Ensure `flutter analyze` passes with zero errors, `flutter test` passes with zero failures, build verification succeeds (`flutter build apk --debug`), update `docs/phase_4_6_final_audit.md`, and generate `docs/phase_4_6_release_ready.md`.
4. When all work and verification is completed and all acceptance criteria are met, send your completion claim back to Sentinel.


