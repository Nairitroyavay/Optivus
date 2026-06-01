# Technical Copy Report: Onboarding Base Timeline Reference Modules

## Executive Summary
This report summarizes the successful copying, isolation, and documentation of the base timeline and routine setup assets from the legacy `optivus2` project. These references will serve as the blueprints for building **Onboarding 4 — Set Your Base Timeline** in the new `Optivus` project.

All files are stored in `reference_copied_old_frontend/onboarding_base_timeline/`. They are completely isolated, not referenced by any compiling code, and safely ignored by the static analyzer via the `analysis_options.yaml` ignore pattern `"reference_copied_old_frontend/**"`.

---

## Copied Modules Overview

### 1. Classes / Timetable Setup (`/classes`)
- **Key Files:** `class_setup_screen.dart`, `README.md`
- **Core Purpose:** Allows students to visually map their class timetable.
- **UX Pattern:** A vertical scrollable daily calendar grid starting at 6 AM. Uses interactive gesture handlers to stretch, shrink, and move class blocks via "tape" grabbers.
- **Data Model:** `ClassRoutineBlock` (UI representation), mapped from/to `ClassItem` (Data representation).

### 2. Eating / Meal Setup (`/eating`)
- **Key Files:** `eating_setup_screen.dart`, `README.md`
- **Core Purpose:** Maps typical daily meal timings (Breakfast, Lunch, Dinner, Snack).
- **UX Pattern:** Interactive card sliders with dynamic progress meters, animated emoji indicators, and preset meal selections.
- **Data Model:** `MealItem` and `DayMealPlan`.

### 3. Fixed Block Schedule (`/fixed`)
- **Key Files:** `fixed_schedule_setup_screen.dart`, `fixed_schedule_editor.dart`, `README.md`
- **Core Purpose:** Defines foundational "load-bearing" routines that are unmovable—specifically Sleep, Work/Job, and customized personal routines.
- **UX Pattern:** A circular 24-hour visual clock dial representing sleep/wake schedules, paired with a vertical list timeline for adding/editing active hours.
- **Data Model:** `FixedBlock` (UI adapter) and `FixedScheduleTemplate` (Data representation).

### 4. Skincare Routine Builder (`/skin_care`)
- **Key Files:** `skin_care_setup_screen.dart`, `README.md`
- **Core Purpose:** Allows building morning, afternoon, and evening skincare steps.
- **UX Pattern:** Multi-tab slot builder. Users add skincare steps (cleanser, toner, moisturizer, etc.) using preset chips, rearrangeable via drag-and-drop.
- **Data Model:** `SkinStep` and `DaySkinPlan`.

### 5. Shared Presentation & Data Structures (`/shared_widgets`, `/shared_models_or_enums`)
- **Key Files:** 
  - `shared_widgets/routine_review_screen.dart`
  - `shared_models_or_enums/routine_template_model.dart`
  - `shared_models_or_enums/copied_routine_provider_subset.dart`
- **Core Purpose:** Provides standard screens for reviewing all configured timeline blocks before submitting them, plus the necessary core parsing routines for models (`RoutineTemplateModel`, `SkinStep`, etc.) without linking back to active backend modules.

---

## Analysis of Legacy Logic & UX Patterns

### Interactive Drag-to-Resize & Reorder
- **Classes Setup Screen:**
  - Uses `GestureDetector(onVerticalDragUpdate: ...)` on both top and bottom grabbers.
  - Converts screen-pixel movement delta (`dy`) into hours based on a scale factor of `kHourHeight = 84.0` pixels per hour: `double deltaHours = details.delta.dy / kHourHeight;`.
  - Enforces boundary conditions (minimum duration of 30 minutes: `0.6` hours, and ensuring time doesn't exceed 24 hours).
- **Skincare Setup Screen:**
  - Uses a reorderable grid list to allow users to arrange their steps seamlessly.

### Aesthetic Design Elements
- **Liquid UI Particles:** Features translucent water-droplet overlays (`_buildDroplet` / `_buildTapeWithDrops`) which give a tactile, fluid sensation when adjusting boundaries.
- **Harmonious Palettes:** Uses customized pastel cycle colors (Blue, Orange/Gold, Green, Purple, Rose) mapped with semi-translucent HSL overlays to prevent visual clutter in dense grids.
- **Glassmorphic Cards:** Elements employ heavy backdrops (`BackdropFilter(blur: 16)`) with thin high-contrast white borders (`Border.all(color: Colors.white.withAlpha(242), width: 1.5)`) to overlay smoothly over vibrant background gradients.

---

## Integration Risks & Future Mitigation Plan

> [!WARNING]
> When executing the full frontend integration, the following risks must be addressed:

| Risk Area | Legacy Behavior | Porting & Mitigation Strategy |
| :--- | :--- | :--- |
| **State Management** | Directly mutates state inline and calls legacy Riverpod `routineProvider`. | Migrate UI to consume localized `StateNotifier` or `Notifier` controllers built to the new Riverpod guidelines. |
| **Overlapping Time Blocks** | Permissive dragging can lead to overlapping fixed and class blocks. | Implement validation algorithms (`validateFixedScheduleTemplateCandidate`) at the form-save level to warn or block overlapping entries. |
| **Firestore Compatibility** | Old models in legacy providers had strict formatting assumptions. | Use the robust `fromMap` converters with defense null-parsing rules present in `routine_template_model.dart` and `copied_routine_provider_subset.dart`. |
| **Liquid UI Dependency** | Depends on specific legacy UI classes like `LiquidUI`. | Adapt these custom widgets to use standard modern widgets or local UI files. |
