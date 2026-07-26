## 2026-07-26T12:14:09Z
<USER_REQUEST>
You are Worker 1 for Group H (Issues 33–42: Recovery-Screen UI & State Repair).
Your working directory is /Users/roy/optivus2/Optivus/.agents/worker_h_1.

Task:
Completely implement the fixes for Group H (Issues 33–42):
- **Issue 33**: System recovery scaffold trigger conditions on corruption error (`lib/state/auth_state.dart`, `lib/features/recovery/models/onboarding_recovery_models.dart`)
- **Issue 34**: Recovery action typed error presentation and user messaging (`lib/features/recovery/screens/onboarding_recovery_screen.dart`, `lib/features/recovery/models/onboarding_recovery_models.dart`)
- **Issue 35**: Draft profile repair action execution from recovery UI (`lib/state/auth_state.dart`, `lib/services/onboarding_completion_service.dart`, `lib/features/recovery/`)
- **Issue 36**: Routine projection state force-resync from recovery UI (`lib/state/auth_state.dart`, `lib/services/routine_onboarding_event_projector.dart`, `lib/services/onboarding_frontend_hydration_service.dart`)
- **Issue 37**: Local storage cache clearing without loss of unpushed user edits (`lib/features/recovery/services/recovery_cache_manager.dart`)
- **Issue 38**: Recovery UI responsive layout on compact mobile devices (`lib/features/recovery/screens/onboarding_recovery_screen.dart`)
- **Issue 39**: Recovery action retry rate limiting and exponential backoff (`lib/features/recovery/services/recovery_retry_controller.dart`)
- **Issue 40**: Recovery screen navigation lock preventing unverified app entry (`lib/core/router/app_router.dart`, `lib/features/recovery/screens/onboarding_recovery_screen.dart`)
- **Issue 41**: Diagnostic bundle generation for user support export (`lib/features/recovery/services/diagnostic_bundle_service.dart`)
- **Issue 42**: Partial failure status banner rendering on recovery dashboard (`lib/features/recovery/widgets/partial_failure_status_banner.dart`)

Detailed Technical Instructions:
1. **Issue 33**: Update `AuthNotifier._loadOrCreateBackendUserState()` to accurately differentiate failure causes (`missingDraftAndBundle`, `missingBundle`, `corruptedBundle`, `projectionFailed`, `networkTimeout`). Verify draft existence before throwing `missingBundle`.
2. **Issue 34**: Ensure `OnboardingRecoveryScreen` retrieves `authState.onboardingFailureReason`, renders the failure reason Chip with user-friendly text (not raw enums), and displays action titles and descriptions on buttons.
3. **Issue 35**: Implement `executeRecoveryAction` on `AuthState` to handle `SynthesizeBundleAction`, `RebuildBundleFromDraftAction`, `RestartOnboardingInputAction`, `RetryCompletionJobAction`, and `ForceResyncProjectionsAction` using `OnboardingCompletionService.recoverCompletionState()` and 4-tier fallback logic.
4. **Issue 36**: Ensure `ForceResyncProjectionsAction` triggers `RoutineOnboardingEventProjector` and `OnboardingFrontendHydrationService` to project pending items into Firestore and sync receipts.
5. **Issue 37**: Create/Update `RecoveryCacheManager` to preserve unpushed local user draft edits (`stepDirty` flags) while clearing stale memory repositories.
6. **Issue 38**: Refactor `OnboardingRecoveryScreen` to wrap the scrollable body in `SafeArea`, `LayoutBuilder`, and `SingleChildScrollView(physics: AlwaysScrollableScrollPhysics())` with `ConstrainedBox`, dynamic icon sizes, and text overflow ellipsis, ensuring 0 `RenderFlex overflowed` errors on viewports <600px height or landscape. Add Sign Out button.
7. **Issue 39**: Create/Update `RecoveryRetryController` with exponential backoff ($\min(2 \times 2^{\text{attempt}-1}, 60\text{s})$), max 5 attempts limit, countdown timer, and disabled button state during backoff cooldown.
8. **Issue 40**: Lock router redirection in `app_router.dart` so `onboardingProjectionStatus == 'failed'` or `backendRestoreFailed` strictly redirects to `/onboarding/recovery`. Ensure Sign Out button on `OnboardingRecoveryScreen` allows user to exit without trapping them.
9. **Issue 41**: Create `DiagnosticBundleService` to aggregate system metadata, job stage, receipt status, and error logs with regex PII redacting (`[REDACTED_EMAIL]`, `[REDACTED_NAME]`).
10. **Issue 42**: Create `PartialFailureStatusBanner` widget displaying 5-stage job indicators (`persistDraft` -> `persistBundle` -> `projectRoutines` -> `projectHabits` -> `updateProfile`), projected vs failed item counts, and resume button.
11. **Test Suite**: Create `test/group_h_issues_33_to_42_test.dart` with unit and widget test cases covering all 10 issues (33 to 42).
12. Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test test/group_h_issues_33_to_42_test.dart`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Deliver your implementation changes, test outputs, and detailed handoff report in /Users/roy/optivus2/Optivus/.agents/worker_h_1/handoff.md.
</USER_REQUEST>
