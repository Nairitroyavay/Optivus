import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_detail_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_timeline_card.dart';

/// Read-only Current Setup view for Classes Base Timeline.
class ClassesCurrentSetupView extends StatelessWidget {
  final BaseTimelineSetup setup;
  final List<ClassRoutineBlock> routineBlocks;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onBack;
  final VoidCallback onChangeSetup;
  final VoidCallback onRemoveSetup;

  const ClassesCurrentSetupView({
    super.key,
    required this.setup,
    required this.routineBlocks,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onBack,
    required this.onChangeSetup,
    required this.onRemoveSetup,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.classes);

    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: false,
    );
    final entries = routineBlocks.expand((b) => adapter.toEntries(b)).toList();
    final blockMap = {for (final b in routineBlocks) b.id: b};

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calm Top Nav Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (snapshot.isConfigured || routineBlocks.isNotEmpty)
                            ? 'Your current setup'
                            : 'Set up your timetable',
                        style: const TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.isConfigured || routineBlocks.isNotEmpty)
                  PopupMenuButton<String>(
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
                        onRemoveSetup();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: OptivusColors.danger,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remove setup',
                              style: TextStyle(
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

          // Source Photo Preview (Truthful Presigned R2)
          if (snapshot.sourceR2Key != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: snapshot.sourceR2Key,
                assetId: snapshot.sourceAssetId,
                title: 'Timetable photo',
                subtitle: routineBlocks.isNotEmpty
                    ? '${routineBlocks.length} weekly classes'
                    : null,
                height: 110,
              ),
            ),

          // Timeline View (Hero)
          Expanded(
            child: FullScreenTimelineScaffold(
              entries: entries,
              selectedDay: selectedDay,
              onDayChanged: onDayChanged,
              styleBuilder: (entry) => adapter.styleForEntry(entry),
              blockBuilder: (context, positioned) {
                final block = blockMap[positioned.entry.sourceId];
                return ClassTimelineCard(
                  positioned: positioned,
                  block: block,
                  isEditable: false,
                  accent: OptivusColors.blueAccent,
                  onTap: () {
                    if (block != null) {
                      ClassDetailSheet.show(context, block);
                    }
                  },
                );
              },
              onEntryTapped: (entry) {
                final block = blockMap[entry.sourceId];
                if (block != null) {
                  ClassDetailSheet.show(context, block);
                }
              },
              accent: OptivusColors.blueAccent,
              mode: TimelineMode.previewReadOnly,
              visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
              stretchPolicy: TimelineStretchPolicy.constraintBased,
              emptyDayMessage: 'No classes on this day.',
            ),
          ),

          // Dominant 52px Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                label: Text(
                  snapshot.isConfigured ? 'Change setup' : 'Set up Classes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: OptivusColors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onChangeSetup,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
