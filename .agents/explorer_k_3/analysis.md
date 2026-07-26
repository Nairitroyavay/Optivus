# Analysis Report: Group K Issues 67 & 68 (Optivus Onboarding Stabilization)

**Author**: `explorer_k_3`  
**Date**: 2026-07-27  
**Scope**: Group K Issues 67 & 68 (Account Migration & Anonymous Link Integration Tests, Multi-Device Sync Conflict Resolution Tests)  
**Target Test Suite**: `test/group_k_issues_67_to_68_test.dart`  

---

## Executive Summary

This report presents a comprehensive code inspection, requirements trace, test design, and verification plan for **Group K Issues 67 & 68** of the Optivus onboarding stabilization sequence. 

- **Issue 67** focuses on **Account Migration & Anonymous Link Integration Tests**, validating anonymous user initialization, onboarding draft building, credential linking to email/password, full multi-tier data preservation across UIDs, and seamless post-linking navigation.
- **Issue 68** focuses on **Multi-Device Sync Conflict Resolution Tests**, validating routine/habit system updates from multiple concurrent device clients, optimistic concurrency version checks, Last-Write-Wins (LWW) timestamp resolution, and non-destructive map/history merging logic.

No source code or existing test files outside `.agents/explorer_k_3` were modified during this investigation.

---

## 1. Deep Code Inspection & Requirements Trace

### 1.1 Issue 67: Account Migration & Anonymous Link Integration Tests

#### Requirements:
1. **Anonymous User Creation**:
   - `AuthNotifier.signInAnonymously()` creates an anonymous `AuthUser` (`isAnonymous == true`, `providerId == 'anonymous'`).
   - Router transitions state to `/onboarding` with status `AuthFlowStatus.signedInOnboardingIncomplete`.
2. **Draft Building**:
   - User populates onboarding steps (steps 0 through 7) under the generated anonymous UID (`oldAnonUid`).
   - Draft data (`OnboardingDraft`), user profile (`UserProfile`), profile settings, routine items (`RoutineItem`), routine occurrence history (`RoutineOccurrenceRecord`), habit systems (`HabitSystemRecord`), and preferences (`AppPreferences`) are saved under `oldAnonUid`.
3. **Credential Linking**:
   - User triggers `AuthNotifier.linkAnonymousWithEmail(email, password, {name})`.
   - `AuthRepository.linkAnonymousWithEmail(...)` links the new email/password credentials to the existing anonymous session.
   - User properties update to `isAnonymous == false` and `providerId == 'password'`.
4. **Data Preservation Across UIDs**:
   - `AuthNotifier` detects `oldAnonUid != user.uid` and invokes `OnboardingAccountMigrationService.migrateAccountData(oldAnonUid: oldAnonUid, newUid: user.uid, read: _ref.read)`.
   - All 5 data tiers are migrated to `newUid`:
     - **Tier 1 (Draft)**: `onboardingRepo.fetchDraft(oldAnonUid)` -> `draft.copyWith(uid: newUid)` -> `saveDraft(...)`.
     - **Tier 2 (Profile & Settings)**: `profileRepo.fetchUserProfile(oldAnonUid)` -> `userProfile.copyWith(uid: newUid, updatedAt: DateTime.now())` -> `saveUserProfile(...)`, and `fetchProfileSettings(...)` -> `saveProfileSettings(newUid, ...)`.
     - **Tier 3 (Routines & History)**: `routineRepo.fetchRoutineItems(oldAnonUid)` -> `item.copyWith(userId: newUid, updatedAt: DateTime.now())` -> `createRoutineItem(...)`, and `routineHistoryRepo.fetchHistory(oldAnonUid)` -> `RoutineOccurrenceRecord(ownerUid: newUid, updatedAt: DateTime.now())` -> `appendHistory(...)`.
     - **Tier 4 (Habit Systems)**: `habitSystemsRepo.fetchHabitSystems(oldAnonUid)` -> `s.copyWith(ownerUid: newUid, updatedAt: DateTime.now())` -> `reconcileProjectedSystems(ownerUid: newUid, projectionId: 'migration', systems: ...)`.
     - **Tier 5 (App Preferences)**: `appPreferencesRepo.fetchAppPreferences(oldAnonUid)` -> `saveAppPreferences(newUid, ...)`.
5. **Seamless Post-Linking Navigation**:
   - Evaluates `_needsEmailVerification(user)`.
   - If email is unverified, sets status to `AuthFlowStatus.signedInEmailUnverified` and routes to `/email-verification`.
   - Upon email verification, calls `_loadOrCreateBackendUserState(user)`, restoring user state to `/app?tab=0` or onboarding completion stage without losing input or restarting onboarding from step 0.

#### Code Evidence Locations:
- `lib/repositories/auth_repository.dart`:
  - Lines 35, 37-41: Abstract methods `signInAnonymously()` and `linkAnonymousWithEmail(...)`.
  - Lines 136-148: `FakeAuthRepository.signInAnonymously()` creating `anon-uid-*` with `isAnonymous: true`.
  - Lines 151-178: `FakeAuthRepository.linkAnonymousWithEmail(...)` converting anonymous user to password user while retaining UID or re-assigning credentials.
  - Lines 295-309: `FirebaseAuthRepository.signInAnonymously()`.
  - Lines 312-341: `FirebaseAuthRepository.linkAnonymousWithEmail(...)`.
- `lib/state/auth_state.dart`:
  - Lines 253-297: `AuthNotifier.linkAnonymousWithEmail` storing `oldAnonUid`, calling repository linking, invoking `OnboardingAccountMigrationService.migrateAccountData`, and handling verification status.
