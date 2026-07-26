# Handoff Report — Group B: Routine Projection & History Correctness (Issues 7–11)

**Agent**: `explorer_group_b_1`  
**Working Directory**: `/Users/roy/optivus2/Optivus/.agents/explorer_group_b_1`  
**Target Scope**: Group B (Issues 7, 8, 9, 10, 11)  
**Date**: 2026-07-25  

---

## 1. Observation

### Key Codebase Files Inspected
1. `lib/models/routine_projection_receipt.dart`
2. `lib/models/routine_item.dart`
3. `lib/repositories/routine_firestore_codec.dart`
4. `lib/repositories/routine_repository.dart`
5. `lib/repositories/onboarding_repository.dart`
6. `lib/services/routine_onboarding_projection.dart`
7. `lib/services/routine_onboarding_event_projector.dart`
8. `lib/services/onboarding_completion_service.dart`
9. `lib/services/onboarding_completion_job_service.dart`
10. `lib/services/onboarding_frontend_hydration_service.dart`
11. `lib/state/auth_state.dart`
12. `lib/features/onboarding/onboarding_flow.dart`

---

### Verbatim Code Observations by Issue

#### Issue 7: Receipt validation against expected items
- **`lib/services/routine_onboarding_event_projector.dart` (lines 38-45)**:
  ```dart
  final receipt = await read(
    routineRepositoryProvider,
  ).fetchProjectionReceipt(bundle.uid, plan.projectionId);
  if (receipt == null ||
      receipt.ownerUid != bundle.uid ||
      receipt.sourceBundleFingerprint != plan.fingerprint) {
    return RoutineOnboardingEventProjectionResult(
      projectionId: plan.projectionId,
      attemptedCount: 0,
    );
  }
  ```
- **`lib/state/auth_state.dart` (lines 548-559)**:
  ```dart
  final receipt = await _ref
      .read(routineRepositoryProvider)
      .fetchProjectionReceipt(user.uid, plan.projectionId);
  if (!_isCurrentRestore(restoreGeneration)) return;
  if (receipt == null ||
      receipt.sourceBundleFingerprint != plan.fingerprint) {
    throw const _RoutineProjectionRestoreException(
      'Routine setup recovery is required because its projection '
      'receipt is missing or does not match.',
      ...
    );
  }
  ```
- **Observation**:
  Validation currently checks only string equality on `sourceBundleFingerprint` and non-null `receipt`. It does NOT validate:
  1. Document existence for each expected routine item ID.
  2. Matching owner UID (`item.userId == ownerUid`).
  3. Source ID (`item.onboardingSourceItemId` matches expected source key and `item.source == RoutineSource.onboarding`).
  4. Projection slot (`item.onboardingProjectionId == receipt.slot`).
  5. Schema version compatibility (`receipt.schemaVersion == RoutineProjectionReceipt.currentSchemaVersion` & `item.schemaVersion == RoutineItem.currentSchemaVersion`).
  6. Active vs archived/deleted state of referenced routine items.

#### Issue 8: Receipt storing all item categories
- **`lib/models/routine_projection_receipt.dart` (lines 15, 37, 86)**:
  ```dart
  final List<String> projectedItemIds;
  ```
- **`lib/repositories/onboarding_repository.dart` (lines 94-95, 287-298)**:
  ```dart
  RoutineProjectionReceipt _receiptForCreatedItems(
    RoutineProjectionReceipt receipt,
    List<String> createdItemIds,
  ) {
    return RoutineProjectionReceipt(
      id: receipt.id,
      ownerUid: receipt.ownerUid,
      ...
      projectedItemIds: createdItemIds.toSet().toList(growable: false)..sort(),
      ...
    );
  }
  ```
- **`lib/repositories/routine_firestore_codec.dart` (lines 388, 412-413)**:
  ```dart
  'projectedItemIds': receipt.projectedItemIds,
  ```
