# Group K Issues 65 & 66 Analysis Report: Optivus Onboarding Stabilization

**Author**: explorer_k_2  
**Timestamp**: 2026-07-27T00:21:30Z  
**Target Package**: Optivus (`/Users/roy/optivus2/Optivus`)  
**Scope**: Group K Issues 65 & 66 Investigation & Test Architecture Design  

---

## Executive Summary

This report delivers a deep code investigation, architectural breakdown, and complete test design for **Group K Issues 65 and 66** within the Optivus Onboarding Stabilization milestone:

1. **Issue 65: Network Disconnect & Offline Queue Integration Tests**
   - **Focus**: Design end-to-end integration tests simulating offline draft persistence, pending outbox queueing, network interruption during onboarding completion, and automatic outbox flush on reconnect.
   - **Core Invariant**: Ensure zero user data loss when offline, intermediate transactional profile states during network drops (`onboardingInputCompleted: true`, `onboardingProjectionStatus: 'pending'`), and deterministic, idempotent outbox event/job flushing upon reconnection.

2. **Issue 66: Dark Mode Screenshot Regression Test Suite**
   - **Focus**: Design golden and widget regression tests verifying dark mode theme tokens, WCAG 2.1 AA text contrast ratios, surface fill colors, and layout rendering across all onboarding step screens (`OnboardingStep0` through `OnboardingStep14`), `OnboardingStepShell`, and `OnboardingRecoveryScreen`.
   - **Core Invariant**: Guarantee all onboarding UI surfaces under `Brightness.dark` resolve canonical dark tokens (`onboardingDarkTop` `#1A1C24`, `darkGlassFill` `#1FFFFFFF`, `textPrimaryDark` `#F1F3F9`), achieve contrast ratios >= 4.5:1, and render without visual overflows or unreadable text.

---

## 1. Issue 65: Network Disconnect & Offline Queue Integration Tests

### 1.1 Requirements & System Behavior Analysis

#### A. Offline Draft Persistence
- **Behavior**: When the device is offline or remote API calls fail (e.g. Firebase unreachable or worker timeout), `saveDraft()` in `FakeOnboardingRepository` or `FirestoreOnboardingRepository` accumulates draft modifications in the local debounced cache (`_pendingDraft`).
- **Safety Guarantee**: Calling `flushPendingDraftSave()` commits the pending draft state without throwing unhandled exceptions or resetting `stepDirty` / `stepCompleted` flags. If cloud sync fails, `OnboardingFlow._persistCurrentDraftAfterNavigation()` catches the error and updates validation message gracefully: *"Your progress is saved locally, but cloud sync failed. Please check your connection."*

#### B. Network Interruption During Onboarding Completion
- **Behavior**: When a user reaches Step 14 (`OnboardingStep14`) and taps *"Enter Optivus"*, `completeOnboarding()` executes a multi-stage process. If network disconnects or an exception occurs during completion:
  1. `FirestoreOnboardingRepository.completeOnboarding()` or `OnboardingCompletionService` writes an intermediate profile patch:
     - `onboardingInputCompleted: true`
     - `onboardingProjectionStatus: 'pending'`
     - `onboardingCompleted: false`
  2. The routine projection receipt is written with `status: 'pending'` and initial `cursor: existingItemIds.length`.
  3. `RoutineProjectionRetryRequiredException` is thrown to trigger retry mechanics without corrupting user profile state or locking out the account.

#### C. Pending Outbox Queueing
- **Behavior**: While offline or pending completion, created routine items, history events, habit system projections, and completion job stages are held in the outbox / pending receipt state:
  - `RoutineProjectionReceipt`: `expectedItemIds`, `createdItemIds`, `existingItemIds`, `repairedItemIds`, `failedItemIds`, `status: 'pending'`.
  - `RoutineOnboardingEventProjector`: Maintains cursor pointer into `expectedItemIds` array, allowing incremental batch execution ($N = 100$ batch size).

#### D. Automatic Outbox Flush on Reconnect
- **Behavior**: When network connectivity is restored or the user retries setup:
  1. `RoutineOnboardingEventProjector.projectCreatedEvents()` resumes event projection from `receipt.cursor`.
  2. Created events are appended to the user's routine event feed.
  3. Once `cursor == totalCount`, the receipt transitions to `status: 'completed'`, `completedAt: timestamp`.
  4. Profile status transitions to `onboardingCompleted: true` and `onboardingProjectionStatus: 'completed'`.
  5. User is cleanly redirected to `/app?tab=0`.

