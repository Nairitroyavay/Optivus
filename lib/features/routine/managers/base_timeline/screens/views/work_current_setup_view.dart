import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_detail_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';

/// Read-only Current Setup view for Work / Business Base Timeline.
class WorkCurrentSetupView extends StatefulWidget {
  final BaseTimelineSetup setup;
  final List<TimelineBlockDraft> routineBlocks;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onBack;
  final VoidCallback onChangeSetup;
  final VoidCallback? onRemoveSetup;
  final bool routineRefreshPending;
  final String? routineRefreshMessage;
  final VoidCallback? onRetryRefresh;
  final String? lifeRole;

  const WorkCurrentSetupView({
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
    this.lifeRole,
  });

  @override
  State<WorkCurrentSetupView> createState() => _WorkCurrentSetupViewState();
}

class _WorkCurrentSetupViewState extends State<WorkCurrentSetupView> {
  String? _frontBlockId;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState(BuildContext context) {
    final emptyTitle = WorkPresentationUtils.currentSetupEmptyTitle(
      widget.lifeRole,
    );
    final emptySubtitle = WorkPresentationUtils.currentSetupEmptySubtitle(
      widget.lifeRole,
    );
    final buttonLabel = WorkPresentationUtils.currentSetupPrimaryButtonLabel(
      isConfigured: false,
      lifeRole: widget.lifeRole,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: OptivusColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: OptivusColors.warning.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 32,
                color: OptivusColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: OptivusColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: OptivusColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: widget.onChangeSetup,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.setup.snapshotFor(BaseTimelineSection.work);
    final headerTitle = WorkPresentationUtils.currentSetupHeaderTitle(
      widget.lifeRole,
    );
    final primaryLabel = WorkPresentationUtils.currentSetupPrimaryButtonLabel(
      isConfigured: snapshot.isConfigured,
      lifeRole: widget.lifeRole,
    );
    final primarySummary = WorkPresentationUtils.setupSummary(
      snapshot: snapshot,
      blocks: widget.routineBlocks,
      lifeRole: widget.lifeRole,
    );
    final secondarySummary = WorkPresentationUtils.secondarySetupSummary(
      widget.routineBlocks,
    );
    final summary = (secondarySummary != null && secondarySummary.isNotEmpty)
        ? '$primarySummary\n$secondarySummary'
        : primarySummary;

    const adapter = BaseTimelineWorkAdapter(accent: OptivusColors.warning);
    final blockMap = {for (final b in widget.routineBlocks) b.id: b};
    final hasSourcePhoto =
        snapshot.sourceR2Key != null || snapshot.sourceAssetId != null;

    final isUnconfiguredEmpty =
        widget.routineBlocks.isEmpty && !snapshot.isConfigured;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Responsive Top Nav Header
          BaseTimelineCurrentSetupHeader(
            title: headerTitle,
            summary: summary,
            accent: OptivusColors.warning,
            onBack: widget.onBack,
            primaryButtonLabel: primaryLabel,
            onPrimaryAction: widget.onChangeSetup,
            removeLabel: WorkPresentationUtils.removeSetupLabel(
              widget.lifeRole,
            ),
            onRemove: snapshot.isConfigured ? widget.onRemoveSetup : null,
          ),

          // 2. Refresh Pending Banner
          if (widget.routineRefreshPending && widget.onRetryRefresh != null)
            BaseTimelineRefreshPendingBanner(
              message: widget.routineRefreshMessage,
              onRetry: widget.onRetryRefresh!,
            ),

          // 3. Work Schedule Photo Preview
          if (hasSourcePhoto)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: snapshot.sourceR2Key,
                assetId: snapshot.sourceAssetId,
                title: WorkPresentationUtils.photoCardTitle(widget.lifeRole),
                height: 140,
              ),
            ),

          // 4. Timeline View or Empty State
          Expanded(
            child: isUnconfiguredEmpty
                ? _buildEmptyState(context)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1.0);
                      final entries = widget.routineBlocks.expand((b) {
                        final hasOverlap = WorkTimelineLayoutHelper.hasOverlap(
                          b,
                          widget.routineBlocks,
                        );
                        final cardWidth =
                            WorkTimelineLayoutHelper.effectiveCardWidth(
                              availableWidth: constraints.maxWidth,
                              hasOverlap: hasOverlap,
                            );
                        return adapter.toEntries(
                          b,
                          contentWidth: cardWidth,
                          textScale: textScale,
                          isEditable: false,
                        );
                      }).toList();

                      return FullScreenTimelineScaffold(
                        entries: entries,
                        selectedDay: widget.selectedDay,
                        onDayChanged: widget.onDayChanged,
                        scrollController: _scrollController,
                        enableHaptics: true,
                        overlapPresentation:
                            TimelineOverlapPresentation.frontAndExposed,
                        frontEntryId: _frontBlockId,
                        onFrontSelected: (id) =>
                            setState(() => _frontBlockId = id),
                        styleBuilder: (entry) => adapter.styleForEntry(entry),
                        blockBuilder: (context, positioned) {
                          final block = blockMap[positioned.entry.sourceId];
                          final canPromote =
                              positioned.hasOverlap && !positioned.isFront;
                          return WorkTimelineCard(
                            positioned: positioned,
                            block: block,
                            isEditable: false,
                            accent: OptivusColors.warning,
                            onTap: () {
                              if (canPromote) {
                                HapticFeedback.lightImpact();
                                setState(
                                  () => _frontBlockId = positioned.entry.id,
                                );
                              } else if (block != null) {
                                WorkDetailSheet.show(context, block);
                              }
                            },
                          );
                        },
                        onEntryTapped: null,
                        accent: OptivusColors.warning,
                        mode: TimelineMode.previewReadOnly,
                        geometryConfig: const TimelineGeometryConfig(
                          bottomPadding: 100.0,
                        ),
                        visibleRangePolicy:
                            TimelineVisibleRangePolicy.contentAdaptive,
                        autoScrollToFirstEntry: false,
                        stretchPolicy: TimelineStretchPolicy.constraintBased,
                        emptyDayMessage: WorkPresentationUtils.emptyDayMessage(
                          widget.lifeRole,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
