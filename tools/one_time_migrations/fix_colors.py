"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import re

f = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'
with open(f, 'r') as file:
    c = file.read()

# Fix OnboardingChip
old_chip = """              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),"""
new_chip = """              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),"""
c = c.replace(old_chip, new_chip)

old_chip_text = """                          color: selected
                              ? accent
                              : OptivusColors.textPrimary,"""
new_chip_text = """                          color: OptivusColors.textPrimary,"""
c = c.replace(old_chip_text, new_chip_text)

# Fix OnboardingActionPill
old_pill = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),"""
new_pill = """                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),"""
c = c.replace(old_pill, new_pill)

old_pill_text = """                        color: selected
                            ? accent
                            : OptivusColors.textPrimary,"""
new_pill_text = """                        color: OptivusColors.textPrimary,"""
c = c.replace(old_pill_text, new_pill_text)

old_pill_icon = """                        Icon(
                          icon,
                          size: compact ? 13 : 15,
                          color: selected
                              ? accent
                              : OptivusColors.textSecondary,
                        ),"""
new_pill_icon = """                        Icon(
                          icon,
                          size: compact ? 13 : 15,
                          color: selected
                              ? OptivusColors.textPrimary
                              : OptivusColors.textSecondary,
                        ),"""
c = c.replace(old_pill_icon, new_pill_icon)

with open(f, 'w') as file:
    file.write(c)

print('Done fixing blue colors!')
