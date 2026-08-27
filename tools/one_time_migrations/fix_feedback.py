"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'
with open(file_path, 'r') as f:
    content = f.read()

# 1. Update _panelPin
old_pin = """Widget _panelPin({double? top, double? left, double? right, double? bottom}) {
  return Positioned(
    top: top,
    left: left,
    right: right,
    bottom: bottom,
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.88),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.72),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
    ),
  );
}"""
new_pin = """Widget _panelPin({double? top, double? left, double? right, double? bottom}) {
  return Positioned(
    top: top,
    left: left,
    right: right,
    bottom: bottom,
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 3,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 10,
            height: 1.5,
            color: Colors.black.withValues(alpha: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}"""
content = content.replace(old_pin, new_pin)

# 2. Update OnboardingGlassCard shadow & gradient
old_card_shadow = """        boxShadow: selected ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 6,
            offset: const Offset(0, 12),
          ),
        ]"""
new_card_shadow = """        boxShadow: selected ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ]"""
content = content.replace(old_card_shadow, new_card_shadow)

old_card_bg = """            decoration: BoxDecoration(
              color: tint ?? Colors.white.withValues(alpha: selected ? 0.20 : 0.05),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.95 : 0.65),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: selected ? 0.25 : 0.15),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.02),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),"""
new_card_bg = """            decoration: BoxDecoration(
              color: tint ?? Colors.white.withValues(alpha: selected ? 0.20 : 0.05),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? OptivusColors.brandAccent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.65),
                width: 1.5,
              ),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        OptivusColors.brandAccent.withValues(alpha: 0.15),
                        OptivusColors.aquaAccent.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.02),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
            ),"""
content = content.replace(old_card_bg, new_card_bg)

# 3. Small buttons OnboardingChip
old_chip_bg = """                color: selected
                    ? accent.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.95 : 0.65),
                  width: 1.5,
                ),"""
new_chip_bg = """                color: selected
                    ? accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.65),
                  width: selected ? 2.0 : 1.5,
                ),"""
content = content.replace(old_chip_bg, new_chip_bg)

# Chip Text Color
old_chip_text = """                        style: TextStyle(
                          color: selected ? Colors.white : OptivusColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),"""
new_chip_text = """                        style: TextStyle(
                          color: selected ? accent : OptivusColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),"""
content = content.replace(old_chip_text, new_chip_text)

old_chip_icon = """Icon(icon, size: 14, color: selected ? Colors.white : accent)"""
new_chip_icon = """Icon(icon, size: 14, color: accent)"""
content = content.replace(old_chip_icon, new_chip_icon)

# 4. Small buttons OnboardingActionPill
old_pill_bg = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: selected ? 0.95 : 0.65),
                    width: 1.5,
                  ),"""
new_pill_bg = """                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected ? accent : Colors.white.withValues(alpha: 0.65),
                    width: selected ? 2.0 : 1.5,
                  ),"""
content = content.replace(old_pill_bg, new_pill_bg)

old_pill_text = """                      style: TextStyle(
                        color: selected ? Colors.white : OptivusColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),"""
new_pill_text = """                      style: TextStyle(
                        color: selected ? accent : OptivusColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),"""
content = content.replace(old_pill_text, new_pill_text)

old_pill_icon = """Icon(icon, size: compact ? 14 : 16, color: selected ? Colors.white : accent)"""
new_pill_icon = """Icon(icon, size: compact ? 14 : 16, color: accent)"""
content = content.replace(old_pill_icon, new_pill_icon)

with open(file_path, 'w') as f:
    f.write(content)
print('Done fixing!')
