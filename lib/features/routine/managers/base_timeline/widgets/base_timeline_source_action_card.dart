import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

/// Canonical source selection action card across Base Timeline domains.
///
/// Features a 44x44 tinted icon container, bold title, descriptive subtitle,
/// optional highlight badge (e.g. RECOMMENDED), and trailing chevron.
class BaseTimelineSourceActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  const BaseTimelineSourceActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      radius: OptivusRadii.cardStandard,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OptivusRadii.cardStandard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      OptivusRadii.controlCompact,
                    ),
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accent).withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (badgeColor ?? accent).withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor ?? accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: OptivusColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
