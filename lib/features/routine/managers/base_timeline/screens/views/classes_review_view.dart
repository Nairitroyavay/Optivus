import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_timeline_card.dart';

/// Review and edit stage for Classes Base Timeline setup.
class ClassesReviewView extends StatelessWidget {
  final List<ClassRoutineBlock> workingBlocks;
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
  final VoidCallback onAddClass;
  final void Function(ClassRoutineBlock block) onEditBlock;
  final VoidCallback onSave;
  final String? frontBlockId;
  final ValueChanged<String>? onFrontSelected;

  const ClassesReviewView({
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
    required this.onAddClass,
    required this.onEditBlock,
    required this.onSave,
    this.frontBlockId,
    this.onFrontSelected,
  });

  @override
  Widget build(BuildContext context) {
    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: true,
    );

    final entries = workingBlocks.expand((b) => adapter.toEntries(b)).toList();
    final blockMap = {for (final b in workingBlocks) b.id: b};

    final sanitizedIssues = ClassSetupErrorMapper.sanitizeDroppedExamples(
      droppedExamples,
    );
    final droppedSummary = ClassSetupErrorMapper.formatDroppedSummary(
      droppedCount,
      sanitizedIssues,
    );

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: isSaving ? null : onCancel,
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
                        'Review Timetable',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        droppedCount > 0
                            ? '${workingBlocks.length} classes scheduled · $droppedCount ${droppedCount == 1 ? 'entry was skipped' : 'entries were skipped'}'
                            : '${workingBlocks.length} classes scheduled',
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

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: OptivusColors.blueAccent.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Scan Again'),
                    onPressed: isSaving ? null : onScanAgain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Class'),
                    onPressed: isSaving ? null : onAddClass,
                  ),
                ),
              ],
            ),
          ),

          // Scanned Photo Preview (Immediate local preview if available)
          if (workingLocalPreviewPath != null || workingR2Key != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: BaseTimelinePhotoPreviewCard(
                localPreviewPath: workingLocalPreviewPath,
                r2Key: workingR2Key,
                assetId: workingAssetId,
                title: 'Scanned Timetable Photo',
                height: 110,
              ),
            ),

          // Sanitized attention banner for dropped entries
          if (droppedCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OptivusColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: OptivusColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: OptivusColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      droppedSummary,
                      style: const TextStyle(
                        color: OptivusColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Inline Error Message Banner
          if (errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OptivusColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: OptivusColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: OptivusColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: OptivusColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: OptivusColors.danger,
                    ),
                    onPressed: onClearError,
                  ),
                ],
              ),
            ),

          // Timeline View
          Expanded(
            child: workingBlocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 48,
                            color: OptivusColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No classes scheduled',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap "Add Class" or scan another photo to get started.',
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
                : FullScreenTimelineScaffold(
                    entries: entries,
                    selectedDay: selectedDay,
                    onDayChanged: onDayChanged,
                    overlapPresentation:
                        TimelineOverlapPresentation.frontAndExposed,
                    frontEntryId: frontBlockId,
                    onFrontSelected: onFrontSelected,
                    styleBuilder: (entry) => adapter.styleForEntry(entry),
                    blockBuilder: (context, positioned) {
                      final block = blockMap[positioned.entry.sourceId];
                      return ClassTimelineCard(
                        positioned: positioned,
                        block: block,
                        isEditable: true,
                        accent: OptivusColors.blueAccent,
                        onTap: () {
                          if (positioned.hasOverlap && !positioned.isFront) {
                            onFrontSelected?.call(positioned.entry.id);
                          } else if (block != null) {
                            onEditBlock(block);
                          }
                        },
                      );
                    },
                    onEntryTapped: (entry) {
                      final block = blockMap[entry.sourceId];
                      if (block != null) {
                        onEditBlock(block);
                      }
                    },
                    accent: OptivusColors.blueAccent,
                    mode: TimelineMode.fullScreenEditable,
                    visibleRangePolicy:
                        TimelineVisibleRangePolicy.contentAdaptive,
                    stretchPolicy: TimelineStretchPolicy.constraintBased,
                    emptyDayMessage: 'No classes on this day.',
                  ),
          ),

          // Dominant 52px Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OptivusColors.blueAccent,
                  disabledBackgroundColor: OptivusColors.blueAccent.withValues(
                    alpha: 0.35,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: (isSaving || workingBlocks.isEmpty) ? null : onSave,
                child: isSaving
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
                        'Use this timetable',
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
