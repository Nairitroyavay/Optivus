import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';

/// Section header with uppercase title and optional trailing action link.
/// Used to label card groups throughout the app (e.g., "ACTIVE TRACKERS", "TODAY'S IDENTITY").
class LiquidSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? actionColor;

  const LiquidSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: OptivusColors.textSecondary,
            ),
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: actionColor ?? OptivusColors.brandAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
