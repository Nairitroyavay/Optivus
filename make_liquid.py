import re

# 1. Update OnboardingStepShell Indicator Pill
f1 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_step_shell.dart'
with open(f1, 'r') as f:
    c1 = f.read()

old_pill = """                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC89F4DD), Color(0x8889F4DD)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF89F4DD,
                          ).withValues(alpha: 0.40),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),"""

new_pill = """                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF89F4DD), Color(0xAA89F4DD), Color(0x4489F4DD)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 2,
                            right: 2,
                            height: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.9),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),"""
c1 = c1.replace(old_pill, new_pill)
with open(f1, 'w') as f:
    f.write(c1)


# 2. Update OnboardingSaveButton
f2 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_save_button.dart'
with open(f2, 'r') as f:
    c2 = f.read()

old_save_bg = """                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  color: success
                      ? OptivusColors.success.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: success
                        ? OptivusColors.success.withValues(alpha: 0.50)
                        : Colors.white.withValues(alpha: 0.40),
                    width: 1,
                  ),
                ),"""

new_save_bg = """                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  color: success
                      ? OptivusColors.success.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: success
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 2,
                      left: 6,
                      right: 6,
                      height: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.8),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),"""

old_save_content_wrapper = """                child: AnimatedSwitcher("""
new_save_content_wrapper = """                    AnimatedSwitcher("""
c2 = c2.replace(old_save_bg, new_save_bg)
c2 = c2.replace(old_save_content_wrapper, new_save_content_wrapper)

old_save_end = """                  child: _content(success),
                ),
              ),"""
new_save_end = """                  child: _content(success),
                    ),
                  ],
                ),
              ),"""
c2 = c2.replace(old_save_end, new_save_end)

with open(f2, 'w') as f:
    f.write(c2)


# 3. Update BaseTimelineStep TabBar Indicator
f3 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/steps/base_timeline_step.dart'
with open(f3, 'r') as f:
    c3 = f.read()

old_indicator = """                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [OptivusColors.aquaAccent, Color(0xFFFF88C9)],
                    ),
                  ),
                  labelColor: OptivusColors.textPrimary,"""

new_indicator = """                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        OptivusColors.aquaAccent.withValues(alpha: 0.4),
                        const Color(0xFFFF88C9).withValues(alpha: 0.4)
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  labelColor: OptivusColors.textPrimary,"""

c3 = c3.replace(old_indicator, new_indicator)
with open(f3, 'w') as f:
    f.write(c3)

print('Done fixing liquid glass for indicator, save button, and tabs!')
