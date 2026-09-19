import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_editor_action_row.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_editor_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_empty_draft_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_timeline_card.dart';

/// Review and edit stage for Classes Base Timeline setup.
class ClassesReviewView extends StatefulWidget {
  final List<ClassRoutineBlock> workingBlocks;
  final String? workingAssetId;
  final String? workingR2Key;
  final String? workingLocalPreviewPath;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onCancel;
  final VoidCallback onScanAgain;
  final VoidCallback onAddClass;
  final ValueChanged<ClassRoutineBlock> onEditBlock;
  final VoidCallback onSave;
  final String? frontBlockId;
  final ValueChanged<String?>? onFrontSelected;
  final bool isSaving;
  final bool isConcurrencyConflict;
  final VoidCallback? onReloadLatestSetup;
  final int droppedCount;
  final List<String> droppedExamples;
  final String? errorMessage;
  final VoidCallback? onClearError;
  final bool isEditing;

  const ClassesReviewView({
    super.key,
    required this.workingBlocks,
    this.workingAssetId,
    this.workingR2Key,
    this.workingLocalPreviewPath,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onCancel,
    required this.onScanAgain,
    VoidCallback? onAddBlock,
    VoidCallback? onAddClass,
    required this.onEditBlock,
    required this.onSave,
    this.frontBlockId,
    this.onFrontSelected,
    this.isSaving = false,
    this.isConcurrencyConflict = false,
    this.onReloadLatestSetup,
    this.droppedCount = 0,
    this.droppedExamples = const [],
    this.errorMessage,
    this.onClearError,
    this.isEditing = false,
  }) : onAddClass = onAddClass ?? onAddBlock ?? _noop;

  static void _noop() {}

  @override
  State<ClassesReviewView> createState() => _ClassesReviewViewState();
}

