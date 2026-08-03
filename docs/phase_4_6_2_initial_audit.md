# HISTORICAL — NOT AUTHORITATIVE

# Optivus Phase 4.6.2 Mandatory Initial Audit Report

**Project**: Optivus  
**Phase**: Phase 4.6.2 Final Corrective Closure  
**Date**: 2026-07-29  
**Audit Scope**: Production Pipeline (`lib/`), Firestore Security Rules (`firestore.rules`), Emulator Test Fixtures (`tests/`), Build and Verification Infrastructure  
**Audit Verdict**: `INITIAL AUDIT COMPLETE — RELEASE BLOCKED`

---

## 1. Executive Summary & Baseline Verification Results

The Phase 4.6.2 Mandatory Initial Audit was executed to establish an authoritative, un-compromised baseline for Optivus. All prior historical reports in `docs/` have been audited and explicitly marked `HISTORICAL — NOT AUTHORITATIVE`.

### Baseline Verification Snapshot

| Gate / Command | Result | Exit Code | Details / Metrics |
|---|---|---|---|
| `flutter pub get` | **PASS** | 0 | Dependencies resolved successfully. |
| `dart format --output=none --set-exit-if-changed .` | **FAIL** | 1 | 6 files formatted differently (`lib/main.dart`, `lib/services/onboarding_completion_job_service.dart`, `lib/services/routine_onboarding_event_projector.dart`, `lib/features/recovery/models/onboarding_recovery_models.dart`, `test/challenger_p46_m3_2_adversarial_test.dart`, `test/onboarding_step4_timeline_layout_test.dart`). |
| `flutter analyze` | **FAIL** | 1 | **20 analyzer errors** across `lib/` and `test/`. |
| `flutter test` | **FAIL** | 1 | Test suite failed to compile due to analyzer errors in `lib/` and `test/`. |
| Firestore Emulator Tests (`npm test`) | **FAIL** | 1 | Requires active Firestore emulator process (`firebase emulators:exec`). |
| `flutter build apk --debug` | **FAIL** | 1 | Android build failed due to compilation errors in Dart code. |

---

## 2. Git Metadata

- **Current Branch**: `main`
- **Commit Hash**: `cf197c96e43251ed9008b9406eac83a14a3cc7f4`
- **Working Tree State**: Clean baseline with prepended historical headers in `docs/`.

---

## 3. Historical Document Audit

All previous audit and QA reports in `docs/` have been audited. The header `HISTORICAL — NOT AUTHORITATIVE` was prepended to all outdated or superseded reports. All historic `PASS` claims have been reset to `NOT VERIFIED`.

Updated files:
- `docs/phase_4_6_final_audit.md` (Updated with historical header)
- `docs/phase_4_6_release_ready.md` (Updated with historical header)
- `docs/phase_4_6_release_closure_report.md` (Updated with historical header)
- `docs/phase_4_6_1_initial_audit.md` (Updated with historical header)
- `docs/onboarding_release_closure_report.md` (Updated with historical header)
- `docs/onboarding_stabilization_report.md` (Updated with historical header)
- `docs/PHASE_3_QA.md` (Updated with historical header)
- `docs/PHASE_0_CLOSEOUT.md` (Updated with historical header)

---

## 4. Production Execution Path Audit (17-Step Pipeline)

The complete end-to-end user journey across `lib/` was traced:

`Application startup` -> `Firebase initialization` -> `Signup` -> `User-profile creation` -> `Email verification` -> `Login` -> `Profile & settings restoration` -> `Onboarding` -> `Final draft persistence` -> `Draft read-back verification` -> `Completion bundle persistence` -> `Bundle verification` -> `Routine reconciliation` -> `Routine verification` -> `Routine History projection` -> `Routine History verification` -> `Habit reconciliation` -> `Habit verification` -> `Controller reload` -> `Frontend-state verification` -> `Profile finalization` -> `Router transition` -> `Home` -> `Cold restart` -> `Sign out` -> `Sign in` -> `Account switch` -> `Recovery`.

### Detailed Step-by-Step Path Analysis & Broken Links

