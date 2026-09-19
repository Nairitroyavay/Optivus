import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Responsive header for Base Timeline Current Setup views.
///
/// Reflows gracefully on narrow viewports (< 320dp) and large accessibility text scales.
class BaseTimelineCurrentSetupHeader extends StatelessWidget {
  final String title;
  final String summary;
  final Color accent;
  final VoidCallback onBack;
  final String primaryButtonLabel;
  final IconData primaryButtonIcon;
  final VoidCallback? onPrimaryAction;
  final String? removeLabel;
  final VoidCallback? onRemove;
  final String? resetLabel;
  final VoidCallback? onReset;
  final String? changeSourceLabel;
  final VoidCallback? onChangeSource;
  final Key? primaryButtonKey;
  final Key? backButtonKey;
  final Key? menuButtonKey;

  /// When [iconOnly] is true the primary action is rendered as a compact
  /// [IconButton] instead of a full-width [FilledButton.icon].
  final bool iconOnly;

  const BaseTimelineCurrentSetupHeader({
    super.key,
    required this.title,
    required this.summary,
    required this.accent,
    required this.onBack,
    required this.primaryButtonLabel,
    this.primaryButtonIcon = Icons.edit_calendar_rounded,
    this.onPrimaryAction,
    this.removeLabel,
    this.onRemove,
    this.resetLabel,
    this.onReset,
    this.changeSourceLabel,
    this.onChangeSource,
    this.primaryButtonKey,
    this.backButtonKey,
    this.menuButtonKey,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasMenu =
        onRemove != null || onReset != null || onChangeSource != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Either a compact icon button or the full labelled filled button.
          final Widget primaryButton = iconOnly
              ? Semantics(
                  label: primaryButtonLabel,
                  button: true,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: primaryButtonLabel,
                    child: SizedBox.square(
                      dimension: 48,
                      child: IconButton(
                        key:
                            primaryButtonKey ??
                            const Key(
                              'base-timeline-header-change-setup-button',
                            ),
                        icon: Icon(primaryButtonIcon, size: 20),
                        color: accent,
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                          backgroundColor: accent.withValues(alpha: 0.12),
                          focusColor: accent.withValues(alpha: 0.24),
                          hoverColor: accent.withValues(alpha: 0.18),
                          highlightColor: accent.withValues(alpha: 0.24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: onPrimaryAction,
                      ),
                    ),
                  ),
                )
              : FilledButton.icon(
                  key:
                      primaryButtonKey ??
                      const Key('base-timeline-header-change-setup-button'),
                  icon: Icon(primaryButtonIcon, size: 16),
                  label: Text(primaryButtonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onPrimaryAction,
                );

          Widget? menuButton;
          if (hasMenu) {
            menuButton = PopupMenuButton<String>(
              key:
                  menuButtonKey ??
                  const Key('base-timeline-header-menu-button'),
              icon: const Icon(
                Icons.more_vert_rounded,
                color: OptivusColors.textSecondary,
              ),
              color: OptivusColors.backgroundBottom,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: OptivusColors.borderStandard),
              ),
              onSelected: (val) {
                if (val == 'remove') {
                  onRemove?.call();
                } else if (val == 'reset') {
                  onReset?.call();
                } else if (val == 'change_source') {
                  onChangeSource?.call();
                }
              },
              itemBuilder: (ctx) => [
                if (onChangeSource != null)
                  PopupMenuItem(
                    key: const Key('base-timeline-header-menu-change-source'),
                    value: 'change_source',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.image_search_rounded,
                          color: OptivusColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            changeSourceLabel ?? 'Change source',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: OptivusColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onReset != null)
                  PopupMenuItem(
                    key: const Key('base-timeline-header-menu-reset'),
                    value: 'reset',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.restart_alt_rounded,
                          color: OptivusColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resetLabel ?? 'Reset setup',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: OptivusColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onRemove != null)
                  PopupMenuItem(
                    key: const Key('base-timeline-header-menu-remove'),
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: OptivusColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            removeLabel ?? 'Remove setup',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: OptivusColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }

          final backButton = IconButton(
            key: backButtonKey ?? const Key('base-timeline-header-back-button'),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: OptivusColors.textPrimary,
            ),
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          );

          final textScaler = MediaQuery.textScalerOf(context);
          final scale = textScaler.scale(1.0);
          final isVeryNarrow = constraints.maxWidth < 320;
          final hasLargeText = scale > 1.15;

          // Wrap if space is constrained or accessibility text scale is enlarged
          final shouldWrap =
              !iconOnly &&
              (isVeryNarrow || hasLargeText || constraints.maxWidth < 440);

          if (shouldWrap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    backButton,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (iconOnly) ...[const SizedBox(width: 4), primaryButton],
                    if (menuButton != null) ...[
                      const SizedBox(width: 4),
                      menuButton,
                    ],
                  ],
                ),
                if (!iconOnly) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: isVeryNarrow
                        ? SizedBox(width: double.infinity, child: primaryButton)
                        : primaryButton,
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              backButton,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              primaryButton,
              if (menuButton != null) ...[const SizedBox(width: 4), menuButton],
            ],
          );
        },
      ),
    );
  }
}
