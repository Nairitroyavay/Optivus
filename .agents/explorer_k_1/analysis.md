# Analysis Report: Group K Issues 63 & 64 (Optivus Onboarding Stabilization)

**Explorer Agent**: explorer_k_1  
**Target Milestone**: Group K Onboarding Stabilization & Security Rules Testing  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_k_1`  
**Date**: 2026-07-26  

---

## Executive Summary

This report delivers a comprehensive investigation and architectural test design for **Group K Issues 63 & 64** in the Optivus workspace.
- **Issue 63**: Full end-to-end integration test for the entire onboarding flow, exercising Step 0 (Welcome) through Step 11 (Today Ready / Completion), draft persistence, profile creation/patching, routine & habit system projections, and home screen navigation (`/app?tab=0`).
- **Issue 64**: Firestore security rules unit tests for `user`, `job` (onboarding completion jobs), and `routine` collections (`routineItems`, `routineHistory`, `routineEvents`, `routineProjections`), validating read/write permissions, owner UID checks, strict schema validation functions, and immutability/append-only constraints.

No codebase source files have been modified during this read-only investigation. Detailed code trace analysis, component maps, state invariants, test structure designs, and targeted/regression execution commands are documented below.

---

## 1. Issue 63 Deep Dive: Full End-to-End Integration Test for Entire Onboarding Flow

### 1.1 Onboarding Flow Architecture & Code Trace

The onboarding subsystem in Optivus is driven by `OnboardingFlow` (`lib/features/onboarding/onboarding_flow.dart`), managed via Flutter Riverpod and GoRouter.

1. **Wizard Step Range**:
   - Total steps: 12 steps (indexed `0` through `11`, where `OnboardingDraft.lastStepIndex == 11`).
   - Managed by `PageController` (`_pageController`) with animated transitions (`animateToPage`, 350ms `easeInOut`).
   - Step Registry (`lib/features/onboarding/steps/`):
     - **Step 0**: Welcome (`OnboardingStep0Welcome`)
     - **Step 1**: Patience (`OnboardingStep1Patience`)
     - **Step 2**: Role & Lifestyle (`OnboardingStep2RoleLifestyle`)
     - **Step 3**: Body Basics (`OnboardingStep3BodyBasics`)
     - **Step 4**: Base Timeline (`OnboardingStep4BaseTimeline` / `OnboardingStep4Unified`)
     - **Step 5**: Bad Habits / Eating Setup (`OnboardingStep5EatingSetup` & `OnboardingStep5BadHabits`)
     - **Step 6**: Fixed Schedule / Good Habits (`OnboardingStep6FixedSchedule` & `OnboardingStep6GoodHabits`)
     - **Step 7**: Identity Goals / Skin Care (`OnboardingStep7IdentityGoals`, `OnboardingStep7SkinCareSetup`)
     - **Step 8**: Coach Setup (`OnboardingStep8CoachSetup`)
     - **Step 9**: Slip Up Plan (`OnboardingStep9SlipUp`)
     - **Step 10**: Notification Preferences (`OnboardingStep10Notifications`)
     - **Step 11**: Today Ready / Final Preview (`OnboardingStep11TodayReady`)

2. **Step Validation & Persistence Chain**:
   - Step validation is invoked per step via `_validateStep(step)` (`onboarding_flow.dart:110-114`).
   - Step saving is executed in `_saveStep(step)` (`onboarding_flow.dart:148-223`):
     - Prevents double-taps via `_isSaving`.
     - Validates current step; if invalid, sets `validationMessage`.
     - Checks user authentication & email verification (`_currentPersistenceUid()`).
     - Transforms step data on `mockOnboardingProvider` notifier.
     - Invalidates downstream steps if role changes on Step 2 (`_invalidateDownstreamStages(2)`).
     - Persists updated draft to `OnboardingRepository` (`saveDraft`).

3. **Flow Completion Sequence (`_completeOnboarding()`, `onboarding_flow.dart:273-395`)**:
   - Validates all steps `0..11`.
   - Saves final step 11 draft (`_saveStep(11)`).
   - Verifies email status for password provider (`_needsEmailVerification`).
   - Constructs completion bundle via `OnboardingCompletionService.buildBundle(draft)` (`lib/services/onboarding_completion_service.dart:95`).
   - Verifies no blocking warnings exist (`Resolve or accept...`).
   - Marks draft `onboardingCompleted = true` and updates step completion arrays.
   - Saves completed draft & bundle via `onboardingRepository.completeOnboarding(finalDraft: finalDraft, bundle: bundle)`.
   - Hydrates Riverpod frontend state via `OnboardingFrontendHydrationService().hydrate(read: ref.read, bundle: bundle)`.
   - Projects routine templates via `RoutineOnboardingProjection.build(bundle)` (`lib/services/routine_onboarding_projection.dart`).
   - Verifies routine projection receipt (`onboarding-initial-v1`) in `RoutineRepository`: must be `status == 'completed'`, `cursor == totalCount`, and matching fingerprint.
   - Initializes initial coach chat session (`mockCoachProvider.notifier.createNewSession(...)`).
   - Updates `authProvider` state (`markOnboardingComplete`).
   - Navigates user to Home screen: `context.go('/app?tab=0')`.

### 1.2 State & Data Invariants Matrix

| Subsystem / Model | Primary Source File | Target Invariants & State Checks |
|---|---|---|
| `OnboardingDraft` | `lib/models/onboarding_draft.dart` | `onboardingCompleted == true`, `currentStep == 11`, `stepCompleted` all `true`, `welcomeSaved == true`, body basics estimated. |
| `OnboardingCompletionBundle` | `lib/models/onboarding_completion_bundle.dart` | Valid `uid`, `baseTimelineBlocks`, `routineItemsForApp`, `goodHabitTemplates`, `badHabitCheckIns`, `identityGoalSystems`, `userProfilePatch`, zero blocking warnings. |
| `UserProfile` | `lib/models/user_profile.dart` | Updated via `userProfilePatch` with role, name, body basics, coach settings, `onboardingInputCompleted: true`, `onboardingCompleted: true`. |
| `RoutineOnboardingProjection` | `lib/services/routine_onboarding_projection.dart` | `projectionId == 'onboarding-initial-v1'`, receipt status `completed`, cursor == totalCount, `routineItems` saved in repository. |
| `HabitSystemOnboardingProjection` | `lib/services/habit_system_onboarding_projection.dart` | `habitSystems` created and linked with routine items. |
| Navigation Route | `lib/core/router/app_router.dart` | Transition from `/onboarding` to `/app?tab=0` (Home screen active). |

### 1.3 Identified Test Scenarios for Issue 63

1. **Scenario 1: Happy Path Full E2E Flow (Step 0 to Home Navigation)**
   - Pump `OnboardingFlow` inside `MaterialApp.router` with fake repositories (`FakeOnboardingRepository`, `FakeProfileRepository`, `FakeRoutineRepository`, `FakeAuthRepository`).
   - Simulate user progression through Step 0 to Step 11 by providing required inputs at each step.
   - Trigger "Finish / Enter Optivus" button on Step 11.
   - Assert all 6 completion side-effects:
     1. `OnboardingDraft` saved with `onboardingCompleted == true`.
     2. `OnboardingCompletionBundle` generated and saved.
     3. `UserProfile` updated with patched profile settings.
     4. `RoutineItem` templates generated and stored.
     5. Projection receipt `onboarding-initial-v1` status is `completed`.
     6. Navigation changes active route to `/app?tab=0`.

2. **Scenario 2: Validation Failure & Navigation Blocking**
   - Attempt to click Next on Step 2 without selecting a role or on Step 3 with invalid time boundaries.
   - Assert `validationMessage` is populated on `mockOnboardingProvider`.
   - Assert wizard remains on current page and does not advance controller page.

3. **Scenario 3: Role Change & Downstream Invalidation**
   - Progress to Step 5, then navigate backward to Step 2 and change role (e.g. Student -> Engineer).
   - Trigger Next on Step 2.
   - Assert `_invalidateDownstreamStages(2)` marks steps 3..11 as uncompleted (`stepCompleted[i] == false`), requiring explicit re-validation.

4. **Scenario 4: Password User Unverified Email Guard**
   - Authenticate password user with `emailVerified == false`.
   - Progress to Step 11 and attempt completion.
   - Assert completion is aborted with message: `"Please verify your email before finishing onboarding."`

5. **Scenario 5: Projection Receipt Failure Error Recovery**
   - Inject a failing projection receipt (e.g., status `pending` or mismatched fingerprint) into `FakeRoutineDatabase`.
   - Attempt completion on Step 11.
   - Assert completion halts with message: `"History event projection failed to complete. Please tap Enter Optivus to retry."`

---

## 2. Issue 64 Deep Dive: Firestore Security Rules Unit Tests

### 2.1 Firestore Security Rules Structure (`firestore.rules`)

`firestore.rules` implements strict security rules for database collections under `/users/{uid}`.

#### 1. Authentication & Ownership Functions (`lines 5-20`)
```firestore
function signedIn() { return request.auth != null; }
function isOwner(uid) { return signedIn() && request.auth.uid == uid; }
function emailVerified() { return signedIn() && request.auth.token.email_verified == true; }
function verifiedOwner(uid) { return isOwner(uid) && emailVerified(); }
```
*Rule Constraint*: Any access to user collections requires `verifiedOwner(uid)` (authenticated, matching UID, and `email_verified == true`).

#### 2. User Collection Rules (`lines 977-979`)
```firestore
match /users/{uid} {
  allow read, write: if verifiedOwner(uid);
}
```
- Controls access to top-level user document `/users/{uid}`.

#### 3. Onboarding Completion Jobs & Onboarding Collections (`lines 929-931, 985-996`)
```firestore
match /users/{uid}/onboarding/{docId} {
  allow read, write: if verifiedOwner(uid);
}

