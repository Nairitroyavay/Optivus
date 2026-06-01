# Routine Filter Dropdown Reference Documentation

This folder contains the visual and animation components of the **GlassFilterDropdown** widget, which drives the premium liquid/prism category filters in the Routine view.

## Contents
1. **[glass_filter_dropdown.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/routine/glass_filter_dropdown.dart)**: Contains the core interactive filter dropdown and the advanced math painter:
   * `GlassFilterDropdown` (Stateful controller that deploys the floating overlay sheet via `CompositedTransformFollower`)
   * `LiquidGlassPill` (Stateless widget representing the glass-frosted capsule trigger pill)
   * `GlassHighlightPainter` (Highly specialized custom painter that handles the 3D rim sweeps, specular inner highlights, and a vibrant **rainbow prism burst** at the bottom-right corner)

---

## Technical Notes & Dependencies

### Domain Dependencies
* **RoutineFilter Enum:** The widget relies on the state model enum `RoutineFilter` to map its items. The enum definition (from `lib/providers/routine_provider.dart` of the old project) contains:
  ```dart
  enum RoutineFilter {
    all,
    fixedSchedule,
    skinCare,
    supplements,
    classes,
    eating
  }
  ```
* **RoutineState Struct:** The widget passes the full active `RoutineState` through its signature to monitor categories or counters, though it primarily responds to the active selection `RoutineFilter selected`.

### Styling & Colors
* **Liquid UI Imports:** The dropdown imports `package:optivus2/core/liquid_ui/liquid_ui.dart` for the following color tokens:
  * `kInk` (`Color(0xFF0F111A)`)
  * `kMint` (`Color(0xFF60D4A0)`)
  * `kBlue` (`Color(0xFF60B8FF)`)
  * `kRose` (`Color(0xFFFF9560)`)
* **Blur sigma:** Both the dropdown overlay sheet and the pill container enforce a high blur:
  * Dropdown blur: `sigmaX: 28, sigmaY: 28`
  * Pill blur: `sigmaX: 20, sigmaY: 20`

---

## Future Adaptation Plan
* When implementing the filter dropdown in `lib/features/routine/widgets/`:
  1. Relocate the files to `lib/features/routine/presentation/widgets/`.
  2. Declare the `RoutineFilter` enum in `lib/features/routine/domain/` or standard state layers.
  3. Swap the `package:optivus2/...` import references to the local colors inside the new design system or replace them with native colors.
  4. Ensure the dropdown callback `onSelected` links to the state notifier of the new active Routine list provider.
