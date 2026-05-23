import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'
with open(file_path, 'r') as f:
    content = f.read()

# 1. OnboardingChip BoxShadow
old_chip_shadow = """        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),"""
new_chip_shadow = """        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),"""
content = content.replace(old_chip_shadow, new_chip_shadow)

# 2. OnboardingChip Background & Gradient
old_chip_bg = """              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.65),
                  width: selected ? 2.0 : 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: selected ? 0.4 : 0.25),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),"""
new_chip_bg = """              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.4),
                  width: selected ? 1.5 : 1.0,
                ),
                gradient: selected ? null : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),"""
content = content.replace(old_chip_bg, new_chip_bg)


# 3. OnboardingActionPill BoxShadow
old_pill_shadow = """              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],"""
new_pill_shadow = """              boxShadow: const [],"""
content = content.replace(old_pill_shadow, new_pill_shadow)

# 4. OnboardingActionPill Background & Gradient
old_pill_bg = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected ? accent : Colors.white.withValues(alpha: 0.65),
                    width: selected ? 2.0 : 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: selected ? 0.35 : 0.2),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),"""
new_pill_bg = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected ? accent : Colors.white.withValues(alpha: 0.4),
                    width: selected ? 1.5 : 1.0,
                  ),
                  gradient: selected ? null : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),"""
content = content.replace(old_pill_bg, new_pill_bg)


# 5. OnboardingDayDroplet BoxShadow
old_droplet_shadow = """        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),"""
new_droplet_shadow = """        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),"""
content = content.replace(old_droplet_shadow, new_droplet_shadow)


with open(file_path, 'w') as f:
    f.write(content)

print('Done fixing shadows and backgrounds!')