match /users/{uid}/{collectionId}/{document=**} {
  allow read, write: if verifiedOwner(uid)
    && collectionId != "uploads"
    && collectionId != "routineImportReviews"
    && collectionId != "routineItems"
    && collectionId != "routineHistory"
    && collectionId != "routineEvents"
    && collectionId != "routineProjections"
    && collectionId != "habitSystems"
    && collectionId != "syncAllowances"
    && collectionId != "syncEvents";
}
```
- `/users/{uid}/onboardingCompletionJobs/{jobId}` (where `jobId == 'current'` or explicit ID) is governed by verified owner access under this subcollection match.

#### 4. Routine Collections Rules (`lines 869-925`)
- **`routineItems` (`/users/{uid}/routineItems/{itemId}`)**:
  - `allow read`: `verifiedOwner(uid)`
  - `allow create`: `verifiedOwner(uid) && validRoutineTemplate(request.resource.data, itemId)`
  - `allow update`: `verifiedOwner(uid) && validRoutineTemplate(...)` + immutability checks (`ownerUid`, `id`, `createdAt`, `onboardingProjectionId`, `onboardingSourceItemId`, `createdByOperationId`).
  - `allow delete`: `verifiedOwner(uid) && resource.data.ownerUid == request.auth.uid && resource.data.id == itemId`
  - Valid Categories (`validRoutineCategory`, `lines 208-224`): includes `"job"`, `"classBlock"`, `"eating"`, `"fixed"`, `"skinCare"`, `"sleep"`, `"habit"`, `"badHabit"`, `"identity"`, `"finance"`, `"health"`, `"focus"`, `"meditation"`, `"hydration"`, `"screenTime"`.
- **`routineHistory` (`/users/{uid}/routineHistory/{occurrenceId}`)**:
  - `allow read`: `verifiedOwner(uid)`
  - `allow create`: `verifiedOwner(uid) && validRoutineOccurrence(request.resource.data, occurrenceId)`
  - `allow update`: `verifiedOwner(uid) && validRoutineOccurrence(...)` + immutability checks (`ownerUid`, `routineItemId`, `occurrenceDateKey`, `createdAt`).
  - `allow delete`: `verifiedOwner(uid) && resource.data.ownerUid == request.auth.uid`
- **`routineEvents` (`/users/{uid}/routineEvents/{eventId}`)**:
  - `allow read`: `verifiedOwner(uid)`
  - `allow create`: `verifiedOwner(uid) && validRoutineEvent(request.resource.data, eventId)`
  - `allow update, delete`: `false` (Strict append-only).
- **`routineProjections` (`/users/{uid}/routineProjections/{projectionId}`)**:
  - Requires `projectionId == "onboarding-initial-v1"`.
  - `allow read`: `verifiedOwner(uid)`
  - `allow create`: `validRoutineProjectionReceipt(request.resource.data, projectionId)`
  - `allow update`: `validRoutineProjectionTransition(resource.data, request.resource.data, projectionId)` (monotonic cursor progress, status completion requirements).
  - `allow delete`: `false`.

### 2.2 Existing Rules Test Baseline (`tests/firestore_rules.test.js`)

Existing tests cover:
- `syncAllowances` and `syncEvents` (lines 159-242).
- Basic `routineItems`, `routineHistory`, `routineEvents`, `routineProjections`, `habitSystems` happy paths (lines 244-409).

**Missing Unit Test Coverage Required for Issue 64**:
1. **User Profile Collection (`/users/{uid}`)**:
   - Verified owner create/read/update -> ALLOW.
   - Unverified owner (`email_verified: false`) -> DENY.
   - Unauthenticated request -> DENY.
   - Cross-user write attempt (`userA` writing to `/users/userB`) -> DENY.
2. **Onboarding Job Collection (`/users/{uid}/onboardingCompletionJobs/{jobId}`)**:
   - Verified owner writing `OnboardingCompletionJob` to `/users/{uid}/onboardingCompletionJobs/current` -> ALLOW.
   - Unverified owner or cross-user write to job document -> DENY.
   - Reading job status by verified owner -> ALLOW; by cross-user -> DENY.
3. **Job Category Routine Template Verification**:
   - Create `routineItem` with `category: "job"` -> ALLOW.
   - Create `routineItem` with invalid category string `category: "unauthorized_category"` -> DENY.
   - Attempting to modify immutable projection fields (`onboardingProjectionId`, `onboardingSourceItemId`, `createdByOperationId`) during update -> DENY.
4. **Routine History Action & Occurrence Validation**:
   - Valid actions (`complete`, `reschedule`, `skip`, `move`) -> ALLOW.
   - Invalid action string -> DENY.
   - Modifying immutable fields (`routineItemId`, `occurrenceDateKey`) -> DENY.
5. **Routine Events Append-Only & Event Type Guards**:
   - Event creation for occurrence event without `occurrenceId` -> DENY.
   - Updating or deleting any `routineEvents` document -> DENY.
6. **Routine Projections Monotonicity & Receipt Guards**:
   - Creating projection with non-matching `projectionId` -> DENY.
   - Transitioning receipt status to `completed` when `cursor < totalCount` -> DENY.
   - Transitioning receipt with regressed cursor (`after.cursor < before.cursor`) -> DENY.

---

## 3. Recommended Test Suite Structures

### 3.1 Issue 63 Test Design (`test/group_k_issues_63_to_64_test.dart`)

```dart
// Location: test/group_k_issues_63_to_64_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group K - Issue 63: Onboarding Flow E2E Integration Test', () {
    testWidgets('Executes Step 0 through completion, profile update, routine projections, and home navigation', (tester) async {
      // 1. Setup fake repositories & initial providers
      // 2. Pump MaterialApp.router with OnboardingFlow
      // 3. Step-by-step UI interaction (Step 0 -> Step 11)
      // 4. Trigger Finish
      // 5. Assert draft persisted with onboardingCompleted: true
      // 6. Assert completion bundle saved
      // 7. Assert profile updated
      // 8. Assert routine projection receipt status == completed
      // 9. Assert active route navigated to /app?tab=0
    });

    testWidgets('Blocks step progression when step validation fails', (tester) async { ... });
    testWidgets('Invalidates downstream steps when role changes on Step 2', (tester) async { ... });
    testWidgets('Blocks completion for unverified password users', (tester) async { ... });
    testWidgets('Recovers gracefully when routine projection receipt check fails', (tester) async { ... });
  });
}
```

### 3.2 Issue 64 Test Design (`tests/firestore_rules.test.js`)

```javascript
// Location: tests/firestore_rules.test.js (Extended describe blocks)

