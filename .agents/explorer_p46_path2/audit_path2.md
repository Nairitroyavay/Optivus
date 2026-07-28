# Phase 4.6 Audit Report — Path 2 (Steps 7–11)
**Project**: Optivus
**Agent**: explorer_p46_path2
**Date**: 2026-07-27
**Scope**: Production execution path audit for Steps 7 through 11 (Routine Projection, Routine History Projection, Habit Projection, Controller Reload, Profile Finalization).

---

## Executive Summary

A comprehensive read-only audit of the production source code implementing Steps 7 through 11 of the Optivus onboarding completion and hydration pipeline was conducted. All previous claims of "PASSED" status were treated as **NOT VERIFIED** and independently audited against actual production implementation.

6 distinct issues were identified across the 5 execution steps:
- **2 P0 Issues**: Critical timeline gaps/receipt deadlocks during event projection, and premature in-memory profile finalization before habit projections/verifications complete.
- **3 P1 Issues**: Race conditions during controller reloads causing dropped state updates, habit system `linkedRoutineIds` permanently saved as empty due to unawaited/unloaded routine controllers, and non-idempotent document ID generation for duplicate source items.
- **1 P2 Issue**: Non-atomic profile finalization in Firestore vulnerable to mid-operation network failures.

---

## Audit Findings Matrix

| ID | Title | Severity | Step | Production Files |
|---|---|---|---|---|
| **FINDING-01** | Routine History Timeline Gap & Receipt Cursor Mismatch in Event Projector when Existing/Repaired Items Exist | **P0** | Step 7 & Step 8 | `lib/services/routine_onboarding_event_projector.dart`, `lib/repositories/onboarding_repository.dart` |
| **FINDING-02** | Premature In-Memory Profile Finalization (`onboardingCompleted: true`) inside Frontend Hydration Service before Projections & Verification Complete | **P0** | Step 11 & Step 9 | `lib/services/onboarding_frontend_hydration_service.dart`, `lib/services/onboarding_completion_job_service.dart` |
| **FINDING-03** | Disconnected/Empty `linkedRoutineIds` in Habit System Projections caused by Async Controller Race Condition | **P1** | Step 9 & Step 10 | `lib/features/routine/controllers/habit_systems_controller.dart`, `lib/services/habit_system_onboarding_projection.dart`, `lib/repositories/firebase_habit_systems_repository.dart` |
| **FINDING-04** | Concurrent `loadForOwner` Calls in `RoutineNotifier` & `HabitSystemsNotifier` Cause Dropped State Updates and Stale UI State | **P1** | Step 10 | `lib/features/routine/routine_state.dart`, `lib/features/routine/controllers/habit_systems_controller.dart`, `lib/state/auth_state.dart`, `lib/features/onboarding/onboarding_flow.dart` |
| **FINDING-05** | Non-Idempotent Routine Document ID Generation for Duplicate Source Items in `RoutineOnboardingProjection` | **P1** | Step 7 | `lib/services/routine_onboarding_projection.dart` |
| **FINDING-06** | Non-Atomic Profile Finalization in Firestore (`saveUserProfile`) Vulnerable to Mid-Operation Failures | **P2** | Step 11 | `lib/services/onboarding_completion_job_service.dart`, `lib/repositories/profile_repository.dart` |

---

## Detailed Audit Findings

### FINDING-01: Routine History Timeline Gap & Receipt Cursor Mismatch in Event Projector when Existing/Repaired Items Exist
- **Severity**: P0
- **Execution Step**: Step 7 (Routine Projection) & Step 8 (Routine History Projection)
- **Production Files**:
  - `lib/services/routine_onboarding_event_projector.dart`: Lines 144–190
  - `lib/repositories/onboarding_repository.dart`: Lines 443–454, 501–540
- **Root Cause Analysis**:
  In `FirestoreOnboardingRepository.completeOnboarding`, when projection items already exist or are repaired, `completeOnboarding` computes `initialCursor = existingItemIds.length` and saves the projection receipt to Firestore with `cursor = initialCursor` and `status = 'pending'`.
  When `RoutineOnboardingEventProjector.projectCreatedEvents` runs subsequently during hydration/job execution, it reads `receipt` from Firestore and calculates `createdEventsOffset = receipt.createdItemIds.isNotEmpty ? receipt.existingItemIds.length : 0`.
  If `receipt.createdItemIds` is empty (e.g. all items existed or were repaired during retry), `createdEventsOffset` evaluates to `0`.
  The event projection loop calculates starting index `index = (currentReceipt.cursor - createdEventsOffset).clamp(0, events.length)` -> `(initialCursor - 0)` = `existingItemIds.length`.
  This skips creating/committing events for indices `0` to `existingItemIds.length - 1`.
  Because `events` are skipped, `RoutineEventRecord`s for existing/repaired items are NEVER written to the event stream or routine history timeline!
  Furthermore, if `receipt.createdItemIds` is empty, `index` starts equal to `events.length`, so the loop terminates immediately without advancing `currentReceipt.status` to `'completed'`.
  This leaves the receipt stuck in `'pending'` in Firestore, causing `OnboardingCompletionJobService` Stage 5 to throw:
  `StateError('Cannot transition profile to onboardingCompleted: true before projection receipt is complete...')`.
