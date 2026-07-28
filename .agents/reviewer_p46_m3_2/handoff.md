# Handoff Report — Independent Safety & Architecture Audit (reviewer_p46_m3_2)

## 1. Observation

A full, independent safety and architecture audit was conducted on the production codebase and test suite across Work Packages A through E for **Phase 4.6 Final Production Closure**.

### Direct Tool Invocations & Verbatim Results:

1. **Static Analysis (`flutter analyze`)**:
   - `lib/` directory: `Analyzing Optivus... No issues found! (ran in 2.6s)`
   - Repository-wide test files: 2 unused import warnings in `test/challenger_p46_m3_2_adversarial_test.dart` (`unused_import` at lines 4:8 and 10:8).

2. **Firestore Security Rules Tests (`firebase emulators:exec "npm test"`)**:
   - Result: `PASS tests/firestore_rules.test.js (6.799 s)`, 27/27 tests passed.

3. **Automated Test Suite (`flutter test`)**:
   - Total tests executed: 853 tests.
   - Result: 851 passed, **2 failed**.
   - Verbatim failing test outputs:
     - `Failing test 1`: `/Users/roy/optivus2/Optivus/test/work_package_b_remediation_test.dart: Work Package B Remediation Tests ISSUE-06-02: validateStep(14) and buildBundle reject un-persisted sub-steps`
       - Error: `Expected: not null, Actual: <null>` at `test/work_package_b_remediation_test.dart:92:9`.
     - `Failing test 2`: `/Users/roy/optivus2/Optivus/test/onboarding_persistence_phase2b_test.dart: no-products face photo is persisted as a face-photo reference`
       - Error: `Bad state: Select at least one recommended product before building your routine.` at `lib/services/onboarding_completion_service.dart:124:9`.

4. **Line-by-Line Code Inspection**:
   - `lib/state/auth_state.dart`: Verified sign-out state purge in `logout()` `finally` block (lines 322-327), account-switch status sequencing `status = AuthFlowStatus.loadingBackendUser` before `_resetSignedOutState` (lines 535-558), and exception handling during `signup` keeping `createdUser` (lines 205-230).
   - `lib/services/onboarding_completion_job_service.dart`: Verified Stage 5 atomic batch write for profile update & job status update (lines 243-260), fingerprint reset on fingerprint mismatch (lines 319-330), and multi-stage execution pipeline.
   - `lib/services/onboarding_frontend_hydration_service.dart`: Verified removal of premature `mockUserProfileProvider.notifier.completeOnboarding()` call.
   - `lib/core/router/app_router.dart`: Verified non-overlapping redirect logic in `optivusAuthRedirect` (lines 35-103) and `addPostFrameCallback` deferment for side-effect navigation state mutations (lines 108-156).
   - `firestore.rules`: Verified replacement of `{document=**}` wildcard subcollection rules with explicit schema validation (`validSimpleTracker`, `validHabitTemplate`, `validBadHabitCheckin`, `validMoneyEntry`, `validHealthLog`, `validHomeDashboard`, `validSettingsDoc`, `validNotificationPreferences`, `validCoachPreferences`, `validProfileSubdoc`) and owner check `verifiedOwner(uid)`.

---

## 2. Logic Chain

1. **Safety Rules (R3/R4) Audit**:
   - **Deterministic**: Document ID generation uses `duplicate:$count` derived per semantic key signature rather than array indices, ensuring deterministic, idempotent routine document IDs across retries (`RoutineOnboardingProjection.build`).
   - **Resumable**: Completion jobs support stage-by-stage progression (`persistDraft` -> `persistBundle` -> `projectRoutines` -> `projectHabits` -> `updateProfile` -> `completeJob`) and resume cleanly from persistent storage on retry (`OnboardingCompletionJobService`).
   - **Idempotent**: Re-running completion job stages or re-attempting onboarding completion produces identical Firestore documents and side effects without duplicating items or events.
   - **Owner-scoped**: All Firestore paths incorporate user UID (`/users/{uid}/...`), and rules enforce `request.auth.uid == uid`. In code, operations are guarded by `ownerUid`.
   - **Fingerprint verified**: Bundle fingerprint (`plan.fingerprint`) is verified against saved completion job, projection receipt, and event projector state before proceeding.
   - **Schema versioned**: Profile, draft, bundle, habit systems, and completion job models carry explicit `schemaVersion` fields (validated by code and Firestore rules).
   - **Restart safe**: Cold restarts fetch draft/bundle/profile safely, handle missing/corrupted data via structured recovery exceptions without unhandled crashes or state wipes.
   - **Account-switch safe**: Switching accounts triggers `_resetSignedOutState` and sets status `loadingBackendUser` before resetting profile state, preventing cross-account data leaks or transient empty profile UI state.
   - **Network safe**: Debounced draft saves return a `Future` completing when network write completes and buffer per UID (`_pendingDraftsByUid`); retry controllers handle network errors gracefully without trapping users.

2. **Recovery Safety Audit**:
   - Recovery actions (`RestartOnboardingInputAction`, `RebuildBundleFromDraftAction`, `RetryCompletionJobAction`, `ForceResyncProjectionsAction`) never fabricate data.
   - `SynthesizeBundleAction` and `RestartOnboardingInputAction` reset user state to `markOnboardingIncomplete` rather than generating fake completed profiles.
   - Onboarding completion is NEVER silently forced without running the validation pipeline.