- **Observation**:
  `RoutineProjectionReceipt` currently has a single `projectedItemIds` list containing only newly created item IDs. It lacks storage and tracking for:
  1. `expectedItemIds` (all items expected by projection plan).
  2. `createdItemIds` (newly created routine item IDs).
  3. `existingItemIds` (pre-existing routine item IDs found in store).
  4. `repairedItemIds` (existing routine items that were repaired/updated).
  5. `failedItemIds` (routine items that failed creation/write).

#### Issue 9: Intermediate account state preventing `pending` receipt coexistence with completed profile
- **`lib/repositories/onboarding_repository.dart` (lines 247-251, 264-270)**:
  ```dart
  transaction.set(
    _firestore.doc(FirestoreUserPaths.profile(bundle.uid)),
    bundle.userProfilePatch,
    SetOptions(merge: true),
  );
  ...
  final receipt = _receiptForCreatedItems(plan.receipt, createdItemIds);
  final receiptData = _receiptCodec.toFirestore(receipt);
  ...
  transaction.set(receiptReference, receiptData);
  ```
- **`lib/services/onboarding_completion_service.dart` (lines 393-395)**:
  ```dart
  'onboardingInputCompleted': true,
  'onboardingProjectionStatus': 'completed',
  'onboardingCompleted': true,
  ```
- **`lib/state/auth_state.dart` (lines 569-581)**:
  ```dart
  if (projectedReceipt == null ||
      projectedReceipt.status != 'completed' ||
      projectedReceipt.sourceBundleFingerprint != plan.fingerprint) {
    throw const _RoutineProjectionRestoreException(
      'Routine setup recovery is required because History projection '
      'did not complete.',
      reason: OnboardingFailureReason.habitsProjectionFailed,
      ...
    );
  }
  ```
- **Observation**:
  `completeOnboarding()` writes `userProfilePatch` directly inside the transaction, setting `onboardingCompleted: true` AND `onboardingProjectionStatus: 'completed'`. At the same time, the receipt is created with `status: 'pending'`. If the app crashes or network drops before event projection finishes, the user profile claims onboarding is completed, but the receipt status is `pending`. Upon app re-launch, `auth_state.dart` detects `profile.onboardingCompleted == true` but `receipt.status == 'pending'`, throwing `_RoutineProjectionRestoreException` and locking the user into `backendRestoreFailed`.

#### Issue 10: History projector typed failures
- **`lib/services/routine_onboarding_event_projector.dart` (lines 38-51)**:
  ```dart
  final receipt = await read(
    routineRepositoryProvider,
  ).fetchProjectionReceipt(bundle.uid, plan.projectionId);
  if (receipt == null ||
      receipt.ownerUid != bundle.uid ||
      receipt.sourceBundleFingerprint != plan.fingerprint) {
    return RoutineOnboardingEventProjectionResult(
      projectionId: plan.projectionId,
      attemptedCount: 0,
    );
  }
  if (receipt.status == 'completed') {
    return RoutineOnboardingEventProjectionResult(
      projectionId: plan.projectionId,
      attemptedCount: 0,
    );
  }
  ```
- **Observation**:
  When `receipt == null`, `ownerUid` mismatches, or `fingerprint` mismatches, `projectCreatedEvents()` silently returns `RoutineOnboardingEventProjectionResult(projectionId: ..., attemptedCount: 0)`. It does not throw typed exceptions or return explicit failure statuses (`receiptMissing`, `ownerMismatch`, `fingerprintMismatch`, `invalidStatus`, `invalidCursor`, `malformedReceipt`). Callers treat this silent no-op as success even though no events were projected and receipt status remains `pending`.