1. **Application Startup (`lib/main.dart`)**:
   - `WidgetsFlutterBinding.ensureInitialized()` and immersive system UI set up correctly.
   - **Broken Link**: `lib/main.dart` references `OptivusAppEnvironmentConfig.requiresLiveServices`, but `OptivusAppEnvironmentConfig` is not imported, causing an analyzer error (`undefined_identifier`).
   - **Swallowed Failure**: Firebase initialization error in non-live environments is swallowed in `safePlatformCall` without rethrowing, leaving the app running with an uninitialized Firebase instance.

2. **Firebase Initialization & App Bootstrapping**:
   - `OptivusRuntimeConfig.validateForStartup` verifies project ID and URLs.
   - `OptivusApp` initializes Riverpod `ProviderScope` and GoRouter config (`app_router.dart`).

3. **Signup (`lib/views/screens/signup_screen.dart`, `lib/state/auth_state.dart`)**:
   - `AuthNotifier.signup()` invokes `AuthRepository.signUp()`.
   - On success, triggers email verification if required, or loads/creates backend user state.

4. **User Profile Creation**:
   - `_loadOrCreateBackendUserState()` checks if Firestore profile exists; if missing, creates an empty profile with `createdAt`/`updatedAt` and `schemaVersion: 1`.

5. **Email Verification**:
   - Router (`optivusAuthRedirect`) redirects unverified password accounts to `/verify-email`.
   - `checkEmailVerification()` reloads user and checks `emailVerified`.

6. **Login (`lib/views/screens/login_screen.dart`, `lib/state/auth_state.dart`)**:
   - `AuthNotifier.login()` calls `AuthRepository.signIn()`.

7. **Profile & Settings Restoration**:
   - Restores `UserProfile`, `ProfileSettings`, `RegionSettings`, `UserPreferences`.

8. **Onboarding Flow (`lib/features/onboarding/onboarding_flow.dart`)**:
   - Step-by-step form state managed by `mockOnboardingProvider`.

9. **Final Draft Persistence**:
   - Stage 1 (`PERSIST_DRAFT`) in `OnboardingCompletionJobService` writes `finalDraft` to Firestore.

10. **Draft Read-Back Verification**:
    - **Compilation Error**: `OnboardingCompletionJobService` accesses `readbackDraft.schemaVersion` as a static member instance access instead of `OnboardingDraft.schemaVersion` or instance property, causing 2 analyzer errors.

11. **Completion Bundle Persistence**:
    - Stage 2 (`PERSIST_BUNDLE`) creates `OnboardingCompletionBundle` via `OnboardingCompletionService.buildBundle(finalDraft)` and writes to Firestore.

12. **Bundle Read-Back Verification**:
    - **Compilation Error**: `OnboardingCompletionJobService` accesses `readbackBundle.schemaVersion` as static member instance access instead of `OnboardingCompletionBundle.schemaVersion`, causing 2 analyzer errors.

13. **Routine Reconciliation & Verification**:
    - Stage 3 (`PROJECT_ROUTINES`) executes `completeOnboarding` in `RoutineRepository`. Records expected, applied, existing, repaired, and failed routine template IDs.

14. **Routine History Projection & Verification**:
    - `RoutineOnboardingEventProjector` commits event batches. Validates receipt status and cursor against plan fingerprint.

15. **Habit Reconciliation & Verification**:
    - Stage 4 (`PROJECT_HABITS`) calls `OnboardingFrontendHydrationService.hydrate()`.
    - **Accounting Gap**: `expectedHistoryIds`, `appliedHistoryIds`, `failedHistoryIds` in `OnboardingCompletionJob` are never populated during routine history projection, leaving history accounting empty (`[]`).

16. **Profile Finalization**:
    - Stage 5 (`UPDATE_PROFILE`) verifies receipt and actual items, then updates user profile in Firestore batch or repository write (`onboardingCompleted: true`).