---

### 1.2 Target Codebase Files to Inspect & Test

| Component / Layer | Target File Path | Responsibilities & Test Interfaces |
|---|---|---|
| Onboarding Repository | `lib/repositories/onboarding_repository.dart` | `FakeOnboardingRepository`, `FirestoreOnboardingRepository`, `saveDraft()`, `flushPendingDraftSave()`, `completeOnboarding()`, `failNextCompletionBeforeCommit()` |
| Completion Job Service | `lib/services/onboarding_completion_job_service.dart` | `OnboardingCompletionJobService`, stage execution (`persistDraft`, `persistBundle`, `projectRoutines`, `projectHabits`, `updateProfile`), wake lock claims |
| Event Projector | `lib/services/routine_onboarding_event_projector.dart` | `RoutineOnboardingEventProjector`, `projectCreatedEvents()`, batch processing, cursor advancement, idempotent retry |
| Completion & Recovery Service | `lib/services/onboarding_completion_service.dart` | `OnboardingCompletionService.buildBundle()`, `recoverCompletionState()` (4-tier fallback) |
| Onboarding Flow UI | `lib/features/onboarding/onboarding_flow.dart` | `_persistCurrentDraftAfterNavigation()`, `_completeOnboarding()`, network offline error banners |
| Auth & Router State | `lib/state/auth_state.dart` | `AuthNotifier`, `markOnboardingComplete()`, `retryBackendRestore()` |

---

### 1.3 Detailed Integration Test Architecture for Issue 65

We design a dedicated test harness `_NetworkOfflineHarness` that simulates network drops, outbox queueing, and reconnect flushes using fake repositories and controllable mutation hooks.

#### Test Cases for Issue 65:

1. **Test 65.1: Offline Draft Persistence and Debounce Recovery**
   - **Objective**: Verify that offline draft saves accumulate in memory debouncer without data loss and flush successfully when forced or restored.
   - **Steps**:
     1. Instantiate `FakeOnboardingRepository`.
     2. Call `saveDraft(draft)` with updated step data (e.g. step 3 body basics).
     3. Verify `isDraftSavedInMap(uid)` is `false` immediately after save due to 400ms debounce.
     4. Simulate network delay and invoke `flushPendingDraftSave()`.
     5. Verify `fetchDraft(uid)` returns exact updated draft with all step fields intact.

2. **Test 65.2: Network Interruption During `completeOnboarding` Transaction**
   - **Objective**: Verify that a network interruption midway through completion leaves the user in a safe intermediate state (`onboardingInputCompleted: true`, `onboardingProjectionStatus: 'pending'`).
   - **Steps**:
     1. Configure harness with `onboarding.failNextCompletionBeforeCommit()`.
     2. Invoke `completeOnboarding(finalDraft, bundle)`.
     3. Assert `RoutineProjectionRetryRequiredException` is thrown.
     4. Inspect profile patch: `onboardingInputCompleted` is `true`, `onboardingProjectionStatus` is `'pending'`, `onboardingCompleted` is `false`.
     5. Inspect projection receipt: `receipt.status` is `'pending'`.

3. **Test 65.3: Pending Outbox Queueing & Multi-Batch Event Staging**
   - **Objective**: Verify that 105 onboarding items are correctly split across batches ($N=100$ per batch) and queued in the pending outbox when interrupted.
   - **Steps**:
     1. Create a bundle with 105 routine items.
     2. Execute `completeOnboarding()`.
     3. Inject an interruption on the 2nd batch call in `RoutineOnboardingEventProjector`.
     4. Verify 100 events were written to event feed, receipt `cursor` is `100`, and `status` is `'pending'`.

4. **Test 65.4: Automatic Outbox Flush and Reconnect Idempotency**
   - **Objective**: Verify that restoring connection and re-invoking `projectCreatedEvents()` flushes remaining outbox events, advances cursor to `105`, sets `status: 'completed'`, and updates profile without duplicating event IDs.
   - **Steps**:
     1. Clear interruption hook (simulating network reconnect).
     2. Re-invoke `projectCreatedEvents()`.
     3. Verify `attemptedCount` is `5`.
     4. Verify total events written = `105`, with 105 unique event IDs.
     5. Verify receipt `status` is `'completed'` and `cursor` is `105`.
     6. Invoke `projectCreatedEvents()` again (duplicate flush) and assert `attemptedCount` is `0` (idempotent no-op).

