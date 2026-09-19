import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';

/// A compact, professional profile and source summary card displayed
/// at the top of the Base Timeline Work / Business current setup view.
class WorkSetupProfileSummaryCard extends StatelessWidget {
  final WorkProfileSummary summary;
  final VoidCallback? onViewPhoto;
  final VoidCallback? onChangeSource;

  const WorkSetupProfileSummaryCard({
    super.key,
    required this.summary,
    this.onViewPhoto,
    this.onChangeSource,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('work-setup-profile-summary-card'),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OptivusColors.borderStandard.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header row: Profile Category & Badges
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      summary.headerTitle.toUpperCase(),
                      style: const TextStyle(
                        color: OptivusColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (summary.badges.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: summary.badges.map((badge) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: OptivusColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          // 2. Headline & Subline
          Text(
            summary.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OptivusColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (summary.subline != null) ...[
            const SizedBox(height: 2),
            Text(
              summary.subline!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: OptivusColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 6),

          // 3. Compact Schedule & Source Row
          LayoutBuilder(
            builder: (context, constraints) {
              final textScaler = MediaQuery.textScalerOf(context);
              final hasLargeText = textScaler.scale(14) > 18;
              final isVeryNarrow = constraints.maxWidth < 240;

              final scheduleWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 13,
                    color: OptivusColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      summary.scheduleSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );

              final sourceWidget = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  Icon(
                    summary.hasSourcePhoto
                        ? Icons.photo_library_outlined
                        : Icons.edit_note_rounded,
                    size: 13,
                    color: OptivusColors.textMuted,
                  ),
                  Text(
                    summary.sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OptivusColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (summary.hasSourcePhoto && onViewPhoto != null)
                    TextButton(
                      key: const Key('work-setup-profile-view-photo-button'),
                      onPressed: onViewPhoto,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: OptivusColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (onChangeSource != null)
                    TextButton(
                      key: const Key('work-setup-profile-change-source-button'),
                      onPressed: onChangeSource,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: OptivusColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );

              if (isVeryNarrow || hasLargeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    scheduleWidget,
                    const SizedBox(height: 3),
                    sourceWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: scheduleWidget),
                  const SizedBox(width: 8),
                  sourceWidget,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
