import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';

/// Unified processing / AI thinking screen scaffold across Base Timeline domains.
///
/// Features a prominent, accessible top cancel bar and centered content card,
/// eliminating duplicate cancel buttons inside thinking view cards.
class BaseTimelineProcessingScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final Widget child;

  const BaseTimelineProcessingScaffold({
    super.key,
    required this.title,
    required this.onCancel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: onCancel,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OptivusRadii.md),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