#### Issue 11: History completion verification before Home navigation
- **`lib/features/onboarding/onboarding_flow.dart` (lines 327-363)**:
  ```dart
  try {
    await ref
        .read(onboardingRepositoryProvider)
        .completeOnboarding(finalDraft: finalDraft, bundle: bundle);
    await const OnboardingFrontendHydrationService().hydrate(
      read: ref.read,
      bundle: bundle,
    );
  } catch (_) { ... }
  ...
  final authUser = ref.read(authProvider).user;
  if (authUser != null) {
    await ref.read(authProvider.notifier).markOnboardingComplete(authUser);
  }

  if (mounted) {
    context.go('/app?tab=0');
  }
  ```
- **Observation**:
  `_completeOnboarding()` in `onboarding_flow.dart` calls `hydrate()`, marks onboarding complete, and immediately navigates to `/app?tab=0`. It NEVER fetches or verifies the projection receipt from Firestore to confirm that `receipt.status == 'completed'`, `receipt.cursor == receipt.totalCount`, and `receipt.sourceBundleFingerprint == plan.fingerprint` before completing onboarding and navigating to Home.

---

## 2. Logic Chain

### Issue 7: Receipt Validation Against Expected Items
1. **Observation**: `RoutineOnboardingEventProjector` and `AuthNotifier` check only `receipt.sourceBundleFingerprint == plan.fingerprint` and non-null receipt.
2. **Step**: Fingerprint verification alone checks bundle metadata hash, but does NOT inspect the physical database state of projected routine items.
3. **Step**: If a routine item document is missing, corrupted, transferred to another user, assigned to wrong projection slot, schema-mismatched, or soft-deleted/archived, fingerprint check still evaluates to true.
4. **Conclusion**: Receipt validation must execute a deep validation step (`RoutineProjectionReceiptValidator`) checking expected item IDs, document existence, owner UID, source ID, projection slot, fingerprint matching, schema version, and archived state.

### Issue 8: Receipt Storing All Item Categories
1. **Observation**: `RoutineProjectionReceipt` has only `projectedItemIds`, populated with `createdItemIds` during `completeOnboarding()`.
2. **Step**: When onboarding completion is run idempotently, existing items in the database are not in `createdItemIds`.
3. **Step**: Without explicit tracking of `expectedItemIds`, `createdItemIds`, `existingItemIds`, `repairedItemIds`, and `failedItemIds`, callers cannot audit which items were skipped vs created vs repaired vs failed.
4. **Conclusion**: `RoutineProjectionReceipt` model and its Firestore codec must be expanded to store all 5 item categories (`expectedItemIds`, `createdItemIds`, `existingItemIds`, `repairedItemIds`, `failedItemIds`), maintaining `projectedItemIds` as a computed getter for backward compatibility.

### Issue 9: Intermediate Account State & Pending Coexistence
1. **Observation**: `completeOnboarding()` writes `userProfilePatch` with `onboardingCompleted: true` and `onboardingProjectionStatus: 'completed'`, but writes receipt with `status: 'pending'`.
2. **Step**: Event projection happens asynchronously after `completeOnboarding()` returns.
3. **Step**: If the app process terminates before event projection finishes, the database is left in a state where `profile.onboardingCompleted == true` while `receipt.status == 'pending'`.
4. **Step**: On next startup, `auth_state.dart` checks `profile.onboardingCompleted == true` and throws a fatal restore exception when `receipt.status != 'completed'`.
5. **Conclusion**: Profile update during `completeOnboarding()` must set an intermediate state (`onboardingInputCompleted: true`, `onboardingProjectionStatus: 'pending'`, `onboardingCompleted: false`). Full completion (`onboardingCompleted: true`, `onboardingProjectionStatus: 'completed'`) must ONLY be set after receipt status transitions to `'completed'`.

