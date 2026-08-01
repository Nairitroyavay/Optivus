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

## 2026-07-28T17:04:51Z

# Teamwork Project Prompt — Optivus Phase 4.6.2 Final Corrective Closure

> Status: Launched
> Project: Optivus Flutter/Firebase
> Working directory: /Users/roy/optivus2/Optivus
> Integrity mode: development
> Scope: Stabilization and pre-device closure only
> Maximum permitted conclusion: READY FOR CONTROLLED REAL-DEVICE TESTING

## Mission

Resolve every remaining P0 and P1 blocker in the existing Optivus production
path.

The team must:

- restore a clean compilable state;
- align production Firebase serializers with Firestore Rules;
- remove unsafe onboarding-recovery behavior;
- complete the persisted onboarding completion state machine;
- guarantee Routine, History and Habit projection integrity;
- prove sign-out and account-switch isolation;
- connect structured failures to production behavior;
- verify Firebase startup behavior;
- produce a correctly configured Android staging release artifact.

Do not add new features.

Do not begin Phase 5.

Do not claim formal real-device testing, production readiness, or public-release
readiness during this task.

## Authoritative Specification

The complete Phase 4.6.2 specification supplied by the user is authoritative
and must be included in full in the delegated task context.

Do not replace it with only this summary.

When this summary conflicts with the detailed specification, follow the stricter
requirement.

The lead agent must confirm that every delegated agent received the relevant
requirements before assigning work.

## Source-of-Truth Order

Use the following priority:

1. Current compilable production code
2. Production serializers
3. Firestore Rules
4. Firestore emulator behavior
5. Automated test results
6. Generated build artifacts
7. Reports and previous PASS labels

Reports must never override contradictory production code.

All existing PASS labels begin as NOT VERIFIED.

## Mandatory Initial Audit

Before modifying production code:

1. Confirm the repository path.
2. Record:

   git branch --show-current
   git rev-parse HEAD
   git status --short
   git diff --stat

3. Read all Phase 4.x reports.
4. Mark outdated or contradictory reports:

   HISTORICAL — NOT AUTHORITATIVE

5. Trace the real production path:

   Application startup
   → Firebase initialization
   → Signup
   → Profile creation
   → Email verification
   → Login
   → Profile and settings restoration
   → Onboarding
   → Final draft persistence
   → Draft read-back verification
   → Completion bundle persistence
   → Bundle verification
   → Routine reconciliation
   → Routine verification
   → Routine History projection
   → Routine History verification
   → Habit reconciliation
   → Habit verification
   → Controller reload
   → Frontend-state verification
   → Profile finalization
   → Router transition
   → Home
   → Cold restart
   → Sign out
   → Sign in
   → Account switch
   → Recovery

6. Compare every production Firestore serializer with its corresponding Rule and
   emulator fixture.
7. Search for unresolved symbols, stale recovery actions, unsafe completion
   assignments, silent catches, raw exception persistence, debug release signing,
   and unused completion-accounting fields.
8. Run the available baseline sequentially:

   flutter pub get
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   Firestore emulator test command
   flutter build apk --debug

9. Create and populate:

   docs/phase_4_6_2_initial_audit.md

Do not edit production code until the initial audit is complete.

## Known Priority Areas

Treat these as NOT VERIFIED until independently tested:

### P0

- Unresolved or deleted recovery-action references.
- Incomplete drafts being force-marked complete.
- Missing drafts producing fabricated completed onboarding.
- Profile serializer and Firestore Rule mismatch.
- Region-localization serializer and Rule mismatch.
- App-preferences serializer and Rule mismatch.
- Completion-job serializer and Rule mismatch.
- Emulator fixtures using test-only field names or enum formats.
- Final draft stage completing before durable write and read-back.
- Profile finalization occurring without verified Draft, Bundle, Routine,
  History, Habit, controller and frontend state.

### P1

- Completion stages being too coarse.
- Completion-accounting fields not populated by production services.
- Structured failure fields existing but raw `e.toString()` still being used.
- Important `catch (_) {}` paths suppressing failures.
- Active completion work surviving sign-out.
- Account A operations modifying Account B local state.
- Mixed Routine creation and repair missing History events.
- Firebase initialization failure being swallowed.
- Release build using debug signing or invalid runtime definitions.
- Release APK/AAB being reported without confirming the artifact exists.

