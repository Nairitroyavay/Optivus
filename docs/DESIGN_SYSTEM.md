# Optivus Design System Contract

Status: Phase 0 complete — token and shared-component freeze

Source of truth: `lib/core/theme/` and `lib/core/widgets/`

## 1. Design principles

The current Optivus visual language is a light, high-contrast Life OS with:

- a pastel-to-white background family for each application area;
- one area accent color for navigation, emphasis, progress, and status;
- translucent, blurred, bordered “liquid glass” cards and panels;
- dark, heavy display titles with compact supporting copy;
- rounded controls, cards, sheets, chips, and status surfaces;
- restrained elevation through soft shadows, white edge highlights, and
  occasional accent glow; and
- short press/state transitions plus longer decorative ambient motion.

The design system preserves that implemented language. It does not authorize a
new brand, a screen redesign, or a repository-wide pixel migration.

Clarity outranks decoration: text and state must remain readable over glass,
disabled and error states must be distinguishable, and decorative animation
must not block an action or obscure progress.

## 2. Canonical token sources

| Token category | Canonical source | Approved usage | Known gaps |
| --- | --- | --- | --- |
| Colors | `lib/core/theme/optivus_colors.dart` | Use semantic text/surface/status tokens and the owning area's top/accent/card tokens. Add a named palette entry before introducing a new product color. | Legacy/auth/feature files still contain local palettes, raw `Color(0x...)`, and broad `Colors.*` usage. Some comments and older area color assumptions need touched-file review. |
| Gradients | `lib/core/theme/optivus_gradients.dart` | Use the area preset or `tabGradient` for the standard pastel-to-light vertical treatment. | `AppShell` and multiple feature surfaces build gradients directly; not all current two-stop variants map exactly to the preset. |
| Spacing | `lib/core/theme/optivus_spacing.dart` | New/touched layout spacing uses `xs` (4), `sm` (8), `md` (12), `base` (16), `lg` (20), `xl` (24), `xxl` (32), or `xxxl` (48), plus the named tab-bar reserves. | Existing screens repeat numeric `EdgeInsets`/`SizedBox` values. `liquidTabBarReserve()` is still a component helper rather than one consolidated layout token. |
| Typography | `lib/core/theme/optivus_typography.dart` and `OptivusTheme.lightTheme.textTheme` in `optivus_theme.dart` | Prefer `Theme.of(context).textTheme` for Material/context roles; use `OptivusTypography` for explicit Optivus display/title/body/label/caption roles. Extend a named role rather than copying a raw `TextStyle`. | `OptivusTypography` currently has no consumers outside its declaration, the theme and preset sizes differ for some roles, and representative screens use many raw `TextStyle` values. This requires gradual convergence. |
| Corner radii | `lib/core/theme/optivus_radii.dart` | Use the approved 0/4/8/12/16/20/24/30 scale or `pill` for fully rounded controls. Select by component role and keep it consistent across states. | Phase 0 added the previously missing canonical source. Existing 14, 18, 22, 28, 28.5, 32, 33, 99, and other literals remain untouched pending feature work. |
| Shadows | `lib/core/theme/optivus_shadows.dart` | Use `soft`, `medium`, `elevated`, `glassCard`, or `glow(accent)` according to elevation and interaction need. | Many glass/feature widgets construct custom multi-shadow recipes; several may be legitimate special effects, while duplicate standard elevation remains unclassified. |
| Motion | `lib/core/theme/optivus_motion.dart` | Use press (120 ms), fast (180 ms), standard (300 ms), or slow (400 ms), with standard/enter/exit curves. Use zero duration for nonessential motion when animations are disabled. | Phase 0 added the previously missing source. Existing screens use many raw durations, repeat controllers, and extra curves; no mass migration occurred. |
| Component states | `lib/core/widgets/liquid_buttons.dart`, `liquid_inputs.dart`, and `liquid_empty_loading_error.dart`, plus `OptivusTheme.lightTheme` | Use shared control states and the canonical empty/loading/error patterns before creating feature variants. Null callbacks represent disabled actions; loading must also prevent duplicate submission. | State components currently have little or no production adoption. Focus, keyboard activation, semantic progress, validation messaging, and operation-state coverage are inconsistent. |

The small radius and motion files are covered by
`test/design_tokens_test.dart`. They formalize values already common in the
repository and do not alter any existing screen in Phase 0.

## 3. Token rules

