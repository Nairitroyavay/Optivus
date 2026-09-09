# Original User Request

## 2026-07-28T15:00:35Z

# Teamwork Project Prompt — Phase 4.6 Final Production Closure

> Status: Phase 4.6 — Final Production Closure
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Integrity mode: development

Complete a final production stabilization pass on the Optivus Flutter/Firebase application. Identify and fix every remaining production blocker, architectural gap, race condition, security issue, data integrity issue, and release blocker so the app is safe for real-device testing. Do not add new features or redesign working systems.

Working directory: /Users/roy/optivus2/Optivus
Integrity mode: development

## Requirements

### R1. Mandatory Initial Audit
Before modifying any production code:
- Read the onboarding architecture, completion job, authentication flow, routing, recovery, and Firestore rules.
- Read every existing Phase 4.x report under `docs/`.
- Compare reports against the actual production code.
- Ignore every previous PASSED status until independently verified.
- Create `docs/phase_4_6_final_audit.md` with every issue initially marked as NOT VERIFIED.

### R2. Audit Only the Real Production Path
Trace the real production execution path end-to-end:

Signup → Email Verification → Login → Onboarding → Draft Persistence → Completion Bundle → Routine Projection → Routine History Projection → Habit Projection → Controller Reload → Profile Finalization → Router Transition → Home Screen → Cold Restart → Sign Out → Sign In → Recovery

Never audit dead code or unused services. Never rely solely on unit tests.

Identify and resolve every remaining:
- Production blocker, architectural inconsistency, race condition, restart failure, sign-out hazard, account-switch hazard, recovery issue, projection issue, weak validation, security gap, Firestore inconsistency, migration issue, data integrity issue, duplicate logic, dead code, stale async update, release blocker.

Continue auditing until no remaining P0 or P1 production issues exist.

### R3. Production Safety Rules
Every implementation must be: deterministic, resumable, idempotent, owner-scoped, fingerprint verified, schema versioned, restart safe, account-switch safe, network safe, duplicate-action safe, migration safe.

Recovery must never: fabricate data, silently complete onboarding, or bypass validation.

Profile completion may occur only after ALL are verified: Draft persisted, Bundle persisted, Routine verified, History verified, Habit verified, Controller state verified, Frontend state verified.

### R4. Security & Data Integrity
Never weaken Firestore Rules, validation, security, or test coverage.
Never expose email, UID, token, health data, worker payloads, or sensitive user information.

### R5. Evidence-Based Fix Protocol
Always work in this order: Understand → Trace → Reproduce → Find Root Cause → Design Minimal Safe Fix → Review Migration Impact → Implement → Verify → Regression Test → Re-audit → Mark PASS.

Every completed issue must include: root cause, production path, files inspected, files changed, tests added, commands executed, migration impact, remaining risks, PASS/FAIL.

Separate CODE BLOCKERS (logic bugs, race conditions, missing validation) from ENVIRONMENT BLOCKERS (missing Android SDK, signing keys, Firebase credentials). Do not attempt to fix environment limitations in production code.

### R6. Verification & Final Reports
Every production change requires: Targeted Tests → Regression Tests → `flutter analyze` → Firestore Emulator Tests (if backend changes) → Repository Re-audit.

Create `docs/phase_4_6_release_ready.md` with: executive summary, every issue fixed, every issue discovered, production files changed, tests added, Firestore changes, migration impact, remaining technical debt, known limitations, risk assessment, release readiness score.

## Acceptance Criteria

### Automated Verification
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] Firestore Emulator tests pass (if backend changes were made)

### Build Verification
- [ ] Debug build succeeds (`flutter build apk --debug`)
- [ ] Release build succeeds or has a documented environment blocker

### Production Integrity
- [ ] `docs/phase_4_6_final_audit.md` is completed and reflects the actual codebase
- [ ] `docs/phase_4_6_release_ready.md` is completed with all required sections
- [ ] Zero remaining P0 issues
- [ ] Zero remaining P1 issues
- [ ] No known recovery loop exists in production code
- [ ] No duplicate projection exists in production code
- [ ] No stale async update exists in production code
- [ ] No account isolation issue exists in production code
- [ ] No data integrity issue exists in the audited production path

