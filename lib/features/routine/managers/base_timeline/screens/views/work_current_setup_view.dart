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
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_setup_profile_summary_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';

/// Read-only Current Setup view for Work / Business Base Timeline.
class WorkCurrentSetupView extends StatefulWidget {
  final BaseTimelineSetup setup;
  final List<TimelineBlockDraft> routineBlocks;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onBack;
  final VoidCallback onChangeSetup;
  final VoidCallback? onEditSchedule;
  final VoidCallback? onChangeSource;
  final ValueChanged<TimelineBlockDraft>? onEditBlock;
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
    this.onEditSchedule,
    this.onChangeSource,
    this.onEditBlock,
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

  void _showPhotoDialog(BuildContext context, String? r2Key, String? assetId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        final previewHeight = (screenHeight * 0.45).clamp(200.0, 420.0);
        return Dialog(
          backgroundColor: OptivusColors.backgroundBottom,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      WorkPresentationUtils.photoCardTitle(widget.lifeRole),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: OptivusColors.textSecondary,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BaseTimelinePhotoPreviewCard(
                    r2Key: r2Key,
                    assetId: assetId,
                    title: '',
                    height: previewHeight,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final showProfileCard =
        snapshot.isConfigured || widget.routineBlocks.isNotEmpty;
    final summary =
        (!showProfileCard &&
            secondarySummary != null &&
            secondarySummary.isNotEmpty)
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
            primaryButtonKey: const Key(
              'base-timeline-header-edit-schedule-button',
            ),
            iconOnly: true,
            onPrimaryAction: snapshot.isConfigured
                ? (widget.onEditSchedule ?? widget.onChangeSetup)
                : widget.onChangeSetup,
            changeSourceLabel:
                WorkPresentationUtils.currentSetupSourceButtonLabel(
                  isConfigured: snapshot.isConfigured,
                  lifeRole: widget.lifeRole,
                ),
            onChangeSource: snapshot.isConfigured
                ? widget.onChangeSource
                : null,
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

          // 3. Work Profile / Setup Summary Card
          if (snapshot.isConfigured || widget.routineBlocks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: WorkSetupProfileSummaryCard(
                summary: WorkPresentationUtils.resolveProfileSummary(
                  blocks: widget.routineBlocks,
                  lifeRole: widget.lifeRole,
                  hasSourcePhoto: hasSourcePhoto,
                ),
                onViewPhoto: hasSourcePhoto
                    ? () => _showPhotoDialog(
                        context,
                        snapshot.sourceR2Key,
                        snapshot.sourceAssetId,
                      )
                    : null,
                onChangeSource: widget.onChangeSource,
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
                                WorkDetailSheet.show(
                                  context,
                                  block,
                                  onEdit: widget.onEditBlock != null
                                      ? () => widget.onEditBlock!(block)
                                      : null,
                                );
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