- `lib/services/onboarding_account_migration_service.dart`:
  - Lines 16-107: `OnboardingAccountMigrationService.migrateAccountData` executing multi-tier data migration across UIDs.
- `test/group_d_issues_16_to_21_test.dart`:
  - Lines 310-365: Basic unit verification of `linkAnonymousWithEmail` and `OnboardingAccountMigrationService`.

---

### 1.2 Issue 68: Multi-Device Sync Conflict Resolution Tests

#### Requirements:
1. **Routine & Habit System Updates from Multiple Device Clients**:
   - Simulates Client A (Device A) and Client B (Device B) concurrently modifying shared routine items and habit systems under the same user UID.
2. **LWW (Last-Write-Wins) / Timestamp & Version Conflict Resolution**:
   - **Habit Systems Concurrency**: Optimistic concurrency control via `expectedVersion`. `updateSystem` and `archiveSystem` check `if (current.version != expectedVersion) throw HabitSystemWriteConflict('Stale version')`.
   - **Routine Items Concurrency**: Operation ID check (`lastMutationOperationId` and `createdByOperationId`) for idempotency, plus timestamp-based LWW (`updatedAt`) when merging out-of-order writes.
3. **Non-Destructive Merge Logic**:
   - **Habit Systems In-Memory / Remote Merge**: `_mergeSystems` in `HabitSystemsNotifier` (`lib/features/routine/controllers/habit_systems_controller.dart`, lines 196-207) performs key-based map merging by `systemId`. Remote records override fallback records without deleting local un-synced entries.
   - **Routine History Non-Destructive Append**: Routine completion occurrences from multiple devices accumulate under unique `operationKey` / `occurrenceDateKey` without overwriting prior records or deleting historical entries (R11 compliance).

#### Code Evidence Locations:
- `lib/models/habit_system_record.dart`:
  - Contains `systemId`, `ownerUid`, `title`, `status`, `version`, `createdAt`, `updatedAt`.
- `lib/repositories/firebase_habit_systems_repository.dart`:
  - Lines 151-153: `if (existing.version != expectedVersion) throw const HabitSystemWriteConflict('Stale version');` inside transaction.
- `lib/repositories/fake_habit_systems_repository.dart`:
  - Lines 71-73: `if (current.version != expectedVersion) throw const HabitSystemWriteConflict('Stale version');`.
- `lib/features/routine/controllers/habit_systems_controller.dart`:
  - Lines 196-207: `_mergeSystems(remote, fallback)` key-based non-destructive merge logic.
- `lib/repositories/routine_repository.dart`:
  - Lines 57-61 & 82-85: `FakeRoutineRepository` operation ID idempotency guards (`createdByOperationId`, `lastMutationOperationId`).

---

## 2. Test Architecture & File Specifications

### 2.1 File to Create
- `test/group_k_issues_67_to_68_test.dart`

### 2.2 Detailed Test Structure

```dart
// test/group_k_issues_67_to_68_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Optivus imports for auth, onboarding, routines, habit systems, repositories, services...

void main() {
  group('Group K Issue 67: Account Migration & Anonymous Link Integration Tests', () {
    test('67.1: Anonymous user creation transitions state to signedInOnboardingIncomplete', () async { ... });
    test('67.2: Draft profile, routine items, habit systems, and settings created under anonymous UID', () async { ... });
    test('67.3: Credential linking invokes OnboardingAccountMigrationService and migrates all 5 data tiers', () async { ... });
    test('67.4: Data preservation verification confirms zero data loss across UIDs', () async { ... });
    test('67.5: Post-linking email verification enforcement routes unverified user to signedInEmailUnverified', () async { ... });
    test('67.6: Email verification reload restores backend state seamlessly to completed onboarding without input loss', () async { ... });
  });

  group('Group K Issue 68: Multi-Device Sync Conflict Resolution Tests', () {
    test('68.1: Concurrent habit system updates from multiple clients with version increment', () async { ... });
    test('68.2: Stale version conflict handling throws HabitSystemWriteConflict and recovers state', () async { ... });
    test('68.3: Non-destructive key-based habit systems merge combines remote and fallback records without data deletion', () async { ... });
    test('68.4: Concurrent routine item updates preserve operation ID idempotency and LWW timestamp ordering', () async { ... });
    test('68.5: Multi-device routine occurrence history append preserves all completion entries without overwriting', () async { ... });
  });
}
```

---

## 3. Targeted & Regression Test Execution Plan

### 3.1 Targeted Test Execution
Command:
```bash
flutter test test/group_k_issues_67_to_68_test.dart
```

### 3.2 Group K & Related Regression Execution
Commands:
```bash
flutter test test/group_k_*.dart
flutter test test/group_d_issues_16_to_21_test.dart
flutter test test/group_c_issues_12_to_15_test.dart
flutter test test/habit_systems_test.dart
```

### 3.3 Full Suite Verification & Analyzer Cadence
Commands:
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

---

## 4. Risks, Assumptions, & Recommendations

1. **Risk: Account Migration Partial Failure**:
   - If one tier of migration fails during `migrateAccountData` (e.g. routine items fail while draft succeeds), the operation should log and preserve remaining tiers without corrupting the target account.
2. **Risk: Optimistic Concurrency Invalidation**:
   - When stale version exceptions occur during multi-device updates, clients must re-fetch remote state (`fetchHabitSystems`) before retrying.
3. **Recommendation**:
   - Implement `test/group_k_issues_67_to_68_test.dart` following the exact structure detailed above.
