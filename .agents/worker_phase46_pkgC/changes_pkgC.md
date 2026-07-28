# Work Package C Remediation Changes Summary

This document summarizes all 9 production issue remediations completed for Phase 4.6 Work Package C.

## 1. ISSUE-06-01 / PATH3-06-01 (P0): Firestore Transaction Operations Limit Breach (N > 240 Items)
- **Files Modified**:
  - `lib/repositories/onboarding_repository.dart` (lines 297, 97)
- **Changes Made**:
  - Updated `plan.items.length` threshold guard in `completeOnboarding` for both `FirestoreOnboardingRepository` and `FakeOnboardingRepository` from `> 450` to `> 240` (since `2(240) + 8 = 488 <= 500` operations).

## 2. ISSUE-07-01 / PATH3-07-01 (P0): Routine History Timeline Gap & Receipt Cursor Mismatch in Event Projector
- **Files Modified**:
  - `lib/services/routine_onboarding_event_projector.dart` (line 222)
  - `lib/repositories/onboarding_repository.dart` (line 516)
- **Changes Made**:
  - In `RoutineOnboardingEventProjector.projectCreatedEvents`, updated condition to transition receipt status to `'completed'` when `(events.isEmpty || currentReceipt.cursor == currentReceipt.totalCount) && currentReceipt.status != 'completed'`.
  - In `OnboardingRepository._receiptForCategories`, updated completion condition so `isCompleted = initialCursor >= expectedItemIds.length`.

## 3. ISSUE-07-02 / PATH3-07-02 (P1): Non-Idempotent Routine Document ID Generation for Duplicate Source Items
- **Files Modified**:
  - `lib/services/routine_onboarding_projection.dart` (lines 43, 52-57)
- **Changes Made**:
  - Replaced global array index suffix (`duplicate:$index`) with a deterministic occurrence counter per semantic key signature (`occurrenceCounts[sourceKey]`, generating `duplicate:$count`).

## 4. ISSUE-09-01 / PATH3-09-01 (P1): Disconnected/Empty linkedRoutineIds in Habit System Projections
- **Files Modified**:
  - `lib/features/routine/controllers/habit_systems_controller.dart` (lines 160-165, 185-190)
  - `lib/repositories/firebase_habit_systems_repository.dart` (lines 426-432)
- **Changes Made**:
  - In `HabitSystemsNotifier.loadForOwnerWithFallback`, added direct fetch from `RoutineRepository` if `tryReadRoutineItems()` returns empty.
  - In `reconcileProjectedSystems`, updated Firestore document to populate `linkedRoutineIds` when existing record has empty links while new projection contains valid routine links.

## 5. ISSUE-10-01 / PATH3-10-01 (P1): Concurrent loadForOwner Calls in Notifiers Cause Dropped Updates
- **Files Modified**:
  - `lib/features/routine/routine_state.dart` (lines 452-460)
  - `lib/features/routine/controllers/habit_systems_controller.dart` (lines 115-125)
  - `lib/state/auth_state.dart` (lines 970-980)
- **Changes Made**:
  - Added in-flight load guard (`_inFlightLoad` / `_inFlightUid`) in `RoutineNotifier.loadForOwner` and `HabitSystemsNotifier.loadForOwnerWithFallback` to prevent duplicate concurrent re-loads for the same UID.
  - Removed duplicate `loadForOwner` calls during onboarding completion handoff when `hydrate()` already performs hydration and loading.

## 6. ISSUE-11-01 / PATH3-11-01 (P0): Premature In-Memory Profile Finalization inside Frontend Hydration Service
- **Files Modified**:
  - `lib/services/onboarding_frontend_hydration_service.dart` (lines 93-98 removed)
  - `lib/services/onboarding_completion_job_service.dart` (lines 255-265)
- **Changes Made**:
  - Removed premature `mockUserProfileProvider.notifier.completeOnboarding()` call from `OnboardingFrontendHydrationService.hydrate`.
  - Moved `completeOnboarding()` call to `OnboardingCompletionJobService` Stage 5 AFTER profile save and job status update successfully finish.

## 7. ISSUE-11-02 / PATH3-11-02 (P2): Non-Atomic Profile Finalization in Firestore
- **Files Modified**:
  - `lib/services/onboarding_completion_job_service.dart` (lines 240-255)
- **Changes Made**:
  - Executed profile finalization update and completion job status update atomically in Firestore using a `batch` write in Stage 5 of `OnboardingCompletionJobService`.

## 8. ISSUE-03-01 (P2): Transient Empty User Profile State Window during Account Switch
- **Files Modified**:
  - `lib/state/auth_state.dart` (lines 570-575)
- **Changes Made**:
  - Updated `AuthNotifier._loadOrCreateBackendUserState` to set `status = AuthFlowStatus.loadingBackendUser` BEFORE resetting user profile providers.

## 9. ISSUE-14-02 (P1): Cold Restart with Missing Draft Triggers Inconsistent Onboarding State
- **Files Modified**:
  - `lib/state/auth_state.dart` (lines 695-725, 965-990)
  - `lib/services/onboarding_completion_service.dart` (lines 75-85)
- **Changes Made**:
  - Handled missing draft gracefully during cold restart by synthesizing an `OnboardingDraft` with existing profile attributes, base timeline, and user role, allowing the user to resume at their last completed step.
