import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
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
class ClassesCurrentSetupView extends StatefulWidget {
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
  State<ClassesCurrentSetupView> createState() =>
      _ClassesCurrentSetupViewState();
}

class _ClassesCurrentSetupViewState extends State<ClassesCurrentSetupView> {
  String? _frontBlockId;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.setup.snapshotFor(BaseTimelineSection.classes);

    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: false,
    );
    final entries = widget.routineBlocks
        .expand((b) => adapter.toEntries(b))
        .toList();
    final blockMap = {for (final b in widget.routineBlocks) b.id: b};
    final hasClasses = snapshot.isConfigured || widget.routineBlocks.isNotEmpty;

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
                  onPressed: widget.onBack,
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
                        hasClasses
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
                if (hasClasses)
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
                        widget.onRemoveSetup();
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

          // Timeline View (Hero)
          Expanded(
            child: FullScreenTimelineScaffold(
              entries: entries,
              selectedDay: widget.selectedDay,
              onDayChanged: widget.onDayChanged,
              scrollController: _scrollController,
              enableHaptics: true,
              overlapPresentation: TimelineOverlapPresentation.frontAndExposed,
              frontEntryId: _frontBlockId,
              onFrontSelected: (id) => setState(() => _frontBlockId = id),
              styleBuilder: (entry) => adapter.styleForEntry(entry),
              blockBuilder: (context, positioned) {
                final block = blockMap[positioned.entry.sourceId];
                return ClassTimelineCard(
                  positioned: positioned,
                  block: block,
                  isEditable: false,
                  accent: OptivusColors.blueAccent,
                  onTap: () {
                    if (positioned.hasOverlap && !positioned.isFront) {
                      HapticFeedback.lightImpact();
                      setState(() => _frontBlockId = positioned.entry.id);
                    } else if (block != null) {
                      ClassDetailSheet.show(context, block);
                    }
                  },
                );
              },
              onEntryTapped: null,
              accent: OptivusColors.blueAccent,
              mode: TimelineMode.previewReadOnly,
              visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
              stretchPolicy: TimelineStretchPolicy.constraintBased,
              emptyDayMessage: 'No classes on this day.',
            ),
          ),

          // Source Photo Preview below Timeline (Fixed-height compact row)
          if (snapshot.sourceR2Key != null || snapshot.sourceAssetId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: snapshot.sourceR2Key,
                assetId: snapshot.sourceAssetId,
                title: 'Timetable photo',
                subtitle: widget.routineBlocks.isNotEmpty
                    ? '${widget.routineBlocks.length} weekly classes'
                    : null,
                isCompactRow: true,
                height: 68,
              ),
            ),

          // Dominant 52px Bottom CTA with Floating Tab Bar Clearance
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              routineBottomCtaReserve(context),
            ),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                label: Text(
                  hasClasses ? 'Change setup' : 'Set up Classes',
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
                onPressed: widget.onChangeSetup,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