## Required Engineering Properties

Every fix must be:

- deterministic;
- resumable;
- idempotent;
- owner-scoped;
- fingerprint-verified;
- schema-versioned;
- restart-safe;
- account-switch-safe;
- network-safe;
- duplicate-action-safe;
- migration-safe.

Recovery must never fabricate data or silently complete onboarding.

Profile completion must occur last and exactly once.

## Issue Execution Loop

For every issue use:

READ
→ TRACE THE REAL PRODUCTION PATH
→ REPRODUCE
→ IDENTIFY ROOT CAUSE
→ DEFINE THE REQUIRED INVARIANT
→ DESIGN THE MINIMAL SAFE FIX
→ REVIEW MIGRATION AND FIRESTORE IMPACT
→ IMPLEMENT
→ FORMAT
→ ANALYZE
→ RUN TARGETED TESTS
→ RUN RELATED REGRESSION TESTS
→ RUN EMULATOR TESTS WHEN APPLICABLE
→ RE-READ THE CHANGED CODE
→ SEARCH FOR ALTERNATE BROKEN PATHS
→ UPDATE THE AUTHORITATIVE REPORT
→ PASS, BLOCK, OR LOOP AGAIN

Do not proceed while the current issue leaves a broken invariant.

## Teamwork and File Ownership

One lead agent owns:

- architecture decisions;
- the authoritative issue tracker;
- workstream assignment;
- overlapping-file prevention;
- patch review;
- integration testing;
- final verdict.

Parallel work is allowed only for independent areas.

Suggested workstreams:

### Workstream A — Compilation and Recovery

- unresolved symbols;
- stale recovery actions;
- unsafe forced completion;
- recovery-command architecture.

### Workstream B — Firestore Contracts

- profile;
- region localization;
- app preferences;
- onboarding draft;
- completion bundle;
- completion job;
- Routine;
- History;
- Habit;
- Rules and real-schema emulator fixtures.

### Workstream C — Completion and Projection Integrity

- fine-grained completion stages;
- durable draft;
- bundle verification;
- Routine reconciliation;
- complete History coverage;
- Habit verification;
- controller and frontend verification;
- profile finalization.

### Workstream D — Authentication and Async Isolation

- auth-generation tokens;
- sign-out invalidation;
- account switching;
- late provider updates;
- late navigation;
- stale AI results.

### Workstream E — Startup and Android Release

- Firebase initialization;
- Android identity;
- staging runtime configuration;
- release signing;
- debug and configured staging artifacts.

No two agents may modify the same architectural module at the same time.

A subagent may not independently declare an issue complete.

## Prohibited Shortcuts

Do not:

- add features;
- weaken Firestore Rules;
- allow arbitrary maps;
- remove failing tests;
- reduce assertions;
- suppress exceptions to keep onboarding moving;
- replace production integration paths with trivial mocks;
- mark incomplete onboarding complete;
- overwrite user-modified records silently;
- use arbitrary delays for synchronization;
- update providers after authentication ownership changes;
- expose email, UID, tokens, health data or AI payloads;
- commit credentials, signing keys or service-account files;
- use destructive Git commands;
- claim device verification without executing it.

Preserve unrelated local changes.

## Evidence Required for Every Issue

Each issue entry must contain:

- Issue ID
- Severity
- Status
- Production path
- Symptom
- Reproduction
- Root cause
- Required invariant
- Files inspected
- Files changed
- Tests added or changed
- Firestore impact
- Migration impact
- Commands executed
- Exact results
- Remaining risks
- Final verdict

Allowed evidence statuses:

- NOT_VERIFIED
- IN_PROGRESS
- PASS_SOURCE_REVIEWED
- PASS_AUTOMATED_TESTED
- PASS_EMULATOR_VERIFIED
- PASS_BUILD_VERIFIED
- ENVIRONMENT_BLOCKED
- FAIL

Do not use a vague PASS status.

## Acceptance Criteria

### Compilation and Automated Verification

- [ ] Project compiles.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] `flutter analyze` reports no issues.
- [ ] All Flutter tests pass.
- [ ] Firestore emulator tests pass.
- [ ] Emulator fixtures match real production serializers.

### Firebase Contracts

