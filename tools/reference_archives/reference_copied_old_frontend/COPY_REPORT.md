# Copy Report — Frontend Reference Material

High-level summary of the stable frontend screens and visual components copied from the old `optivus2` repository into this isolated reference directory inside the new `optivus2/Optivus` project.

---

## 1. Catalog of Inspected & Copied Files

All copied reference files are stored exclusively within:
`optivus2/Optivus/reference_copied_old_frontend/`

### A. Onboarding Reference Components
* **Old Files Inspected**:
  * [onboarding_page_0.dart](file:///Users/roy/optivus2/lib/views/onboarding/onboarding_page_0.dart) (Welcome Screen)
  * [onboarding_patience_test_page.dart](file:///Users/roy/optivus2/lib/views/onboarding/onboarding_patience_test_page.dart) (First Patience Test Screen)
  * [onboarding_screen.dart](file:///Users/roy/optivus2/lib/views/screens/onboarding_screen.dart) (Parent wrapper holding indicators)
* **Copied Destination**:
  * [onboarding_page_0.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/onboarding_page_0.dart) (Welcome layout)
  * [onboarding_patience_test_page.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/onboarding_patience_test_page.dart) (Patience test layout)
  * [liquid_glass_indicator.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/liquid_glass_indicator.dart) (Extracted page dot indicator, renamed to public `LiquidGlassIndicator`)
  * [README.md](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/README.md) (Notes on overlays and indicators)

### B. Routine Filter Reference Components
* **Old Files Inspected**:
  * [glass_filter_dropdown.dart](file:///Users/roy/optivus2/lib/views/routine/glass_filter_dropdown.dart) (Frosted pill and category popup dropdown)
  * [routine_provider.dart](file:///Users/roy/optivus2/lib/providers/routine_provider.dart) (Provides category filters and enums)
* **Copied Destination**:
  * [glass_filter_dropdown.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/routine/glass_filter_dropdown.dart) (Filter pill, dropdown, and GlassHighlightPainter)
  * [README.md](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/routine/README.md) (Notes on category enum mapping and math prism effects)

### C. Coach Wavy Input Reference Components
* **Old Files Inspected**:
  * [coach_tab.dart](file:///Users/roy/optivus2/lib/views/tabs/coach_tab.dart) (Chat message composer and wavy painters)
* **Copied Destination**:
  * [coach_wavy_text_field.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/coach/coach_wavy_text_field.dart) (Extracted input bar and mathematical custom painters, renamed to public `HeavyGlassInput`, `WavyClipper`, `OuterShadowWavyPainter`, `WavyGlassInputPainter`, and `InnerCavityPainter`)
  * [README.md](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/coach/README.md) (Notes on attenuation wave math, iridescent colors, and text field focus)

### D. Shared Visual Components
* **Old Files Inspected**:
  * [liquid_glass_panel.dart](file:///Users/roy/optivus2/lib/widgets/liquid_glass_panel.dart) (Physical acrylic style panel widget)
* **Copied Destination**:
  * [liquid_glass_panel.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/shared_widgets/liquid_glass_panel.dart) (frosted glass card with 3D shadows and screws)
  * [README.md](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/shared_widgets/README.md) (Notes on backdrop filters and corner plaque pins)

---

## 2. Dependencies & Risks Identified

### A. Old Imports & Packages
* Many files contain package references pointing to the old project (`package:optivus2/...`).
* These are isolated safely in this reference folder and are **not** imported by any active new app file under `lib/`. Therefore, they will not break compilation of the new app.

### B. State Management & Providers
* The old Routine Filter Dropdown widget is tightly coupled to the old `RoutineState` and `RoutineFilter` enum declared in `package:optivus2/providers/routine_provider.dart`.
* The Coach Wavy input is visually self-contained but will require integration with the new message list stream/state notifier and the new local/mock AI coach model dispatcher when moved to production.

---

## 3. Recommended Migration & Porting Plan

When the development phase reaches full frontend build-out, we recommend migrating these widgets into their respective active modules inside `lib/features/`:

1. **Onboarding Integration (`lib/features/onboarding/`)**:
   * Move `OnboardingPage0`, `OnboardingPatienceTestPage`, and `LiquidGlassIndicator` into `lib/features/onboarding/presentation/widgets/`.
   * Add the local assets image logo into the new project's assets folders.
   * Wire them into the GoRouter onboarding page views.

2. **Routine filter Integration (`lib/features/routine/`)**:
   * Move `GlassFilterDropdown`, `LiquidGlassPill`, and `GlassHighlightPainter` into `lib/features/routine/presentation/widgets/`.
   * Declare the new clean `RoutineFilter` enum and wire the `onSelected` event into the new Riverpod `routineControllerProvider` or equivalent state controllers.

3. **Coach Composer Integration (`lib/features/coach/`)**:
   * Move the self-contained `HeavyGlassInput` and all mathematical custom painters/clippers into `lib/features/coach/presentation/widgets/`.
   * Bind the message submitting callback to dispatch simulated mock AI coach text generation.

---

## 4. Integrity Declarations
* **Current App Code Intact:** We explicitly confirm that **no** active frontend app files (such as `lib/main.dart`, `app_router.dart`, `app_shell.dart`, active screens, active widgets, or `pubspec.yaml`) were modified, imported from, or connected to these copied files.
* **Backend Bypassed:** Confirming that no Firebase Auth, Cloud Firestore database writes, AI/Gemini endpoints, or Cloudflare credentials/calls were configured or touched in this copy task.