### Stop Conditions
Declare READY FOR REAL-DEVICE TESTING only when ALL of the above are true.
If any condition fails, continue the audit → fix → verify loop.
Remaining P2/P3 issues must be documented as technical debt but do not block testing.

## 2026-07-28T09:59:20Z

# Teamwork Project Prompt — Phase 4.6 Final Production Closure (Resumed)

> Status: Phase 4.6 — Final Production Closure
> Goal: Resume after interruption, complete adversarial review, verification, and final reports.
> Integrity mode: development

The previous teamwork instance completed the audit and remediation phases (Work Packages A-E) but was interrupted before completing the adversarial review, verification, and final reports. Pick up where the previous team left off.

Working directory: /Users/roy/optivus2/Optivus
Integrity mode: development

## Requirements

### R1. Context Recovery
- Review the `docs/phase_4_6_final_audit.md` generated by the previous run.
- Review the modified files from the previous run (e.g., auth state, onboarding services, tests).

### R2. Resume Adversarial Review
Dispatch reviewers, challengers, and a forensic auditor to stress-test the fixes from Work Packages A-E.

### R3. Verification & Final Reports
Every production change requires: Targeted Tests → Regression Tests → `flutter analyze` → Firestore Emulator Tests (if backend changes) → Repository Re-audit.

Create `docs/phase_4_6_release_ready.md` with: executive summary, every issue fixed, every issue discovered, production files changed, tests added, Firestore changes, migration impact, remaining technical debt, known limitations, risk assessment, release readiness score.

## Acceptance Criteria

### Automated Verification
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes with zero failures
- [ ] Firestore Emulator tests pass (if backend changes were made)

### Build Verification
- [ ] Debug build succeeds (`flutter build apk --debug`)
- [ ] Release build succeeds or has a documented environment blocker

### Production Integrity
- [ ] `docs/phase_4_6_final_audit.md` is completed and reflects the actual codebase
- [ ] `docs/phase_4_6_release_ready.md` is completed with all required sections
- [ ] Zero remaining P0 issues
- [ ] Zero remaining P1 issues
- [ ] No known recovery loop exists in production code
- [ ] No duplicate projection exists in production code
- [ ] No stale async update exists in production code
- [ ] No account isolation issue exists in production code
- [ ] No data integrity issue exists in the audited production path

### Stop Conditions
Declare READY FOR REAL-DEVICE TESTING only when ALL of the above are true.
If any condition fails, continue the audit → fix → verify loop.
Remaining P2/P3 issues must be documented as technical debt but do not block testing.

## 2026-07-28T15:32:38Z

You are the Project Orchestrator (teamwork_preview_orchestrator) resuming Phase 4.6 Final Production Closure.

Working directory: /Users/roy/optivus2/Optivus/.agents/orchestrator
Original request: /Users/roy/optivus2/Optivus/.agents/ORIGINAL_REQUEST.md
Audit doc: /Users/roy/optivus2/Optivus/docs/phase_4_6_final_audit.md

Resume where the previous orchestrator left off:
1. Review .agents/orchestrator/plan.md and .agents/orchestrator/progress.md to understand the state. Work Packages A through E are completed.
2. Resume Milestone 3: Dispatch reviewers, challengers, and forensic auditor to stress-test the fixes.
3. Resume Milestone 4: Verification & Final Reports. Ensure `flutter analyze` passes with zero errors, `flutter test` passes with zero failures, build verification succeeds (`flutter build apk --debug`), update `docs/phase_4_6_final_audit.md`, and generate `docs/phase_4_6_release_ready.md`.
4. When all work and verification is completed and all acceptance criteria are met, send your completion claim back to Sentinel.

## 2026-07-28T17:04:51Z

# Teamwork Project Prompt — Optivus Phase 4.6.2 Final Corrective Closure

> Status: Launched
> Project: Optivus Flutter/Firebase
> Working directory: /Users/roy/optivus2/Optivus
> Integrity mode: development
> Scope: Stabilization and pre-device closure only
> Maximum permitted conclusion: READY FOR CONTROLLED REAL-DEVICE TESTING

## Mission

