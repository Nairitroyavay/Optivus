import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';

enum ProfileStatusType { success, warning, danger, info, muted }

class ProfileStatusChip extends StatelessWidget {
  final String label;
  final ProfileStatusType type;

  const ProfileStatusChip({
    super.key,
    required this.label,
    this.type = ProfileStatusType.muted,
  });

  @override
  Widget build(BuildContext context) {
    Color getBgColor() {
      switch (type) {
        case ProfileStatusType.success:
          return OptivusColors.success.withValues(alpha: 0.15);
        case ProfileStatusType.warning:
          return OptivusColors.warning.withValues(alpha: 0.15);
        case ProfileStatusType.danger:
          return OptivusColors.danger.withValues(alpha: 0.15);
        case ProfileStatusType.info:
          return OptivusColors.info.withValues(alpha: 0.15);
        case ProfileStatusType.muted:
          return OptivusColors.disabled.withValues(alpha: 0.2);
      }
    }

    Color getTextColor() {
      switch (type) {
        case ProfileStatusType.success:
          return OptivusColors.success;
        case ProfileStatusType.warning:
          return OptivusColors.warning;
        case ProfileStatusType.danger:
          return OptivusColors.danger;
        case ProfileStatusType.info:
          return OptivusColors.info;
        case ProfileStatusType.muted:
          return OptivusColors.textSecondary;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: getBgColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: getTextColor(),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