1. Feature screens use canonical tokens instead of introducing new hard-coded
   design values.
2. New colors are added intentionally to `OptivusColors` with a semantic or
   owner-area name. Do not add an unexplained hexadecimal literal.
3. New spacing uses `OptivusSpacing`; a new value requires a demonstrated
   layout role, not one screen's preference.
4. Typography uses the canonical text roles. A one-off `copyWith` is acceptable
   for color/emphasis when the base role remains identifiable.
5. Corner radii use `OptivusRadii`.
6. Standard elevation and glow use `OptivusShadows`; bespoke painted/glass
   effects must explain why a preset cannot express the result.
7. Motion uses `OptivusMotion`. Decorative motion observes
   `MediaQuery.disableAnimations`, must not delay state truth, and must have a
   reduced/no-motion result.
8. New interactive components define all applicable states listed in Section
   6 and include accessibility behavior.
9. An exception records the reason, affected component, owner, and migration
   plan in the change or technical-debt register.

Hard-coded values that encode data geometry rather than visual design (for
example a timeline minute scale or chart math) are not automatically design
tokens. Ownership must be determined from responsibility, not the numeric
value alone.

## 4. Component ownership

`lib/core/widgets/` is the canonical home for reusable cross-feature UI.

Current canonical component families include:

| Family | Canonical components |
| --- | --- |
| Buttons/actions | `LiquidPrimaryButton`, `LiquidOutlineButton`, `LiquidIconButton`, `LiquidBlobButton` |
| Inputs | `LiquidInput`, `LiquidInputCard`, `LiquidWavyTextField` |
| Cards/surfaces | `LiquidBlurCard`, `LiquidBlurCardAccented`, `FolderShapeCard`, `GraphPerformanceCard`, `ConflictCard`, `PermissionStatusCard` |
| Scaffolds/layout | `LiquidScreenScaffold`, `LiquidDetailScaffold`, `LiquidDetailHeader`, `LiquidDetailSection`, `LiquidSafeScrollView`, `LiquidSectionHeader` |
| Sheets | `LiquidModalSheet`, `showLiquidBottomSheet` and its shared sheet surface |
| Selection/status | `LiquidChip`, `LiquidChipGroup`, `LiquidSegmentedControl`, `LiquidPill`, `LiquidSettingsRow` |
| Screen states | `LiquidEmptyState`, `LiquidLoadingState`, `LiquidErrorState` |

Feature-specific widgets stay in
`lib/features/<feature>/widgets/` (or an explicitly feature-owned subfolder).
They may compose core primitives but must not be promoted merely because two
screens in the same area use them.

`lib/widgets/` is transitional. It currently includes `AppButton`,
`LiquidTextField`, `LiquidGlassCard`, `LiquidGlassPanel`,
`LiquidGlassTabBar`, `WavyLoadingIndicator`, `GlassLogo`, and other
reusable-looking components. Existing imports remain until scheduled feature
work classifies/migrates them. New shared components must not be added there.
The bottom tab bar can remain temporarily because it is an existing shell
dependency, not permission to grow the transitional directory.

## 5. Duplicate-component policy

Before creating a shared button, input, card, sheet, status view, chip, or
segmented control:

1. Search `lib/core/widgets/` and its consumers.
2. Determine whether an existing semantic component can be extended without
   breaking current states or accessibility.
3. Search `lib/widgets/` and feature widgets so the new component does not
   accidentally become a third implementation.
4. Document why a new component is necessary and why composition/extension is
   insufficient.
5. Define applicable visual, interaction, error, and accessibility states.
6. Add focused tests for the shared behavior.

Known overlaps include `AppButton` versus `LiquidPrimaryButton`,
`LiquidTextField` versus `LiquidInput`, and legacy glass card/panel classes
versus core liquid card primitives. They must be classified and migrated when
their consuming feature is scheduled, not merged mechanically in Phase 0.

## 6. Required component states

Every new interactive shared component defines the applicable subset of:

- default;
- pressed;
- focused (and keyboard-focused where applicable);
- selected;
- loading/busy;
- disabled;
- validation error;
- operation error;
- empty;
- success.

A component must prevent duplicate action while busy, retain an understandable
label, and expose state semantically. Purely decorative components do not need
nonsensical loading, validation, or selected APIs.

Current shared coverage is partial:

