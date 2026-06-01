# Coach Wavy Text Field Reference Documentation

This folder houses the custom mathematical widgets and custom painters designed for the premium **HeavyGlassInput** chat composer in the AI Coach view.

## Contents
1. **[coach_wavy_text_field.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/coach/coach_wavy_text_field.dart)**: Contains the core input layout and all underlying rendering constructs:
   * `HeavyGlassInput` (Stateful composition of the wavy input bar, containing text fields, mic/send buttons, and interactive states)
   * `getMorphingPillPath` (Core mathematical utility that calculates a morphing capsule curve based on sine/cosine wave equations)
   * `WavyClipper` (Clips standard widgets or backdrop blurs to the morphing wave contour)
   * `OuterShadowWavyPainter` (Draws a matching real-time ambient soft drop shadow around the morphing wave)
   * `WavyGlassInputPainter` (The load-bearing glass style component: applies frosting, 3D rim shading, side refraction, iridescent caustics, and a sealing razor membrane)
   * `InnerCavityPainter` (Renders the 3D-engraved physical slot inside the input bar where the input text field resides)

---

## Technical Notes & Mathematics

### Morphing Math Wave Logic
The `getMorphingPillPath` function defines the top and bottom wave functions:
* **Top Wave Equation:**
  `wave = sin(t * pi * 3 + phase) * 0.7 + cos(t * pi * 5 - phase * 1.3) * 0.3`
* **Bottom Wave Equation:**
  `wave = sin(t * pi * 4 - phase) * 0.7 + cos(t * pi * 6 + phase * 1.1) * 0.3`
* **Attenuation Multiplier:** A sine-based easing factor `sin(t * pi)` locks the wave amplitude to zero at the exact left and right semi-circular ends so that the curves connect flawlessly to the circular endcaps.

### Styling & Animation Parameters
* **Varying Sigmas:** The widget deploys a high blur filter of `sigmaX: 24, sigmaY: 24` to create a dense glass thickness.
* **Fluid Shading:** Gradient fills are mapped to the bounding box of the input using distinct iridescent caustics (`#C084FC` to cyan to `#9333EA`) and dual-rim white specular highlights.
* **Controller Loop:** An `AnimationController` runs continuously with a `4-second` duration to update the morphing wave's phase variable.

---

## Future Adaptation Plan
* When implementing the chat message composer in `lib/features/coach/widgets/`:
  1. Port `coach_wavy_text_field.dart` into `lib/features/coach/presentation/widgets/`.
  2. Maintain standard Flutter `TextEditingController` and `FocusNode` state bindings in the parent page notifier.
  3. Customize the gradient/color properties (currently using static purple/cyan/indigo hues) to utilize color tokens from the active design system.
  4. Hook `onSend` directly to the mock or real AI Coach state dispatcher.