- [ ] Profile writes match Rules.
- [ ] Region-localization writes match Rules.
- [ ] App-preferences writes match Rules.
- [ ] Completion-job writes match Rules.
- [ ] Draft and bundle writes match Rules.
- [ ] Routine, History and Habit writes match Rules.
- [ ] Cross-user access is denied.
- [ ] Immutable ownership changes are denied.
- [ ] Unknown fields are denied.
- [ ] Invalid statuses, stages, schemas and timestamps are denied.

### Recovery and Completion

- [ ] Recovery cannot fabricate completed onboarding.
- [ ] Missing drafts cannot produce completed setup.
- [ ] Incomplete drafts resume instead of completing.
- [ ] Valid completed drafts can rebuild missing bundles.
- [ ] Final draft is durably written and read-back verified.
- [ ] Completion bundle is persisted and verified.
- [ ] Routine expected set is verified.
- [ ] Routine History expected set is verified.
- [ ] Mixed create/repair outcomes receive complete History coverage.
- [ ] Habit expected set is verified.
- [ ] Controllers reload after reconciliation.
- [ ] Frontend-visible IDs are verified.
- [ ] Profile finalization occurs last and exactly once.
- [ ] Completion accounting fields contain real production data.
- [ ] Structured failures are used in blocking production paths.

### Account Isolation

- [ ] Sign-out invalidates active completion operations.
- [ ] Empty authenticated UID invalidates rather than permits late work.
- [ ] Account B receives no Account A local state.
- [ ] Late operations cannot navigate after sign-out.
- [ ] Stale AI results are ignored after source or account changes.

### Startup and Build

- [ ] Firebase initialization fails safely in Firebase mode.
- [ ] Debug APK exists.
- [ ] Configured staging release APK or AAB exists.
- [ ] Artifact path and file size are recorded.
- [ ] Runtime environment, backend mode and upload mode are recorded.
- [ ] Release signing strategy is documented.
- [ ] Fake backend and fake upload mode are not unintentionally used.

### Final Deliverables

- [ ] `docs/phase_4_6_2_initial_audit.md` is current.
- [ ] `docs/phase_4_6_2_execution_report.md` is current.
- [ ] `docs/phase_4_6_2_pre_device_readiness.md` is current.
- [ ] Older reports are labelled historical.
- [ ] All current reports agree.
- [ ] No known P0 issue remains.
- [ ] No known P1 issue remains.
- [ ] P2/P3 debt is documented and does not invalidate controlled device testing.

## Environment Blockers

Clearly distinguish:

### CODE BLOCKER

A source, architecture, contract, security, persistence or test issue that must
be fixed in the repository.

### ENVIRONMENT BLOCKER

Missing SDK, credentials, signing material, Firebase access, emulator support,
network access or physical-device availability.

Do not modify production logic to hide an environment blocker.

Record the exact blocked command, missing dependency and smallest next action.

A required build may only be marked environment-blocked when the team provides
specific evidence.

## Required Reports

Maintain one authoritative status across:

- `docs/phase_4_6_2_initial_audit.md`
- `docs/phase_4_6_2_execution_report.md`
- `docs/phase_4_6_2_pre_device_readiness.md`

The pre-device report must include:

- executive verdict;
- P0 issues discovered and resolved;
- P1 issues discovered and resolved;
- unresolved blockers;
- production files changed;
- tests changed;
- Firestore contracts changed;
- migration strategy;
- recovery result;
- projection-integrity result;
- account-isolation result;
- analyzer result;
- Flutter test result;
- emulator result;
- debug build result;
- configured release build result;
- artifact path and size;
- remaining P2/P3 debt;
- pre-device readiness score out of 100.

## Stop Condition

Declare:

READY FOR CONTROLLED REAL-DEVICE TESTING

only when every acceptance criterion is supported by evidence and no known P0
or P1 blocker remains.

Do not declare:

- formal real-device testing passed;
- production ready;
- public release ready;
- Phase 4 fully complete;
- Phase 5 ready.

When blocked, return:

BLOCKED — NOT READY FOR REAL-DEVICE TESTING

and list:

- every unresolved blocker;
- its severity;
- its production impact;
- the smallest safe next action.

Stop after the pre-device gate is genuinely satisfied.

Do not continue indefinitely with optional P2/P3 refactors.



