import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';

/// Unified review editor header across Base Timeline domains (Classes, Work, Eating).
class BaseTimelineEditorHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onCancel;
  final bool isSaving;
  final Key? backButtonKey;

  const BaseTimelineEditorHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCancel,
    this.isSaving = false,
    this.backButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            key: backButtonKey,
            tooltip: 'Discard changes',
            icon: const Icon(
              Icons.close_rounded,
              color: OptivusColors.textPrimary,
            ),
            onPressed: isSaving ? null : onCancel,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OptivusRadii.md),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
