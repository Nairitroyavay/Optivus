"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import re

# 1. Fix OnboardingChip border
f1 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'
with open(f1, 'r') as f:
    c1 = f.read()

old_chip_border = """                border: Border.all(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.4),
                  width: selected ? 1.5 : 1.0,
                ),"""
new_chip_border = """                border: Border.all(
                  color: selected ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.4),
                  width: selected ? 1.5 : 1.0,
                ),"""
c1 = c1.replace(old_chip_border, new_chip_border)

# 2. Fix OnboardingActionPill border & text
old_pill_border = """                  border: Border.all(
                    color: selected ? accent : Colors.white.withValues(alpha: 0.65),
                    width: selected ? 2.0 : 1.5,
                  ),"""
new_pill_border = """                  border: Border.all(
                    color: selected ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.4),
                    width: selected ? 1.5 : 1.0,
                  ),"""
c1 = c1.replace(old_pill_border, new_pill_border)

old_pill_text = """                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : OptivusColors.textPrimary,"""
new_pill_text = """                            style: TextStyle(
                              color: selected
                                  ? accent
                                  : OptivusColors.textPrimary,"""
c1 = c1.replace(old_pill_text, new_pill_text)

old_pill_icon = """                          Icon(
                            icon,
                            size: compact ? 15 : 17,
                            color: selected ? Colors.white : accent,
                          ),"""
new_pill_icon = """                          Icon(
                            icon,
                            size: compact ? 15 : 17,
                            color: selected ? accent : accent,
                          ),"""
c1 = c1.replace(old_pill_icon, new_pill_icon)

with open(f1, 'w') as f:
    f.write(c1)


# 3. Fix OnboardingStepShell track background to not mix with app background
f2 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_step_shell.dart'
with open(f2, 'r') as f:
    c2 = f.read()

old_track_bg = """            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(_trackH / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42),
                width: 1.0,
              ),
            ),"""
new_track_bg = """            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(_trackH / 2),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),"""
c2 = c2.replace(old_track_bg, new_track_bg)

# Make the dots inside the track a bit darker/clearer so they don't fade into the cream background
old_dot = """                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.completedSteps[i]
                            ? OptivusColors.success.withValues(alpha: 0.78)
                            : Colors.white.withValues(alpha: 0.58),
                      ),"""
new_dot = """                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.completedSteps[i]
                            ? OptivusColors.success.withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.12),
                      ),"""
c2 = c2.replace(old_dot, new_dot)

with open(f2, 'w') as f:
    f.write(c2)


print('Done fixing borders and indicator!')
