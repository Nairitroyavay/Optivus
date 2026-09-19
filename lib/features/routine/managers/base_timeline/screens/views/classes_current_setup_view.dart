import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_setup_context_card.dart';
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
  final ValueChanged<ClassRoutineBlock>? onEditBlock;
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
    this.onEditBlock,
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

  void _showPhotoDialog(BuildContext context, String? r2Key, String? assetId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        final previewHeight = (screenHeight * 0.45).clamp(200.0, 420.0);
        return Dialog(
          backgroundColor: OptivusColors.backgroundBottom,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Timetable Photo',
                      style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.setup.snapshotFor(BaseTimelineSection.classes);

    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: false,
    );
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
                (snapshot.isConfigured ? 'Edit schedule' : 'Set up Classes'),
            primaryButtonKey: const Key(
              'base-timeline-header-edit-schedule-button',
            ),
            iconOnly: true,
            onPrimaryAction: snapshot.isConfigured
                ? (widget.onEditSchedule ?? widget.onChangeSetup)
                : widget.onChangeSetup,
            changeSourceLabel: 'Change source',
            onChangeSource: snapshot.isConfigured
                ? widget.onChangeSource
                : null,
            removeLabel: 'Remove setup',
            onRemove: snapshot.isConfigured ? widget.onRemoveSetup : null,
          ),

          // Routine Refresh Pending Banner
          if (widget.routineRefreshPending && widget.onRetryRefresh != null)
            BaseTimelineRefreshPendingBanner(
              message: widget.routineRefreshMessage,
              onRetry: widget.onRetryRefresh!,
            ),

          // 2. Compact Setup Context Card directly below header
          if (snapshot.isConfigured || widget.routineBlocks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: BaseTimelineSetupContextCard(
                category: hasSourcePhoto ? 'Timetable photo' : 'Class schedule',
                title: hasSourcePhoto
                    ? 'Scanned Semester Timetable'
                    : 'Manual Academic Schedule',
                subtitle:
                    '${widget.routineBlocks.length} classes active across your week',
                accent: OptivusColors.blueAccent,
                icon: hasSourcePhoto
                    ? Icons.photo_library_outlined
                    : Icons.school_outlined,
                badges: [
                  '${widget.routineBlocks.length} classes',
                  if (hasSourcePhoto) 'Photo synced',
                ],
                actionLabel: hasSourcePhoto ? 'View photo' : null,
                actionIcon: Icons.visibility_outlined,
                onAction: hasSourcePhoto
                    ? () => _showPhotoDialog(
                        context,
                        snapshot.sourceR2Key,
                        snapshot.sourceAssetId,
                      )
                    : null,
              ),
            ),

          // 3. Timeline View
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final entries = widget.routineBlocks.expand((b) {
                  final hasOverlap = _hasOverlap(b, widget.routineBlocks);
                  final cardWidth = WorkTimelineLayoutHelper.effectiveCardWidth(
                    availableWidth: constraints.maxWidth,
                    hasOverlap: hasOverlap,
                  );
                  return adapter.toEntries(
                    b,
                    contentWidth: cardWidth,
                    textScale: textScale,
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
                          ClassDetailSheet.show(
                            context,
                            block,
                            onEdit: widget.onEditBlock != null
                                ? () => widget.onEditBlock!(block)
                                : widget.onEditSchedule,
                          );
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
                  visibleRangePolicy:
                      TimelineVisibleRangePolicy.contentAdaptive,
                  autoScrollToFirstEntry: false,
                  stretchPolicy: TimelineStretchPolicy.constraintBased,
                  emptyDayMessage: 'No classes on this day',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