17. **Router Transition, Home & Account Switch**:
    - `optivusAuthRedirect` moves to `/app?tab=0`.
    - Account switch correctly calls `_resetSignedOutState(targetUserUid: user.uid)`.
    - **Broken Link in Recovery**: Recovery actions reference `SynthesizeBundleAction`, which is missing from `onboarding_recovery_models.dart`. `AuthNotifier` is also missing imports for `onboardingCompletionJobServiceProvider` and `onboardingCompletionJobProvider`.
    - **Unsafe Recovery Behavior**: In `auth_state.dart`, `RebuildBundleFromDraftAction` force-marks incomplete drafts as completed (`onboardingCompleted: true`, `currentStep: lastStepIndex`) without checking if required step fields are populated.
    - **Static State Leakage**: `OnboardingCompletionJobService._inFlight` static map is not invalidated on sign-out.

---

## 5. Firestore Serializer vs Security Rules vs Test Fixture Audit

Every production model serializer was compared against `firestore.rules` and `tests/firestore_rules.test.js`:

| Serializer / Model | Firestore Security Rule Match | Emulator Fixture Match | Identified Discrepancies / Gaps |
|---|---|---|---|
| `UserProfile.toFirestoreMap()` | **MATCH** (`validUserProfileKeys`) | **MATCH** (`userData`) | Serializer correctly includes `schemaVersion: 1` and all 28 allowed keys. |
| `RegionSettings.toFirestoreMap()` | **MATCH** (`validSettingsDoc`) | **MATCH** | 19 keys match `validSettingsDoc`. |
| `UserPreferences.toFirestoreMap()` | **MATCH** (`validProfileSubdoc`) | **MATCH** | Fields match rules. |
| `OnboardingDraft.toFirestoreMap()` | **MATCH** (`validOnboardingDraftKeys`) | **MATCH** | All 25 keys match rules. |
| `OnboardingCompletionBundle.toFirestoreMap()` | **MATCH** (`validOnboardingCompletionBundleKeys`) | **MATCH** | 20 keys match rules. |
| `OnboardingCompletionJob.toMap()` | **MATCH** (`validOnboardingCompletionJob`) | **MATCH** (`onboardingJobData`) | `lastFailureOccurredAt` outputs ISO string; rules accept timestamp or string. |
| `RoutineItem.toFirestoreMap()` | **MATCH** (`validRoutineTemplateKeys`) | **MATCH** (`routineItemData`) | All 35 keys match rules. |
| `RoutineOccurrence.toFirestoreMap()` | **MATCH** (`validRoutineOccurrence`) | **MATCH** (`occurrenceData`) | Fields match rules. |
| `RoutineEventRecord.toFirestoreMap()` | **MATCH** (`validRoutineEvent`) | **MATCH** (`eventData`) | Fields match rules. |
| `RoutineProjectionReceipt.toFirestoreMap()` | **MATCH** (`validRoutineProjectionReceipt`) | **MATCH** (`projectionData`) | Receipt status transition enforced by `validRoutineProjectionTransition`. |
| `HabitSystem.toFirestoreMap()` | **MATCH** (`validHabitSystem`) | **MATCH** (`habitSystemData`) | Strict version increment rule (`resource.data.version + 1`) enforced. |

---

## 6. Deep Code Analysis (P0/P1 Findings)

