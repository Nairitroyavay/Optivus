import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';

/// Unified source selection scaffold across Classes, Work, and Eating domains.
///
/// Ensures consistent top bar, responsive layout, overflow menus, optional
/// current photo/source preview, and truthful preservation notices.
class BaseTimelineSourceSelectionScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String? preservationNotice;
  final Widget? currentSourcePreview;
  final Widget? errorBanner;
  final List<Widget> children;
  final VoidCallback? onRemoveSetup;
  final String? removeLabel;

  const BaseTimelineSourceSelectionScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.preservationNotice,
    this.currentSourcePreview,
    this.errorBanner,
    required this.children,
    this.onRemoveSetup,
    this.removeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Bar
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
                  onPressed: onBack,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemoveSetup != null)
                  PopupMenuButton<String>(
                    key: const Key('base-timeline-source-selection-menu'),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: OptivusColors.textSecondary,
                    ),
                    color: OptivusColors.backgroundBottom,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: OptivusColors.borderStandard,
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'remove') {
                        onRemoveSetup!();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: OptivusColors.danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              removeLabel ?? 'Remove setup',
                              style: const TextStyle(
                                color: OptivusColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error banner if any
                  if (errorBanner != null) ...[
                    errorBanner!,
                    const SizedBox(height: 12),
                  ],

                  // Preservation notice (only shown when changing an existing configured source)
                  if (preservationNotice != null) ...[
                    Container(
                      key: const Key(
                        'base-timeline-source-preservation-notice',
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OptivusColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: OptivusColors.warning.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: OptivusColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              preservationNotice!,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Current source preview (photo preview card or similar)
                  if (currentSourcePreview != null) ...[
                    currentSourcePreview!,
                    const SizedBox(height: 16),
                  ],

                  // Action cards / options
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
