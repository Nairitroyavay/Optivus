## 2026-09-09T04:02:56Z

You are the PROJECT ORCHESTRATOR for Optivus Gate 5 fourth and final closure.

Working directory: /Users/avayroy/Optivus/.agents/orchestrator_gate5_1
Project workspace root: /Users/avayroy/Optivus
Original user request log: /Users/avayroy/Optivus/.agents/ORIGINAL_REQUEST.md

You must maintain your persistent working memory in BRIEFING.md and your progress in progress.md inside your working directory (/Users/avayroy/Optivus/.agents/orchestrator_gate5_1).

Here is the authoritative user prompt for this project:

# Teamwork Project Prompt

Optivus Gate 5 fourth and final closure: unify structured Auth/session errors under `RecoverableError`, complete and document an exhaustive session provider reset inventory to close TD-039, implement real Account A→B pending async race tests against the Auth reconstruction pipeline, and verify all Gate 1–5 regression suites.

Working directory: /Users/avayroy/Optivus
Integrity mode: development

======================================================================
0. MANDATORY CURRENT-SOURCE AUDIT BEFORE DELEGATION OR EDITING
======================================================================

DO NOT divide implementation work between agents before this audit is complete.

Read completely:

AGENTS.md
docs/OPTIVUS_STRICT_TASK_RULES.md
docs/ARCHITECTURE.md
docs/TECHNICAL_DEBT.md

Current Gate 1–4 verification reports:
- docs/verification/GATE_1_COMPLETION_REPORT.md
- docs/verification/GATE_2_EATING_REPORT.md
- docs/verification/GATE_3_SKIN_CARE_REPORT.md
- docs/verification/GATE_4_ONBOARDING_FOUNDATION_REPORT.md
- docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md

AUTH:
- lib/state/auth_state.dart
- lib/state/auth_flow_status.dart
- lib/state/auth_generation.dart
- lib/repositories/auth_repository.dart

ERRORS:
- lib/core/errors/recoverable_error.dart
- lib/core/errors/auth_error_mapper.dart
- lib/core/errors/reconstruction_error_mapper.dart
- lib/core/errors/completion_error_mapper.dart
- lib/core/errors/diagnostic_codes.dart

VERIFY EMAIL:
- lib/state/verification_lifecycle_state.dart
- lib/views/screens/verify_email_screen.dart
- lib/views/screens/login_screen.dart
- lib/views/screens/signup_screen.dart

SESSION DESTINATION / ROUTING:
- lib/services/session_destination_resolver.dart
- lib/core/router/app_router.dart

RECONSTRUCTION:
- lib/services/server_reconstructor.dart
- lib/services/onboarding_frontend_hydration_service.dart

SESSION RESET:
- lib/services/auth_session_reset_coordinator.dart

