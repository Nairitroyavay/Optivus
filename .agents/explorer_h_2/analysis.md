# Deep-Dive Technical Analysis: Group H (Issues 37, 39, 41, 42) — Recovery-Screen UI & State Repair

## Executive Summary

This report delivers a deep-dive investigation into four critical issues in Group H (Recovery-Screen UI & State Repair) within the Optivus Flutter application:
- **Issue 37**: Local storage cache clearing without loss of unpushed user edits.
- **Issue 39**: Recovery action retry rate limiting and exponential backoff.
- **Issue 41**: Diagnostic bundle generation for user support export (with PII sanitization).
- **Issue 42**: Partial failure status banner rendering on recovery dashboard.

Our examination of `lib/features/recovery/`, `lib/state/auth_state.dart`, `lib/services/onboarding_completion_job_service.dart`, `lib/models/onboarding_draft.dart`, `lib/models/onboarding_completion_job.dart`, and `lib/repositories/` reveals that while the baseline recovery models (`OnboardingRecoveryAction`, `OnboardingFailureReason`) and router lock mechanism are present, key recovery infrastructure—including dirty edit protection during cache purges, retry backoff calculation, diagnostic log bundle generation with PII scrubbing, and partial failure banner rendering—is currently missing or incomplete.

---

## 1. Detailed Investigation: Issue 37 (Local Storage Cache Clearing without Loss of Unpushed User Edits)

### 1.1 Context & Problem Statement
During recovery or state repair, clearing local storage caches (e.g., cached routine items, stale receipts, or profile settings copies) is often required to resolve inconsistency. However, if a user has unpushed local edits (such as an `OnboardingDraft` where `stepDirty` contains `true` values or pending offline modifications), an indiscriminate local cache wipe permanently destroys user data.

### 1.2 Current Codebase State & Observations
- **`AuthNotifier._resetSignedOutState`** (`lib/state/auth_state.dart:879-911`):
  Wipes all local Riverpod provider states and user-scoped mock data (`routineNotifierProvider`, `habitSystemsNotifierProvider`, `mockUserProfileProvider`, `mockOnboardingProvider`, etc.) unconditionally upon reset/sign-out.
- **`OnboardingDraft`** (`lib/models/onboarding_draft.dart:8-12`):
  Tracks per-step dirty state via `final List<bool> stepDirty`. If any index in `stepDirty` is `true`, the draft contains unsaved/unpushed local edits.
- **Missing Infrastructure**:
  There is currently no `RecoveryCacheManager` or cache clearing service that differentiates re-fetchable clean cache from unpushed dirty edits prior to purging local storage.

### 1.3 Proposed Architecture & Implementation
Create `RecoveryCacheManager` in `lib/features/recovery/services/recovery_cache_manager.dart`:
1. **Dirty Check (`hasUnpushedEdits`)**:
   Inspect `OnboardingDraft.stepDirty.any((dirty) => dirty)` and pending local mutations.
2. **Preservation Backup (`preserveUnpushedEdits`)**:
   Serialize unpushed `OnboardingDraft` or dirty user state into a protected local backup key (`unpushed_draft_backup_<uid>`).
3. **Selective Cache Purge (`clearCleanCache`)**:
   Purge re-fetchable caches (cached receipts, projected routine items, read-only profile copies).
4. **Re-hydration (`restoreUnpushedEdits`)**:
   Re-apply saved dirty draft state to Riverpod providers post-clearance.

```dart
// Proposed pseudo-code snippet for RecoveryCacheManager
class RecoveryCacheManager {
  Future<CacheClearResult> clearCachePreservingEdits({
    required String uid,
    required Ref ref,
  }) async {
    final draft = ref.read(mockOnboardingProvider).draft;
    final isDirty = draft.stepDirty.any((dirty) => dirty);
    
    OnboardingDraft? backedUpDraft;
    if (isDirty) {
      backedUpDraft = draft;
      await _secureStorage.write('unpushed_draft_$uid', draft.toMap());
    }
    
    // Purge clean/re-fetchable caches
    ref.read(routineNotifierProvider.notifier).resetForSignedOut();
    ref.read(habitSystemsNotifierProvider.notifier).resetForSignedOut();
    
    if (backedUpDraft != null) {
      ref.read(mockOnboardingProvider.notifier).loadSeedData(backedUpDraft);
    }
    return CacheClearResult(preservedEdits: isDirty);
  }
}
```

---

## 2. Detailed Investigation: Issue 39 (Recovery Action Retry Rate Limiting & Exponential Backoff)

### 2.1 Context & Problem Statement
When background setup restore or onboarding projection fails, users are presented with a "Retry Setup" button on `OnboardingRecoveryScreen`. Without rate limiting and exponential backoff, rapid button tapping triggers repeated network requests, overloading backend services, hitting Firestore quota limits, and causing cascading failure loops.

