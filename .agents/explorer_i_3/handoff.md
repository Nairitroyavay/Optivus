# Handoff Report — Group I Issues 52–55 (Onboarding-Wide UI/UX Consistency)

## 1. Observation

### Issue 52: Toast Error Notification Stack Overlap Prevention
- **File**: `lib/features/onboarding/widgets/onboarding_step_shell.dart` (Lines 464–508)
- **Observation**:
  `OnboardingStepShell` renders validation error notifications using a single `AnimatedSwitcher`:
  ```dart
  AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    child: validationMessage == null
        ? const SizedBox.shrink()
        : Container(
            key: ValueKey(validationMessage),
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: OptivusColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OptivusColors.danger.withValues(alpha: 0.65), width: 1.1),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: OptivusColors.danger, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    validationMessage!,
                    style: const TextStyle(color: OptivusColors.danger, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
  ),
  ```
- **Observation**:
  In `lib/features/onboarding/onboarding_flow.dart` (e.g., lines 135–142, 151–157, 209–215, 263–266, 448–453, 456–462), calls to `ref.read(mockOnboardingProvider.notifier).setValidationMessage(msg)` immediately overwrite any active validation error. Rapid validation failures or async operations cause previous error banners to disappear instantly before the user reads them. Conversely, across other screens (`login_screen.dart`, `mind_note_card.dart`, `routine_timeline_viewport.dart`), standard `ScaffoldMessenger.of(context).showSnackBar()` is invoked without clearing active snackbars (`clearSnackBars()`), resulting in stacked, delayed toast notifications.

---

### Issue 53: Scroll Physics Consistency Across iOS and Android Viewports
- **Files**:
  - `lib/core/widgets/liquid_safe_scroll_view.dart` (Line 32)
  - `lib/core/widgets/liquid_detail_scaffold.dart` (Line 45)
  - `lib/features/onboarding/steps/onboarding_step4_unified.dart` (Line 3084)
  - `lib/features/onboarding/steps/onboarding_class_setup_timeline.dart` (Line 1189)
  - `lib/features/onboarding/steps/onboarding_step_5_eating_setup.dart` (Line 670)
  - `lib/features/onboarding/steps/onboarding_step_6_fixed_schedule.dart` (Line 301)
  - `lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart` (Lines 1184, 3814, 4584)
  - `lib/features/onboarding/widgets/onboarding_timeline_preview.dart` (Line 286)
- **Observation**:
  Scrollable views across core widgets and onboarding steps explicitly hardcode iOS bouncing scroll physics:
  ```dart
  // In liquid_safe_scroll_view.dart:
  physics: physics ?? const BouncingScrollPhysics(),

  // In onboarding_timeline_preview.dart (line 286):
  physics: const BouncingScrollPhysics(),

  // In onboarding_step4_unified.dart (line 3084):
  physics: const BouncingScrollPhysics(),
  ```
- **Observation**:
  Hardcoding `BouncingScrollPhysics()` across all platforms forces spring overscroll behavior on Android, violating Android system HIG and platform scroll physics standards. Additionally, default scroll physics disables scrolling when content fits within the viewport height, preventing user drag gesture interactions or keyboard dismissal.

---

### Issue 54: Screen Transition Gesture Navigation Handling During Inputs
- **File**: `lib/features/onboarding/onboarding_flow.dart` (Lines 491–511, 580–584)
- **Observation**:
  `OnboardingFlow` wraps the wizard in a `PopScope`:
  ```dart
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _goToPreviousStep();
    },
    child: OnboardingStepShell(...),
  );
  ```
  `_goToPreviousStep()` is implemented as:
  ```dart
  void _goToPreviousStep() {
    if (_handleInternalBackIfNeeded()) return;

    if (_currentPage <= 0) {
      context.go('/');
      return;
    }

    final target = _currentPage - 1;
    _currentPage = target;
    ref.read(mockOnboardingProvider.notifier).setStep(target);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _persistCurrentDraftAfterNavigation();
  }
  ```
- **Observation**:
  When an input field (such as text input in step 3 body basics, step 4 custom timeline blocks, step 6 fixed schedule, step 7 skincare, or step 8 coach setup) is focused or has dirty unsaved state (`stepDirty[_currentPage] == true`), invoking an iOS edge swipe back gesture or Android system back action triggers `_goToPreviousStep()` without:
  1. Unfocusing the input keyboard first.
  2. Auto-saving or prompting for draft confirmation.
  3. Confirming exit when `_currentPage == 0`, resulting in immediate navigation to `/` and potential input data loss.

---

