# Execution Plan — Phase 4.6.2 Final Corrective Closure (Gen 3 Orchestrator)

## Strategy
As Gen 3 Lead Orchestrator, resume execution from Milestone 2 Workstream D and E:
1. **Workstream D (Authentication & Async Isolation)**:
   - Check `.agents/worker_workstream_d_2` status. Spawn or complete `worker_workstream_d_2` / `worker_phase462_pkgD_auth` to implement `resetForSignedOut()` in `OnboardingCompletionJobService`, call in `_resetSignedOutState`, enforce account switching isolation & auth-generation tokens, replace `catch (_) {}` error suppression with structured logging/handling, and run `flutter analyze` + targeted tests (`group_h_issues_33_to_42_test.dart`, `group_k_issues_63_to_68_test.dart`).
2. **Workstream E (Startup & Android Release)**:
   - Spawn worker `worker_phase462_pkgE_release` in `.agents/worker_phase462_pkgE_release`.
   - Verify Firebase initialization, Android application ID / manifest, staging runtime configuration, debug signing & release signing setup.
   - Run `flutter build apk --debug` and `flutter build apk --release` (or staging build). Record artifact paths, file sizes, build outputs.
3. **Milestone 3 (Review, Challenge & Forensic Audit)**:
   - Dispatch Reviewer (`reviewer_p46_m3_1`), Challenger (`challenger_p46_m3_1`), and Forensic Auditor (`auditor_p46_m3_1`).
   - Audit is a BINARY VETO — verify zero integrity violations.
4. **Milestone 4 (Final Deliverables & Gate Verification)**:
   - Run complete baseline verification: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, Firestore emulator tests.
   - Create/update deliverables: `docs/phase_4_6_2_execution_report.md` and `docs/phase_4_6_2_pre_device_readiness.md`. Mark older reports as `HISTORICAL — NOT AUTHORITATIVE`.
   - Report final verdict `READY FOR CONTROLLED REAL-DEVICE TESTING` to parent sentinel.

## Workstream Breakdown
| Phase / Workstream | Target Directory | Primary Objectives | Status |
|-------------------|------------------|--------------------|--------|
| Milestone 1 | docs/ | Initial Audit Report | COMPLETE |
| Workstream A | lib/, test/ | Compilation & Recovery Invariants | COMPLETE |
| Workstream B | lib/, test/ | Firestore Rules & Serializer Alignment | COMPLETE |
| Workstream C | lib/, test/ | Completion Stages, History Accounting & Failure Payload | COMPLETE |
| Workstream D | lib/state/, lib/services/ | Auth Isolation, Generation Tokens & Error Suppression | IN_PROGRESS |
| Workstream E | lib/, android/ | Firebase Startup & Android Release Builds | PENDING |
| Milestone 3 | codebase | Reviewers, Challengers & Forensic Auditor | PENDING |
| Milestone 4 | docs/ | Execution Report, Pre-Device Readiness Report & Gate | PENDING |
