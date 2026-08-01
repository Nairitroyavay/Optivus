# Optivus Phase 4.6.2 Final Corrective Closure — Master Plan

## Overview
Phase 4.6.2 stabilizes the Optivus production code, resolves all P0/P1 blockers, verifies Firestore rules and serializers, guarantees account isolation, and produces pre-device readiness reports.

## Milestones

### Milestone 1: Mandatory Initial Audit & Baseline Verification
- [ ] Confirm repository path and record Git status (`git branch`, `git rev-parse HEAD`, `git status --short`, `git diff --stat`).
- [ ] Read all existing Phase 4.x reports in `docs/` and mark outdated ones as `HISTORICAL — NOT AUTHORITATIVE`.
- [ ] Trace real production execution path (Startup -> Firebase Init -> Signup -> Profile -> Onboarding -> Draft -> Bundle -> Routine -> History -> Habit -> Controller -> Router -> Home -> Restart -> Signout -> Signin -> Account Switch -> Recovery).
- [ ] Compare production Firestore serializers against Firestore Rules and emulator fixtures.
- [ ] Search for unresolved symbols, stale recovery actions, unsafe completion assignments, silent catches, raw exception persistence, debug release signing, unused completion-accounting fields.
- [ ] Run baseline: `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, Firestore emulator tests, `flutter build apk --debug`.
- [ ] Populate `docs/phase_4_6_2_initial_audit.md`.

### Milestone 2: Workstream Execution (P0 & P1 Issue Resolution)
- [ ] **Workstream A: Compilation and Recovery**
  - Unresolved symbols, stale recovery actions, unsafe forced completion, recovery-command architecture.
- [ ] **Workstream B: Firestore Contracts**
  - Profile, region localization, app preferences, onboarding draft, completion bundle, completion job, Routine, History, Habit, Rules & real-schema emulator fixtures.
- [ ] **Workstream C: Completion and Projection Integrity**
  - Fine-grained completion stages, durable draft, bundle verification, Routine reconciliation, complete History coverage, Habit verification, controller & frontend verification, profile finalization.
- [ ] **Workstream D: Authentication and Async Isolation**
  - Auth-generation tokens, sign-out invalidation, account switching, late provider updates, late navigation, stale AI results.
- [ ] **Workstream E: Startup and Android Release**
  - Firebase initialization, Android identity, staging runtime configuration, release signing, debug & configured staging artifacts.

### Milestone 3: Adversarial Review, Stress Testing & Forensic Audit
- [ ] Reviewers verify code quality, correctness, security contracts, and non-regression.
- [ ] Challengers stress test edge cases, race conditions, sign-out hazards, state corruption.
- [ ] Forensic Auditor performs binary-veto integrity audit on all changes.

### Milestone 4: Final Deliverables & Pre-Device Readiness Gate
- [ ] Populate `docs/phase_4_6_2_execution_report.md`.
- [ ] Populate `docs/phase_4_6_2_pre_device_readiness.md`.
- [ ] Verify all acceptance criteria.
- [ ] Report final claim `READY FOR CONTROLLED REAL-DEVICE TESTING` to parent sentinel.
