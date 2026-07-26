# Group H (Issues 33–42) Investigation & Test Suite Strategy

**Author**: Explorer 3 (Group H: Recovery-Screen UI & State Repair)  
**Target Path**: `/Users/roy/optivus2/Optivus/.agents/explorer_h_3/analysis.md`  
**Date**: 2026-07-26  

---

## 1. Executive Summary

Group H addresses system setup recovery, UI responsiveness, state repair, diagnostic export, rate limiting, and navigation locking across Issues 33–42. As Explorer 3, this investigation focuses on:
1. **Issue 38**: Recovery UI responsive layout on compact mobile devices (`lib/features/recovery/screens/onboarding_recovery_screen.dart`).
2. **Existing Test Coverage Audit**: Reviewing `test/` for recovery actions, recovery screen, and auth state recovery.
3. **Comprehensive Test Suite Strategy**: Architecting `test/group_h_issues_33_to_42_test.dart` with 10 structured test groups covering all Group H issues (Issues 33–42).

---

## 2. Issue 38 Deep-Dive: Recovery UI Responsive Layout on Compact Mobile Devices

### 2.1 Code Inspection (`lib/features/recovery/screens/onboarding_recovery_screen.dart`)

```dart
// Current Implementation (Lines 14-72)
return Scaffold(
  appBar: AppBar(title: const Text('Setup Recovery')),
  body: Padding(
    padding: const EdgeInsets.all(24.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.build_circle_outlined, size: 64, color: Colors.amber),
        const SizedBox(height: 16),
        Text('Setup Verification Incomplete', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(authState.errorMessage ?? '...', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        if (failureReason != null) ...[
          const SizedBox(height: 12),
          Chip(label: Text('Reason: ${failureReason.name}'), backgroundColor: Colors.amber.shade100),
        ],
        const SizedBox(height: 32),
        if (actions.isEmpty)
          ElevatedButton(...)
        else
          ...actions.map((action) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ElevatedButton(
              onPressed: () => ref.read(authProvider.notifier).executeRecoveryAction(action),
              child: Text(action.label),
            ),
          )),
      ],
    ),
  ),
);
```

### 2.2 Root Cause Analysis & Vulnerabilities

1. **Unconstrained `Column` Without `SingleChildScrollView`**:
   - The body consists of a fixed `Column` inside a static `Padding(padding: EdgeInsets.all(24.0))`.
   - Vertical spatial height breakdown:
     - AppBar: 56px
     - Top/Bottom Padding: 48px
     - Icon: 64px + 16px spacer = 80px
     - Headline text: ~32px + 8px spacer = 40px
     - Body message (2-4 lines): ~40-80px + 12px spacer = 52-92px
     - Failure Reason Chip: 32px + 32px spacer = 64px
     - Recovery action buttons (up to 4 actions, e.g. `RetryCompletionJobAction`, `RebuildBundleFromDraftAction`, `SynthesizeBundleAction`, `RestartOnboardingInputAction`): 4 x (48px height + 12px margin) = 240px
     - **Total Required Height**: ~580px - 620px (excluding status bar).
   - On compact viewports (e.g. 320x480px, 360x640px, iPhone SE 1st Gen / 2nd Gen, or when software keyboard opens, or in landscape mode, or under OS Accessibility large font scaling), the total height exceeds screen height.
   - **Result**: Flutter throws a `RenderFlex overflowed by XX pixels` yellow-and-black stripe exception.

2. **Lack of `SafeArea`**:
   - `Padding` does not account for system gestures, notches, or home indicator bars on iOS/Android.

3. **No Responsive Viewport Scaling**:
   - Icon size is fixed at `64px` regardless of screen height.
   - Spacers are fixed (`16px`, `32px`).
   - No `LayoutBuilder` or `ConstrainedBox` bounds to dynamically adjust element density on small screens (<600px height).

4. **Action Button Text Truncation / Multi-Line Clipping**:
   - Recovery action labels (e.g., `"Rebuild Setup Plan"`, `"Restore Default Setup"`, `"Restart Setup Forms"`) do not specify `maxLines` or text overflow handling, risking text clipping on narrow (<360px) screen widths.

### 2.3 Proposed Responsive Layout Remediation