3. **Profile Completion Safety Audit**:
   - Profile completion (`onboardingCompleted: true`) occurs in Firestore ONLY inside `OnboardingCompletionJobService` Stage 5 (UPDATE_PROFILE) after:
     - Draft persisted
     - Bundle persisted
     - Routine projection receipt verified (status == 'completed', cursor == totalCount, fingerprint match)
     - History event projection completed
     - Habit systems reconciled and verified persisted/visible
     - Controller state verified
     - Frontend hydration completed
   - In-memory Riverpod `mockUserProfileProvider.notifier.completeOnboarding()` is invoked ONLY after Stage 5 atomic batch commit succeeds.

4. **Forensic Integrity Audit**:
   - No hardcoded test results or expected outputs embedded in source code.
   - No dummy or facade implementations bypassing real logic.
   - No shortcuts bypassing the intended task.
   - All fixes across Work Packages A-E use genuine application and database logic.

5. **Test Failure Root Cause Analysis**:
   - `validateStep(14)` in `lib/models/onboarding_draft.dart` lines 319-327 only checks `buildFinalPreview()` and does not invoke `baseTimeline.validateSkinCareSetup()` or `baseTimeline.validateEatingSetup()`. Thus, `invalidDraft.validateStep(14, completedSteps)` returns `null` instead of rejecting invalid sub-steps.
   - In `lib/models/onboarding_draft.dart` lines 1826-1828, `validateSkinCareSetup()` unconditionally returns `'Select at least one recommended product before building your routine.'` when `skinCareSetupPath == 'no_products'` and `skinCareSuggestedProducts` is empty. This throws a `StateError` during `buildBundle` for valid `no_products` drafts where products are directly configured in routine blocks.

---

## 3. Caveats

- Operating in `CODE_ONLY` network mode — no external network requests were performed.
- Firebase Emulator tests for security rules were verified using `tests/firestore_rules.test.js`.
- Minor unused import warnings in `test/challenger_p46_m3_2_adversarial_test.dart` do not affect production code in `lib/` (which passed static analysis with 0 issues).

---

## 4. Conclusion

### **Verdict**: **REQUEST_CHANGES**

#### **Critical/Major Findings**:
1. **[Major] Finding 1: Unpersisted Sub-Step Validation Bypass in `validateStep(14)`**:
   - **What**: `OnboardingDraft.validateStep(14)` in `lib/models/onboarding_draft.dart` does not check `baseTimeline.validateSkinCareSetup()` or `baseTimeline.validateEatingSetup()`.
   - **Where**: `lib/models/onboarding_draft.dart:319-327`
   - **Why**: Step 14 is the final preview step before completing onboarding. Failing to validate sub-steps allows users with invalid/unpersisted sub-steps to pass step 14 validation.
   - **Impact**: Causes `test/work_package_b_remediation_test.dart` ("ISSUE-06-02: validateStep(14) and buildBundle reject un-persisted sub-steps") to fail.
   - **Suggestion**: In `validateStep(14)`, add explicit checks:
     ```dart
     if (baseTimeline.skinCareSetupPath != null) {
       final skinCareErr = baseTimeline.validateSkinCareSetup();
       if (skinCareErr != null) return skinCareErr;
     }
     if (baseTimeline.eatingSetupPath != null ||
         baseTimeline.eatingMode != null ||
         baseTimeline.shouldPlanMeals != null) {
       final eatingErr = baseTimeline.validateEatingSetup();
       if (eatingErr != null) return eatingErr;
     }
     ```

2. **[Major] Finding 2: Overly Restrictive `validateSkinCareSetup()` Guard Breaks `no_products` Bundle Building**:
   - **What**: In `lib/models/onboarding_draft.dart` lines 1826-1828, `validateSkinCareSetup()` rejects `no_products` setups if `skinCareSuggestedProducts` is empty.
   - **Where**: `lib/models/onboarding_draft.dart:1823-1833`
   - **Why**: For `no_products` setups, routine blocks may exist without populating `skinCareSuggestedProducts`. Unconditionally requiring `skinCareSuggestedProducts.isNotEmpty` blocks valid bundle generation.
   - **Impact**: Causes `test/onboarding_persistence_phase2b_test.dart` ("no-products face photo is persisted as a face-photo reference") to throw `Bad state: Select at least one recommended product before building your routine.` during `buildBundle`.
   - **Suggestion**: Update `validateSkinCareSetup()` for `no_products` path:
     ```dart
     if (skinCareSetupPath == 'no_products') {
       if (skinCareProductPhotoR2Key?.trim().isNotEmpty != true) {
         return 'Add a face photo to personalize your product recommendations.';
       }
       final desired = _normalizeSkinCareDesiredApplicationsPerDay(
         skinCareDesiredApplicationsPerDay,
       );
       return _missingSkinCareRoutineMessage(desired);
     }
     ```

---

## 5. Verification Method

To independently verify:
1. Run static analysis:
   ```bash
   flutter analyze
   ```
2. Run unit & widget test suite:
   ```bash
   flutter test test/work_package_b_remediation_test.dart test/onboarding_persistence_phase2b_test.dart
   flutter test
   ```
3. Run Firestore rules emulator test suite:
   ```bash
   JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home PATH=/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home/bin:$PATH firebase emulators:exec "npm test"
   ```