### P0-01: Analyzer & Compilation Blockers (20 Errors)
1. `lib/main.dart:52:13`: `OptivusAppEnvironmentConfig` is an undefined identifier due to a missing import.
2. `lib/services/onboarding_completion_job_service.dart:133:56`, `133:84`: Invalid static member access `readbackDraft.schemaVersion`.
3. `lib/services/onboarding_completion_job_service.dart:154:58`, `154:82`: Invalid static member access `readbackBundle.schemaVersion`.
4. `lib/state/auth_state.dart:754:15`, `772:17`: `SynthesizeBundleAction` is referenced as a class constructor, but `SynthesizeBundleAction` is deleted or missing from `onboarding_recovery_models.dart`.
5. `lib/state/auth_state.dart:1046:21`, `1047:21`: `onboardingCompletionJobServiceProvider` and `onboardingCompletionJobProvider` are undefined due to missing import of `onboarding_completion_job_service.dart`.
6. `test/challenger_p46_m3_2_adversarial_test.dart:52:50`: `SynthesizeBundleAction` isn't a class.
7. `test/group_h_adversarial_stress_test.dart:106:61`: `tier3Synthesized` isn't in `OnboardingRecoveryTier`.
8. `test/group_h_adversarial_stress_test.dart:237:44`: `SynthesizeBundleAction` isn't a class.
9. `test/group_h_issues_33_to_42_test.dart:96:52`: `SynthesizeBundleAction` isn't a class.
10. `test/group_k_issues_63_to_68_test.dart:1027:43`: `tier3Synthesized` isn't in `OnboardingRecoveryTier`.
11. `test/onboarding_completion_group_a_test.dart:425:59`: `tier3Synthesized` isn't in `OnboardingRecoveryTier`.
12. `test/work_package_c_remediation_test.dart:393:59`: `tier3Synthesized` isn't in `OnboardingRecoveryTier`.

### P0-02: Missing Recovery Action Definition (`SynthesizeBundleAction`)
- In `auth_state.dart` (lines 754 & 772), `SynthesizeBundleAction()` is thrown in recovery exceptions, but `SynthesizeBundleAction` is missing from `lib/features/recovery/models/onboarding_recovery_models.dart`.

### P0-03: Force-Marking Incomplete Drafts Complete in Recovery
- In `AuthNotifier.executeRecoveryAction(RebuildBundleFromDraftAction)` (`lib/state/auth_state.dart`:1103), an incomplete draft (`onboardingCompleted: false`) is forcibly overwritten with `onboardingCompleted: true` and `currentStep: OnboardingDraft.lastStepIndex` without checking if mandatory onboarding inputs are present.

### P1-01: Empty Accounting Fields in Completion Job
- `OnboardingCompletionJobService._runCompletionJob` fails to populate `expectedHistoryIds`, `appliedHistoryIds`, and `failedHistoryIds` during Stage 3/4. They remain empty `[]`, creating incomplete audit trails for routine history events.

### P1-02: Raw Exception Strings Persisted in Jobs
- `OnboardingCompletionJobService` writes raw `e.toString()` into `job.lastError` instead of structured, sanitized diagnostic failure objects.

### P1-03: Error Suppression via `catch (_) {}`
- Multiple places (`_loadOrCreateBackendUserState`, `executeRecoveryAction`, `_saveJobStatus`) swallow underlying exceptions with generic `catch (_) {}`, hiding root-cause failures during restoration.

### P1-04: Static `_inFlight` Map Leaks Across Sessions
- `OnboardingCompletionJobService._inFlight` static map is not cleared on sign-out, allowing in-flight completion jobs to leak across account switches.

---

## 7. Actionable Remediation Instructions for Lead Orchestrator

1. **Fix Analyzer Errors**:
   - Add missing imports in `lib/main.dart` and `lib/state/auth_state.dart`.
   - Correct static access (`OnboardingDraft.schemaVersion` and `OnboardingCompletionBundle.schemaVersion`) in `lib/services/onboarding_completion_job_service.dart`.
   - Restore or cleanly remove `SynthesizeBundleAction` and `tier3Synthesized` references across `lib/` and `test/`.
2. **Harden Recovery Logic**:
   - Ensure `RebuildBundleFromDraftAction` validates draft completeness before attempting bundle reconstruction.
3. **Populate Job Accounting Fields**:
   - Ensure `expectedHistoryIds`, `appliedHistoryIds`, and `failedHistoryIds` are recorded in `OnboardingCompletionJob`.
4. **Clear In-Flight Cache**:
   - Add a `resetForSignedOut()` method to `OnboardingCompletionJobService` to clear `_inFlight`.
5. **Verify Baseline Gates**:
   - Re-run `dart format`, `flutter analyze`, `flutter test`, Firestore emulator tests, and `flutter build apk --debug` to confirm 100% PASS status.

---

*Report compiled by worker_phase462_initial_audit_2 for Optivus Phase 4.6.2 Final Corrective Closure.*
