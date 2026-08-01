# Plan — Optivus Phase 4.6.2 Final Corrective Closure

## Milestone Breakdown

### Milestone 1: Mandatory Initial Audit & Baseline Verification
- [x] 1. Record Git metadata (branch main, commit cf197c96e43251ed9008b9406eac83a14a3cc7f4).
- [x] 2. Audit historical reports in `docs/`, mark outdated/contradictory ones with `HISTORICAL — NOT AUTHORITATIVE`.
- [x] 3. Trace full production path (Application startup -> ... -> Sign in -> Recovery).
- [x] 4. Audit all production Firestore serializers against Firestore Rules and emulator fixtures.
- [x] 5. Deep static analysis for all known P0/P1 areas (20 analyzer errors found, missing imports, unresolved `SynthesizeBundleAction`, force-marking incomplete drafts complete, empty job accounting fields, static map leak).
- [x] 6. Run sequential baseline check (`pub get` PASS, `dart format` FAIL, `analyze` FAIL, `test` FAIL, emulator FAIL, `build apk` FAIL).
- [x] 7. Populate `docs/phase_4_6_2_initial_audit.md`.

### Milestone 2: Workstream Execution (P0 & P1 Issue Resolution)
- [ ] Workstream A: Compilation and Recovery
  - Fix imports in `lib/main.dart`, `lib/state/auth_state.dart`, and static access in `lib/services/onboarding_completion_job_service.dart`.
  - Resolve missing `SynthesizeBundleAction` and `tier3Synthesized` references or restore definitions.
  - Fix unsafe recovery behavior in `RebuildBundleFromDraftAction` so incomplete drafts are never force-marked complete.
- [ ] Workstream B: Firestore Contracts
  - Reconcile serializers and Rules for profile, region localization, app preferences, onboarding draft, completion bundle, completion job, Routine, History, Habit, and emulator fixtures.
- [ ] Workstream C: Completion and Projection Integrity
  - Verify fine-grained completion stages.
  - Fix empty job accounting fields: populate `expectedHistoryIds`, `appliedHistoryIds`, `failedHistoryIds` in `OnboardingCompletionJob`.
  - Replace raw `e.toString()` in jobs with structured failure objects.
  - Ensure profile finalization occurs last and exactly once.
- [ ] Workstream D: Authentication and Async Isolation
  - Fix static `_inFlight` map in `OnboardingCompletionJobService` leaking across sessions (add `resetForSignedOut()`).
  - Account switch isolation and sign-out invalidation of active operations.
  - Remove unsafe `catch (_) {}` exception suppression in auth state.
- [ ] Workstream E: Startup and Android Release
  - Secure Firebase startup error handling in `lib/main.dart`.
  - Run `dart format --set-exit-if-changed .` and ensure 0 changes needed.
  - Run `flutter analyze` (0 issues).
  - Run `flutter test` (100% pass).
  - Run Firestore emulator tests (`npm test`).
  - Run `flutter build apk --debug` and verify output artifact path and size.

### Milestone 3: Review, Challenge & Forensic Audit
- [ ] Spawn Reviewers (`teamwork_preview_reviewer`) to verify code quality, correctness, and contract adherence.
- [ ] Spawn Challengers (`teamwork_preview_challenger`) to stress test edge cases, race conditions, sign-out isolation, and Firestore rule bypasses.
- [ ] Spawn Forensic Auditor (`teamwork_preview_auditor`) to perform integrity audit (verify zero cheating, facade, or test-hardcoding).

### Milestone 4: Final Deliverables & Gate Verification
- [ ] Create/update `docs/phase_4_6_2_execution_report.md` with complete 18-step issue execution loops and evidence.
- [ ] Create/update `docs/phase_4_6_2_pre_device_readiness.md` with executive verdict, scores out of 100, and artifact paths/sizes.
- [ ] Ensure all 3 reports agree on status.
- [ ] Deliver completion claim `READY FOR CONTROLLED REAL-DEVICE TESTING` to parent sentinel.
