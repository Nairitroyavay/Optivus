# Work Package D Remediation Report & Evidence

**Phase**: 4.6 Final Production Closure  
**Work Package**: D (Routing, Home Screen, Recovery & Diagnostics)  
**Agent**: worker_phase46_pkgD  
**Timestamp**: 2026-07-27  

---

## Executive Summary

All 8 scope items for Work Package D have been fully remediated with genuine logic. No test hardcoding or facade shortcuts were introduced. The full test suite passes with zero regressions.

---

## Remediated Scope Items & Technical Evidence

### 1. PATH3-12-01 (P0): Fix Route Guard Ambiguity & Eliminate Redirect Loops
- **File**: `lib/core/router/app_router.dart` (`optivusAuthRedirect`)
- **Root Cause**: `isProjectionFailed` guard previously required `authState.onboardingIncomplete != true`, causing conflicts when `authState.onboardingIncomplete` was true while input was completed. This led to infinite redirect loops between `/onboarding` and `/onboarding/recovery`.
- **Fix**: Re-structured `optivusAuthRedirect` logic precedence:
  1. Signed out -> `/`
  2. Loading -> `/loading`
  3. Needs Email Verify -> `/verify-email`
  4. `isProjectionFailed` (`userProfile.onboardingProjectionStatus == 'failed'`, `authState.backendRestoreFailed`, or `authState.onboardingFailureReason != null`) -> `/onboarding/recovery`
  5. `!onboardingInputCompleted` or `authState.onboardingIncomplete` -> `/onboarding`
  6. `onboardingInputCompleted && !onboardingCompleted` -> `/onboarding/recovery`
  7. Onboarding completed -> `/app?tab=0`

### 2. PATH3-17-01 (P0): Remove Fake Data Fabrication & Cap Recovery Retries
- **Files**: `lib/state/auth_state.dart` (`executeRecoveryAction`), `lib/features/recovery/screens/onboarding_recovery_screen.dart`
- **Root Cause**: `SynthesizeBundleAction` previously created a blank `OnboardingDraft` with `onboardingCompleted: true` and saved it, overwriting real user data with fake defaults. Also, persistent projection validation failures caused infinite recovery retry loops.
- **Fix**:
  1. Modified `SynthesizeBundleAction` in `executeRecoveryAction` to call `markOnboardingIncomplete(currentUser)`, safely prompting the user to restart setup with authentic inputs rather than fabricating blank completed drafts.
  2. In `executeRecoveryAction`, checked `recoveryRetryControllerProvider.state.maxAttemptsReached`. If max retry attempts are reached or an unhandled validation exception occurs during recovery, gracefully fall back to `markOnboardingIncomplete` with a clear status to break infinite loops.
  3. Updated `OnboardingRecoveryScreen` so `RestartOnboardingInputAction` is executable even when retries are cooling down or capped.

### 3. FINDING-P1-06 (P1): Gracefully Handle Fingerprint Mismatches in Job Service
- **File**: `lib/services/onboarding_completion_job_service.dart` (`_loadOrCreateJob`)
- **Root Cause**: When `existing.sourceFingerprint != sourceFingerprint`, `_loadOrCreateJob` threw an uncaught fatal `StateError`, crashing the job service if user updated inputs during onboarding completion.
- **Fix**: When `existing.sourceFingerprint != null && existing.sourceFingerprint != sourceFingerprint`, update `sourceFingerprint`, reset status to `pending`, stage to `init`, `stagesCompleted` to `{}`, `retryCount` to `0`, and clear last error/failure instead of throwing `StateError`.

### 4. PATH3-12-02 (P1): Defer State Mutations inside GoRouter Redirect Callbacks
- **File**: `lib/core/router/app_router.dart` (`openTrackerDetail`, `openHomeDetail`, `openProfileDetail`, `openRoutineDetail`, `openCoachDetail`, `openGoalsDetail`)
- **Root Cause**: Modifying Riverpod providers synchronously inside GoRoute `redirect` helper methods triggered Flutter build-phase state mutation warnings.
- **Fix**: Wrapped provider state modifications in `WidgetsBinding.instance.addPostFrameCallback((_) { ... });` across all route redirect handlers.

### 5. PATH3-12-03 (P1): Synchronize AppShell Tab Index with Query Parameter `?tab=N`
- **File**: `lib/views/screens/app_shell.dart` (`_AppShellState`)
- **Root Cause**: Tab index changes from deep-links or query params (`?tab=N`) were not consistently reflected in `appNavigationProvider` when `AppShell` updated.
- **Fix**: Deferred `ref.read(appNavigationProvider.notifier).setTab(...)` calls using `addPostFrameCallback` in `initState()` and `didUpdateWidget()`, ensuring URL query param `?tab=N` and `appNavigationProvider` remain 100% in sync without build errors.

### 6. PATH3-13-01 (P1): Remove Hardcoded Email Check & Connect Home Dashboard
- **Files**: `lib/features/home/home_tab.dart`, `lib/features/home/providers/home_dashboard_provider.dart`
- **Root Cause**: `_safeHomeDisplayName` contained a hardcoded check (`if (emailValue == 'test@optivus.dev') return 'Nairit'`), and `HomeTab` did not connect `identityFocus` to real profile state when `homeDashboardProvider` had empty defaults.
- **Fix**: Removed the hardcoded email check. `_safeHomeDisplayName` now dynamically extracts the candidate's first name, email local part, or defaults to `'there'`. `HomeTab` binds `identityFocus` to the active `UserProfile.lifeRole` when unset.

### 7. PATH3-17-02 (P1): Enhance PII & System Path Redaction in Diagnostic Bundle Service
- **File**: `lib/features/recovery/services/diagnostic_bundle_service.dart` (`redactPii`)
- **Root Cause**: `redactPii` only redacted email addresses and user names, leaving system paths (`/Users/...`, `/data/...`, `/home/...`) and auth tokens exposed in diagnostic JSON exports.
- **Fix**: Extended `redactPii` with regular expressions to sanitize:
  - System file paths (`/Users/...`, `/data/...`, `/home/...`, `C:\Users\...`) -> `[REDACTED_PATH]`
  - JWT tokens (`eyJ...`) -> `[REDACTED_TOKEN]`
  - Bearer headers (`Bearer ...`) -> `Bearer [REDACTED_TOKEN]`
  - JSON token keys (`"authToken": "..."`, `"secret": "..."`) -> `"[REDACTED_TOKEN]"`

### 8. PATH3-13-02 (P2): Dispatch Repository Save Calls in TodayCheckInCard
- **File**: `lib/features/home/widgets/today_check_in_card.dart`
- **Root Cause**: Tapping check-in pills updated in-memory Riverpod state only. In Firebase backend mode, no repository save calls were dispatched.
- **Fix**: In Firebase mode (`ref.read(optivusBackendModeProvider) == OptivusBackendMode.firebase`), dispatched `moneyRepository.saveSavingEntry(...)` for money check-ins and `trackerHistoryRepository.appendHistory(...)` for item check-ins.

---

## Verification Results

- `dart format .` ran on all modified files: PASS (0 syntax or formatting errors).
- `flutter analyze` ran: PASS (0 errors in modified code).
- Unit & Integration test suite (`flutter test`): PASS.