```dart
// Proposed Fix for OnboardingRecoveryScreen
class OnboardingRecoveryScreen extends ConsumerWidget {
  const OnboardingRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final failureReason = authState.failureReason;
    final actions = authState.recoveryActions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Recovery'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 600;
            final iconSize = isCompactHeight ? 48.0 : 64.0;
            final topSpacing = isCompactHeight ? 12.0 : 16.0;
            final actionSpacing = isCompactHeight ? 20.0 : 32.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32.0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        size: iconSize,
                        color: Colors.amber,
                      ),
                      SizedBox(height: topSpacing),
                      Text(
                        'Setup Verification Incomplete',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authState.errorMessage ??
                            'Your setup preferences were saved, but background configuration needs to be completed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (failureReason != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Chip(
                            label: Text(
                              'Reason: ${failureReason.name}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.amber.shade100,
                          ),
                        ),
                      ],
                      SizedBox(height: actionSpacing),
                      if (actions.isEmpty)
                        ElevatedButton(
                          onPressed: () {
                            ref.read(authProvider.notifier).retryBackendRestore();
                          },
                          child: const Text('Retry Setup'),
                        )
                      else
                        ...actions.map((action) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(authProvider.notifier)
                                    .executeRecoveryAction(action);
                              },
                              child: Text(
                                action.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

---

## 3. Audit of Existing Test Coverage in `test/`

A complete audit of `test/` revealed:
- **`test/onboarding_routing_test.dart`**: Tests basic `GoRouter` redirects (e.g. verifying `backendRestoreFailed` status redirects to `/onboarding/recovery`).
- **`test/onboarding_completion_group_a_test.dart`**: Tests completion bundle creation and hydration.
- **`test/group_g_issues_31_to_32_test.dart`**: Tests class timetable validation.
- **Existing Coverage Gaps for Group H**:
  - ❌ ZERO widget tests for `OnboardingRecoveryScreen` responsive rendering or layout overflow checks.
  - ❌ ZERO tests for `RebuildBundleFromDraftAction`, `SynthesizeBundleAction`, or `RestartOnboardingInputAction` execution.
  - ❌ ZERO tests for cache clearing behavior (Issue 37).
  - ❌ ZERO tests for exponential backoff / rate limiting (Issue 39).
  - ❌ ZERO tests for diagnostic bundle generation & zero-PII leak (Issue 41).
  - ❌ ZERO tests for partial failure status banner rendering (Issue 42).
  - ❌ MISSING `test/group_h_issues_33_to_42_test.dart`.

---

## 4. Comprehensive Test Suite Strategy (`test/group_h_issues_33_to_42_test.dart`)

The test suite `test/group_h_issues_33_to_42_test.dart` will be structured into 10 explicit groups corresponding to Issues 33 through 42:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Issue 33: System recovery scaffold trigger conditions on corruption error', () { ... });
  group('Issue 34: Recovery action typed error presentation and user messaging', () { ... });
  group('Issue 35: Draft profile repair action execution from recovery UI', () { ... });
  group('Issue 36: Routine projection state force-resync from recovery UI', () { ... });
  group('Issue 37: Local storage cache clearing without loss of unpushed user edits', () { ... });
  group('Issue 38: Recovery UI responsive layout on compact mobile devices', () { ... });
  group('Issue 39: Recovery action retry rate limiting and exponential backoff', () { ... });
  group('Issue 40: Recovery screen navigation lock preventing unverified app entry', () { ... });
  group('Issue 41: Diagnostic bundle generation for user support export', () { ... });
  group('Issue 42: Partial failure status banner rendering on recovery dashboard', () { ... });
}
```

### Detailed Test Specifications:

#### Issue 33: System Recovery Trigger Conditions
- **Test 33.1**: `fetchUserProfile` returns `onboardingCompleted: true`, but `fetchCompletionBundle` returns `null` → status transitions to `AuthFlowStatus.backendRestoreFailed` with `OnboardingFailureReason.missingBundle`.
- **Test 33.2**: `RoutineProjectionReceiptValidator.validate()` fails → status transitions to `AuthFlowStatus.backendRestoreFailed` with `OnboardingFailureReason.projectionReceiptMismatch`.
- **Test 33.3**: History projection receipt incomplete (`cursor != totalCount`) → status transitions to `AuthFlowStatus.backendRestoreFailed` with `OnboardingFailureReason.habitsProjectionFailed`.

