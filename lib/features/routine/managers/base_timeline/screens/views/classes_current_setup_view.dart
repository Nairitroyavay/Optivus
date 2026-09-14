import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class ClassesCurrentSetupView extends StatefulWidget {
  final BaseTimelineSetup setup;
  final List<ClassRoutineBlock> routineBlocks;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onBack;
  final VoidCallback onChangeSetup;
  final VoidCallback? onRemoveSetup;
  final bool routineRefreshPending;
  final String? routineRefreshMessage;
  final VoidCallback? onRetryRefresh;

  const ClassesCurrentSetupView({
    super.key,
    required this.setup,
    required this.routineBlocks,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onBack,
    required this.onChangeSetup,
    this.onRemoveSetup,
    this.routineRefreshPending = false,
    this.routineRefreshMessage,
    this.onRetryRefresh,
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

  Widget _buildHeader(
    BuildContext context,
    BaseTimelineSectionSnapshot snapshot,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final isVeryNarrow = constraints.maxWidth < 320;
          final hasLargeText = textScaler.scale(18) > 24;

          final changeButton = FilledButton.icon(
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: Text(
              snapshot.isConfigured ? 'Change setup' : 'Set up Classes',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.onChangeSetup,
          );

          if (isVeryNarrow || (constraints.maxWidth < 350 && hasLargeText)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Classes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          Text(
                            snapshot.summary,
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
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: changeButton),
              ],
            );
          }

          return Row(
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
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Classes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    Text(
                      snapshot.summary,
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
              changeButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildRefreshPendingBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OptivusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OptivusColors.warning.withValues(alpha: 0.3),
        ),
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
          _buildHeader(context, snapshot),

          // Routine Refresh Pending Banner
          if (widget.routineRefreshPending)
            _buildRefreshPendingBanner(context),

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