### Issue 10: History Projector Typed Failures
1. **Observation**: `projectCreatedEvents()` returns `attemptedCount: 0` for missing receipt, owner mismatch, fingerprint mismatch, or completed status.
2. **Step**: `attemptedCount: 0` is ambiguous — it disguises error conditions as benign no-ops.
3. **Step**: Callers are unable to trigger recovery actions or surface diagnostics when a failure occurs.
4. **Conclusion**: `RoutineOnboardingEventProjector` must throw typed exceptions (`RoutineProjectionFailureException` with reasons: `receiptMissing`, `ownerMismatch`, `fingerprintMismatch`, `invalidStatus`, `invalidCursor`, `malformedReceipt`) rather than returning a silent no-op.

### Issue 11: History Completion Verification Before Navigation
1. **Observation**: `onboarding_flow.dart` calls `hydrate()` and immediately executes `context.go('/app?tab=0')`.
2. **Step**: No receipt lookup is performed post-hydration to verify `receipt.status == 'completed'` and `receipt.cursor == receipt.totalCount`.
3. **Step**: If history projection failed or remained `pending`, the UI still navigates to Home, resulting in missing event history and session crash on re-launch.
4. **Conclusion**: `_completeOnboarding()` must explicitly fetch and verify the receipt status before calling `markOnboardingComplete()` and executing Home navigation.

---

## 3. Caveats

1. **Read-only Investigation**: No files in `lib/` or `test/` were modified during this investigation. Implementation must be performed by an implementer agent.
2. **Firestore Transactions**: In Firebase mode, transactions require read-before-write ordering. Receipt verification must adhere to Firestore transaction rules.
3. **Backward Compatibility**: Existing Firestore receipt documents in production only contain `projectedItemIds`. Codecs must fallback gracefully when `expectedItemIds`, `createdItemIds`, etc., are absent in existing documents.

---

## 4. Conclusion & Concrete Fix Strategy

### Issue 7 Fix Strategy: Receipt Validation Against Expected Items
- Create `RoutineProjectionReceiptValidator` with method:
  `ReceiptValidationResult validate(RoutineProjectionReceipt receipt, List<RoutineItem> actualItems, OnboardingCompletionBundle bundle, RoutineOnboardingProjectionPlan plan)`
- Check list equality on `expectedItemIds`, document existence, `item.userId == bundle.uid`, `item.onboardingSourceItemId == expectedSourceKey`, `item.onboardingProjectionId == plan.projectionId`, `receipt.sourceBundleFingerprint == plan.fingerprint`, schema version matching, and `!item.isArchived`.
- Call this validator in `RoutineOnboardingEventProjector`, `AuthNotifier`, and `OnboardingCompletionJobService`.

### Issue 8 Fix Strategy: Receipt Storing All Item Categories
- Update `RoutineProjectionReceipt` in `lib/models/routine_projection_receipt.dart`:
  - Add fields: `expectedItemIds`, `createdItemIds`, `existingItemIds`, `repairedItemIds`, `failedItemIds`.
  - Provide `List<String> get projectedItemIds => [...createdItemIds, ...existingItemIds, ...repairedItemIds];` (or retain field with fallback constructor logic).
- Update `RoutineProjectionReceiptFirestoreCodec` in `lib/repositories/routine_firestore_codec.dart`:
  - Serialize all 5 fields in `toFirestore()`.
  - In `fromFirestore()`, default missing array fields to `projectedItemIds` or empty lists.
- Update `completeOnboarding()` in `onboarding_repository.dart`:
  - Populate `expectedItemIds` from `plan.items`.
  - Inspect `itemSnapshots`: populate `createdItemIds`, `existingItemIds`, `repairedItemIds`, `failedItemIds`.

### Issue 9 Fix Strategy: Intermediate Account State
- Modify `userProfilePatch` in `lib/services/onboarding_completion_service.dart` and `FirestoreOnboardingRepository.completeOnboarding()`:
  - Set `onboardingInputCompleted: true`.
  - Set `onboardingProjectionStatus: 'pending'`.
  - Set `onboardingCompleted: false`.