- `LiquidPrimaryButton` renders pressed, loading, and disabled visuals.
- `LiquidInput` renders enabled/focused borders and defines error-border
  styling, but its public API does not yet provide validation/error text.
- `LiquidChip` and `LiquidSegmentedControl` render selected/unselected states.
- `LiquidEmptyState`, `LiquidLoadingState`, and `LiquidErrorState` provide
  feature-neutral content states.

Keyboard/focus/semantic behavior and shared operation-success/error patterns
remain acceptance work before these components can be called fully mature.

## 7. Loading, empty, and error patterns

| Need | Current canonical pattern | Rule / current gap |
| --- | --- | --- |
| App startup and restore loading | `LoadingScreen` at `/loading` | Reserved for resolving auth/profile/onboarding truth. It must not be replaced by protected content. |
| App restore blocking error | `LoadingScreen` with restore message and `AppButton` retry | Current route-level retry pattern; uses a transitional button and needs later core-component/accessibility convergence. |
| Feature screen/section loading | `LiquidLoadingState` | Canonical for new/touched feature screens, but it currently has no consumers; existing feature spinners are transitional. |
| Inline action loading | `LiquidPrimaryButton(isLoading: true)` or a bounded progress indicator within the owning control | Busy state must disable duplicate action and announce progress where applicable. Current primary button does not enforce this automatically when a non-null callback remains. |
| Empty collection | `LiquidEmptyState` with optional action | Message explains the empty state; action is present only when recovery/creation is possible. Adoption is pending. |
| Recoverable feature error | `LiquidErrorState(onRetry: ...)` | Message is actionable and safe; retry remains owner-scoped. Adoption is pending. |
| Blocking feature error | `LiquidErrorState` without navigation-sensitive content, inside the owning scaffold | A blocking state must not expose stale/incorrect data and must provide back/retry/support where applicable. No dedicated cross-feature blocking-error scaffold exists. |
| Disabled action | Null callback with a clearly disabled Material/shared-control state | Disabled state must remain legible and must not be represented only by low opacity or color. |

The repository still contains feature-specific `CircularProgressIndicator`,
empty copy, and error layouts across Home, Tracker, Goals, Onboarding, and
Routine Import. Those are migration inventory, not alternative canonical
systems.

## 8. Accessibility rules

New and touched UI must meet these minimums:

1. Provide semantic labels for icon-only actions, custom-painted controls,
   progress, and non-text status indicators.
2. Maintain adequate foreground/background contrast over gradients and glass;
   do not rely on transparency alone for disabled text.
3. Allow text scaling without clipping critical labels or hiding actions.
4. Provide at least a 48 by 48 logical-pixel target for primary touch actions,
   or equivalent padded hit testing when the visual mark is smaller.
5. Support keyboard traversal, visible focus, Enter/Space activation, and
   escape/back behavior on platforms where they apply.
6. Make disabled state clear in semantics and appearance.
7. Announce determinate progress values and meaningful indeterminate progress
   when assistive technology is active.
8. Honor `MediaQuery.disableAnimations`; remove nonessential repeating motion
   and use `OptivusMotion.reducedDuration` for state transitions that can be
   immediate.
9. Pair errors/success/warnings with text or icon semantics; color alone is
   never the message.
10. Preserve a predictable reading/focus order when a dialog, sheet, inline
    detail, loading state, or error state replaces content.

## 9. Migration policy

Phase 0 does not mass-migrate existing screens.

- When a feature is modified in its scheduled phase, migrate affected UI to
  canonical tokens/components where safe.
- Preserve current behavior and appearance unless a product/design change is
  explicitly authorized.
- Avoid unrelated large visual diffs or mechanical replacements.
- Classify a legacy/shared component from its consumers and responsibility
  before moving it.
- Add an exception to the technical-debt register when safe local migration is
  not possible.
- Remove a legacy implementation only after all consumers and relevant widget
  tests move to the canonical component.

### Verified design-system debt

The technical-debt document is the single register. Relevant items are:

- **TD-007:** overlapping shared-widget homes and duplicate button/input/glass
  component families;
- **TD-040:** token bypass and typography/radius/motion convergence across
  representative auth, shell, onboarding, and six-area screens; and
- **TD-041:** fragmented loading, empty, error, disabled, progress, and retry
  patterns with little adoption of the canonical state components.

See the [technical-debt register](TECHNICAL_DEBT.md#4-active-debt-register)
for evidence, risks, target phases, and acceptance conditions.