USER-STATE OWNERS:
- lib/state/app_state.dart
- lib/state/region_settings_provider.dart
- lib/state/upload_state.dart
- lib/state/routine_import_ai_state.dart
- lib/features/onboarding/**
- lib/features/uploads/**
- lib/features/home/providers/**
- lib/features/tracker/providers/**
- lib/features/tracker/fitness/providers/**
- lib/features/profile/providers/**
- lib/features/routine/**
- lib/features/coach/providers/**
- lib/features/goals/providers/**

Read every provider referenced by AuthSessionResetCoordinator.
Read all current Gate-5/Auth/session tests.

Repository-wide search:
- mockUserProfileProvider
- mockOnboardingProvider
- backendRestoreFailed
- AuthFlowStatus
- SessionDestination
- resolveAuthSessionDestination
- resolveOnboardingSessionDestination
- statusFor(
- VerificationLifecycleState
- VerificationMessageKind
- messageKind
- showAccountError
- RecoverableError
- AuthErrorMapper
- resetForSignedOut
- resetIdentityBoundary
- prepareForAuthoritativeHydration
- authGenerationProvider
- _authOperationGeneration
- _backendRestoreGeneration
- Provider<
- StateProvider<
- StateNotifierProvider<
- NotifierProvider<
- AsyncNotifierProvider<
- FutureProvider<
- StreamProvider<

Before ANY edit, output:

AREA | CURRENT AUTHORITY | CURRENT MUTABLE STATE | UID/SESSION SCOPE | RESET/FENCE MECHANISM | CURRENT DEFECT | SMALLEST FIX | TEST THAT MUST FAIL BEFORE FIX

Only after this table is complete may implementation begin.

======================================================================
REQUIREMENTS
======================================================================

### R1. Provider & Field Cleanup Freezes
- Confirm 0 active `lib/` occurrences of `mockUserProfileProvider` and `mockOnboardingProvider` (must use `userProfileProvider` and `onboardingStateProvider`).
- Confirm 0 active production `lib/` occurrences of `backendRestoreFailed` (failed reconstruction remains typed through `ServerReconstructionResult` + `RecoverableError` + `SessionDestinationResolver`).
- Preserve `RouterNotifier` listening exclusively to `authProvider` with 0 direct dependencies on `userProfileProvider`, `onboardingStateProvider`, completion providers, or reconstruction providers.

### R2. Canonical Session Destination Authority & AuthNotifier.statusFor()
- Maintain `lib/services/session_destination_resolver.dart` as the sole authority deciding all session destinations (`resolving`, `signedOut`, `verifyEmail`, `freshOnboarding`, `resumeOnboarding`, `finishOnboarding`, `home`, `reconnect`, `needsAction`).
- AuthNotifier.statusFor() clarification:
  - `SessionDestinationResolver` remains the ONLY destination policy.
  - `AuthNotifier.statusFor()` may classify credential-level `AuthFlowStatus` facts: null user, email verification requirement, onboarding-complete boolean.
  - It must NOT decide: `freshOnboarding`, `resumeOnboarding`, `finishOnboarding`, `home`, `reconnect`, `needsAction`.
  - Do not rename `statusFor()` merely for churn. Rename to `credentialFallbackStatus` only if the current source remains genuinely ambiguous after documentation and tests.
  - Invariant: Behavioral authority matters more than the symbol name; `app_router.dart` consumes `AuthState.sessionDestination`.

### R3. Exact Verify Email State Contract & Structured Error Authority
- Target `VerificationLifecycleState` failure/presentation shape:
  ```dart
  RecoverableError? error;
  String? successMessage;
  ```
- Keep operational state independently:
  - `foreground`, `checking`, `resendInFlight`, `verificationConfirmed`
  - `nextResendAllowedAt`, `nextVerificationCheckAllowedAt`
  - `resendSecondsRemaining`, `verificationThrottleStreak`, `resendThrottleStreak`
- DELETE the parallel failure taxonomy completely:
  - `VerificationMessageKind`
  - `String? message`
  - `VerificationMessageKind? messageKind`
- `copyWith` must support independent `clearError` and `clearSuccessMessage`.
- Failure flow:
  - catch error → `AuthErrorMapper` → `RecoverableError` → `state.error`
- Success flow:
  - successful resend → `successMessage`
- Rate limit flow:
  - remains represented by `RecoverableError` + `next...AllowedAt` + throttle streaks (operational policy, NOT another failure taxonomy).
- UI renders `state.error?.publicMessage` and separately `state.successMessage`. No feature-level switch may recreate `network`, `rateLimited`, `firebaseFailure` as a second enum.
- Remove `showAccountError(String message)` and replace with a typed API (`showAccountError(RecoverableError error)` or consume `ref.read(authProvider).error` directly).
- Replace hard-coded Verify Email logout failure string (`Couldn't sign out. Please try again.`) with the typed `AuthState.error` published by `AuthNotifier.logout()`.
- Ensure `AuthErrorMapper` is the canonical failure mapper.
- Retain form validation / success presentation strings in Login/Signup, but enforce `RecoverableError` as the source domain authority for operation failures.
- Fix Gate-5 report error matrix to reflect actual current enum values in `RecoverableError` and `AuthErrorMapper` (no nonexistent categories or actions).

### R4. Centralized Session Reset & Tightened Provider Inventory
- Preserve `AuthSessionResetCoordinator` as the synchronous privacy boundary for `null → A`, `A → B`, and `logout` (`resetIdentityBoundary`), and projection clearing (`prepareForAuthoritativeHydration`).
- Do NOT make the coordinator forcibly reset everything mechanically. Every mutable state owner must receive exactly ONE classification:
  - `USER_SCOPED_RESET`
  - `USER_SCOPED_UID_KEYED`
  - `USER_SCOPED_AUTO_DISPOSE`
  - `USER_SCOPED_GENERATION_FENCED`
  - `SESSION_UI_RESET`
  - `GLOBAL_CONFIG`
  - `DERIVED`
  - `REPOSITORY_UID_SCOPED`
  - `NOT_USER_SCOPED`
- For every `USER_SCOPED` provider answer with source evidence:
  1. Can Account A data live in this owner?
  2. What happens synchronously when A → B?
  3. Can an Account-A async callback complete after B?
  4. What prevents that callback writing into B?
  5. Does logout clear it?
  6. Does same-UID token refresh preserve it?
- Note: `autoDispose` alone does not count if an app-wide listener can keep the provider alive. Generation fencing requires proof that old results cannot apply AND old visible state cannot survive into B. UID-keying requires that B cannot read A's key. Repository UID scoping requires that all reads/writes require explicit authenticated UID.
- Explicitly audit and classify: `skinCareFlowControllerProvider`, `step7ActionBridgeProvider`, `onboardingStep7PrimaryActionProvider`, `verificationLifecycleProvider`, `onboardingCompletionJobServiceProvider`, `onboardingCompletionJobProvider`, `onboardingUploadInteractionProvider`, `routineImportAiControllerProvider`, `uploadControllerProvider`, `restoredUploadsProvider`, `regionSettingsProvider`, `homeDashboardProvider`, `fitnessCenterProvider`, `trackerSettingsProvider`, `trackerSessionLinksProvider`, `profileSettingsProvider`, all six detail-view request providers, and UID-sensitive repository providers.
- Ensure 0 unclassified mutable user/session providers remain.
- Reconcile `docs/TECHNICAL_DEBT.md` (TD-039 status) and `docs/ARCHITECTURE.md` with source evidence to eliminate documentation contradictions.

### R5. Real Auth Reconstruction Race & Async Isolation Tests
The decisive Account A → B race test must use the actual Auth startup / reconstruction pipeline. Do NOT satisfy this requirement only by delaying Routine Import AI or a UI operation.
Create a controlled reconstruction source using `ServerReconstructionSource` or controlled repositories behind `serverReconstructorProvider` using `Completer` objects.

- TEST A — A reconstruction completes after B:
  1. Start `AuthNotifier`.
  2. Emit authenticated Account A.
  3. A's `ServerReconstructionSource.load(A)` begins.
  4. DO NOT complete A's Future.
  5. Seed/observe clearly identifiable A state where appropriate.
  6. Emit authenticated Account B.
  7. Assert synchronous identity boundary has already cleared A before B is published/usable.
  8. Begin B reconstruction.
  9. Complete B reconstruction with B-owned profile, onboarding draft, completion state.
  10. Wait until B reaches its final `SessionDestination`.
  11. ONLY NOW complete A's old reconstruction Future.
  12. Pump the event queue.
  - Assert:
    - `AuthState.user.uid == B`
    - `AuthState.sessionDestination` belongs to B
    - `authGeneration` belongs to current boundary
    - `userProfileProvider.uid == B`
    - `onboardingStateProvider.draft.uid == B`
    - routine, habit, upload, region, home, fitness states contain NO Account A data
    - no A error becomes `AuthState.error`
    - no A `reconstructionResult` becomes active
    - no A route/destination becomes active

- TEST B — A reconstruction completes after sign-out:
  1. A reconstruction starts and is pending.
  2. Sign out succeeds.
  3. Synchronous reset occurs.
  4. `AuthState == signedOut`.
  5. Complete old A Future.
  6. Pump queue.
  - Assert: still `signedOut`, no A state returns, no A error published, no destination changes.

- TEST C — Failed logout preserves Account A:
  1. Account A fully hydrated.
  2. `signOut` repository throws typed/mappable failure.
  - Assert: A remains current, no identity reset occurs, `authGeneration` unchanged, A state remains, `AuthState.error` is `RecoverableError`. Verify Verify Email renders this same typed failure.

- TEST D — Same UID refresh:
  1. Emit updated `AuthUser` with same UID.
  - Assert: no privacy reset, no `authGeneration` increment, no `appNavigation` reset, no reconstruction restart, current projections remain intact.

### R6. Static Architecture Enforcement Test
Static test must verify known architectural invariants without banning valid Riverpod patterns globally:
- 0 active `lib/` uses of `mockUserProfileProvider`
- 0 active `lib/` uses of `mockOnboardingProvider`
- 0 active `lib/` uses of `backendRestoreFailed`
- `RouterNotifier` only listens to `authProvider`
- Router redirect reads `AuthState.sessionDestination` and does NOT choose destination from profile/onboarding/completion providers
- Verify Email:
  - 0 `VerificationMessageKind`
  - 0 `messageKind`
  - 0 failure `String? message` authority
  - 0 `showAccountError(String ...)`
  - 0 hard-coded logout-failure override
- Auth identity reset delegates through `AuthSessionResetCoordinator`
- Session inventory: every provider listed in Gate-5 inventory has one valid classification.

### R7. Scope Constraints & Freezes
- DO NOT redesign Auth UX or replace `AuthNotifier` / Riverpod.
- DO NOT rewrite `SessionDestinationResolver` or redesign Onboarding.
- DO NOT modify Step 4/5/7 UX or Step 14 completion behavior.
- DO NOT touch Firestore rules/schema, Workers, or R2.
- DO NOT upgrade packages, Gradle, AGP, Kotlin, or Flutter.
- DO NOT begin Routine product development.

======================================================================
ACCEPTANCE CRITERIA
======================================================================

### Formatting Acceptance (Avoid Scope Expansion)
- [ ] Every Dart file CHANGED by Gate 5 must pass `dart format`:
  `dart format --output=none --set-exit-if-changed <Gate-5 changed Dart files>`
- [ ] Run repo-wide format check as an audit:
  `dart format --output=none --set-exit-if-changed .`
  - If pre-existing unrelated formatting debt exists, record it separately.
  - DO NOT mass-format unrelated files.
  - Report:
    - GATE-5 CHANGED FILES FORMAT: PASS / FAIL
    - REPOSITORY-WIDE FORMAT: PASS / PRE-EXISTING BASELINE / FAIL CAUSED BY GATE 5

### Static Architecture & Code Quality
- [ ] `flutter analyze` passes with 0 errors and 0 warnings on Gate-5 files/codebase.
- [ ] Static architecture test passes verifying all R6 invariants.

### Gate-5 Focused Tests
- [ ] `test/gate5_auth_session_isolation_test.dart`
- [ ] `test/ah_f004_auth_identity_isolation_test.dart`
- [ ] `test/ah_f003_google_auth_test.dart`
- [ ] `test/workstream_d_auth_async_isolation_test.dart`
- [ ] `test/onboarding_session_destination_test.dart`
- [ ] `test/onboarding_routing_test.dart`
- [ ] `test/onboarding_restore_test.dart`
- [ ] `test/verify_email_redesign_test.dart`
- [ ] `test/ah_f020_recoverable_error_model_test.dart`
- [ ] `test/ah_f011_no_production_mock_leakage_test.dart`
- [ ] `test/routine_phase4_4_ownership_test.dart`
- [ ] New real reconstruction race tests (Test A, B, C, D) pass.

### Cross-Gate Regressions
- [ ] Gate 1 regressions pass:
  - `test/ah_f013_completion_terminalization_test.dart`
  - `test/ah_f014_step14_idempotency_test.dart`
  - `test/ah_f021_step14_final_review_test.dart`
  - `test/onboarding_completion_bundle_test.dart`
  - `test/onboarding_completion_retry_contract_test.dart`
- [ ] Gate 2 regressions pass:
  - `test/nutrition_target_service_test.dart`
  - `test/onboarding_eating_weekly_plan_test.dart`
  - `test/onboarding_step5_eating_ai_flow_test.dart`
  - `test/onboarding_step5_regeneration_test.dart`
  - `test/onboarding_step5_generated_no_fake_fallback_test.dart`
  - `test/onboarding_step5_save_test.dart`
- [ ] Gate 3 regressions pass:
  - `test/onboarding_step7_skin_care_test.dart`
  - `test/onboarding_step7_transaction_test.dart`
  - `test/onboarding_step7_state_machine_test.dart`
  - `test/onboarding_step7_cta_navigation_test.dart`
  - `test/onboarding_step7_full_timeline_regression_test.dart`
  - `test/onboarding_step7_pending_photo_generation_test.dart`
  - `test/onboarding_step7_runtime_ui_stability_test.dart`
- [ ] Gate 4 regressions pass:
  - `test/onboarding_step_layout_migration_test.dart`
  - `test/onboarding_persistence_phase2b_test.dart`
  - `test/onboarding_restore_test.dart`
  - `test/onboarding_routing_test.dart`
  - `test/onboarding_session_destination_test.dart`
  - `test/ah_f012_onboarding_resume_monotonicity_test.dart`
  - `test/onboarding_foundation_final_pass_test.dart`

### Full Suite Run
- [ ] Full suite run: `flutter test --reporter compact`. Gate-5 changes introduce zero failures. If any pre-existing unrelated failure exists, classify it explicitly without repairing an unrelated feature inside Gate 5.

### Deliverables & Report
- [ ] Pre-editing audit table completed before code edits.
- [ ] Fully verified session-state inventory matrix with 0 unclassified user/session owners and source evidence for each.
- [ ] Error authority matrix showing typed domain failure authority across all Auth flows.
- [ ] Updated `docs/verification/GATE_5_AUTH_CLEANUP_REPORT.md` containing exact current commit/source, correct gate labels, current `RecoverableError` matrix, test counts, and TD-039 status.
- [ ] Reconciled `docs/TECHNICAL_DEBT.md` and `docs/ARCHITECTURE.md`.
- [ ] Final verdict: `GATE 5 PASSED`.