- Update `OnboardingCompletionJobService` and `AuthNotifier.markOnboardingComplete()`:
  - Transition profile to `onboardingCompleted: true` and `onboardingProjectionStatus: 'completed'` ONLY after `receipt.status == 'completed'`.

### Issue 10 Fix Strategy: History Projector Typed Failures
- Define `RoutineProjectionFailureReason` enum:
  `receiptMissing, ownerMismatch, fingerprintMismatch, invalidStatus, invalidCursor, malformedReceipt, retryRequired`.
- Define `RoutineProjectionFailureException` implementing `Exception`.
- Update `RoutineOnboardingEventProjector.projectCreatedEvents()`:
  - If receipt is null -> throw `RoutineProjectionFailureException(receiptMissing)`
  - If ownerUid mismatches -> throw `RoutineProjectionFailureException(ownerMismatch)`
  - If fingerprint mismatches -> throw `RoutineProjectionFailureException(fingerprintMismatch)`
  - If status is invalid -> throw `RoutineProjectionFailureException(invalidStatus)`
  - If cursor is out of bounds -> throw `RoutineProjectionFailureException(invalidCursor)`
  - Return `alreadyCompleted: true` result ONLY when `receipt.status == 'completed'` and fingerprint/cursor are valid.

### Issue 11 Fix Strategy: History Completion Verification Before Navigation
- Update `_completeOnboarding()` in `lib/features/onboarding/onboarding_flow.dart`:
  - After calling `hydrate()`, perform receipt verification:
    ```dart
    final verificationReceipt = await ref
        .read(routineRepositoryProvider)
        .fetchProjectionReceipt(uid, plan.projectionId);
    if (verificationReceipt == null ||
        verificationReceipt.status != 'completed' ||
        verificationReceipt.cursor != verificationReceipt.totalCount ||
        verificationReceipt.sourceBundleFingerprint != plan.fingerprint) {
      ref.read(mockOnboardingProvider.notifier).setValidationMessage(
        'History event projection failed to complete. Please tap Finish to retry.',
      );
      return;
    }
    ```
  - Only after verification succeeds, call `markOnboardingComplete()` and `context.go('/app?tab=0')`.

---

## 5. Verification Method

### Automated Tests to Run / Add
1. **Receipt Validation Test**:
   - `flutter test test/routine_validation_service_test.dart`
   - Add test verifying that receipt validation fails if an item is missing, owner UID mismatches, source ID mismatches, projection slot mismatches, schema version mismatches, or item is archived.
2. **Receipt Category Storage Test**:
   - `flutter test test/routine_onboarding_event_outbox_test.dart`
   - Add test asserting that `receipt.expectedItemIds`, `receipt.createdItemIds`, `receipt.existingItemIds`, `receipt.repairedItemIds`, and `receipt.failedItemIds` are correctly populated and serialized via Firestore codec.
3. **Intermediate Account State Test**:
   - `flutter test test/onboarding_completion_group_a_test.dart`
   - Add test verifying profile has `onboardingCompleted == false` and `onboardingProjectionStatus == 'pending'` when receipt is pending, and `onboardingCompleted == true` only when receipt is completed.
4. **Typed Projector Failures Test**:
   - `flutter test test/routine_onboarding_event_outbox_test.dart`
   - Add tests expecting `RoutineProjectionFailureException` with specific failure reasons (`receiptMissing`, `ownerMismatch`, `fingerprintMismatch`, `invalidStatus`, `invalidCursor`).
5. **Home Navigation Verification Test**:
   - `flutter test test/onboarding_routing_test.dart`
   - Add test verifying that onboarding flow blocks Home navigation when receipt status remains `pending`.

### Verification Commands
- `flutter analyze`
- `flutter test test/routine_onboarding_event_outbox_test.dart`
- `flutter test test/onboarding_completion_group_a_test.dart`
- `flutter test test/onboarding_routing_test.dart`

---
*Report compiled by explorer_group_b_1*
