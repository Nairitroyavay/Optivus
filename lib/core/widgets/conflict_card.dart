import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';

/// Timeline conflict alert card.
/// Shows a warning-styled card with description and action buttons.
class ConflictCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> actions;
  final void Function(int actionIndex)? onActionTap;

  const ConflictCard({
    super.key,
    required this.title,
    required this.description,
    this.actions = const [],
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: OptivusColors.danger.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 22,
                color: OptivusColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: OptivusColors.danger.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < actions.length; i++)
                  InkWell(
                    onTap: () => onActionTap?.call(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: OptivusColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        actions[i],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.danger,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
