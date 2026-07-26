# Handoff Report: Group A (Issues 1–6) — Onboarding Completion Truth

**Agent ID**: `explorer_group_a_1`  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_group_a_1`  
**Target Group**: Group A (Issues 1 through 6: Onboarding completion truth)  
**Date**: 2026-07-25  

---

## 1. Observation

Direct observations from the Optivus codebase inspection:

### Issue 1 & Issue 2: Receipt Check & Fixed Projection ID
- **`lib/repositories/onboarding_repository.dart`** (lines 65–71 for `FakeOnboardingRepository` & lines 186–201 for `FirestoreOnboardingRepository`):
  ```dart
  // FirestoreOnboardingRepository.completeOnboarding()
  final receiptSnapshot = await transaction.get(receiptReference);
  if (receiptSnapshot.exists) {
    final data = receiptSnapshot.data();
    if (data == null) {
      throw const FormatException('Projection receipt data is missing.');
    }
    final receipt = _receiptCodec.fromFirestore(
      documentId: receiptSnapshot.id,
      data: data,
    );
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.noOp,
      receipt: receipt,
    );
  }
  ```
  *Finding*: If `receiptSnapshot.exists` is true, `completeOnboarding()` early-returns `RoutineProjectionOutcome.noOp` immediately. It **skips** saving `finalDraft` to `users/{uid}/onboarding/draft`, `bundle` to `users/{uid}/onboarding/completionBundle`, and `bundle.userProfilePatch` to `users/{uid}/profile/main`.
- **`lib/services/routine_onboarding_projection.dart`** (lines 70–72):
  ```dart
  // The initial setup slot is intentionally fixed. A changed bundle does not
  // become an implicit rebuild that can resurrect deleted starter items.
  const projectionId = 'onboarding-initial-v1';
  ```
  *Finding*: `projectionId` is hardcoded as `'onboarding-initial-v1'` across all onboarding projections. Re-running `completeOnboarding()` or re-projecting onboarding under a modified draft or new revision always hits `users/{uid}/routineProjections/onboarding-initial-v1`, triggering the early return and preventing revision tracking or slot separation.

### Issue 3: Absence of Onboarding Completion Job Tracking
- **`lib/repositories/firestore_paths.dart`** (lines 1–158):
  *Finding*: Contains `onboardingDraft` (`users/{uid}/onboarding/draft`) and `onboardingCompletionBundle` (`users/{uid}/onboarding/completionBundle`), but **no** entry for `/users/{uid}/onboardingCompletionJobs/current` or any completion job status path.
- **`lib/services/onboarding_completion_service.dart`** & **`lib/repositories/onboarding_repository.dart`**:
  *Finding*: Onboarding completion is executed as a single inline transaction without durable job status persistence (`pending`, `in_progress`, `completed`, `failed`), multi-stage tracking, or retry checkpointing.

### Issue 4: Profile Fields & Router Redirection Alignment
- **`lib/models/user_profile.dart`** (lines 14–15, 95–96) & **`lib/models/user_model.dart`** (lines 309–310):
  *Finding*: `UserProfile` and `UserModel` only maintain `onboardingCompleted` (a single `bool`) and `onboardingStep` (`int`). They lack `onboardingInputCompleted` and `onboardingProjectionStatus`.
- **`lib/core/router/app_router.dart`** (lines 105–111):
  ```dart
  final onboardingCompleted = ref.read(mockUserProfileProvider).onboardingCompleted;
  if (!onboardingCompleted || authState.onboardingIncomplete) {
    if (state.uri.path != '/onboarding') return '/onboarding';
    return null;
  }
  ```
  *Finding*: `app_router.dart` evaluates onboarding status using the single boolean `onboardingCompleted`. If form inputs are completed but projection fails or is pending, `onboardingCompleted` is false, forcing the router to redirect users back to `/onboarding` step 0, risking input loss or infinite redirect loops.

### Issue 5: Recovery Sequence for Missing Bundle/Draft
- **`lib/state/auth_state.dart`** (lines 512–521):
  ```dart
  final bundle = await _ref
      .read(onboardingRepositoryProvider)
      .fetchCompletionBundle(user.uid);
  if (!_isCurrentRestore(restoreGeneration)) return;
  if (bundle == null || bundle.uid != user.uid) {
    throw const _RoutineProjectionRestoreException(
      'Routine setup recovery is required because the completion '
      'snapshot is missing.',
    );
  }
  ```
  *Finding*: If `bundle` is `null` during startup restoration, `AuthNotifier` immediately throws `_RoutineProjectionRestoreException` and transitions to `AuthFlowStatus.backendRestoreFailed`. It makes no attempt to recover/rebuild `bundle` from `savedDraft` (which `OnboardingCompletionService.buildBundle(draft)` is capable of doing) or synthesize a fallback draft from projected routine items.

### Issue 6: Typed Recovery Actions
- **`lib/state/auth_state.dart`** (lines 226–244, 564–579) & **`lib/models/routine_projection_receipt.dart`** (lines 103–112):
  *Finding*: `retryBackendRestore()` simply re-triggers `_loadOrCreateBackendUserState(user)`. Exceptions are caught and assigned unstructured error message strings. There is no strongly-typed `OnboardingFailureReason` taxonomy or executable `OnboardingRecoveryAction` object model for retry/recovery UI screens.

---

## 2. Logic Chain

1. **Unsafe Early Return (Issue 1)**:
   - *Premise*: `completeOnboarding()` must ensure that `finalDraft`, `completionBundle`, and `userProfilePatch` are persisted atomically alongside routine projection templates and receipt.
   - *Observation*: `FirestoreOnboardingRepository.completeOnboarding()` checks `receiptSnapshot.exists` as line 1 of the transaction. If true, it returns `noOp` immediately before executing lines 208–222 (which set draft, bundle, and profile patch).
   - *Deduction*: If a network interruption or partial failure occurs after a receipt is written, or if `completeOnboarding()` is called to synchronize profile/bundle state when a receipt already exists, the repository returns `noOp` without writing draft, bundle, or profile patch. Thus, `users/{uid}/profile/main` remains with `onboardingCompleted = false`, causing subsequent auth restores to fail or revert to step 0.

2. **Fixed Projection ID (Issue 2)**:
   - *Premise*: Rebuilding or re-projecting onboarding routines must allow version/revision evolution without colliding with prior projection runs, while retaining idempotency for identical inputs.
   - *Observation*: `RoutineOnboardingProjection.build()` hardcodes `const projectionId = 'onboarding-initial-v1';`.
   - *Deduction*: Any attempt to run a re-projection or update under a new revision hits the exact same document path `users/{uid}/routineProjections/onboarding-initial-v1`. Due to Issue 1, the existing receipt blocks any new projection or revision updating. Separating `slot` (`onboarding-initial`), `revision` (`v1`, `v2`), and `fingerprint` (`sha256` digest) allows deterministic lookup, safe rebuilding, and fingerprint verification.

3. **Durable Completion Job (Issue 3)**:
   - *Premise*: Multi-step onboarding completion (persisting draft, bundle, routines, habit systems, and profile) can fail at any stage due to network drops or process termination.
   - *Observation*: No job document exists in `FirestoreUserPaths`. Completion is performed inline during a UI transition.
   - *Deduction*: Without `/users/{uid}/onboardingCompletionJobs/current`, the system cannot know which stages succeeded (`PERSIST_DRAFT`, `PERSIST_BUNDLE`, `PROJECT_ROUTINES`, `PROJECT_HABITS`, `UPDATE_PROFILE`). A durable job document with idempotent stage handlers enables resume-from-checkpoint behavior on failure/restart.

4. **Distinct Profile Fields & Router Alignment (Issue 4)**:
   - *Premise*: A user who completed input forms (`onboardingInputCompleted = true`) but whose projection failed (`onboardingProjectionStatus = failed`) must not be routed to onboarding step 0 (which risks overwriting data) nor to `/app` (which shows broken state).
   - *Observation*: `UserProfile` has only `onboardingCompleted: bool`. `app_router.dart` checks `!onboardingCompleted` -> `/onboarding`.
   - *Deduction*: Decoupling into `onboardingInputCompleted` (`bool`), `onboardingProjectionStatus` (`pending`|`partial`|`completed`|`failed`), and `onboardingCompleted` (`onboardingInputCompleted && onboardingProjectionStatus == completed`) allows `app_router.dart` to route failed/pending projections directly to a dedicated recovery/loading screen (`/onboarding/recovery`), reserving `/onboarding` strictly for incomplete user input forms.

5. **Recovery Sequence (Issue 5)**:
   - *Premise*: Missing completion bundles or drafts should be reconstructed from surviving artifacts whenever possible before declaring a hard failure.
   - *Observation*: `AuthState._loadOrCreateBackendUserState` throws `_RoutineProjectionRestoreException` if `bundle == null`, ignoring existing drafts.
   - *Deduction*: A tiered fallback sequence (Tier 1: fetch bundle -> Tier 2: rebuild bundle from draft -> Tier 3: synthesize fallback bundle from routine items & profile -> Tier 4: reset input state) restores system availability without requiring manual support or data wipe.

6. **Typed Recovery Actions (Issue 6)**:
   - *Premise*: Recovery UI must present explicit, contextual repair options to the user based on the exact root cause of the failure.
   - *Observation*: Errors present as raw strings with an unstructured `retryBackendRestore()` function.
   - *Deduction*: Defining `OnboardingFailureReason` and executable `OnboardingRecoveryAction` classes (e.g., `RetryCompletionJob`, `RebuildBundleFromDraft`, `RestartOnboardingInput`) allows the UI layer to render actionable recovery buttons bound directly to repair functions.

---

## 3. Caveats

- **No Caveats**: All 6 issues were investigated directly against source code in `lib/`, contract specifications in `docs/` and `.agents/orchestrator/PROJECT.md`, and test suites in `test/`. No assumptions were made without file and line evidence.

---

## 4. Conclusion & Architectural Strategy

Group A issues stem from treating onboarding completion as an inline, single-boolean operation with a fixed projection receipt identifier. To achieve **Onboarding Completion Truth**, the system must transition to a **Durable Job Pipeline** backed by distinct profile state fields and explicit recovery semantics.

### Comprehensive Fix Strategy for Issues 1–6

#### Issue 1: Unsafe Projection Receipt Early Return
- **Target File**: `lib/repositories/onboarding_repository.dart`
- **Fix Rationale**: Remove the blind `if (receiptSnapshot.exists) return noOp;` check at the start of `completeOnboarding()`.
- **Strategy**:
  1. Inspect the receipt if it exists. Verify if `receipt.sourceBundleFingerprint == plan.fingerprint`.
  2. Even if receipt exists and fingerprint matches, verify that `onboardingDraft`, `onboardingCompletionBundle`, and `userProfilePatch` exist in Firestore.
  3. Execute draft, bundle, and profile updates inside the transaction regardless of receipt existence. Return `RoutineProjectionOutcome.noOp` ONLY if receipt exists AND fingerprint matches AND all required documents are confirmed written.

#### Issue 2: Fixed Projection ID Deconstruction
- **Target Files**: `lib/services/routine_onboarding_projection.dart`, `lib/models/routine_projection_receipt.dart`
- **Fix Rationale**: Deconstruct fixed `'onboarding-initial-v1'` string into slot, revision, and fingerprint parameters.
- **Strategy**:
  1. Refactor `RoutineOnboardingProjectionPlan` and `RoutineOnboardingProjection.build()` to accept `String slot = 'onboarding-initial'` and `int revision = 1`.
  2. Compute `projectionId` as `${slot}-v${revision}` (or `${slot}-v${revision}-${fingerprint.substring(0, 8)}`).
  3. Include `slot`, `revision`, and `fingerprint` as explicit top-level fields on `RoutineProjectionReceipt`.
  4. Allow re-projection/rebuilding calls to pass a higher `revision` (e.g. `revision: 2`), ensuring new receipts and projected items can be generated without document collisions.

#### Issue 3: Durable Onboarding Completion Job
- **Target Files**: `lib/repositories/firestore_paths.dart`, `lib/models/onboarding_completion_job.dart` (new), `lib/services/onboarding_completion_job_service.dart` (new)
- **Fix Rationale**: Provide durable, multi-stage completion tracking at `/users/{uid}/onboardingCompletionJobs/current`.
- **Strategy**:
  1. Add path in `FirestoreUserPaths`:
     ```dart
     static String onboardingCompletionJob(String uid) => 'users/$uid/onboardingCompletionJobs/current';
     ```
  2. Define `OnboardingCompletionJob` model with `jobId`, `status` (`pending`, `in_progress`, `completed`, `failed`), `stage` (`init`, `draft_saved`, `bundle_saved`, `routines_projected`, `habits_projected`, `profile_updated`, `completed`), `stagesCompleted` (`Map<String, bool>`), `retryCount`, `lastError`.
  3. Implement `OnboardingCompletionJobService` with idempotent step runners:
     - Stage 1: `PERSIST_DRAFT` -> write `finalDraft`
     - Stage 2: `PERSIST_BUNDLE` -> write `completionBundle`
     - Stage 3: `PROJECT_ROUTINES` -> write routine templates & receipt
     - Stage 4: `PROJECT_HABITS` -> reconcile habit systems
     - Stage 5: `UPDATE_PROFILE` -> write profile patch (`onboardingInputCompleted: true`, `onboardingProjectionStatus: 'completed'`, `onboardingCompleted: true`)
     - Stage 6: `COMPLETE_JOB` -> set job status `completed`

#### Issue 4: Profile Fields & Router Alignment
- **Target Files**: `lib/models/user_profile.dart`, `lib/models/user_model.dart`, `lib/core/router/app_router.dart`, `lib/state/auth_state.dart`
- **Fix Rationale**: Separate form completion from projection status to prevent improper routing.
- **Strategy**:
  1. Add fields to `UserProfile` and `UserModel`:
     - `onboardingInputCompleted`: bool (default `false`)
     - `onboardingProjectionStatus`: String (`'none'`, `'pending'`, `'partial'`, `'completed'`, `'failed'`)
     - `onboardingCompleted`: getter returning `onboardingInputCompleted && onboardingProjectionStatus == 'completed'`
  2. Update `app_router.dart` redirect logic:
     - `if (!profile.onboardingInputCompleted)` -> return `'/onboarding'` (user fills forms)
     - `if (profile.onboardingInputCompleted && profile.onboardingProjectionStatus != 'completed')` -> return `'/onboarding/recovery'` or `'/loading'` (run/resume completion job)
     - `if (profile.onboardingCompleted)` -> return `'/app?tab=0'` (access main app)

#### Issue 5: Recovery Sequence for Missing Bundle/Draft
- **Target Files**: `lib/services/onboarding_completion_service.dart`, `lib/state/auth_state.dart`
- **Fix Rationale**: Reconstruct missing bundle or draft state automatically during auth restore or completion recovery.
- **Strategy**:
  1. Implement `recoverCompletionState(String uid)` in `OnboardingCompletionService`:
     - **Tier 1**: Fetch `completionBundle`. If valid, proceed.
     - **Tier 2 (Draft -> Bundle)**: If `completionBundle` missing, fetch `onboardingDraft`. If found, execute `OnboardingCompletionService.buildBundle(draft)`, persist bundle to Firestore, and continue job.
     - **Tier 3 (Projections -> Bundle)**: If `onboardingDraft` missing, inspect existing `routineItems` and `profile`. Synthesize fallback bundle to restore consistency.
     - **Tier 4 (Form Reset)**: If no artifacts exist, set `onboardingInputCompleted = false` and navigate safely to step 0.

#### Issue 6: Typed Recovery Actions
- **Target Files**: `lib/features/recovery/models/onboarding_recovery_models.dart` (new), `lib/state/auth_state.dart`
- **Fix Rationale**: Provide structured failure reasons and executable recovery actions for the UI layer.
- **Strategy**:
  1. Define `enum OnboardingFailureReason`: `networkTimeout`, `missingBundle`, `missingDraftAndBundle`, `projectionReceiptMismatch`, `habitsProjectionFailed`, `unhandledException`.
  2. Define `abstract class OnboardingRecoveryAction`:
     - `RetryCompletionJobAction`: re-triggers completion job from stored stage.
     - `RebuildBundleFromDraftAction`: executes Tier 2 recovery.
     - `ReprojectHabitsAction`: re-runs Stage 4 habit projection.
     - `RestartOnboardingInputAction`: resets `onboardingInputCompleted = false` and returns to step 0.
  3. Expose `currentFailureReason` and `availableRecoveryActions` on `AuthState` / `OnboardingRecoveryController`.

---

## 5. Verification Method

To verify these architectural changes independently once implemented:

1. **Automated Unit & Integration Tests**:
   - Run `flutter test test/routine_data_contract_phase4_test.dart` to verify re-projection and receipt behavior.
   - Run `flutter test test/onboarding_persistence_phase2b_test.dart` to verify bundle creation and persistence.
   - Run `flutter test test/onboarding_routing_test.dart` to verify router redirection across all 3 profile states (`onboardingInputCompleted`, `onboardingProjectionStatus`, `onboardingCompleted`).
   - Add new test suite `test/onboarding_completion_job_test.dart` to test multi-stage job resumption and recovery sequence.

2. **Manual & Fault-Injection Verification**:
   - Inject network failure before Stage 5 (`UPDATE_PROFILE`) in `OnboardingCompletionJobService`. Verify that `onboardingInputCompleted = true`, `onboardingProjectionStatus = 'pending'`, and router directs user to `/onboarding/recovery`.
   - Trigger `RetryCompletionJobAction` and verify job resumes from Stage 5 without duplicating routine items or corrupting profile fields.
   - Delete `completionBundle` document while keeping `onboardingDraft`. Restart app and verify Tier 2 recovery automatically rebuilds `completionBundle` and completes setup.

3. **Invalidation Conditions**:
   - Any scenario where `completeOnboarding()` returns `noOp` while `users/{uid}/profile/main` lacks `onboardingCompleted: true`.
   - Any scenario where router redirects user with `onboardingInputCompleted = true` to onboarding step 0 without explicit user confirmation of input reset.
   - Any unhandled exception during backend restore that presents a raw error string without typed recovery actions.
