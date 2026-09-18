import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
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
  final VoidCallback? onEditSchedule;
  final VoidCallback? onChangeSource;
  final VoidCallback? onRemoveSetup;
  final bool routineRefreshPending;
  final String? routineRefreshMessage;
  final VoidCallback? onRetryRefresh;
  final String? primaryButtonLabel;

  const ClassesCurrentSetupView({
    super.key,
    required this.setup,
    required this.routineBlocks,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onBack,
    required this.onChangeSetup,
    this.onEditSchedule,
    this.onChangeSource,
    this.onRemoveSetup,
    this.routineRefreshPending = false,
    this.routineRefreshMessage,
    this.onRetryRefresh,
    this.primaryButtonLabel,
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

  Widget _buildRefreshPendingBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OptivusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OptivusColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            size: 18,
            color: OptivusColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.routineRefreshMessage ??
                  'Setup saved. Updating your daily Routine projection is pending.',
              style: const TextStyle(
                fontSize: 12,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          if (widget.onRetryRefresh != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onRetryRefresh,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: OptivusColors.warning,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
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
    final hasSourcePhoto =
        snapshot.sourceR2Key != null || snapshot.sourceAssetId != null;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Nav Header matching Work/Eating/Skin Care/Fixed
          BaseTimelineCurrentSetupHeader(
            title: 'Classes',
            summary: snapshot.summary,
            accent: OptivusColors.blueAccent,
            onBack: widget.onBack,
            primaryButtonLabel:
                widget.primaryButtonLabel ??
                (snapshot.isConfigured ? 'Change setup' : 'Set up Classes'),
            primaryButtonKey: const Key(
              'base-timeline-header-change-setup-button',
            ),
            onPrimaryAction: widget.onChangeSetup,
            changeSourceLabel: 'Change source',
            onChangeSource: snapshot.isConfigured
                ? widget.onChangeSource
                : null,
            removeLabel: 'Remove setup',
            onRemove: snapshot.isConfigured ? widget.onRemoveSetup : null,
          ),

          // Routine Refresh Pending Banner
          if (widget.routineRefreshPending) _buildRefreshPendingBanner(context),

          // 2. Large Timetable Photo Preview directly below header
          if (hasSourcePhoto)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: snapshot.sourceR2Key,
                assetId: snapshot.sourceAssetId,
                title: 'Timetable Photo',
                height: 140,
              ),
            ),

          // 3. Timeline View
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
              geometryConfig: const TimelineGeometryConfig(
                bottomPadding: 100.0,
              ),
              visibleRangePolicy: TimelineVisibleRangePolicy.legacy,
              autoScrollToFirstEntry: false,
              stretchPolicy: TimelineStretchPolicy.constraintBased,
              emptyDayMessage: 'No classes on this day.',
            ),
          ),
        ],
      ),
    );
  }
}
