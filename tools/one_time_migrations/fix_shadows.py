import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Fix OnboardingGlassCard shadow
card_shadow_old = """        boxShadow: selected ? [
          BoxShadow(
            color: OptivusColors.brandAccent.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(-10, 8),
          ),
          BoxShadow(
            color: OptivusColors.aquaAccent.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(10, 8),
          ),
        ]"""
card_shadow_new = """        boxShadow: selected ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ]"""
content = content.replace(card_shadow_old, card_shadow_new)

# Fix OnboardingChip shadow
chip_shadow_old = """          boxShadow: selected ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ]"""
chip_shadow_new = """          boxShadow: selected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]"""
content = content.replace(chip_shadow_old, chip_shadow_new)

# Fix OnboardingActionPill shadow
pill_shadow_old = """              if (selected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                )"""
pill_shadow_new = """              if (selected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )"""
content = content.replace(pill_shadow_old, pill_shadow_new)

# Fix OnboardingDayDroplet shadow
droplet_shadow_old = """              if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              )"""
droplet_shadow_new = """              if (selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )"""
content = content.replace(droplet_shadow_old, droplet_shadow_new)

# Fix OnboardingLiquidToggle shadow
toggle_shadow_old = """            BoxShadow(
              color: value
                  ? accent.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),"""
toggle_shadow_new = """            BoxShadow(
              color: Colors.black.withValues(alpha: value ? 0.12 : 0.05),
              blurRadius: value ? 16 : 6,
              offset: const Offset(0, value ? 6 : 3),
            ),"""
content = content.replace(toggle_shadow_old, toggle_shadow_new)


with open(file_path, 'w') as f:
    f.write(content)

print('Done fixing shadows.')
