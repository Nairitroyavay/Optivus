import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Compact warning status banner displayed below the context card when a generated
/// plan has become stale due to changes in body basics, routine, or settings.
class BaseTimelineStalePlanBanner extends StatelessWidget {
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const BaseTimelineStalePlanBanner({
    super.key,
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('base-timeline-stale-plan-banner'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OptivusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: OptivusColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message,
                style: TextStyle(
                  fontSize: title != null ? 11 : 12,
                  fontWeight: title != null ? FontWeight.w500 : FontWeight.w600,
                  color: title != null
                      ? OptivusColors.textSecondary
                      : OptivusColors.textPrimary,
                ),
              ),
            ],
          );

          final content = Row(
            crossAxisAlignment: title != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: title != null ? 2 : 0),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: OptivusColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: textContent),
            ],
          );

          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (secondaryActionLabel != null && onSecondaryAction != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: OptivusColors.textSecondary,
                  ),
                  onPressed: onSecondaryAction,
                  child: Text(
                    secondaryActionLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  key: const Key('base-timeline-stale-plan-regenerate-button'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: OptivusColors.warning,
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                content,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }
}
