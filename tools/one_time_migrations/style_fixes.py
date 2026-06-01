import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. OnboardingGlassCard Shadows
card_shadow_old = """        boxShadow: selected ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],"""
card_shadow_new = """        boxShadow: selected ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 6,
            offset: const Offset(0, 12),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],"""
content = content.replace(card_shadow_old, card_shadow_new)

# 2. OnboardingGlassPanel Shadows
panel_shadow_old = """        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],"""
panel_shadow_new = """        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 16),
          ),
        ],"""
content = content.replace(panel_shadow_old, panel_shadow_new)

# 3. OnboardingGlassCard Border
card_border_old = """              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.6 : 0.45),
                width: 1.0,
              ),"""
card_border_new = """              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.95 : 0.65),
                width: 1.5,
              ),"""
content = content.replace(card_border_old, card_border_new)

# 4. OnboardingGlassPanel Border
panel_border_old = """              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 1.2,
              ),"""
panel_border_new = """              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),"""
content = content.replace(panel_border_old, panel_border_new)

# 5. OnboardingChip Border & Fill
chip_fill_old = """                color: selected
                    ? accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.7 : 0.45),
                  width: 1.0,
                ),"""
chip_fill_new = """                color: selected
                    ? accent.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.95 : 0.65),
                  width: 1.5,
                ),"""
content = content.replace(chip_fill_old, chip_fill_new)

# 6. OnboardingActionPill Border & Fill
pill_fill_old = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: selected ? 0.75 : 0.45),
                    width: 1.0,
                  ),"""
pill_fill_new = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: selected ? 0.95 : 0.65),
                    width: 1.5,
                  ),"""
content = content.replace(pill_fill_old, pill_fill_new)

# 7. Unselected Circle trailing
trailing_old = """                trailing ??
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? accent : OptivusColors.borderSoft,
                    ),"""
trailing_new = """                trailing ??
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? accent : Colors.black.withValues(alpha: 0.35),
                    ),"""
content = content.replace(trailing_old, trailing_new)


with open(file_path, 'w') as f:
    f.write(content)

print('Done fixing specific widget styles.')

