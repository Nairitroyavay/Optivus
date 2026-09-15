import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';

/// Review and edit stage for Work / Business Base Timeline setup.
class WorkReviewView extends StatefulWidget {
  final List<TimelineBlockDraft> workingBlocks;
  final String? workingAssetId;
  final String? workingR2Key;
  final String? workingLocalPreviewPath;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final int droppedCount;
  final List<String> droppedExamples;
  final String? errorMessage;
  final VoidCallback onClearError;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onScanAgain;
  final VoidCallback onAddBlock;
  final void Function(TimelineBlockDraft block) onEditBlock;
  final VoidCallback onSave;
  final String? frontBlockId;
  final ValueChanged<String>? onFrontSelected;
  final bool isConcurrencyConflict;
  final VoidCallback? onReloadLatestSetup;

  const WorkReviewView({
    super.key,
    required this.workingBlocks,
    required this.workingAssetId,
    required this.workingR2Key,
    required this.workingLocalPreviewPath,
    required this.selectedDay,
    required this.onDayChanged,
    required this.droppedCount,
    required this.droppedExamples,
    required this.errorMessage,
    required this.onClearError,
    required this.isSaving,
    required this.onCancel,
    required this.onScanAgain,
    required this.onAddBlock,
    required this.onEditBlock,
    required this.onSave,
    this.frontBlockId,
    this.onFrontSelected,
    this.isConcurrencyConflict = false,
    this.onReloadLatestSetup,
  });

  @override
  State<WorkReviewView> createState() => _WorkReviewViewState();
}

class _WorkReviewViewState extends State<WorkReviewView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const adapter = BaseTimelineWorkAdapter(accent: OptivusColors.warning);
    final blockMap = {for (final b in widget.workingBlocks) b.id: b};

    final sanitizedIssues = WorkSetupErrorMapper.sanitizeDroppedExamples(
      widget.droppedExamples,
    );
    final droppedSummary = WorkSetupErrorMapper.formatDroppedSummary(
      widget.droppedCount,
      sanitizedIssues,
    );

    final hasWorkingSource =
        (widget.workingLocalPreviewPath?.isNotEmpty ?? false) ||
        (widget.workingR2Key?.isNotEmpty ?? false) ||
        (widget.workingAssetId?.isNotEmpty ?? false);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: widget.isSaving ? null : widget.onCancel,
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
                    children: [
                      Text(
                        'Review Work Schedule',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.droppedCount > 0
                            ? '${widget.workingBlocks.length} blocks scheduled · ${widget.droppedCount} ${widget.droppedCount == 1 ? 'entry was skipped' : 'entries were skipped'}'
                            : '${widget.workingBlocks.length} blocks scheduled',
                        maxLines: 1,
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
          ),

          // 2. Compact Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: OptivusColors.warning.withValues(
                        alpha: 0.12,
                      ),
                      side: BorderSide(
                        color: OptivusColors.warning.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          OptivusRadii.controlCompact,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(
                      hasWorkingSource
                          ? Icons.photo_library_outlined
                          : Icons.camera_alt_outlined,
                      size: 18,
                      color: OptivusColors.warning,
                    ),
                    label: Text(
                      hasWorkingSource ? 'Change photo' : 'Add photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.warning,
                      ),
                    ),
                    onPressed: widget.isSaving ? null : widget.onScanAgain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          OptivusRadii.controlCompact,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: OptivusColors.textPrimary,
                    ),
                    label: const Text(
                      'Add Work',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    onPressed: widget.isSaving ? null : widget.onAddBlock,
                  ),
                ),
              ],
            ),
          ),

          // 3. Sanitized attention banner for dropped entries
          if (widget.droppedCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OnboardingGlassCard(
                radius: OptivusRadii.lg,
                tint: OptivusColors.warning.withValues(alpha: 0.14),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: OptivusColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        droppedSummary,
                        style: const TextStyle(
                          color: OptivusColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Inline Error Message Banner
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: OnboardingGlassCard(
                radius: OptivusRadii.lg,
                tint: OptivusColors.danger.withValues(alpha: 0.12),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: OptivusColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.errorMessage!,
                            style: const TextStyle(
                              color: OptivusColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: OptivusColors.danger,
                          ),
                          onPressed: widget.onClearError,
                        ),
                      ],
                    ),
                    if (widget.isConcurrencyConflict &&
                        widget.onReloadLatestSetup != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Reload latest setup'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: OptivusColors.danger,
                          ),
                          onPressed: widget.onReloadLatestSetup,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 5. Timeline View (Hero)
          Expanded(
            child: widget.workingBlocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            size: 48,
                            color: OptivusColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No work blocks scheduled',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap "Add Work" or scan another photo to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1.0);
                      final entries = widget.workingBlocks.expand((b) {
                        final hasOverlap = WorkTimelineLayoutHelper.hasOverlap(
                          b,
                          widget.workingBlocks,
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
                          isEditable: true,
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
                        frontEntryId: widget.frontBlockId,
                        onFrontSelected: widget.onFrontSelected,
                        styleBuilder: (entry) => adapter.styleForEntry(entry),
                        blockBuilder: (context, positioned) {
                          final block = blockMap[positioned.entry.sourceId];
                          return WorkTimelineCard(
                            positioned: positioned,
                            block: block,
                            isEditable: true,
                            accent: OptivusColors.warning,
                            onTap: () {
                              if (positioned.hasOverlap &&
                                  !positioned.isFront) {
                                HapticFeedback.lightImpact();
                                widget.onFrontSelected?.call(
                                  positioned.entry.id,
                                );
                              } else if (block != null) {
                                widget.onEditBlock(block);
                              }
                            },
                          );
                        },
                        onEntryTapped: null,
                        accent: OptivusColors.warning,
                        mode: TimelineMode.fullScreenEditable,
                        visibleRangePolicy:
                            TimelineVisibleRangePolicy.contentAdaptive,
                        stretchPolicy: TimelineStretchPolicy.constraintBased,
                        emptyDayMessage: 'No work scheduled on this day.',
                      );
                    },
                  ),
          ),

          // 6. Scanned Photo Preview (Fixed-height compact row below Timeline)
          if (hasWorkingSource)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: BaseTimelinePhotoPreviewCard(
                localPreviewPath: widget.workingLocalPreviewPath,
                r2Key: widget.workingR2Key,
                assetId: widget.workingAssetId,
                title: 'Scanned schedule',
                subtitle: widget.workingBlocks.isNotEmpty
                    ? '${widget.workingBlocks.length} weekly blocks'
                    : null,
                isCompactRow: true,
                height: 68,
              ),
            ),

          // 7. Dominant 52px Bottom CTA with Floating Tab Bar Clearance
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              routineBottomCtaReserve(context),
            ),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OptivusColors.warning,
                  disabledBackgroundColor: OptivusColors.warning.withValues(
                    alpha: 0.35,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(OptivusRadii.lg),
                  ),
                  elevation: 0,
                ),
                onPressed: (widget.isSaving || widget.workingBlocks.isEmpty)
                    ? null
                    : widget.onSave,
                child: widget.isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Saving…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Use this work schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