class _ClassesReviewViewState extends State<ClassesReviewView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static bool _hasOverlap(
    ClassRoutineBlock block,
    List<ClassRoutineBlock> allBlocks,
  ) {
    for (final other in allBlocks) {
      if (identical(other, block) || other.id == block.id) continue;
      final sharesDay = other.repeatDays.any(block.repeatDays.contains);
      if (!sharesDay) continue;
      if (other.startMinute < block.endMinute &&
          block.startMinute < other.endMinute) {
        return true;
      }
    }
    return false;
  }

  void _showPhotoViewer() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: BaseTimelinePhotoPreviewCard(
                localPreviewPath: widget.workingLocalPreviewPath,
                r2Key: widget.workingR2Key,
                assetId: widget.workingAssetId,
                title: 'Timetable Photo',
                height: MediaQuery.sizeOf(context).height * 0.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: true,
    );
    final blockMap = {for (final b in widget.workingBlocks) b.id: b};

    final hasPhoto =
        widget.workingLocalPreviewPath != null ||
        widget.workingR2Key != null ||
        widget.workingAssetId != null;

    final subtitle = widget.droppedCount > 0
        ? '${widget.workingBlocks.length} classes scheduled · ${widget.droppedCount} ${widget.droppedCount == 1 ? 'entry was skipped' : 'entries were skipped'}'
        : '${widget.workingBlocks.length} classes scheduled';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Shared Header Bar
          BaseTimelineEditorHeader(
            title: 'Review Timetable',
            subtitle: subtitle,
            onCancel: widget.onCancel,
            isSaving: widget.isSaving,
          ),

          // 2. Responsive Compact Action Buttons
          BaseTimelineEditorActionRow(
            primaryAction: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: OptivusColors.blueAccent.withValues(
                  alpha: 0.12,
                ),
                side: BorderSide(
                  color: OptivusColors.blueAccent.withValues(alpha: 0.5),
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
                Icons.photo_library_outlined,
                size: 18,
                color: OptivusColors.blueAccent,
              ),
              label: Text(
                hasPhoto ? 'Change photo' : 'Add photo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: OptivusColors.blueAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: widget.isSaving ? null : widget.onScanAgain,
            ),
            secondaryAction: OutlinedButton.icon(
              key: const Key('classes-review-add-class-button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
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
                'Add class',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OptivusColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: widget.isSaving ? null : widget.onAddClass,
            ),
          ),

          // Error Banner
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: OptivusColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: OptivusColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: OptivusColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: const TextStyle(
                          color: OptivusColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (widget.onClearError != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: OptivusColors.textSecondary,
                        ),
                        onPressed: widget.onClearError,
                      ),
                  ],
                ),
              ),
            ),

          // Concurrency Conflict Banner
          if (widget.isConcurrencyConflict)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OptivusColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OptivusColors.danger, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: OptivusColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your schedule was updated on another device.',
                      style: TextStyle(
                        color: OptivusColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.onReloadLatestSetup != null)
                    TextButton(
                      onPressed: widget.onReloadLatestSetup,
                      child: const Text('Reload'),
                    ),
                ],
              ),
            ),

          // Compact Photo Row
          if (hasPhoto)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: _showPhotoViewer,
                borderRadius: BorderRadius.circular(OptivusRadii.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(OptivusRadii.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: OptivusColors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Timetable Photo',
                          style: TextStyle(
                            color: OptivusColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'Tap to view',
                        style: TextStyle(
                          color: OptivusColors.blueAccent.withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: OptivusColors.blueAccent.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Interactive Timeline / Empty Draft
          Expanded(
            child: widget.workingBlocks.isEmpty
                ? BaseTimelineEmptyDraftView(
                    title: 'No classes in draft',
                    subtitle:
                        'Tap "Add class" above to manually add your subjects, or scan your timetable photo.',
                    icon: Icons.school_outlined,
                    accent: OptivusColors.blueAccent,
                    actionLabel: 'Add class',
                    onAction: widget.onAddClass,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1.0);
                      final entries = widget.workingBlocks.expand((b) {
                        final hasOverlap = _hasOverlap(b, widget.workingBlocks);
                        final cardWidth =
                            WorkTimelineLayoutHelper.effectiveCardWidth(
                              availableWidth: constraints.maxWidth,
                              hasOverlap: hasOverlap,
                            );
                        return adapter.toEntries(
                          b,
                          contentWidth: cardWidth,
                          textScale: textScale,
                          isEditable: !widget.isSaving,
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
                        onFrontSelected: (id) =>
                            widget.onFrontSelected?.call(id),
                        styleBuilder: (entry) => adapter.styleForEntry(entry),
                        blockBuilder: (context, positioned) {
                          final block = blockMap[positioned.entry.sourceId];
                          return ClassTimelineCard(
                            positioned: positioned,
                            block: block,
                            isEditable: !widget.isSaving,
                            accent: OptivusColors.blueAccent,
                            onTap: () {
                              if (positioned.hasOverlap &&
                                  !positioned.isFront) {
                                HapticFeedback.lightImpact();
                                widget.onFrontSelected?.call(
                                  positioned.entry.id,
                                );
                              } else if (block != null && !widget.isSaving) {
                                widget.onEditBlock(block);
                              }
                            },
                          );
                        },
                        onEntryTapped: null,
                        accent: OptivusColors.blueAccent,
                        mode: TimelineMode.fullScreenEditable,
                        geometryConfig: const TimelineGeometryConfig(
                          bottomPadding: 100.0,
                        ),
                        visibleRangePolicy:
                            TimelineVisibleRangePolicy.contentAdaptive,
                        autoScrollToFirstEntry: false,
                        stretchPolicy: TimelineStretchPolicy.constraintBased,
                        emptyDayMessage: 'No classes on this day.',
                      );
                    },
                  ),
          ),

          // 5. Sticky Bottom Action Bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('classes-review-use-timetable-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OptivusColors.blueAccent,
                    disabledBackgroundColor: OptivusColors.blueAccent
                        .withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OptivusRadii.lg),
                    ),
                    elevation: 0,
                  ),
                  onPressed: widget.isSaving ? null : widget.onSave,
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
                      : Text(
                          widget.isEditing
                              ? 'Save changes'
                              : 'Use this timetable',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
