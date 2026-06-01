# Fixed Schedule Setup — Reference Material

This directory contains the legacy implementation of the fixed blocks / schedule editor and setup screen from the old `optivus2` app. This includes the Job/Work/Business non-negotiables setup.

## Source Reference
* **Legacy Paths:**
  - `lib/views/routine/fixed_schedule_setup_screen.dart` (Container screen)
  - `lib/views/routine/widgets/fixed_schedule_editor.dart` (Core interactive editor widget)
* **Target Integration Path:** `lib/views/onboarding/screens/fixed_schedule_setup_screen.dart` (or similar under active onboarding)

## Components & Functionality
1. **Interactive Task blocks:** Visually represents scheduled routines (sleep, work, exercise, classes, meals, commuting, etc.).
2. **Top / Bottom Drag Handles:** Tape drag-handlers with floating water drops allowing users to adjust block start times and durations visually.
3. **Task Type Icon Inference:** Dynamically resolves UI icons based on task titles or categories matching common keywords (e.g. sleep -> bed icon, work -> work icon).
4. **Validation Dialogs:** Input validation flow enforcing non-overlapping times and correct durations unless overlaps are explicitly enabled.
5. **Job / Work / Business Non-negotiables:** Tightly integrated within the editor under the "Work" and "Job" task categories (referenced at line 129 in the editor).

## Future Reuse Plan
* **UI Restyling:** Align margins, typography (Outfit/Inter), drop-down buttons, and sheet panels with the modern Optivus dark glassmorphic design system.
* **Remove Backend Dependencies:** Keep state updates strictly local/notifiers-scoped initially, removing live Firestore template persistence calls.
* **Overlap Management:** Enhance overlap UI indicator with a cleaner neon glow warning when allowed overlaps occur.
