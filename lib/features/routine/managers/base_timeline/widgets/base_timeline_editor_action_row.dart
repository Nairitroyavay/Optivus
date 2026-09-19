import 'package:flutter/material.dart';

/// Responsive action buttons row displayed at the top of Base Timeline review views.
///
/// Reflows gracefully from a side-by-side [Row] into a stacked [Column] on
/// narrow viewports (< 320dp) or large accessibility text scales (> 1.3x).
class BaseTimelineEditorActionRow extends StatelessWidget {
  final Widget? primaryAction;
  final Widget? secondaryAction;

  const BaseTimelineEditorActionRow({
    super.key,
    this.primaryAction,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    if (primaryAction == null && secondaryAction == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final hasLargeText = textScaler.scale(14) > 18;
          final isNarrow = constraints.maxWidth < 320;

          if (primaryAction != null && secondaryAction != null) {
            if (isNarrow || hasLargeText) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  primaryAction!,
                  const SizedBox(height: 8),
                  secondaryAction!,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: primaryAction!),
                const SizedBox(width: 10),
                Expanded(child: secondaryAction!),
              ],
            );
          }

          return (primaryAction ?? secondaryAction)!;
        },
      ),
    );
  }
}