- **Repro Steps**:
  1. Trigger onboarding completion for a user who already has projected routine items in Firestore (or during a retry where items were created on attempt 1).
  2. `completeOnboarding` executes: `createdItemIds` = `[]`, `existingItemIds` = `[item1, item2]`, `cursor` = 2, `status` = `'pending'`.
  3. `projectCreatedEvents` executes: `events` has 2 elements, `createdEventsOffset` = 0.
  4. Loop starts at `index = 2`. `2 < 2` is false. Loop exits immediately. Receipt remains in status `'pending'` with 0 events written.
  5. Stage 5 of `OnboardingCompletionJobService` fails due to receipt status mismatch.
- **Recommended Minimal Safe Fix**:
  In `RoutineOnboardingEventProjector.projectCreatedEvents`, decouple event batch iteration from `createdEventsOffset` ambiguity. Compute the set of event IDs that have already been persisted or check `receipt.cursor` directly against `receipt.totalCount`. If `receipt.cursor == receipt.totalCount` and `receipt.status == 'pending'`, perform a single receipt update transaction to transition `receipt.status` to `'completed'`.

---

### FINDING-02: Premature In-Memory Profile Finalization (`onboardingCompleted: true`) inside Frontend Hydration Service before Projections & Verification Complete
- **Severity**: P0
- **Execution Step**: Step 11 (Profile Finalization) & Step 9 (Habit Projection)
- **Production Files**:
  - `lib/services/onboarding_frontend_hydration_service.dart`: Lines 93–98, 116–147, 149–202
  - `lib/services/onboarding_completion_job_service.dart`: Lines 160–181, 183–238
- **Root Cause Analysis**:
  In `OnboardingFrontendHydrationService.hydrate` (invoked during Stage 4 `projectHabits` of `OnboardingCompletionJobService`), line 97 performs:
  `read(mockUserProfileProvider.notifier).completeOnboarding();`
  as soon as `receipt.status == 'completed'`.
  This mutates the global in-memory user profile state to `onboardingCompleted = true` BEFORE:
  1. Habit system projections are reconciled in Firestore (`repo.reconcileProjectedSystems`).
  2. Habit system persistence verification passes (`_verifyProjectedHabitSystemsPersisted`).
  3. Habit system controller visibility verification passes (`_verifyProjectedHabitSystemsVisible`).
  4. Stage 5 (UPDATE_PROFILE) verifies projection receipt integrity and updates the persistent Firestore user profile.
  If any error/exception is thrown during habit system reconciliation or verification (lines 116–202), `hydrate` throws `HabitSystemProjectionFailureException`, but `mockUserProfileProvider` has ALREADY been mutated to `onboardingCompleted = true`.
  Consequently, UI components listening to `mockUserProfileProvider` or `authProvider` immediately dismiss onboarding screens and display the main app shell, even though habit projections failed and persistent profile finalization was aborted.
- **Repro Steps**:
  1. Run onboarding completion job where habit system reconciliation fails (e.g. mock network error or Firestore rule conflict during `reconcileProjectedSystems`).
  2. Stage 4 enters `hydrate`. Routine receipt is checked (`status == 'completed'`).
  3. Line 97 calls `mockUserProfileProvider.notifier.completeOnboarding()`.
  4. Line 121 fails with `HabitSystemProjectionFailureException`. Job aborts.
  5. Observe UI state: `mockUserProfileProvider.onboardingCompleted` is `true`, forcing UI into app dashboard while Firestore backend has `onboardingCompleted: false` and missing habit systems.
- **Recommended Minimal Safe Fix**:
  Move `read(mockUserProfileProvider.notifier).completeOnboarding()` out of `OnboardingFrontendHydrationService.hydrate` stage. Call it ONLY inside `OnboardingCompletionJobService` Stage 5 AFTER `profileRepository.saveUserProfile(profile)` and `_saveJobStatus(job)` successfully complete.

---

### FINDING-03: Disconnected/Empty `linkedRoutineIds` in Habit System Projections caused by Async Controller Race Condition
- **Severity**: P1
- **Execution Step**: Step 9 (Habit Projection) & Step 10 (Controller Reload)
- **Production Files**:
  - `lib/features/routine/controllers/habit_systems_controller.dart`: Lines 105–185
  - `lib/services/habit_system_onboarding_projection.dart`: Lines 10–116
  - `lib/repositories/firebase_habit_systems_repository.dart`: Lines 371–434
