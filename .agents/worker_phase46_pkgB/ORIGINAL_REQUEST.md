## 2026-07-28T09:34:45Z

You are worker_phase46_pkgB assigned to Work Package B Remediation for Phase 4.6 Final Production Closure.
Working Directory: /Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgB

Task Description:
Remediate the following 6 production issues in genuine code logic following the Evidence-Based Fix Protocol (R5) and Production Safety Rules (R3/R4):

1. ISSUE-04-01 / PATH3-04-01 (P1): Step Navigation Race Condition Corrupts Onboarding Draft Data
   Files: lib/features/onboarding/onboarding_flow.dart (lines 148-271, 427-489)
   Fix: Add `if (_isSaving || _isNavigating) return;` guard to `_navigateToIndicatorStep` and pass target step index explicitly into `_saveStep(stepIndex)` as a parameter instead of relying on mutable `_currentPage`.

2. ISSUE-05-01 / PATH3-05-01 (P0): Unhandled Async Debounced Draft Save Causes Data Loss & User State Overwrite
   Files: lib/repositories/onboarding_repository.dart (lines 64-73, 260-271), lib/core/utils/debouncer.dart
   Fix: Update `saveDraft` to return a Future that completes when the Firestore write finishes, and maintain a `Map<String, OnboardingDraft> _pendingDraftsByUid` keyed by UID so concurrent user saves do not overwrite each other.

3. ISSUE-06-02 / PATH3-06-02 (P1): Completion Bundle Validation Bypass for Un-Persisted Sub-Steps
   Files: lib/features/onboarding/onboarding_flow.dart (lines 275-340), lib/models/onboarding_draft.dart (lines 280-330)
   Fix: In `OnboardingDraft.validateStep(14, ...)` and `OnboardingCompletionService.buildBundle`, explicitly run `baseTimeline.validateSkinCareSetup()` and `baseTimeline.validateEatingSetup()` to ensure sub-step completion before bundling.

4. ISSUE-01-01 (P2): Missing Resend Password Reset Flow in Signup Account Exists Banner
   Files: lib/views/screens/signup_screen.dart (lines 380-392, 682-767)
   Fix: In `_sendResetForExistingAccount`, if `_emailCtrl.text` is empty or invalid, automatically populate `_emailCtrl.text` with `_accountExistsEmail` before invoking `sendPasswordResetEmail`.

5. ISSUE-02-01 (P1): Async Router Navigation Race Condition in VerifyEmailScreen
   Files: lib/views/screens/verify_email_screen.dart (lines 44-73), lib/core/router/app_router.dart (lines 62-74)
   Fix: Guard all `setState` invocations in `VerifyEmailScreen` with `if (!mounted) return;` before and after async calls, allowing router redirect to handle screen dispatches cleanly.

6. ISSUE-02-02 (P2): Resend Email Verification Rate Limiting Cooldown Lost on Screen Re-Entry
   Files: lib/views/screens/verify_email_screen.dart (lines 28-42, 100-114), lib/state/auth_state.dart
   Fix: Persist `lastVerificationEmailSentTimestamp` in AuthNotifier or persistent storage, deriving cooldown from `DateTime.now().difference(lastSent)`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Verification Requirements:
1. Create targeted tests in `test/work_package_b_remediation_test.dart`.
2. Run `dart format` on all modified files.
3. Run `flutter analyze` and ensure 0 errors / 0 warnings.
4. Run `flutter test test/work_package_b_remediation_test.dart` and `flutter test`.
5. Write your report to `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgB/changes_pkgB.md` and `/Users/roy/optivus2/Optivus/.agents/worker_phase46_pkgB/handoff.md`.
6. Send a completion message to parent when done.
