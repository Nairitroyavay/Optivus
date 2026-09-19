import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_setup_context_card.dart';

/// A compact, professional profile and source summary card displayed
/// at the top of the Base Timeline Work / Business current setup view.
class WorkSetupProfileSummaryCard extends StatelessWidget {
  final WorkProfileSummary summary;
  final VoidCallback? onViewPhoto;
  const WorkSetupProfileSummaryCard({
    super.key,
    required this.summary,
    this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    return KeyedSubtree(
      key: const Key('work-setup-profile-summary-card'),
      child: BaseTimelineSetupContextCard(
        category: summary.headerTitle,
        title: summary.headline,
        subtitle: summary.subline,
        accent: OptivusColors.warning,
        icon: summary.hasSourcePhoto
            ? Icons.photo_library_outlined
            : Icons.work_outline_rounded,
        badges: summary.badges,
        actionLabel: summary.hasSourcePhoto && onViewPhoto != null
            ? 'View photo'
            : null,
        actionIcon: Icons.visibility_outlined,
        actionKey: const Key('work-setup-profile-view-photo-button'),
        onAction: summary.hasSourcePhoto ? onViewPhoto : null,
        footer: largeText
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ContextLine(
                    icon: Icons.event_note_rounded,
                    text: summary.scheduleSummary,
                  ),
                  const SizedBox(height: 3),
                  _ContextLine(
                    icon: summary.hasSourcePhoto
                        ? Icons.photo_library_outlined
                        : Icons.edit_note_rounded,
                    text: summary.sourceLabel,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContextLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: OptivusColors.textMuted),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: OptivusColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
