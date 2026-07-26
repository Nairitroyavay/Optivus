# Handoff Report — Group C: Habit System Projection & Hydration (Issues 12–15)

**Agent**: `explorer_group_c_1`  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_group_c_1`  
**Target Scope**: Group C (Issues 12, 13, 14, 15)  
**Date**: 2026-07-25  

---

## Executive Summary

This investigation analyzed Group C (Issues 12–15: Habit System projection & hydration) in the Optivus Onboarding Stabilization initiative. All four root causes have been traced to exact files and line numbers in the codebase (`lib/repositories/firebase_habit_systems_repository.dart`, `lib/repositories/habit_systems_repository.dart`, `lib/models/habit_system_record.dart`, `lib/models/habit_system_operation.dart`, `lib/features/routine/controllers/habit_systems_controller.dart`, `lib/services/habit_system_onboarding_projection.dart`, `lib/services/onboarding_frontend_hydration_service.dart`, `lib/state/auth_state.dart`, `test/helpers/fake_habit_systems_repository.dart`, `firestore.rules`). 

Concrete architectural fixes conforming strictly to requirements R1–R11 (zero data deletion, backward compatibility, typed failures, non-colliding stable IDs, multi-account isolation) have been formulated alongside targeted test plans.

---

## 1. Observation

### Key Codebase Files Inspected
1. `lib/repositories/habit_systems_repository.dart`
2. `lib/repositories/firebase_habit_systems_repository.dart`
3. `lib/models/habit_system_record.dart`
4. `lib/models/habit_system_operation.dart`
5. `lib/features/routine/controllers/habit_systems_controller.dart`
6. `lib/services/habit_system_onboarding_projection.dart`
7. `lib/services/onboarding_frontend_hydration_service.dart`
8. `lib/state/auth_state.dart`
9. `lib/features/routine/screens/routine_habit_systems_screen.dart`
10. `test/helpers/fake_habit_systems_repository.dart`
11. `test/habit_systems_test.dart`
12. `test/routine_habit_systems_screen_test.dart`
13. `firestore.rules`

---

### Verbatim Code Observations by Issue

#### Issue 12: Habit system record owner UID matching and validation
- **`lib/repositories/firebase_habit_systems_repository.dart` (lines 16–20)**:
  ```dart
  void _validateOwnerUid(String uid) {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError('Valid owner UID is required.');
    }
  }
  ```
- **`lib/repositories/firebase_habit_systems_repository.dart` (lines 136–150)**:
  ```dart
  final updatedSystem = await _firestore.runTransaction<HabitSystemRecord>((tx) async {
    final snapshot = await tx.get(docRef);
    if (!snapshot.exists) {
      throw const HabitSystemWriteConflict('System not found');
    }
    final existing = HabitSystemRecord.fromMap(
      snapshot.data()!,
      documentId: snapshot.id,
    );
    if (existing.version != expectedVersion) {
      throw const HabitSystemWriteConflict('Stale version');
    }
    ...
  ```
- **`lib/models/habit_system_record.dart` (lines 115–116)**:
  ```dart
  final rawOwnerUid = (map['ownerUid'] as String?) ?? '';
  ```
- **`lib/features/routine/controllers/habit_systems_controller.dart` (lines 264–277)**:
  ```dart
  Future<bool> updateSystem(HabitSystemRecord updated) async {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) return false;

    final existingIndex = state.systems.indexWhere(
      (s) => s.systemId == updated.systemId,
    );
    if (existingIndex < 0) return false;
  ```
- **Observation**:
  1. `FirestoreHabitSystemsRepository` validates `system.ownerUid` on parameter input, but inside Firestore transactions (`updateSystem`, `archiveSystem`, `restoreSystem`, `reconcileProjectedSystem`), it fetches the existing snapshot and NEVER validates that `existing.ownerUid == targetOwnerUid`. If a Firestore document is corrupted or has a mismatched owner UID, the write proceeds without checking document ownership equality.
  2. `HabitSystemRecord.fromMap` defaults `ownerUid` to `''` if missing in Firestore, without throwing or enforcing non-empty owner UID constraints.
  3. `HabitSystemsNotifier.updateSystem(HabitSystemRecord updated)` checks if notifier `_ownerUid` is set, but does NOT verify `updated.ownerUid == _ownerUid`. If `updated` contains a mismatched `ownerUid` (e.g. cross-user object leak), `updateSystem` processes it without rejecting the mismatched owner UID.
  4. `HabitSystemOnboardingProjection.build(bundle, projectedRoutines)` does NOT validate `bundle.uid`. If `bundle.uid` is blank or invalid, records are created with invalid owner UIDs.

---

#### Issue 13: Habit system batch operation transactional integrity
- **`lib/services/onboarding_frontend_hydration_service.dart` (lines 79–86)**:
  ```dart
  final habitSystemProjections = HabitSystemOnboardingProjection.build(
    bundle,
    routineItems,
  );
  final repo = read(habitSystemsRepositoryProvider);
  for (final system in habitSystemProjections) {
    await repo.reconcileProjectedSystem(system);
  }
  ```
- **`lib/repositories/firebase_habit_systems_repository.dart` (lines 288–331)**:
  ```dart
  await _firestore.runTransaction((tx) async {
    final sysSnap = await tx.get(docRef);
    ...
    final projSnap = await tx.get(projectionRef);
    if (!projSnap.exists) {
      final receipt = {
        'projectionId': system.onboardingProjectionId,
        'ownerUid': system.ownerUid,
        'sourceVersion': '1',
        'expectedSystemIds': [system.systemId],
        'appliedSystemIds': [system.systemId],
        'failedSystemIds': const <String>[],
        'status': 'completed',
        ...
      };
      tx.set(projectionRef, receipt);
    } else {
      ...
    }
  });
  ```
- **`firestore.rules` (lines 809–831, 949–959)**:
  ```rules
  function validHabitSystemProjectionReceipt(data, projectionId) {
    return data.keys().hasOnly([
      "projectionId", "ownerUid", "sourceVersion", "expectedSystemIds",
      "appliedSystemIds", "failedSystemIds", "status", "createdAt",
      "updatedAt", "completedAt", "schemaVersion"
    ])
    ...
  }
  ```
- **Observation**:
  1. `OnboardingFrontendHydrationService` iterates through `habitSystemProjections` in a `for` loop, executing `reconcileProjectedSystem` individually per habit system.
  2. Each call to `reconcileProjectedSystem` executes a separate Firestore transaction that writes 1 habit system document and creates/updates the `habitSystemProjections` receipt document.
  3. On receipt creation in `reconcileProjectedSystem`, `expectedSystemIds` is set to `[system.systemId]` (a single-item list). If 5 systems are projected, the receipt initial snapshot undercounts expected items.
  4. If process drops or network fails mid-loop (e.g. after system 2 of 5), the batch is left partially written without an atomic rollback or unified receipt state (`completed` vs `partial` vs `failed`). The receipt is overwritten 5 separate times, racing and causing state drift.

---

#### Issue 14: Habit system hydration fallback when remote projection is pending
- **`lib/features/routine/controllers/habit_systems_controller.dart` (lines 100–129)**:
  ```dart
  Future<void> loadForOwner(String uid) async {
    ...
    try {
      final remoteSystems = await _repository.fetchHabitSystems(uid);
      if (!mounted || generation != _loadGeneration || _ownerUid != uid) return;

      state = state.copyWith(systems: remoteSystems, loading: false);
    } catch (e) {
      ...
    }
  }
  ```
- **`lib/state/auth_state.dart` (lines 702–764)**:
  ```dart
  Future<void> _loadFakeUserState(AuthUser user) async {
    ...
    if (savedDraft.onboardingCompleted && bundle != null) {
      await const OnboardingFrontendHydrationService().hydrate(
        read: _ref.read,
        bundle: bundle,
      );
    } else {
      await _ref.read(routineNotifierProvider.notifier).loadForOwner(user.uid);
      await _ref
          .read(habitSystemsNotifierProvider.notifier)
          .loadForOwner(user.uid);
    }
  }
  ```
- **`lib/features/routine/screens/routine_habit_systems_screen.dart` (lines 33–35)**:
  ```dart
  if (ref.read(habitSystemsNotifierProvider).systems.isEmpty) {
    ref.read(habitSystemsNotifierProvider.notifier).loadForOwner(uid);
  }
  ```
- **Observation**:
  1. `HabitSystemsNotifier.loadForOwner(uid)` fetches remote habit systems via `_repository.fetchHabitSystems(uid)`.
  2. If remote habit system projection is pending (or Firestore documents haven't synced yet), `fetchHabitSystems(uid)` returns an empty list `[]`.
  3. `HabitSystemsNotifier` overwrites `state.systems` with `[]`. `RoutineHabitSystemsScreen` displays an empty state ("No active Good Habit systems. Create one to get started."), ignoring the fact that the user has completed onboarding and has habit systems in their draft/completion bundle.
  4. There is no in-memory hydration fallback to build habit systems from `OnboardingCompletionBundle` when remote projection is pending or empty, nor a deduplicating merge strategy to combine remote and projected systems without data loss.

---

#### Issue 15: Habit system schedule frequency update reconciliation
- **`lib/models/habit_system_record.dart` (lines 15, 33, 75)**:
  ```dart
  final List<String> linkedRoutineIds;
  ```
- **`lib/models/routine_item.dart` (lines 103, 165, 194)**:
  ```dart
  final List<int> repeatDays; // 1 = Monday, 7 = Sunday
  ```
- **`lib/features/routine/controllers/habit_systems_controller.dart` (lines 325–391, 445–465)**:
  ```dart
  Future<bool> pauseSystem(String systemId) async { ... }
  Future<bool> archiveSystem(String systemId) async { ... }
  Future<bool> linkRoutine(String systemId, String routineId) async { ... }
  Future<bool> unlinkRoutine(String systemId, String routineId) async { ... }
  ```
- **Observation**:
  1. `HabitSystemRecord` stores a list of `linkedRoutineIds`. `RoutineItem` stores schedule `repeatDays` (e.g. `[1..7]`).
  2. When a Habit System's status is changed (e.g. `pauseSystem`, `archiveSystem`, `restoreSystem`), or when its schedule/linked routines are modified, there is NO schedule frequency reconciliation service.
  3. When a Habit System is paused or archived, linked routine items remain active in `RoutineNotifier`, continuing to trigger daily schedule timeline cards and notifications.
  4. When a linked `RoutineItem` is deleted or archived, `linkedRoutineIds` in `HabitSystemRecord` retains dangling/stale routine IDs.
  5. There is no frequency synchronization mechanism to propagate changes in habit repeat frequency (e.g. Daily vs Weekdays) across linked routine items without corrupting routine data or violating zero data deletion (R11).

---

## 2. Logic Chain

### Issue 12: Owner UID Matching & Validation
1. **Observation**: `FirestoreHabitSystemsRepository` transaction callbacks (`updateSystem`, `archiveSystem`, `restoreSystem`, `reconcileProjectedSystem`) fetch `existing` document snapshot but do not verify `existing.ownerUid == targetOwnerUid`. `HabitSystemRecord.fromMap` defaults `ownerUid` to `''`. `HabitSystemsNotifier.updateSystem` does not verify `updated.ownerUid == _ownerUid`.
2. **Logic Step 1**: In a multi-user environment or during auth transitions, if a record snapshot has an empty or mismatched `ownerUid`, operations can mutate Firestore documents under the wrong owner path or pass invalid data to Firestore rules.
3. **Logic Step 2**: Requirement R11 & R3 require strict auth isolation, zero data corruption, and explicit validation guards.
4. **Conclusion**: `HabitSystemRecord` must validate `ownerUid` on creation/deserialization. Repositories must verify `existing.ownerUid == targetOwnerUid` inside transactions. Notifier mutation methods must verify `record.ownerUid == _ownerUid`. `HabitSystemOnboardingProjection` must validate `bundle.uid`.

---

### Issue 13: Batch Operation Transactional Integrity
1. **Observation**: `OnboardingFrontendHydrationService` calls `reconcileProjectedSystem` in a `for` loop. Each call executes an independent Firestore transaction updating `habitSystemProjections/{projectionId}` and setting `expectedSystemIds = [system.systemId]`.
2. **Logic Step 1**: Sequential un-batched writes mean a network drop midway leaves partial systems written without a unified receipt state. Overwriting the receipt 5 times undercounts `expectedSystemIds` and races in Firestore.
3. **Logic Step 2**: Firestore rules line 809 requires a valid `validHabitSystemProjectionReceipt` with matching `expectedSystemIds`, `appliedSystemIds`, `failedSystemIds`, and `status`.
4. **Conclusion**: `HabitSystemsRepository` must expose an atomic `reconcileProjectedSystems` method accepting a full list of projected systems and executing a single Firestore transaction/batch that writes all systems and updates the projection receipt atomically. `OnboardingFrontendHydrationService` must use this batch entrypoint.

---

### Issue 14: Hydration Fallback for Pending Remote Projections
1. **Observation**: `HabitSystemsNotifier.loadForOwner` sets `state.systems` directly to `_repository.fetchHabitSystems(uid)`. If remote projection is pending, `fetchHabitSystems` returns `[]`, causing `RoutineHabitSystemsScreen` to render an empty screen despite existing onboarding draft/bundle data.
2. **Logic Step 1**: During onboarding completion or cold boot, remote write latency or offline status means local memory must present the user's habits immediately.
3. **Logic Step 2**: `HabitSystemOnboardingProjection._stableSystemId` builds deterministic IDs (`habitsys_<hash>`).
4. **Conclusion**: `HabitSystemsNotifier` must implement `loadForOwnerWithFallback` that checks for an `OnboardingCompletionBundle`. If remote systems are empty or incomplete, it falls back to in-memory projected systems built from the bundle, merging them by `systemId` without duplicates or data deletion, and triggering background reconciliation.

---

### Issue 15: Schedule Frequency Update Reconciliation
1. **Observation**: `HabitSystemRecord` contains `linkedRoutineIds`, while `RoutineItem` contains schedule `repeatDays`. `HabitSystemsNotifier` mutates system status (`pause`, `archive`, `restore`, `link`, `unlink`) without propagating status or schedule updates to `RoutineNotifier` or cleaning up orphaned routine IDs.
2. **Logic Step 1**: If a habit system is paused/archived, its linked routine items should not remain active in the daily timeline. If a routine item is removed, dangling IDs in `linkedRoutineIds` corrupt link queries.
3. **Logic Step 2**: Frequency updates (e.g. changing repeat days) must propagate to linked routine items while preserving routine notes, start/end times, and history (R11 zero data deletion).
4. **Conclusion**: Implement a bidirectional schedule reconciler service (`HabitSystemScheduleReconciler`). Integrate it into `HabitSystemsNotifier` to prune orphan IDs on load/update, propagate habit system status (`active`/`paused`/`archived`) to linked routines, and synchronize `repeatDays` across linked routine items without destroying routine data.

---

## 3. Caveats

1. **Firestore Rules Alignment**: `firestore.rules` lines 809–831 (`validHabitSystemProjectionReceipt`) and lines 934–959 (`habitSystems` & `habitSystemProjections` collection match rules) strictly enforce schema keys. Any batch receipt field modification must align 100% with these rules.
2. **Fake Repository Fidelity**: `FakeHabitSystemsRepository` must mirror all new repository methods (`reconcileProjectedSystems`, owner UID transaction checks) so that unit and widget tests run in `OptivusBackendMode.fake` behave identically to production `Firebase` mode.
3. **Zero Data Deletion (R11)**: Routine items linked to a habit system must NEVER be hard-deleted when unlinking or pausing a habit system. Only relationships or status flags may be updated.

---

## 4. Conclusion

Group C analysis is complete. The exact root causes, data flows, and architectural fixes for Issues 12–15 have been fully documented:

- **Issue 12 (Owner UID Validation)**: Add UID guards in `HabitSystemRecord` constructor/codec, transaction owner checks in `FirestoreHabitSystemsRepository` & `FakeHabitSystemsRepository`, `_ownerUid` matching in `HabitSystemsNotifier`, and `bundle.uid` validation in `HabitSystemOnboardingProjection`.
- **Issue 13 (Transactional Batch Integrity)**: Implement atomic `reconcileProjectedSystems({uid, projectionId, systems})` in `HabitSystemsRepository` (Firestore & Fake) and update `OnboardingFrontendHydrationService` to perform single-transaction batch writes.
- **Issue 14 (Hydration Fallback)**: Implement `loadForOwnerWithFallback` in `HabitSystemsNotifier` to merge in-memory projected habit systems from `OnboardingCompletionBundle` when remote projection is pending, eliminating empty screen states.
- **Issue 15 (Schedule Frequency Reconciliation)**: Implement `HabitSystemScheduleReconciler` to clean orphan routine IDs, propagate active/paused/archived habit status to linked routine items, and synchronize frequency `repeatDays` bidirectionally without deleting routine history.

---

## 5. Verification Method

### 1. Targeted Unit & Widget Tests
Execute the targeted test suite using `flutter test`:
```bash
flutter test test/habit_systems_test.dart test/routine_habit_systems_screen_test.dart
```

### 2. Implementation Verification Checklist
1. **Issue 12 Verification**:
   - `HabitSystemRecord` throws `ArgumentError` on empty or malformed `ownerUid`.
   - `FirestoreHabitSystemsRepository.updateSystem` fails transaction when `existing.ownerUid != targetUid`.
   - `HabitSystemsNotifier.updateSystem` rejects mismatched `updated.ownerUid`.
2. **Issue 13 Verification**:
   - `reconcileProjectedSystems` executes a single Firestore transaction for $N$ habit systems.
   - Projection receipt document contains accurate `expectedSystemIds` ($N$ items), `appliedSystemIds`, `failedSystemIds`, and `status`.
3. **Issue 14 Verification**:
   - `loadForOwnerWithFallback` renders habit systems immediately from `OnboardingCompletionBundle` when remote systems are empty.
   - Merging remote and fallback systems by stable `systemId` produces zero duplicates.
4. **Issue 15 Verification**:
   - Pausing a habit system updates linked routine items to paused/inactive.
   - Updating habit system frequency updates `repeatDays` on linked routine items.
   - Deleting a routine item prunes stale IDs from `linkedRoutineIds` on next reconciliation without data deletion.

### 3. Invalidation Conditions
- Any test failure in `test/habit_systems_test.dart` or `test/routine_habit_systems_screen_test.dart`.
- `flutter analyze` reporting any warning or lint error on habit system code.
- Firestore security rules rejecting batch projection receipts during emulator runs.