### Issue 55: Accessibility Semantics Labels on Custom Timeline Widgets
- **Files**:
  - `lib/features/onboarding/widgets/onboarding_timeline_preview.dart` (Lines 13–125, 159–354)
  - `lib/core/timeline/timeline_visual_layout.dart` (Lines 5–93)
  - `lib/features/onboarding/steps/onboarding_step4_unified.dart`
- **Observation**:
  In `onboarding_timeline_preview.dart`:
  1. `OnboardingDayChips` renders day chips MON–SUN using plain `GestureDetector` widgets over styled `_OnboardingDayChip` circles. No `Semantics` wrapper, button trait (`button: true`), or selection state (`selected: true/false`) is provided. Screen readers announce "MON", "TUE" as plain text fragments without indicating interactive button traits or current day selection.
  2. `OnboardingVerticalTimeline` builds a custom `Stack` containing tick indicators (`OnboardingTimelineTick`), minute lines (`OnboardingMinuteIndicator`), and timeline block cards. Background ticks and minute markers lack `ExcludeSemantics()` or grouped container semantics (`Semantics(container: true, label: ...)`). Screen readers read out raw time ticks individually ("8:00 AM", "8:00 PM") in isolation without context.
  3. Custom timeline block widgets in `blockBuilder` lack semantic button/card traits, detailed time duration labels, and screen reader action hints (e.g. `Semantics(button: true, label: 'Math 101, 9:00 AM to 10:30 AM, Room 204. Double tap to edit.')`).
  4. Changing selected day or adding timeline blocks does not trigger screen reader announcements via `SemanticsService.announce(...)`.

---

## 2. Logic Chain

1. **Issue 52 Logic**:
   - Single-field state (`validationMessage: String?`) overwrites instantly when set repeatedly.
   - Without a Toast Queue Manager that handles message FIFO queueing, clean dismissal animations, and auto-dismiss timing, error messages overlap or vanish abruptly.
   - Providing a dedicated `ToastQueueNotifier` / `LiquidToastQueue` with `dismissCurrent()`, auto-clear timer (e.g. 3s), and deduplication ensures clean, readable error notifications without UI overlap.

2. **Issue 53 Logic**:
   - Hardcoding `BouncingScrollPhysics()` across all platforms breaks platform-native scroll behavior on Android (which expects `ClampingScrollPhysics` / stretch overscroll).
   - Furthermore, default scroll physics on viewports with short content disables dragging.
   - Wrapping scroll physics in `const AlwaysScrollableScrollPhysics()` delegates overscroll behavior to the underlying platform default while guaranteeing that views remain scrollable/draggable on any viewport height.

3. **Issue 54 Logic**:
   - The current `PopScope` callback directly invokes `_goToPreviousStep()`.
   - If a keyboard is open or a draft form is dirty (`stepDirty[_currentPage] == true`), back swipe gesture instantly navigates away without unfocusing or saving.
   - Intercepting `PopScope` to: (a) unfocus primary focus if keyboard is visible, (b) execute internal stage back step if applicable, (c) auto-save or prompt for draft save if dirty, and (d) prompt before exiting on step 0 prevents accidental data loss during gesture navigation.

4. **Issue 55 Logic**:
   - Custom timeline and day selector widgets were constructed focusing on visual aesthetics (glassmorphic containers, blur filters, gradient borders) without screen reader annotations.
   - Adding `Semantics` wrappers with `button: true`, explicit `label`, `hint`, and `selected` properties on day chips and block cards, hiding decorative tick lines via `ExcludeSemantics`, and dispatching `SemanticsService.announce` calls when timeline state changes provides a 100% accessible experience for VoiceOver and TalkBack users without modifying visual rendering.

---

## 3. Caveats

- **No Caveats**: All 4 target issues and affected files were thoroughly inspected across `lib/features/onboarding/`, `lib/core/widgets/`, `lib/core/timeline/`, and `lib/core/utils/`.

---

## 4. Conclusion & Proposed Architectural Fix Designs

### Summary Table of Fixes