### 2.2 Current Codebase State & Observations
- **`OnboardingRecoveryScreen`** (`lib/features/recovery/screens/onboarding_recovery_screen.dart:49-68`):
  Directly executes `ref.read(authProvider.notifier).retryBackendRestore()` or `executeRecoveryAction(action)` on button tap without delay, cooldown state, or throttle checks.
- **`AuthNotifier.retryBackendRestore`** (`lib/state/auth_state.dart:334-352`):
  Immediately calls `_loadOrCreateBackendUserState(user)` without checking retry counts or cooldown timers.
- **Missing Infrastructure**:
  No exponential backoff formula, retry attempt counter, cooldown timer, or disabled UI state exists for recovery actions.

### 2.3 Proposed Architecture & Policy
Implement `RecoveryRetryController` in `lib/features/recovery/controllers/recovery_retry_controller.dart`:
- **Policy Configuration**:
  - `baseDelay`: 2.0 seconds
  - `backoffMultiplier`: 2.0
  - `maxDelayCap`: 60.0 seconds
  - `maxAttempts`: 5 retries (after 5 failures, button directs user to alternative recovery action, e.g. `RebuildBundleFromDraftAction`).
- **Exponential Backoff Formula**:
  $$\text{delay} = \min(\text{baseDelay} \times 2^{\text{attempt} - 1}, \text{maxDelayCap})$$
  *(Attempt 1: 2s, Attempt 2: 4s, Attempt 3: 8s, Attempt 4: 16s, Attempt 5: 32s)*.
- **State Properties**:
  - `retryAttemptCount`: Number of failed retries.
  - `cooldownSecondsRemaining`: Countdown integer for UI display.
  - `isRateLimited`: `bool` indicating active cooldown period.
  - `canRetry`: `!isRateLimited && retryAttemptCount < maxAttempts`.
- **UI Integration**:
  Disable retry buttons when `isRateLimited` is true, displaying text such as `"Retry available in 4s"`.

---

## 3. Detailed Investigation: Issue 41 (Diagnostic Bundle Generation for User Support Export)

### 3.1 Context & Problem Statement
When state repair fails repeatedly, users require a mechanism to export diagnostic data to submit to support. The exported bundle must collect complete system diagnostic information (logs, job status, projection receipts, failure reasons) while strictly preventing Personally Identifiable Information (PII) leakage.

### 3.2 Current Codebase State & Observations
- **No Diagnostic Bundle Infrastructure**:
  Searching the codebase for `diagnostic` returned 0 matches in `lib/`.
- **Current Error Display**:
  `OnboardingRecoveryScreen` only displays a generic error message string and the `OnboardingFailureReason` enum name.

### 3.3 Proposed Architecture & PII Sanitization Policy
Implement `DiagnosticBundle` model and `DiagnosticBundleService` in `lib/features/recovery/services/diagnostic_bundle_service.dart`:
1. **Bundle Composition**:
   - `timestamp`: ISO-8601 creation timestamp.
   - `systemMetadata`: App version, build number, OS platform, backend mode (`firebase` / `fake`).
   - `failureDetails`: `OnboardingFailureReason`, error message string, stage where failure occurred.
   - `jobState`: `OnboardingCompletionJob` state (`status`, `stage`, `stagesCompleted`, `retryCount`, `lastError`).
   - `projectionReceiptState`: `RoutineProjectionReceipt` details (`id`, `status`, `expectedCount`, `createdCount`, `cursor`, `sourceBundleFingerprint`).
   - `recentLogs`: List of diagnostic event strings.
2. **PII Sanitization Rules**:
   - **Email Scrubbing**: Regex `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` -> replace with `[REDACTED_EMAIL]`.
   - **Name Scrubbing**: Omit or replace user display names, bio, and personal draft texts with `[REDACTED_NAME]`.
   - **UID Sanitization**: Truncate or hash UID (e.g. `usr_***a1b2`).
   - **Passwords & Tokens**: Excluded entirely.
3. **Export Functionality**:
   - `toFormattedJson()` for copying to clipboard or exporting as a file string.
   - Add "Export Diagnostics" button on `OnboardingRecoveryScreen`.

---

## 4. Detailed Investigation: Issue 42 (Partial Failure Status Banner Rendering on Recovery Dashboard)

### 4.1 Context & Problem Statement
Onboarding setup execution progresses through 5 discrete stages in `OnboardingCompletionJobService` (`lib/services/onboarding_completion_job_service.dart:51-170`):
1. `persistDraft`
2. `persistBundle`
3. `projectRoutines`
4. `projectHabits`
5. `updateProfile`

