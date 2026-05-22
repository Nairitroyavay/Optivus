# Shared Widgets Reference Documentation

This directory houses the shared frosted-glass panels and global decorators imported by multiple high-fidelity screens.

## Contents
1. **[liquid_glass_panel.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/shared_widgets/liquid_glass_panel.dart)**: Contains the reusable **LiquidGlassPanel** component:
   * Recreates the look of a physical, elevated, frosted acrylic plaque.
   * Employs real-time `BackdropFilter` blurring at `sigmaX: 25, sigmaY: 25` to achieve premium iOS frosted glass.
   * Implements four 3D-shaded corner pin screws when `hasScrews` is true, providing physical plaque aesthetics.
   * Utilizes dual drop-shadows (broad ambient soft shadows combined with tight outset and inset white highlights) to give thickness to the glass bounds.

---

## Future Adaptation Plan
* When stabilizing features in `lib/shared/` or `lib/widgets/`:
  1. Port `liquid_glass_panel.dart` into the main application widgets folder (`lib/views/widgets/` or `lib/widgets/`).
  2. The code is completely self-contained and clean with zero dependencies beyond standard Flutter SDK constructs, making it trivial to drop into the active app immediately when the layout is wired up.
