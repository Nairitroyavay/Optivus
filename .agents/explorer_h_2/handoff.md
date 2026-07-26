# Handoff Report — Group H (Issues 37, 39, 41, 42) Explorer 2 Investigation

## 1. Observation

Direct code observations from `/Users/roy/optivus2/Optivus`:

1. **Local Storage Cache Clearing (Issue 37)**:
   - `lib/state/auth_state.dart:879-911` (`_resetSignedOutState`): Wipes all Riverpod providers and user mock states (`routineNotifierProvider`, `mockOnboardingProvider`, `mockUserProfileProvider`) indiscriminately.
   - `lib/models/onboarding_draft.dart:8-12`: Contains per-step dirty flag list `stepDirty`. There is no logic in recovery/auth controllers to back up dirty draft steps before cache purges.

2. **Retry Rate Limiting & Exponential Backoff (Issue 39)**:
   - `lib/features/recovery/screens/onboarding_recovery_screen.dart:49-68`: Tapping "Retry Setup" triggers `ref.read(authProvider.notifier).retryBackendRestore()` without any delay or rate limiting.
   - `lib/state/auth_state.dart:334-352`: Executes backend restore immediately on call with no cooldown tracking, backoff calculation, or attempt counters. No backoff or rate-limiting class exists in `lib/`.

3. **Diagnostic Bundle Generation & PII Protection (Issue 41)**:
   - Searching `lib/` for `diagnostic` returned 0 matches.
   - `onboarding_recovery_screen.dart:40-45`: Displays only enum name (`Reason: ${failureReason.name}`) and raw string error message. No PII-scrubbed diagnostic bundle generator or export feature exists.

4. **Partial Failure Status Banner Rendering (Issue 42)**:
   - `lib/services/onboarding_completion_job_service.dart:51-170`: Pipeline executes across 5 discrete stages (`persistDraft`, `persistBundle`, `projectRoutines`, `projectHabits`, `updateProfile`).
   - `onboarding_recovery_screen.dart`: Renders generic recovery screen UI with no stage-by-stage status banner, step progress indicators, or partial failure metrics.

---

## 2. Logic Chain

1. **Issue 37 (Cache Clearing)**:
   - *Observation*: `_resetSignedOutState` purges all Riverpod state; `OnboardingDraft` tracks dirty steps in `stepDirty`.
   - *Reasoning*: Purging local state without checking `stepDirty` permanently deletes user inputs if local cache is cleared during recovery.
   - *Conclusion*: A `RecoveryCacheManager` is required to check `hasUnpushedEdits()`, back up dirty drafts, purge clean re-fetchable caches, and re-hydrate user inputs.

2. **Issue 39 (Rate Limiting & Backoff)**:
   - *Observation*: Button clicks immediately call `retryBackendRestore()` with zero delay.
   - *Reasoning*: Unthrottled retries cause backend request spamming and retry loops.
   - *Conclusion*: A `RecoveryRetryController` must enforce exponential backoff ($\text{delay} = \min(\text{baseDelay} \times 2^{\text{attempt}-1}, \text{maxCap})$), maintain a cooldown timer, and disable retry buttons during active cooldown.

3. **Issue 41 (Diagnostic Bundle)**:
   - *Observation*: Zero diagnostic bundle code exists in `lib/`.
   - *Reasoning*: Support troubleshooting requires exporting system metadata, job stage status, and error logs, but user email/name must not be exposed.
   - *Conclusion*: A `DiagnosticBundleService` is needed to aggregate system state and scrub emails (`[REDACTED_EMAIL]`) and personal details prior to export.

4. **Issue 42 (Partial Failure Banner)**:
   - *Observation*: Jobs execute in 5 distinct stages, but `OnboardingRecoveryScreen` shows only a single error card.
   - *Reasoning*: Users and support need to see which stages completed and which stage failed to understand partial failure state.
   - *Conclusion*: A `PartialFailureStatusBanner` component must be built to visually display 5-stage progress indicators and completion metrics.

---

## 3. Caveats

- **Scope Boundary**: Issues 33, 34, 35, 36, 40 were investigated by Explorer 1. Issue 38 and master test file integration (`test/group_h_issues_33_to_42_test.dart`) are covered by Explorer 3.
- **Assumptions**: It is assumed that recovery execution in production uses Riverpod state management and `OnboardingCompletionJobService` stage tracking.

---

## 4. Conclusion

Group H Issues 37, 39, 41, and 42 require 4 dedicated additions to `lib/features/recovery/`:
1. `RecoveryCacheManager` (`lib/features/recovery/services/recovery_cache_manager.dart`) for Issue 37.
2. `RecoveryRetryController` (`lib/features/recovery/controllers/recovery_retry_controller.dart`) for Issue 39.
3. `DiagnosticBundleService` (`lib/features/recovery/services/diagnostic_bundle_service.dart`) for Issue 41.
4. `PartialFailureStatusBanner` (`lib/features/recovery/widgets/partial_failure_status_banner.dart`) for Issue 42.

These components will complete the state repair infrastructure and recovery UI dashboard.

---

## 5. Verification Method

To verify the findings and subsequent implementations:
1. **Inspect Analysis File**:
   View `/Users/roy/optivus2/Optivus/.agents/explorer_h_2/analysis.md`.
2. **Codebase Inspection**:
   - Check `lib/features/recovery/models/onboarding_recovery_models.dart` and `lib/features/recovery/screens/onboarding_recovery_screen.dart`.
   - Check `lib/state/auth_state.dart:879-911` for current reset behavior.
3. **Execute Analysis & Build Checks**:
   - Run `flutter analyze` or `dart analyze` from repo root to verify static analysis state.
   - Run existing unit tests via `flutter test`.
