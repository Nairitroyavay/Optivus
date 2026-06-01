import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';

/// A settings/profile row with icon, title, optional subtitle, and trailing widget.
/// Used in Profile tab and settings sub-screens.
class LiquidSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const LiquidSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (iconColor ?? OptivusColors.brandAccent).withValues(
                  alpha: 0.12,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? OptivusColors.brandAccent,
              ),
            ),
            const SizedBox(width: 14),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Trailing widget
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Flexible(child: trailing!),
            ],
            if (trailing == null && onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: OptivusColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
