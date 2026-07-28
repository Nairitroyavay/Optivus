## 2026-07-28T09:34:45Z
You are worker_phase46_pkgC assigned to Work Package C Remediation for Phase 4.6 Final Production Closure.
Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgC

Task Description:
Remediate the following 9 production issues in genuine code logic following the Evidence-Based Fix Protocol (R5) and Production Safety Rules (R3/R4):

1. ISSUE-06-01 / PATH3-06-01 (P0): Firestore Transaction Operations Limit Breach (N > 240 Items)
   Files: lib/repositories/onboarding_repository.dart (lines 291-470)
   Fix: Update `plan.items.length` guard in `completeOnboarding` from `> 450` to `> 240` (since 2(240)+8 = 488 <= 500).

2. ISSUE-07-01 / PATH3-07-01 (P0): Routine History Timeline Gap & Receipt Cursor Mismatch in Event Projector
   Files: lib/services/routine_onboarding_event_projector.dart (lines 144-190), lib/repositories/onboarding_repository.dart (lines 443-454, 501-540)
   Fix: Decouple event batch iteration from `createdEventsOffset` ambiguity. Compute set of event IDs already persisted or check `receipt.cursor` directly against `receipt.totalCount`. If `receipt.cursor == receipt.totalCount` and `receipt.status == 'pending'`, perform receipt update transaction to transition `receipt.status` to `'completed'`.

3. ISSUE-07-02 / PATH3-07-02 (P1): Non-Idempotent Routine Document ID Generation for Duplicate Source Items
   Files: lib/services/routine_onboarding_projection.dart (lines 43-60)
   Fix: Replace index-based duplicate key suffix (`duplicate:$index`) with a deterministic hash of position-independent attributes or stable occurrence counter per semantic key signature (`duplicate:occurrenceCount`).

4. ISSUE-09-01 / PATH3-09-01 (P1): Disconnected/Empty linkedRoutineIds in Habit System Projections
   Files: lib/features/routine/controllers/habit_systems_controller.dart (lines 105-185), lib/services/habit_system_onboarding_projection.dart (lines 10-116), lib/repositories/firebase_habit_systems_repository.dart (lines 371-434)
   Fix: In `HabitSystemsNotifier.loadForOwnerWithFallback`, ensure `routineNotifierProvider` has finished loading before projecting fallback systems, or fetch routine items directly from RoutineRepository if `tryReadRoutineItems()` returns empty. In `reconcileProjectedSystems`, update `linkedRoutineIds` if existing record has empty links while new projection contains valid routine links.

5. ISSUE-10-01 / PATH3-10-01 (P1): Concurrent loadForOwner Calls in Notifiers Cause Dropped Updates
   Files: lib/features/routine/routine_state.dart (lines 476-576), lib/features/routine/controllers/habit_systems_controller.dart (lines 105-186), lib/state/auth_state.dart (lines 940-951)
   Fix: Guard `loadForOwner` against redundant in-flight re-loads for the same UID (`if (_inFlightLoad != null) await _inFlightLoad;`). Remove duplicate `loadForOwner` calls during onboarding completion handoff.

6. ISSUE-11-01 / PATH3-11-01 (P0): Premature In-Memory Profile Finalization inside Frontend Hydration Service
   Files: lib/services/onboarding_frontend_hydration_service.dart (lines 93-98, 116-202), lib/services/onboarding_completion_job_service.dart (lines 160-238)
   Fix: Move `read(mockUserProfileProvider.notifier).completeOnboarding()` out of `OnboardingFrontendHydrationService.hydrate` stage. Call it ONLY inside `OnboardingCompletionJobService` Stage 5 AFTER `profileRepository.saveUserProfile(profile)` and `_saveJobStatus(job)` successfully complete.

7. ISSUE-11-02 / PATH3-11-02 (P2): Non-Atomic Profile Finalization in Firestore
   Files: lib/services/onboarding_completion_job_service.dart (lines 229-238), lib/repositories/profile_repository.dart
   Fix: Execute profile finalization update and completion job status update atomically in Firestore using batch write or transaction, or verify job completion status in AuthNotifier before treating `onboardingCompleted: true` as final.

8. ISSUE-03-01 (P2): Transient Empty User Profile State Window during Account Switch
   Files: lib/state/auth_state.dart (lines 538-575), lib/state/app_state.dart
   Fix: Ensure AuthNotifier sets `status = AuthFlowStatus.loadingBackendUser` BEFORE calling `resetEmpty()` on user profile providers.

9. ISSUE-14-02 (P1): Cold Restart with Missing Draft Triggers Inconsistent Onboarding State
   Files: lib/state/auth_state.dart (lines 656-665)
   Fix: Handle missing draft gracefully by synthesizing a draft from existing profile attributes or prompting user to resume at last completed step.
