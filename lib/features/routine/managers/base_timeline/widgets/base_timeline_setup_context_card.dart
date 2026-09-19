import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';

/// Compact, premium setup context card displayed at the top of Base Timeline
/// current setup views (below the sticky header) to anchor the active schedule's
/// source, metadata badges, and non-destructive context actions (such as viewing the photo).
class BaseTimelineSetupContextCard extends StatelessWidget {
  final String category;
  final String title;
  final String? subtitle;
  final Color accent;
  final IconData? icon;
  final List<String> badges;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const BaseTimelineSetupContextCard({
    super.key,
    required this.category,
    required this.title,
    this.subtitle,
    required this.accent,
    this.icon,
    this.badges = const [],
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(OptivusRadii.cardStandard),
        border: Border.all(
          color: OptivusColors.borderStandard.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header row: Category + Badges
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 12, color: accent),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    if (badges.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: badges.map((badge) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: OptivusColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          // 2. Headline and Action Row
          LayoutBuilder(
            builder: (context, constraints) {
              final textScaler = MediaQuery.textScalerOf(context);
              final hasLargeText = textScaler.scale(14) > 18;
              final isNarrow = constraints.maxWidth < 280;

              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OptivusColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              );

              final actionBtn = (actionLabel != null && onAction != null)
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      onPressed: onAction,
                      icon: Icon(
                        actionIcon ?? Icons.visibility_outlined,
                        size: 14,
                      ),
                      label: Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null;

              if (actionBtn == null) {
                return titleSection;
              }

              if (isNarrow || hasLargeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleSection,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: actionBtn,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 8),
                  actionBtn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