- **Root Cause Analysis**:
  When `HabitSystemsNotifier.loadForOwnerWithFallback` executes (e.g. during app boot or onboarding reload), it reads routine items using `tryReadRoutineItems()`:
  `final routines = projectedRoutines ?? tryReadRoutineItems();`
  `tryReadRoutineItems()` reads `_ref.read(routineNotifierProvider).items`.
  If `routineNotifierProvider` is currently loading from Firestore (or has empty items in its state), `tryReadRoutineItems()` returns an empty list `[]`.
  `HabitSystemOnboardingProjection.build(activeBundle, routines)` matches habits against `routines`. Because `routines` is empty, every generated `HabitSystemRecord` is created with `linkedRoutineIds: []`.
  When `reconcileProjectedSystems` runs or when state is saved:
  In `FirestoreHabitSystemsRepository.reconcileProjectedSystems`, if `sysSnap.exists` is true or when new systems are written, the record with `linkedRoutineIds: []` is stored.
  Furthermore, `FirestoreHabitSystemsRepository.reconcileProjectedSystems` checks `if (exists)` and SKIPS updating existing system properties. Once an empty `linkedRoutineIds` record is written, subsequent reloads NEVER repair or populate `linkedRoutineIds`.
- **Repro Steps**:
  1. Trigger `loadForOwnerWithFallback` on `HabitSystemsNotifier` while `routineNotifierProvider` is in `loading: true` state.
  2. `tryReadRoutineItems()` returns `[]`.
  3. `HabitSystemOnboardingProjection.build` outputs habit systems with `linkedRoutineIds: []`.
  4. System projections are saved to Firestore with empty routine links.
  5. Subsequent app reloads fetch these habit systems from Firestore, leaving habits permanently unlinked from their routine items.
- **Recommended Minimal Safe Fix**:
  In `HabitSystemsNotifier.loadForOwnerWithFallback`, ensure `routineNotifierProvider` has finished loading before projecting fallback systems, or fetch routine items directly from `RoutineRepository` if `tryReadRoutineItems()` returns empty. In `reconcileProjectedSystems`, update `linkedRoutineIds` if the existing record in Firestore has an empty `linkedRoutineIds` list while the new projection contains valid routine links.

---

### FINDING-04: Concurrent `loadForOwner` Calls in `RoutineNotifier` & `HabitSystemsNotifier` Cause Dropped State Updates and Stale UI State
- **Severity**: P1
- **Execution Step**: Step 10 (Controller Reload)
- **Production Files**:
  - `lib/features/routine/routine_state.dart`: Lines 476–576
  - `lib/features/routine/controllers/habit_systems_controller.dart`: Lines 105–186
  - `lib/state/auth_state.dart`: Lines 940–951
  - `lib/features/onboarding/onboarding_flow.dart`: Lines 346–390
- **Root Cause Analysis**:
  During onboarding completion finalization, `OnboardingFrontendHydrationService.hydrate` (Stage 4) invokes `routineNotifierProvider.notifier.loadForOwner(uid)` and `habitSystemsNotifierProvider.notifier.loadForOwner(uid)`.
  Immediately after the completion job returns, `_OnboardingFlowState._completeOnboarding` calls `authProvider.notifier.acceptCanonicalOnboardingCompletion(authUser)`, which calls `_restoreBackendStateForUser(user)`, which AGAIN invokes `routineNotifierProvider.notifier.loadForOwner(uid)` and `habitSystemsNotifierProvider.notifier.loadForOwner(uid)`.
  In `RoutineNotifier.loadForOwner`:
  Each call increments `_loadGeneration` (`++_loadGeneration`).
  When the first asynchronous call (from Stage 4) completes its Firestore fetch, it checks:
  `if (generation != _loadGeneration || _ownerUid != uid) return;`
  Because `_loadGeneration` was incremented by the second call, the first call's result is discarded!
  If the second call was initiated before the first call completed, or if the second call fails/encounters a race condition with event stream subscription cancellation (`_eventsSubscription?.cancel()`), the controller is left in an inconsistent or unhydrated state (`loading: false` with outdated items or unhandled stream listeners).
- **Repro Steps**:
  1. Complete onboarding flow on a physical device / slow network connection.
  2. Stage 4 calls `loadForOwner` (generation 1).
  3. `acceptCanonicalOnboardingCompletion` calls `loadForOwner` (generation 2).
  4. Generation 1 finishes fetching from Firestore and drops its result because `generation (1) != _loadGeneration (2)`.
  5. Generation 2 event subscription cancels generation 1's listener, resulting in missed events and blank routine screens upon navigation to home dashboard.
