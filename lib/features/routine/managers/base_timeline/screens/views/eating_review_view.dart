import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_editor_action_row.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_editor_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_empty_draft_view.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Review and edit stage for Eating Base Timeline setup.
///
/// Features:
/// - Clean top navigation with discard check
/// - Source label and action row (Plan settings / Add meal)
/// - Hero interactive timeline with editable meal cards
/// - Dominant 52px bottom CTA with floating tab bar reserve
class EatingReviewView extends StatefulWidget {
  final List<TimelineBlockDraft> workingBlocks;
  final String? workingAssetId;
  final String? workingR2Key;
  final String? workingSetupPath;
  final bool workingCustomized;
  final int? targetCalories;
  final int? targetProtein;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final String? errorMessage;
  final VoidCallback onClearError;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onAddMeal;
  final void Function(TimelineBlockDraft block) onEditBlock;
  final VoidCallback onSave;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onChangePhoto;
  final String? frontBlockId;
  final ValueChanged<String>? onFrontSelected;
  final bool isNew;
  final String? primaryCtaLabel;

  const EatingReviewView({
    super.key,
    required this.workingBlocks,
    required this.workingAssetId,
    required this.workingR2Key,
    required this.workingSetupPath,
    required this.workingCustomized,
    required this.targetCalories,
    required this.targetProtein,
    required this.selectedDay,
    required this.onDayChanged,
    required this.errorMessage,
    required this.onClearError,
    required this.isSaving,
    required this.onCancel,
    required this.onAddMeal,
    required this.onEditBlock,
    required this.onSave,
    this.onOpenSettings,
    this.onChangePhoto,
    this.frontBlockId,
    this.onFrontSelected,
    this.isNew = false,
    this.primaryCtaLabel,
  });

  @override
  State<EatingReviewView> createState() => _EatingReviewViewState();
}

class _EatingReviewViewState extends State<EatingReviewView> {
  @override
  Widget build(BuildContext context) {
    final blockMap = {for (final b in widget.workingBlocks) b.id: b};

    final isPhotoSetup =
        widget.workingSetupPath == 'photo' ||
        widget.workingSetupPath == 'has_routine' ||
        widget.workingAssetId != null;

    final ctaText =
        widget.primaryCtaLabel ??
        (widget.isNew ? 'Use this meal plan' : 'Save changes');

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar
          BaseTimelineEditorHeader(
            title: widget.isNew ? 'Review Meal Plan' : 'Edit Eating Schedule',
            subtitle:
                '${widget.workingBlocks.length} ${widget.workingBlocks.length == 1 ? 'meal' : 'meals'} scheduled',
            onCancel: widget.onCancel,
            isSaving: widget.isSaving,
          ),

          // 2. Compact Action Buttons (matching Classes and Work)
          BaseTimelineEditorActionRow(
            primaryAction: isPhotoSetup
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: OptivusColors.roseAccent.withValues(
                        alpha: 0.12,
                      ),
                      side: BorderSide(
                        color: OptivusColors.roseAccent.withValues(alpha: 0.5),
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
                      color: OptivusColors.roseAccent,
                    ),
                    label: Text(
                      (widget.workingR2Key != null ||
                              widget.workingAssetId != null)
                          ? 'Change photo'
                          : 'Add photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.roseAccent,
                      ),
                    ),
                    onPressed: widget.isSaving ? null : widget.onChangePhoto,
                  )
                : (widget.onOpenSettings != null
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: OptivusColors.roseAccent
                                .withValues(alpha: 0.12),
                            side: BorderSide(
                              color: OptivusColors.roseAccent.withValues(
                                alpha: 0.5,
                              ),
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
                            Icons.tune_rounded,
                            size: 18,
                            color: OptivusColors.roseAccent,
                          ),
                          label: const Text(
                            'Plan settings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.roseAccent,
                            ),
                          ),
                          onPressed: widget.isSaving
                              ? null
                              : widget.onOpenSettings,
                        )
                      : null),
            secondaryAction: OutlinedButton.icon(
              key: const Key('base-timeline-edit-add-meal-button'),
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
                'Add meal',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textPrimary,
                ),
              ),
              onPressed: widget.isSaving ? null : widget.onAddMeal,
            ),
          ),

          // 3. Error Banner
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

          // 4. Hero interactive timeline or Empty Draft View
          Expanded(
            child: widget.workingBlocks.isEmpty
                ? BaseTimelineEmptyDraftView(
                    icon: Icons.restaurant_outlined,
                    title: 'No meals scheduled yet',
                    subtitle:
                        'Add meals across your week, or use AI generation to create a balanced schedule.',
                    actionLabel: 'Add your first meal',
                    actionKey: const Key('base-timeline-empty-add-meal-button'),
                    accent: OptivusColors.roseAccent,
                    onAction: widget.onAddMeal,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final textScaler = MediaQuery.maybeTextScalerOf(context);
                      final textScale = textScaler?.scale(1.0) ?? 1.0;
                      final availableWidth = constraints.maxWidth > 72
                          ? constraints.maxWidth - 72
                          : constraints.maxWidth;
                      final adapter = MealTimelineAdapter(
                        accent: OptivusColors.roseAccent,
                        contentWidth: availableWidth,
                        textScale: textScale,
                      );
                      final entries = widget.workingBlocks
                          .expand((b) => adapter.toEntries(b))
                          .toList();

                      return FullScreenTimelineScaffold(
                        entries: entries,
                        selectedDay: widget.selectedDay,
                        onDayChanged: widget.onDayChanged,
                        styleBuilder: (entry) => adapter.styleForEntry(entry),
                        overlapPresentation:
                            TimelineOverlapPresentation.frontAndExposed,
                        frontEntryId: widget.frontBlockId,
                        onFrontSelected: widget.onFrontSelected,
                        blockBuilder: (context, positioned) {
                          final block = blockMap[positioned.entry.sourceId];
                          if (block == null) return const SizedBox.shrink();
                          return BaseTimelineDomainCard(
                            positioned: positioned,
                            block: block,
                            domain: BaseTimelineCardDomain.eating,
                            accent: OptivusColors.roseAccent,
                            isEditable: true,
                            onTap: () {
                              if (positioned.hasOverlap &&
                                  !positioned.isFront) {
                                HapticFeedback.lightImpact();
                                widget.onFrontSelected?.call(
                                  positioned.entry.id,
                                );
                              } else {
                                widget.onEditBlock(block);
                              }
                            },
                          );
                        },
                        accent: OptivusColors.roseAccent,
                        visibleRangePolicy:
                            TimelineVisibleRangePolicy.contentAdaptive,
                        stretchPolicy: TimelineStretchPolicy.constraintBased,
                        emptyDayMessage: 'No meals on this day.',
                      );
                    },
                  ),
          ),

          // 7. Dominant 52px Bottom CTA with Floating Tab Bar Clearance
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('base-timeline-eating-save-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OptivusColors.roseAccent,
                    disabledBackgroundColor: OptivusColors.roseAccent
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
                          ctaText,
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