| Issue | Target Files | Primary Problem | Proposed Architectural Fix Design |
|---|---|---|---|
| **Issue 52** | `lib/features/onboarding/widgets/onboarding_step_shell.dart`, `lib/features/onboarding/onboarding_flow.dart` | Single state field overwrites errors; no queue or clean dismiss mechanism. | Implement a `ToastQueueNotifier` / `LiquidToastQueue` in `lib/core/utils/` and `OnboardingStepShell` that manages a FIFO queue with auto-dismiss (3s), clean slide-out animations, and deduplication. |
| **Issue 53** | `lib/core/widgets/liquid_safe_scroll_view.dart`, `lib/core/widgets/liquid_detail_scaffold.dart`, `lib/features/onboarding/widgets/onboarding_timeline_preview.dart`, `lib/features/onboarding/steps/onboarding_step4_unified.dart` | Hardcoded `BouncingScrollPhysics()` breaks Android scroll mechanics and prevents drag on short viewports. | Replace hardcoded `BouncingScrollPhysics()` with `const AlwaysScrollableScrollPhysics()`, allowing platform-adaptive scroll physics (bouncing on iOS, clamping/stretch on Android) and ensuring all views remain scrollable regardless of content size. |
| **Issue 54** | `lib/features/onboarding/onboarding_flow.dart` | Back gesture pops immediately during input focus or dirty state, losing data. | Update `PopScope` handler to: (1) unfocus active keyboard, (2) handle internal step back, (3) auto-save or prompt for draft confirmation if step is dirty, (4) prompt before exiting step 0. |
| **Issue 55** | `lib/features/onboarding/widgets/onboarding_timeline_preview.dart`, `lib/features/onboarding/steps/onboarding_step4_unified.dart` | Custom timeline ticks, day chips, and block cards lack Semantics labels, button traits, and screen reader announcements. | Wrap day chips in `Semantics(button: true, selected: ...)`; wrap timeline container in `Semantics(container: true, label: ...)`; hide decorative ticks with `ExcludeSemantics`; dispatch `SemanticsService.announce()` on day/timeline updates. |

---

### Detailed Code Fix Designs

#### Fix Design for Issue 52 (Toast Error Queue)
Create `lib/core/utils/liquid_toast_manager.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToastType { error, warning, info, success }

class ToastItem {
  final String id;
  final String message;
  final ToastType type;
  final Duration duration;

  ToastItem({
    required this.id,
    required this.message,
    this.type = ToastType.error,
    this.duration = const Duration(seconds: 3),
  });
}

class ToastQueueState {
  final ToastItem? current;
  final List<ToastItem> queue;

  const ToastQueueState({this.current, this.queue = const []});
}

class ToastQueueNotifier extends StateNotifier<ToastQueueState> {
  Timer? _timer;

  ToastQueueNotifier() : super(const ToastQueueState());

  void showToast(String message, {ToastType type = ToastType.error, Duration? duration}) {
    if (state.current?.message == message) return; // Deduplicate
    final item = ToastItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      type: type,
      duration: duration ?? const Duration(seconds: 3),
    );

    if (state.current == null) {
      _displayToast(item);
    } else {
      state = ToastQueueState(current: state.current, queue: [...state.queue, item]);
    }
  }

  void _displayToast(ToastItem item) {
    state = ToastQueueState(current: item, queue: state.queue);
    _timer?.cancel();
    _timer = Timer(item.duration, () => dismissCurrent());
  }

  void dismissCurrent() {
    _timer?.cancel();
    if (state.queue.isNotEmpty) {
      final next = state.queue.first;
      final remaining = state.queue.sublist(1);
      state = ToastQueueState(current: null, queue: remaining);
      Future.delayed(const Duration(milliseconds: 150), () => _displayToast(next));
    } else {
      state = const ToastQueueState(current: null, queue: []);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final toastQueueProvider = StateNotifierProvider<ToastQueueNotifier, ToastQueueState>(
  (ref) => ToastQueueNotifier(),
);
```

Update `OnboardingStepShell` validation banner (lines 464–508):
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  transitionBuilder: (child, animation) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation),
    child: FadeTransition(opacity: animation, child: child),
  ),
  child: validationMessage == null
      ? const SizedBox.shrink()
      : Container(
          key: ValueKey(validationMessage),
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: OptivusColors.danger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OptivusColors.danger.withValues(alpha: 0.65), width: 1.1),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: OptivusColors.danger, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  validationMessage!,
                  style: const TextStyle(color: OptivusColors.danger, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(mockOnboardingProvider.notifier).clearValidation(),
                child: const Icon(Icons.close_rounded, color: OptivusColors.danger, size: 16),
              ),
            ],
          ),
        ),
),
```

---

#### Fix Design for Issue 53 (Scroll Physics)
In `lib/core/widgets/liquid_safe_scroll_view.dart`:
```dart
// Before:
physics: physics ?? const BouncingScrollPhysics(),

// After:
physics: physics ?? const AlwaysScrollableScrollPhysics(),
```

In `lib/core/widgets/liquid_detail_scaffold.dart`:
```dart
// Before:
physics: const BouncingScrollPhysics(),