- **Recommended Minimal Safe Fix**:
  In `RoutineNotifier` and `HabitSystemsNotifier`, guard `loadForOwner` against redundant in-flight re-loads for the same `uid` if an active load operation for that `uid` is already running (`if (_inFlightLoad != null) await _inFlightLoad;`). Remove duplicate `loadForOwner` calls during onboarding completion handoff in `_completeOnboarding` / `acceptCanonicalOnboardingCompletion`.

---

### FINDING-05: Non-Idempotent Routine Document ID Generation for Duplicate Source Items in `RoutineOnboardingProjection`
- **Severity**: P1
- **Execution Step**: Step 7 (Routine Projection)
- **Production Files**:
  - `lib/services/routine_onboarding_projection.dart`: Lines 43–60
- **Root Cause Analysis**:
  In `RoutineOnboardingProjection.build`:
  ```dart
      if (!usedIds.add(id)) {
        id = stableRoutineDocumentId(
          ownerUid: bundle.uid,
          sourceItemId:
              '$sourceKey|${_semanticSourceKey(source)}|duplicate:$index',
        );
        usedIds.add(id);
      }
  ```
  When `bundle.routineItemsForApp` contains items with duplicate source keys (or empty IDs generating identical semantic keys), the fallback routine document ID incorporates `duplicate:$index`, where `$index` is the item's 0-based position in `bundle.routineItemsForApp`.
  If `bundle.routineItemsForApp` items are reordered, filtered, or regenerated across retry attempts (or between frontend draft preview and backend completion job execution), `$index` changes for duplicate items.
  This produces DIFFERENT document IDs (`onb_...`) for identical routine items across retries.
  As a result:
  1. Firestore writes on retry create NEW duplicate routine documents instead of overwriting existing ones.
  2. The source bundle fingerprint (`_fingerprint`) changes, causing `fingerprintMismatch` errors in `RoutineProjectionReceiptValidator` and failing job completion.
- **Repro Steps**:
  1. Create an onboarding draft with two identical flexible task items (or two skincare items with matching title/time).
  2. Run `RoutineOnboardingProjection.build`. The second item gets an ID derived from `duplicate:X`.
  3. Modify draft preview or reorder items in draft.
  4. Run `RoutineOnboardingProjection.build` again. The document IDs shift, producing a fingerprint mismatch against the saved completion bundle.
- **Recommended Minimal Safe Fix**:
  Replace index-based duplicate key suffix (`duplicate:$index`) with a deterministic hash of the item's position-independent attributes (or a stable occurrence counter per semantic key signature, e.g. `duplicate:occurrenceCount`).

---

### FINDING-06: Non-Atomic Profile Finalization in Firestore (`saveUserProfile`) Vulnerable to Mid-Operation Failures
- **Severity**: P2
- **Execution Step**: Step 11 (Profile Finalization)
- **Production Files**:
  - `lib/services/onboarding_completion_job_service.dart`: Lines 229–238
  - `lib/repositories/profile_repository.dart`
- **Root Cause Analysis**:
  In `OnboardingCompletionJobService` Stage 5 (UPDATE_PROFILE):
  `profileRepository.saveUserProfile(profile)` is called to persist `onboardingCompleted: true` to `/users/{uid}`.
  This write occurs outside of a Firestore transaction and separately from the job status update `_saveJobStatus(job)`.
  If network connectivity drops or the app is killed immediately after `saveUserProfile` completes but before `_saveJobStatus(job)` finishes:
  1. Firestore profile document has `onboardingCompleted: true`.
  2. `onboardingCompletionJob` document in Firestore has `status: inProgress` or `stage: updateProfile`.
  3. Upon app restart, `AuthNotifier` fetches user profile, sees `onboardingCompleted: true`, and navigates to the app shell without completing the job or verifying receipt completeness.
- **Repro Steps**:
  1. Simulate network disconnect right after `profileRepository.saveUserProfile(profile)` completes in Stage 5.
  2. `_saveJobStatus(job)` throws NetworkException.
  3. Restart app. Auth state reads profile with `onboardingCompleted: true` and skips completion job recovery.
- **Recommended Minimal Safe Fix**:
  Execute profile finalization update and completion job status update atomically in Firestore using a batch write or transaction, or verify job completion status in `AuthNotifier` before treating `onboardingCompleted: true` as final.

---

## Conclusion

The audit of production execution path Steps 7 through 11 reveals critical flaws in event projection cursor management, habit system routine linking, controller reload race conditions, and profile finalization order. Addressing these minimal safe fixes is required before Phase 4.6 production closure can be safely declared.
