## 2026-07-25T20:12:38Z
You are the Worker subagent for Group C (Issues 12–15: Habit System projection & hydration) of Optivus Onboarding Stabilization.

Working directory: /Users/roy/optivus2/Optivus/.agents/worker_group_c_1
Handoff path: /Users/roy/optivus2/Optivus/.agents/worker_group_c_1/handoff.md
Explorer handoff report: /Users/roy/optivus2/Optivus/.agents/explorer_group_c_1/handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope: Implement Group C (Issues 12, 13, 14, 15)
1. Issue 12: Habit system record owner UID matching and validation
   - Validate non-empty, valid owner UID in `HabitSystemRecord` constructor/codec and `HabitSystemOnboardingProjection.build`.
   - Add explicit `existing.ownerUid == targetOwnerUid` transaction validation checks in `FirestoreHabitSystemsRepository` and `FakeHabitSystemsRepository`.
   - Enforce `updated.ownerUid == _ownerUid` matching guards in `HabitSystemsNotifier`.

2. Issue 13: Habit system batch operation transactional integrity
   - Add atomic `reconcileProjectedSystems({required String ownerUid, required String projectionId, required List<HabitSystemRecord> systems})` to `HabitSystemsRepository` interface, `FirestoreHabitSystemsRepository`, and `FakeHabitSystemsRepository`.
   - Update `FirestoreHabitSystemsRepository` to execute a single Firestore transaction/batch that sets/updates all habit system documents and updates the projection receipt document atomically with accurate `expectedSystemIds` ($N$ items), `appliedSystemIds`, `failedSystemIds`, and `status`.
   - Update `OnboardingFrontendHydrationService` to call `reconcileProjectedSystems` instead of iterating and making single-item calls.

3. Issue 14: Habit system hydration fallback when remote projection is pending
   - Implement `loadForOwnerWithFallback` in `HabitSystemsNotifier` (and `loadForOwner` integration) checking for an `OnboardingCompletionBundle`.
   - When remote habit systems fetch is empty or pending, fall back to in-memory projected habit systems built from `OnboardingCompletionBundle`, merging them by stable `systemId` without duplicates or data deletion.

4. Issue 15: Habit system schedule frequency update reconciliation
   - Implement `HabitSystemScheduleReconciler` (or helper in `HabitSystemsNotifier` / routine reconciler service).
   - Prune orphaned routine IDs in `linkedRoutineIds` when routines no longer exist.
   - Bidirectionally propagate Habit System status changes (`active`, `paused`, `archived`) to linked `RoutineItem`s.
   - Synchronize frequency `repeatDays` updates to linked `RoutineItem`s without violating R11 zero data deletion (never hard-delete routine items or historical entries).

5. Testing & Verification:
   - Create `test/group_c_issues_12_to_15_test.dart` covering all 4 issues with thorough unit and widget tests.
   - Run `dart format --output=none --set-exit-if-changed .` (or apply `dart format .` as needed).
   - Run `flutter analyze` to ensure 0 errors, 0 warnings, 0 lints.
   - Run `flutter test test/group_c_issues_12_to_15_test.dart` and `flutter test`.

6. Living Report Update:
   - Update `docs/onboarding_stabilization_report.md` for Issues 12, 13, 14, 15:
     Set Status: `PASSED`, and fill out Root Cause, Files Inspected, Files Changed, Fix Implemented, Targeted Tests, Regression Tests, Runtime Verification, Re-audit Result, and Evidence for all 4 issues.

7. Write your handoff report to `/Users/roy/optivus2/Optivus/.agents/worker_group_c_1/handoff.md` and send a message back to the orchestrator.
