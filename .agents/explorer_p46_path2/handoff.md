# Handoff Report — explorer_p46_path2

## 1. Observation

### Code Paths Inspected
1. **Step 7 (Routine Projection)**:
   - `lib/services/routine_onboarding_projection.dart`: Lines 43–60
   - `lib/services/routine_onboarding_event_projector.dart`: Lines 144–190
   - `lib/services/routine_projection_receipt_validator.dart`: Lines 22–148
   - `lib/repositories/onboarding_repository.dart`: Lines 91–193, 291–470
2. **Step 8 (Routine History Projection)**:
   - `lib/repositories/routine_transaction_repository.dart`: Lines 106–266, 350–565
   - `lib/repositories/routine_history_repository.dart`: Lines 12–170, 282–303
3. **Step 9 (Habit Projection)**:
   - `lib/services/habit_system_onboarding_projection.dart`: Lines 10–131
   - `lib/repositories/firebase_habit_systems_repository.dart`: Lines 371–504
   - `lib/services/onboarding_frontend_hydration_service.dart`: Lines 65–202
4. **Step 10 (Controller Reload)**:
   - `lib/features/routine/controllers/habit_systems_controller.dart`: Lines 105–186
   - `lib/features/routine/routine_state.dart`: Lines 476–576, 614–631
   - `lib/state/auth_state.dart`: Lines 560–650, 940–985
   - `lib/features/onboarding/onboarding_flow.dart`: Lines 346–390
5. **Step 11 (Profile Finalization)**:
   - `lib/services/onboarding_completion_job_service.dart`: Lines 182–238
   - `lib/models/user_profile.dart`: Lines 18–20, 163–197

### Specific Verbatim Code Quotations & Defect Direct Evidence
- **Observation 1.1**: In `lib/services/routine_onboarding_event_projector.dart`, lines 175–181:
  `final createdEventsOffset = receipt.createdItemIds.isNotEmpty ? receipt.existingItemIds.length : 0;`
  `for (var index = (currentReceipt.cursor - createdEventsOffset).clamp(0, events.length); ...)`
  When `createdItemIds` is empty, `createdEventsOffset` is 0. If `currentReceipt.cursor` was set to `existingItemIds.length` by `completeOnboarding`, `index` starts at `existingItemIds.length`, skipping event generation for items 0 through `existingItemIds.length - 1`, resulting in a history timeline gap and leaving `receipt.status` stuck in `'pending'`.
- **Observation 1.2**: In `lib/services/onboarding_frontend_hydration_service.dart`, lines 96–98:
  ```dart
  if (receipt != null && receipt.status == 'completed') {
    read(mockUserProfileProvider.notifier).completeOnboarding();
  }
  ```
  This mutates the in-memory user profile state to `onboardingCompleted: true` during Stage 4 before habit system reconciliation, verification, and persistent profile finalization in Stage 5.
- **Observation 1.3**: In `lib/features/routine/controllers/habit_systems_controller.dart`, lines 146–147 & 188–194:
  `final routines = projectedRoutines ?? tryReadRoutineItems();`
  If `routineNotifierProvider` is currently loading from Firestore when `HabitSystemsNotifier` executes `loadForOwnerWithFallback`, `tryReadRoutineItems()` returns `[]`, causing projected habit systems to be written to Firestore with `linkedRoutineIds: []`.
- **Observation 1.4**: In `lib/features/routine/routine_state.dart`, line 477 & lines 547–550:
  `final generation = ++_loadGeneration;`
  Concurrent calls to `loadForOwner` during onboarding completion handoff discard the async fetch response of the earlier generation, leaving the UI with stale state or unhandled listeners.
- **Observation 1.5**: In `lib/services/routine_onboarding_projection.dart`, lines 52–57:
  `sourceItemId: '$sourceKey|${_semanticSourceKey(source)}|duplicate:$index'`
  Fallback document ID incorporates `duplicate:$index`, which shifts document IDs when duplicate items are reordered across retries.
- **Observation 1.6**: In `lib/services/onboarding_completion_job_service.dart`, lines 234–237:
  `profileRepository.saveUserProfile(profile)` occurs outside a transaction in Stage 5, allowing `profile.onboardingCompleted` to be saved to Firestore while `_saveJobStatus(job)` fails.