When a failure occurs midway through execution (e.g. `persistDraft` and `persistBundle` succeed, but `projectRoutines` fails or is `pending` with `cursor < totalCount`), the system is in a **Partial Failure / Pending State**. Currently, the recovery screen displays a generic error card without showing stage progress or highlighting which specific stage failed.

### 4.2 Current Codebase State & Observations
- **`onboarding_recovery_screen.dart`**:
  Displays only a simple icon, title, error text, reason chip, and action buttons.
- **`OnboardingCompletionJob.stagesCompleted`** (`lib/models/onboarding_completion_job.dart`):
  Stores a map of completed stages (e.g. `{"persistDraft": true, "persistBundle": true}`).
- **Missing Infrastructure**:
  No visual step progress banner or partial failure dashboard component exists to inform the user of completed vs failed setup stages.

### 4.3 Proposed Architecture & UI Design
Implement `PartialFailureStatusBanner` in `lib/features/recovery/widgets/partial_failure_status_banner.dart`:
- **Header Card**:
  - Title: `"Partial Setup Progress — Action Required"`
  - Subtitle: `"Stages 1-2 completed successfully. Stage 3 (Routine Projection) requires retry."`
- **Visual Stage Progress Tracker**:
  - Render 5 step indicators representing the completion stages.
  - Step Status Badges:
    - Completed: Green check icon + step label.
    - Failed / Interrupted: Amber alert icon + error details.
    - Pending: Gray dot.
- **Detailed Progress Metrics**:
  - Routine items projected: `12 / 24` items completed.
- **Action Button**:
  - `"Resume from Routine Projection (Stage 3)"` button.

---

## 5. Synthesis of Dependencies & Cross-Issue Interaction

| Issue | Core Responsibility | Inter-Issue Dependencies |
| :--- | :--- | :--- |
| **Issue 37** (Cache Clearing) | Safe cache purges preserving dirty edits | Interacts with Issue 39 (cache clear can be offered when retries exceed max backoff limit). |
| **Issue 39** (Retry Backoff) | Rate limiting & exponential backoff for recovery retries | Controls execution of actions triggered from Issue 42 (Partial Failure Banner). |
| **Issue 41** (Diagnostic Bundle) | Log collection & PII-sanitized support export | Reads job status from `OnboardingCompletionJob` and failure details from Issue 42 state. |
| **Issue 42** (Partial Banner) | Dashboard stage-by-stage status visualization | Visualizes `OnboardingCompletionJob` progress and triggers rate-limited retries (Issue 39). |

---

## 6. Implementation Roadmap & Required File Additions

To fully implement Group H Issues 37, 39, 41, 42, the following files should be created or updated:

1. **`lib/features/recovery/services/recovery_cache_manager.dart`** (Issue 37)
   - Implements `hasUnpushedEdits()`, `clearCachePreservingEdits()`, and local draft backup key management.
2. **`lib/features/recovery/controllers/recovery_retry_controller.dart`** (Issue 39)
   - Implements exponential backoff calculation, retry attempt state, and countdown timer.
3. **`lib/features/recovery/services/diagnostic_bundle_service.dart`** (Issue 41)
   - Implements `DiagnosticBundle` model, PII scrubbing regex, and formatted JSON export.
4. **`lib/features/recovery/widgets/partial_failure_status_banner.dart`** (Issue 42)
   - Renders 5-stage progress indicator, item projection counters, and resume-from-failed-stage button.
5. **`lib/features/recovery/screens/onboarding_recovery_screen.dart`** (UI Updates)
   - Integrates `PartialFailureStatusBanner`, `DiagnosticBundle` export button, and rate-limited retry buttons.

---

## 7. Recommended Test Strategy

A comprehensive unit and widget test suite should be created in `test/group_h_issues_37_39_41_42_test.dart` (or as part of `test/group_h_issues_33_to_42_test.dart`):

1. **Issue 37 Tests**:
   - Verify `hasUnpushedEdits()` returns `true` when `stepDirty` has `true` values.
   - Verify `clearCachePreservingEdits()` preserves dirty draft state while resetting read-only caches.
2. **Issue 39 Tests**:
   - Verify exponential backoff sequence (2s, 4s, 8s, 16s, 32s, capped at 60s).
   - Verify retry button is disabled during active rate limit cooldown.
   - Verify max attempt cap (5 retries) transitions state to recommend alternative recovery action.
3. **Issue 41 Tests**:
   - Verify PII sanitization replaces user emails (`user@example.com` -> `[REDACTED_EMAIL]`) and names.
   - Verify generated JSON diagnostic bundle contains accurate app metadata, failure reason, and job stage details.
4. **Issue 42 Tests**:
   - Widget test verifying `PartialFailureStatusBanner` correctly renders 2 completed stages and 1 failed stage.
   - Verify progress counter display (e.g. "12 / 24 routine items projected").