Resolve every remaining P0 and P1 blocker in the existing Optivus production
path.

The team must:

- restore a clean compilable state;
- align production Firebase serializers with Firestore Rules;
- remove unsafe onboarding-recovery behavior;
- complete the persisted onboarding completion state machine;
- guarantee Routine, History and Habit projection integrity;
- prove sign-out and account-switch isolation;
- connect structured failures to production behavior;
- verify Firebase startup behavior;
- produce a correctly configured Android staging release artifact.

Do not add new features.

Do not begin Phase 5.

Do not claim formal real-device testing, production readiness, or public-release
readiness during this task.

## Authoritative Specification

The complete Phase 4.6.2 specification supplied by the user is authoritative
and must be included in full in the delegated task context.

Do not replace it with only this summary.

When this summary conflicts with the detailed specification, follow the stricter
requirement.

The lead agent must confirm that every delegated agent received the relevant
requirements before assigning work.

## Source-of-Truth Order

Use the following priority:

1. Current compilable production code
2. Production serializers
3. Firestore Rules
4. Firestore emulator behavior
5. Automated test results
6. Generated build artifacts
7. Reports and previous PASS labels

Reports must never override contradictory production code.

All existing PASS labels begin as NOT VERIFIED.

## Mandatory Initial Audit

Before modifying production code:

1. Confirm the repository path.
2. Record:

   git branch --show-current
   git rev-parse HEAD
   git status --short
   git diff --stat

3. Read all Phase 4.x reports.
4. Mark outdated or contradictory reports:

   HISTORICAL — NOT AUTHORITATIVE

5. Trace the real production path:

   Application startup
   → Firebase initialization
   → Signup
   → Profile creation
   → Email verification
   → Login
   → Profile and settings restoration
   → Onboarding
   → Final draft persistence
   → Draft read-back verification
   → Completion bundle persistence
   → Bundle verification
   → Routine reconciliation
   → Routine verification
   → Routine History projection
   → Routine History verification
   → Habit reconciliation
   → Habit verification
   → Controller reload
   → Frontend-state verification
   → Profile finalization
   → Router transition
   → Home
   → Cold restart
   → Sign out
   → Sign in
   → Account switch
   → Recovery

6. Compare every production Firestore serializer with its corresponding Rule and
   emulator fixture.
7. Search for unresolved symbols, stale recovery actions, unsafe completion
   assignments, silent catches, raw exception persistence, debug release signing,
   and unused completion-accounting fields.
8. Run the available baseline sequentially:

   flutter pub get
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   Firestore emulator test command
   flutter build apk --debug

9. Create and populate:

   docs/phase_4_6_2_initial_audit.md

Do not edit production code until the initial audit is complete.

## Known Priority Areas

Treat these as NOT VERIFIED until independently tested:

### P0

- Unresolved or deleted recovery-action references.
- Incomplete drafts being force-marked complete.
- Missing drafts producing fabricated completed onboarding.
- Profile serializer and Firestore Rule mismatch.
- Region-localization serializer and Rule mismatch.
- App-preferences serializer and Rule mismatch.
- Completion-job serializer and Rule mismatch.
- Emulator fixtures using test-only field names or enum formats.
- Final draft stage completing before durable write and read-back.
- Profile finalization occurring without verified Draft, Bundle, Routine,
  History, Habit, controller and frontend state.

### P1

- Completion stages being too coarse.
- Completion-accounting fields not populated by production services.
- Structured failure fields existing but raw `e.toString()` still being used.
- Important `catch (_) {}` paths suppressing failures.
- Active completion work surviving sign-out.
- Account A operations modifying Account B local state.
- Mixed Routine creation and repair missing History events.
- Firebase initialization failure being swallowed.
- Release build using debug signing or invalid runtime definitions.
- Release APK/AAB being reported without confirming the artifact exists.

## Required Engineering Properties

Every fix must be:

- deterministic;
- resumable;
- idempotent;
- owner-scoped;
- fingerprint-verified;
- schema-versioned;
- restart-safe;
- account-switch-safe;
- network-safe;
- duplicate-action-safe;
- migration-safe.

Recovery must never fabricate data or silently complete onboarding.

