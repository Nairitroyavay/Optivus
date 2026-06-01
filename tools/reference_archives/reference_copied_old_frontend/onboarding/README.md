# Onboarding Reference Documentation

This folder contains high-fidelity copies of the onboarding visual foundation from the old `optivus2` app.

## Contents
1. **[onboarding_page_0.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/onboarding_page_0.dart)**: Welcome and introduction screen with an animated floating logo image.
2. **[onboarding_patience_test_page.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/onboarding_patience_test_page.dart)**: The discipline "First Patience Test" messaging screen.
3. **[liquid_glass_indicator.dart](file:///Users/roy/optivus2/Optivus/reference_copied_old_frontend/onboarding/liquid_glass_indicator.dart)**: Extracted premium iOS-style liquid capsule slide dot indicator (`LiquidGlassIndicator`).

---

## Technical Notes & Layout Metrics

### Insets and Overlays
Both onboarding screens are designed to scroll underneath transparent floating overlays (e.g., top status/indicator bar and bottom action buttons). To prevent content overlap, the pages read constant padding metrics:
* `kIndicatorOverlayH = 44.0` (Height of the top indicator capsule overlay area)
* `kButtonOverlayH = 140.0` (Height of the bottom glass navigation action bar)
* Layout padding calculations:
  ```dart
  final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
  final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;
  padding: EdgeInsets.fromLTRB(24, top + 24, 24, bottom + 24)
  ```

### Dependencies
* **Backdrop blur UI:** Both screens wrap their core cards with `LiquidGlassPanel` (`package:optivus2/widgets/liquid_glass_panel.dart`), copied into the `shared_widgets/` folder of this reference suite.
* **Animated Logo:** Onboarding 0 relies on a local asset logo image loaded via `Image.asset('assets/images/logo.png')` inside an animated bounce scale controller.
* **Indicators:** The pages themselves do not declare the capsule dot indicators; they are laid out in the parent `OnboardingScreen` wrapper using the `LiquidGlassIndicator` with an active `PageController` offset.

---

## Future Adaptation Plan
* When implementing the full onboarding page in `lib/features/onboarding/`:
  1. Move the `LiquidGlassIndicator` and screens into `lib/features/onboarding/presentation/widgets/`.
  2. Map these screens as discrete children inside the new `PageView` of the onboarding wizard.
  3. Replace the legacy `package:optivus2/...` references with the new clean models and riverpod controller states.