describe("Issue 64: User Collection Security Rules", () => {
  it("allows verified owner to read and write user profile document", async () => { ... });
  it("denies unverified owner read/write to user profile document", async () => { ... });
  it("denies cross-user access to user profile document", async () => { ... });
});

describe("Issue 64: Onboarding Completion Job Security Rules", () => {
  it("allows verified owner to create/update job status in onboardingCompletionJobs", async () => { ... });
  it("denies unverified owner or cross-user write to onboardingCompletionJobs", async () => { ... });
});

describe("Issue 64: Routine Collections Security & Validation Rules", () => {
  it("allows routine template creation with 'job' category", async () => { ... });
  it("denies routine template creation with invalid category", async () => { ... });
  it("denies update to immutable routine template fields (onboardingProjectionId)", async () => { ... });
  it("denies occurrence creation with invalid action string", async () => { ... });
  it("denies update to immutable occurrence fields (occurrenceDateKey)", async () => { ... });
  it("strictly enforces append-only rules on routineEvents", async () => { ... });
  it("denies projection completion transition if cursor does not equal totalCount", async () => { ... });
});
```

---

## 4. Targeted & Regression Test Execution Guide

### 4.1 Issue 63 (Flutter E2E Integration Tests)
- **Targeted Test Execution**:
  ```bash
  flutter test test/group_k_issues_63_to_64_test.dart
  ```
- **Regression Suite Execution**:
  ```bash
  flutter test test/
  ```

### 4.2 Issue 64 (Firestore Security Rules Unit Tests)
- **Targeted Test Execution**:
  ```bash
  npm test
  ```
  *(Runs `jest tests/firestore_rules.test.js` against local Firestore emulator on port 8080)*.

---

## 5. Summary of Target Files to Inspect / Modify (For Implementer)

| Issue | Role | Target File Path | Action Description |
|---|---|---|---|
| **63** | Test Implementation | `test/group_k_issues_63_to_64_test.dart` | Create end-to-end integration widget test covering onboarding flow. |
| **63** | Inspection Reference | `lib/features/onboarding/onboarding_flow.dart` | Source implementation for onboarding step wizard and completion logic. |
| **63** | Inspection Reference | `lib/services/onboarding_completion_service.dart` | Source implementation for bundle building & recovery logic. |
| **64** | Test Extension | `tests/firestore_rules.test.js` | Extend Jest test suite with user, job, and routine collection permission/schema tests. |
| **64** | Inspection Reference | `firestore.rules` | Security rules definition file for Cloud Firestore. |
| **64** | Inspection Reference | `lib/repositories/firestore_paths.dart` | Path definitions for user, job, and routine Firestore documents. |