Profile completion must occur last and exactly once.

## Issue Execution Loop

For every issue use:

READ
→ TRACE THE REAL PRODUCTION PATH
→ REPRODUCE
→ IDENTIFY ROOT CAUSE
→ DEFINE THE REQUIRED INVARIANT
→ DESIGN THE MINIMAL SAFE FIX
→ REVIEW MIGRATION AND FIRESTORE IMPACT
→ IMPLEMENT
→ FORMAT
→ ANALYZE
→ RUN TARGETED TESTS
→ RUN RELATED REGRESSION TESTS
→ RUN EMULATOR TESTS WHEN APPLICABLE
→ RE-READ THE CHANGED CODE
→ SEARCH FOR ALTERNATE BROKEN PATHS
→ UPDATE THE AUTHORITATIVE REPORT
→ PASS, BLOCK, OR LOOP AGAIN

Do not proceed while the current issue leaves a broken invariant.

## Teamwork and File Ownership

One lead agent owns:

- architecture decisions;
- the authoritative issue tracker;
- workstream assignment;
- overlapping-file prevention;
- patch review;
- integration testing;
- final verdict.

Parallel work is allowed only for independent areas.

Suggested workstreams:

### Workstream A — Compilation and Recovery

- unresolved symbols;
- stale recovery actions;
- unsafe forced completion;
- recovery-command architecture.

### Workstream B — Firestore Contracts

- profile;
- region localization;
- app preferences;
- onboarding draft;
- completion bundle;
- completion job;
- Routine;
- History;
- Habit;
- Rules and real-schema emulator fixtures.

### Workstream C — Completion and Projection Integrity

- fine-grained completion stages;
- durable draft;
- bundle verification;
- Routine reconciliation;
- complete History coverage;
- Habit verification;
- controller and frontend verification;
- profile finalization.

### Workstream D — Authentication and Async Isolation

- auth-generation tokens;
- sign-out invalidation;
- account switching;
- late provider updates;
- late navigation;
- stale AI results.

### Workstream E — Startup and Android Release

- Firebase initialization;
- Android identity;
- staging runtime configuration;
- release signing;
- debug and configured staging artifacts.

No two agents may modify the same architectural module at the same time.

A subagent may not independently declare an issue complete.

## Prohibited Shortcuts

Do not:

- add features;
- weaken Firestore Rules;
- allow arbitrary maps;
- remove failing tests;
- reduce assertions;
- suppress exceptions to keep onboarding moving;
- replace production integration paths with trivial mocks;
- mark incomplete onboarding complete;
- overwrite user-modified records silently;
- use arbitrary delays for synchronization;
- update providers after authentication ownership changes;
- expose email, UID, tokens, health data or AI payloads;
- commit credentials, signing keys or service-account files;
- use destructive Git commands;
- claim device verification without executing it.

Preserve unrelated local changes.

## Evidence Required for Every Issue

Each issue entry must contain:

- Issue ID
- Severity
- Status
- Production path
- Symptom
- Reproduction
- Root cause
- Required invariant
- Files inspected
- Files changed
- Tests added or changed
- Firestore impact
- Migration impact
- Commands executed
- Exact results
- Remaining risks
- Final verdict

Allowed evidence statuses:

- NOT_VERIFIED
- IN_PROGRESS
- PASS_SOURCE_REVIEWED
- PASS_AUTOMATED_TESTED
- PASS_EMULATOR_VERIFIED
- PASS_BUILD_VERIFIED
- ENVIRONMENT_BLOCKED
- FAIL

Do not use a vague PASS status.

## Acceptance Criteria

### Compilation and Automated Verification

- [ ] Project compiles.
- [ ] `dart format --output=none --set-exit-if-changed .` passes.
- [ ] `flutter analyze` reports no issues.
- [ ] All Flutter tests pass.
- [ ] Firestore emulator tests pass.
- [ ] Emulator fixtures match real production serializers.

### Firebase Contracts