---

## 2. Issue 66: Dark Mode Screenshot Regression Test Suite

### 2.1 Requirements & System Behavior Analysis

#### A. Token Resolution under Dark Mode
- When `ThemeData.brightness` is `Brightness.dark` (or `OptivusTheme.darkTheme` is applied), all onboarding components must resolve dark mode color tokens defined in `OptivusColors`:
  - Background Gradient: `onboardingDarkTop` (`#1A1C24`) → `onboardingDarkBottom` (`#0F1015`)
  - Glass Card Surface: `darkGlassFill` (`Color(0x1FFFFFFF)`), `darkGlassBorder` (`Color(0x33FFFFFF)`)
  - Card Fill: `Color(0xFF1E202A)`
  - Text Hierarchy:
    - Primary Text: `textPrimaryDark` (`#F1F3F9`)
    - Body Text: `textBodyDark` (`#E2E8F0`)
    - Secondary Text: `textSecondaryDark` (`#94A3B8`)
    - Muted Text: `textMutedDark` (`#64748B`)

#### B. Contrast Ratio Compliance (WCAG 2.1 AA)
- Standard text (<18pt bold or <24pt regular) must achieve a contrast ratio $\ge 4.5:1$ against dark background surfaces (`#1A1C24`, `#1E202A`, `#0F1015`).
- Relative Luminance Math:
  $$L = 0.2126 R + 0.7152 G + 0.0722 B$$
  $$\text{Contrast Ratio} = \frac{L_1 + 0.05}{L_2 + 0.05}$$
- Verification values:
  - `textPrimaryDark` (`#F1F3F9`, $L \approx 0.88$) on `#1A1C24` ($L \approx 0.012$): Ratio $\approx \frac{0.88 + 0.05}{0.012 + 0.05} = \mathbf{15.0:1} \ge 4.5:1$ (PASSED)
  - `textBodyDark` (`#E2E8F0`, $L \approx 0.77$) on `#1E202A` ($L \approx 0.015$): Ratio $\approx \frac{0.77 + 0.05}{0.015 + 0.05} = \mathbf{12.6:1} \ge 4.5:1$ (PASSED)
  - `textSecondaryDark` (`#94A3B8`, $L \approx 0.36$) on `#1E202A` ($L \approx 0.015$): Ratio $\approx \frac{0.36 + 0.05}{0.015 + 0.05} = \mathbf{6.3:1} \ge 4.5:1$ (PASSED)

#### C. Comprehensive Onboarding Screen Coverage
The test suite must verify layout rendering, theme token inheritance, text contrast, and golden snapshot assertions for all onboarding step screens:
- `OnboardingStep0` (Welcome & Intro)
- `OnboardingStep1` (Patience & Value)
- `OnboardingStep2` (Role & Lifestyle Selection)
- `OnboardingStep3` (Body Basics & Sleep Inputs)
- `OnboardingStep4` (Base Timeline & Class Schedule Setup)
- `OnboardingStep5` (Eating Setup & Meal Timetable)
- `OnboardingStep6` (Fixed Schedule & Habit Systems)
- `OnboardingStep7` (Skin Care Setup & Product Selection)
- `OnboardingStep8` (Coach Persona & Style Customization)
- `OnboardingStep9` (Slip Up Strategy)
- `OnboardingStep10` (Notification Preferences)
- `OnboardingStep11` (Today Ready Setup)
- `OnboardingStep12` (Routine Import & Review)
- `OnboardingStep13` (Pre-Home Final Review)
- `OnboardingStep14` (Onboarding Stage Summary)
- `OnboardingStepShell` (Header, Progress Dots, Navigation CTA)
- `OnboardingRecoveryScreen` (System Recovery Scaffold)

---

### 2.2 Target Codebase Files to Inspect & Test