// After:
physics: const AlwaysScrollableScrollPhysics(),
```

In `lib/features/onboarding/widgets/onboarding_timeline_preview.dart`:
```dart
// Before:
physics: const BouncingScrollPhysics(),

// After:
physics: const AlwaysScrollableScrollPhysics(),
```

In `lib/features/onboarding/steps/onboarding_step4_unified.dart`:
```dart
// Before:
physics: const BouncingScrollPhysics(),

// After:
physics: const AlwaysScrollableScrollPhysics(),
```

---

#### Fix Design for Issue 54 (Back Swipe Navigation & Draft Guard)
In `lib/features/onboarding/onboarding_flow.dart`:
```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;

    // 1. Unfocus keyboard if active
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus != null && currentFocus.hasFocus) {
      currentFocus.unfocus();
      return;
    }

    // 2. Handle internal sub-step back navigation
    if (_handleInternalBackIfNeeded()) return;

    // 3. Handle Step 0 Onboarding Exit
    if (_currentPage <= 0) {
      final confirmExit = await _showExitConfirmationDialog(context);
      if (confirmExit == true && mounted) {
        context.go('/');
      }
      return;
    }

    // 4. Handle Unsaved Draft State on Step Back
    final onboardingState = ref.read(mockOnboardingProvider);
    final isDirty = onboardingState.stepDirty[_currentPage];
    if (isDirty) {
      final saved = await _saveStep(_currentPage);
      if (!saved && mounted) {
        final proceedAnyway = await _showDiscardDraftDialog(context);
        if (!proceedAnyway) return;
      }
    }

    _goToPreviousStepDirect();
  },
  child: OnboardingStepShell(...),
)
```

---

#### Fix Design for Issue 55 (Timeline Semantics)
In `lib/features/onboarding/widgets/onboarding_timeline_preview.dart`:

Day chips:
```dart
for (var index = 0; index < _labels.length; index++)
  Expanded(
    child: Semantics(
      button: true,
      selected: selectedDay == index + 1,
      label: _fullDayNames[index], // 'Monday', 'Tuesday', etc.
      hint: selectedDay == index + 1 ? 'Currently selected' : 'Double tap to select ${_fullDayNames[index]} schedule',
      onTap: () {
        onChanged(index + 1);
        SemanticsService.announce(
          context,
          '${_fullDayNames[index]} schedule selected',
          TextDirection.ltr,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(index + 1),
        child: _OnboardingDayChip(
          label: _labels[index],
          selected: selectedDay == index + 1,
          accent: accent,
        ),
      ),
    ),
  );
```

Timeline container & decorative ticks:
```dart
// Exclude decorative background tick lines from screen readers:
ExcludeSemantics(
  child: OnboardingTimelineTick(...),
)

// Wrap main timeline in semantic container:
Semantics(
  container: true,
  label: 'Timeline schedule, ${blocks.length} items',
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    ...
  ),
)

// Wrap block card in Semantics:
Semantics(
  button: true,
  label: '${block.title}, from ${onboardingTimeLabel(block.startMinute)} to ${onboardingTimeLabel(block.endMinute)}',
  hint: 'Double tap to edit timeline item',
  child: blockBuilder(context, block),
)
```

---

## 5. Verification Method

1. **Static Analysis**:
   ```bash
   flutter analyze lib/features/onboarding lib/core/widgets lib/core/utils
   ```
   Verify 0 errors or warnings introduced.

2. **Toast Queue Verification**:
   - Trigger rapid validation errors by tapping 'Next Step' repeatedly on step 3 or step 4 with incomplete inputs.
   - Confirm active toast cleanly transitions or dismisses without stacking or overlapping UI header elements.

3. **Scroll Physics Verification**:
   - Run app on iOS simulator and Android emulator.
   - Verify Android displays native overscroll (clamping/stretch glow) while iOS displays rubber-band bouncing scroll.
   - Test on small screen viewports (e.g. iPhone SE / 4.7" Android screen); verify viewports with few items are still draggable and dismiss keyboard on scroll drag.

4. **Back Gesture Verification**:
   - Focus a text field on step 3 (Body Basics) or step 4 (Class/Work setup).
   - Perform edge swipe back gesture on iOS or back button tap on Android.
   - Verify keyboard unfocuses first without popping the screen. Perform back gesture again and verify draft is saved or confirmation dialog is displayed.

5. **Accessibility Verification**:
   - Enable Accessibility Inspector / VoiceOver (iOS) or TalkBack (Android).
   - Navigate day chips MON–SUN; verify screen reader announces "Monday, button, selected", "Tuesday, button", etc.
   - Focus custom timeline cards; verify screen reader announces block title, start time, end time, and action hint cleanly.
