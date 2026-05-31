import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

class ProfileIdentityCard extends StatelessWidget {
  final String identityStatement;
  final VoidCallback? onTap;

  const ProfileIdentityCard({
    super.key,
    required this.identityStatement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3.5,
                  height: 14,
                  decoration: BoxDecoration(
                    color: OptivusColors.profileAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'IDENTITY STATEMENT',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 10,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              identityStatement,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: OptivusColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileChipsCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final String emptyMessage;
  final String actionButtonText;
  final VoidCallback? onActionTap;
  final Color accentColor;

  const ProfileChipsCard({
    super.key,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.actionButtonText,
    this.onActionTap,
    this.accentColor = OptivusColors.profileAccent,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 10,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty) ...[
            Text(
              emptyMessage,
              style: const TextStyle(
                color: OptivusColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  actionButtonText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) =>
                        ProfileChip(label: item, accentColor: accentColor),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class ProfileChip extends StatelessWidget {
  final String label;
  final Color accentColor;

  const ProfileChip({
    super.key,
    required this.label,
    this.accentColor = OptivusColors.profileAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: OptivusColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