- [ ] Profile writes match Rules.
- [ ] Region-localization writes match Rules.
- [ ] App-preferences writes match Rules.
- [ ] Completion-job writes match Rules.
- [ ] Draft and bundle writes match Rules.
- [ ] Routine, History and Habit writes match Rules.
- [ ] Cross-user access is denied.
- [ ] Immutable ownership changes are denied.
- [ ] Unknown fields are denied.
- [ ] Invalid statuses, stages, schemas and timestamps are denied.

### Recovery and Completion

- [ ] Recovery cannot fabricate completed onboarding.
- [ ] Missing drafts cannot produce completed setup.
- [ ] Incomplete drafts resume instead of completing.
- [ ] Valid completed drafts can rebuild missing bundles.
- [ ] Final draft is durably written and read-back verified.
- [ ] Completion bundle is persisted and verified.
- [ ] Routine expected set is verified.
- [ ] Routine History expected set is verified.
- [ ] Mixed create/repair outcomes receive complete History coverage.
- [ ] Habit expected set is verified.
- [ ] Controllers reload after reconciliation.
- [ ] Frontend-visible IDs are verified.
- [ ] Profile finalization occurs last and exactly once.
- [ ] Completion accounting fields contain real production data.
- [ ] Structured failures are used in blocking production paths.

### Account Isolation

- [ ] Sign-out invalidates active completion operations.
- [ ] Empty authenticated UID invalidates rather than permits late work.
- [ ] Account B receives no Account A local state.
- [ ] Late operations cannot navigate after sign-out.
- [ ] Stale AI results are ignored after source or account changes.

### Startup and Build

- [ ] Firebase initialization fails safely in Firebase mode.
- [ ] Debug APK exists.
- [ ] Configured staging release APK or AAB exists.
- [ ] Artifact path and file size are recorded.
- [ ] Runtime environment, backend mode and upload mode are recorded.
- [ ] Release signing strategy is documented.
- [ ] Fake backend and fake upload mode are not unintentionally used.

### Final Deliverables

- [ ] `docs/phase_4_6_2_initial_audit.md` is current.
- [ ] `docs/phase_4_6_2_execution_report.md` is current.
- [ ] `docs/phase_4_6_2_pre_device_readiness.md` is current.
- [ ] Older reports are labelled historical.
- [ ] All current reports agree.
- [ ] No known P0 issue remains.
- [ ] No known P1 issue remains.
- [ ] P2/P3 debt is documented and does not invalidate controlled device testing.

## Environment Blockers

Clearly distinguish:

### CODE BLOCKER

A source, architecture, contract, security, persistence or test issue that must
be fixed in the repository.

### ENVIRONMENT BLOCKER

Missing SDK, credentials, signing material, Firebase access, emulator support,
network access or physical-device availability.

Do not modify production logic to hide an environment blocker.

Record the exact blocked command, missing dependency and smallest next action.

A required build may only be marked environment-blocked when the team provides
specific evidence.

## Required Reports

Maintain one authoritative status across:

- `docs/phase_4_6_2_initial_audit.md`
- `docs/phase_4_6_2_execution_report.md`
- `docs/phase_4_6_2_pre_device_readiness.md`

The pre-device report must include:

- executive verdict;
- P0 issues discovered and resolved;
- P1 issues discovered and resolved;
- unresolved blockers;
- production files changed;
- tests changed;
- Firestore contracts changed;
- migration strategy;
- recovery result;
- projection-integrity result;
- account-isolation result;
- analyzer result;
- Flutter test result;
- emulator result;
- debug build result;
- configured release build result;
- artifact path and size;
- remaining P2/P3 debt;
- pre-device readiness score out of 100.

## Stop Condition

Declare:

READY FOR CONTROLLED REAL-DEVICE TESTING

only when every acceptance criterion is supported by evidence and no known P0
or P1 blocker remains.

Do not declare:

- formal real-device testing passed;
- production ready;
- public release ready;
- Phase 4 fully complete;
- Phase 5 ready.

When blocked, return:

BLOCKED — NOT READY FOR REAL-DEVICE TESTING

and list:

- every unresolved blocker;
- its severity;
- its production impact;
- the smallest safe next action.

Stop after the pre-device gate is genuinely satisfied.

Do not continue indefinitely with optional P2/P3 refactors.

## 2026-09-09T04:01:22Z

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