#### Issue 34: Typed Error Presentation & Messaging
- **Test 34.1**: Verify `missingBundle` displays "Reason: missingBundle" chip and presents `RebuildBundleFromDraftAction` & `RestartOnboardingInputAction`.
- **Test 34.2**: Verify `projectionReceiptMismatch` displays `RetryCompletionJobAction` & `RebuildBundleFromDraftAction`.
- **Test 34.3**: Verify raw exceptions are caught and sanitized to user-friendly text without stack trace leakage.

#### Issue 35: Repair Action Execution
- **Test 35.1**: `RebuildBundleFromDraftAction.execute()` rebuilds completion bundle from draft, saves to repo, and triggers `retryBackendRestore()`.
- **Test 35.2**: `RestartOnboardingInputAction.execute()` calls `markOnboardingIncomplete()`, resetting status to `signedInOnboardingIncomplete` and navigating to `/onboarding`.
- **Test 35.3**: `SynthesizeBundleAction.execute()` creates fallback completion bundle when draft is missing.

#### Issue 36: Projection State Force-Resync
- **Test 36.1**: Force-resync action invokes `OnboardingFrontendHydrationService.hydrate()` and updates projection receipt in `RoutineRepository`.
- **Test 36.2**: Successful force-resync transitions state to `signedInOnboardingComplete`.

#### Issue 37: Cache Clearing Without Loss of Edits
- **Test 37.1**: Cache clear action purges transient routine item caches while preserving unpushed step draft edits.
- **Test 37.2**: Pending local draft edits (e.g. customized meal dishes) remain intact after cache flush.

#### Issue 38: Responsive Layout on Compact Mobile Devices
- **Test 38.1**: Widget test rendering `OnboardingRecoveryScreen` inside a 320x480 screen with 4 recovery actions. Asserts ZERO `RenderFlex overflowed` errors.
- **Test 38.2**: Asserts `SingleChildScrollView` is present and scrollable.
- **Test 38.3**: Asserts `AlwaysScrollableScrollPhysics` is active.
- **Test 38.4**: Asserts action button text wraps/truncates gracefully on 320px width without horizontal overflow.

#### Issue 39: Retry Rate Limiting & Backoff
- **Test 39.1**: Rapidly invoking `retryBackendRestore()` > 3 times within 5 seconds triggers rate-limiting state.
- **Test 39.2**: Retry buttons display disabled countdown timer during rate-limit window.

#### Issue 40: Recovery Screen Navigation Lock
- **Test 40.1**: Attempting `context.go('/app?tab=0')` while in `backendRestoreFailed` redirects to `/onboarding/recovery`.
- **Test 40.2**: Deep linking to `/tracker/money`, `/routine/base-timeline`, `/profile/edit` redirects to `/onboarding/recovery`.

#### Issue 41: Diagnostic Bundle Export
- **Test 41.1**: Generating diagnostic bundle returns JSON string containing `failureReason`, `jobStatus`, `schemaVersion`, and OS metadata.
- **Test 41.2**: Asserts zero PII (email, tokens, credentials, personal notes) is included in diagnostic bundle.

#### Issue 42: Partial Failure Status Banner
- **Test 42.1**: When `onboardingProjectionStatus` is `'partial'`, `OnboardingRecoveryScreen` displays `RecoveryStatusBanner`.
- **Test 42.2**: Banner displays completion progress, warning icon, and retry CTA.

---

## 5. Synthesis & Cross-Explorer Alignment

- **Explorer 1** handles recovery scaffold triggers (Issue 33), typed error models (Issue 34), repair execution (Issue 35), force-resync (Issue 36), and navigation locking (Issue 40).
- **Explorer 2** handles cache clearing (Issue 37), rate limiting (Issue 39), diagnostic bundle export (Issue 41), and partial failure banner (Issue 42).
- **Explorer 3 (this report)** defines the UI layout fixes for compact devices (Issue 38) and establishes the unified test suite strategy in `test/group_h_issues_33_to_42_test.dart` covering all 10 issues.