---

## 2. Logic Chain

1. **Premature Finalization (Finding 02)**: Line 97 of `onboarding_frontend_hydration_service.dart` calls `mockUserProfileProvider.notifier.completeOnboarding()` inside `hydrate()` (Stage 4). Because this happens before lines 121 (`reconcileProjectedSystems`) and Stage 5 (`UPDATE_PROFILE`), any failure in habit projection leaves the in-memory user profile falsely marked complete.
2. **Timeline Gap & Receipt Stalling (Finding 01)**: Line 175 of `routine_onboarding_event_projector.dart` sets `createdEventsOffset = 0` when `createdItemIds` is empty. Line 181 calculates `index = (currentReceipt.cursor - 0)` = `existingItemIds.length`. This skips event generation for initial items, creating a timeline gap in routine event history, and causes the loop to exit without advancing `receipt.status` to `'completed'`, which halts Stage 5 of the completion job.
3. **Unlinked Habit Systems (Finding 03)**: Lines 146–147 of `habit_systems_controller.dart` use `tryReadRoutineItems()` during `loadForOwnerWithFallback`. If routine state is loading, `tryReadRoutineItems()` returns `[]`. `HabitSystemOnboardingProjection.build` creates habit systems with empty `linkedRoutineIds`. `FirestoreHabitSystemsRepository.reconcileProjectedSystems` writes these empty links to Firestore and skips updating them on future runs (`if (exists)` check), permanently breaking habit-routine links.
4. **State Loss on Reload (Finding 04)**: Lines 346–390 of `onboarding_flow.dart` run `runCompletionJob` (which calls `loadForOwner` in Stage 4), then immediately call `acceptCanonicalOnboardingCompletion` (which calls `loadForOwner` again). In `routine_state.dart` (lines 477 & 547), `_loadGeneration` is incremented, causing the first load's async result to be dropped and event listeners cancelled.
5. **Fingerprint Mismatch on Reorder (Finding 05)**: Lines 52–57 of `routine_onboarding_projection.dart` append `duplicate:$index` to document IDs. If item order shifts on retry, document IDs shift, producing a fingerprint mismatch against the saved completion bundle.
6. **Non-Atomic Profile Update (Finding 06)**: Lines 234–237 of `onboarding_completion_job_service.dart` update `/users/{uid}` via `saveUserProfile` non-atomically before `_saveJobStatus`. Network failure after profile update leaves Firestore profile set to `onboardingCompleted: true` while job status remains incomplete.

---

## 3. Caveats

- **No Code Modifications Made**: This investigation was strictly read-only. No production files in `lib/` were edited.
- **Backend Environment Mode**: Audit covered both `OptivusBackendMode.firebase` and `OptivusBackendMode.fake` code branches. Firestore transactions were analyzed against Cloud Firestore transaction constraints (e.g. max 500 document limit, read-before-write requirement).

---

## 4. Conclusion

The audit identified **6 distinct findings** (2 P0, 3 P1, 1 P2) in the production execution path for Steps 7 through 11. The production pipeline currently suffers from timeline gaps during event projection, premature profile completion state mutation, race conditions during controller reloads, and unlinked habit system records. Resolving these issues using the minimal safe fixes detailed in `audit_path2.md` is required before final production closure.

---

## 5. Verification Method

To independently verify these findings:
1. Inspect the production files and line numbers quoted above using `view_file`.
2. Run project tests:
   ```bash
   flutter test
   ```
3. Run specific onboarding & routine projection unit/integration test suites:
   ```bash
   flutter test test/services/routine_onboarding_event_projector_test.dart
   flutter test test/services/onboarding_completion_job_service_test.dart
   ```
4. Check invalidation conditions:
   - Invalidation 1: If `RoutineOnboardingEventProjector` correctly advances cursor and projects events even when `createdItemIds` is empty, Finding 01 is resolved.
   - Invalidation 2: If `mockUserProfileProvider.notifier.completeOnboarding()` is called strictly after Stage 5 profile persistence succeeds, Finding 02 is resolved.
   - Invalidation 3: If `HabitSystemsNotifier` waits for routine items to load before projecting fallback systems, Finding 03 is resolved.