| Component / Layer | Target File Path | Responsibilities & Test Interfaces |
|---|---|---|
| Color Tokens | `lib/core/theme/optivus_colors.dart` | `onboardingDarkTop`, `onboardingDarkBottom`, `darkGlassFill`, `darkGlassBorder`, `textPrimaryDark`, `textBodyDark`, `textSecondaryDark` |
| Theme Provider | `lib/core/theme/optivus_theme.dart` | `OptivusTheme.darkTheme`, `colorScheme`, `textTheme`, `cardTheme`, `dividerTheme` |
| Step Shell Widget | `lib/features/onboarding/widgets/onboarding_step_shell.dart` | `OnboardingStepShell`, dark mode background gradient, step indicators, action buttons |
| Glass Widgets | `lib/features/onboarding/widgets/onboarding_glass_widgets.dart` | `OnboardingGlassCard`, `OnboardingChoiceTile`, `OnboardingChip`, `OnboardingActionPill`, `OnboardingScrollView` |
| Step Widgets | `lib/features/onboarding/steps/` | `OnboardingStep0` through `OnboardingStep14` |
| Recovery Screen | `lib/features/recovery/screens/onboarding_recovery_screen.dart` | `OnboardingRecoveryScreen`, error chips, typed action cards in dark mode |

---

### 2.3 Detailed Screenshot & Widget Test Architecture for Issue 66

We design a comprehensive widget & golden test suite wrapped in `ProviderScope` and `MaterialApp(theme: OptivusTheme.darkTheme)`.

#### Test Cases for Issue 66:

1. **Test 66.1: Dark Mode Theme Token & Contrast Ratio Verification**
   - **Objective**: Programmatically calculate and assert contrast ratios for all dark mode text tokens against dark mode surfaces.
   - **Assertions**:
     - `textPrimaryDark` vs `onboardingDarkTop` $\ge 4.5:1$
     - `textBodyDark` vs dark card surface (`0xFF1E202A`) $\ge 4.5:1$
     - `textSecondaryDark` vs dark card surface (`0xFF1E202A`) $\ge 4.5:1$
     - `textMutedDark` vs `onboardingDarkBottom` $\ge 3.0:1$

2. **Test 66.2: Onboarding Step Shell Dark Background Gradient**
   - **Objective**: Mount `OnboardingStepShell` under dark theme and verify `BoxDecoration` contains `LinearGradient` starting with `onboardingDarkTop` (`0xFF1A1C24`) and ending with `onboardingDarkBottom` (`0xFF0F1015`).

3. **Test 66.3: Glass Widgets Dark Surface & Token Resolution**
   - **Objective**: Render `OnboardingGlassCard`, `OnboardingChoiceTile`, and `OnboardingChip` under dark theme. Verify glass fills use `darkGlassFill` (`0x1FFFFFFF`) and borders use `darkGlassBorder` (`0x33FFFFFF`).

4. **Test 66.4: Onboarding Steps 0 through 14 Dark Mode Layout Rendering**
   - **Objective**: Pump each individual onboarding step widget (`OnboardingStep0` to `OnboardingStep14`) inside `MaterialApp(theme: OptivusTheme.darkTheme)`.
   - **Assertions**:
     - Widget mounts cleanly without throwing layout overflow errors.
     - Title, subtitle, and body `Text` widgets inherit `textPrimaryDark` and `textBodyDark` styles.
     - Input fields, choice tiles, and preview cards maintain visible borders and readable labels.
     - Golden assertions match expected dark mode widget snapshots.

5. **Test 66.5: Onboarding Recovery Screen Dark Mode Rendering**
   - **Objective**: Pump `OnboardingRecoveryScreen` in dark mode with simulated failure reason (`missingBundle`).
   - **Assertions**:
     - Status banner chip renders with contrasting text.
     - Action cards render with dark surface fills and readable titles/descriptions.
     - Zero `RenderFlex` overflow errors on mobile dimensions (360x640).

---

## 3. Targeted & Regression Test Execution Commands

### 3.1 Targeted Test Execution Command
To run only the newly designed Group K Issue 65 & 66 test suite:
```bash
flutter test test/group_k_issues_65_to_66_test.dart
```

### 3.2 Comprehensive Regression Test Suite Execution
To verify no regressions across the entire suite (including Groups A–J):
```bash
flutter test
```

---

## 4. Summary Matrix of Identifiable Test Files to Create

| File Path | Issues Covered | Description & Primary Test Group |
|---|---|---|
| `test/group_k_issues_65_to_66_test.dart` | Issues 65 & 66 | Unified Group K test suite for network offline queueing, outbox flush idempotency, dark mode theme token resolution, contrast ratio math, and step 0-14 dark mode layout rendering. |

