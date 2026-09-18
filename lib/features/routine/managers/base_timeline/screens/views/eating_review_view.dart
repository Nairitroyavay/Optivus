import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_day_summary_bar.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Review and edit stage for Eating Base Timeline setup.
///
/// Features:
/// - Clean top navigation with discard check
/// - Source label and action row (Plan settings / Add meal)
/// - Nutrition summary bar
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
  String _sourceLabelForPath(String? setupPath, bool customized) {
    return switch (setupPath) {
      'photo' || 'has_routine' => 'Imported from meal plan',
      'manual' => 'Manual plan',
      'create' => customized ? 'Built for me · Customized' : 'Built for me',
      _ => 'Eating plan',
    };
  }

  @override
  Widget build(BuildContext context) {
    const adapter = MealTimelineAdapter(accent: OptivusColors.roseAccent);

    final entries = widget.workingBlocks
        .expand((b) => adapter.toEntries(b))
        .toList();
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
                        widget.isNew
                            ? 'Review Meal Plan'
                            : 'Edit Eating Schedule',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.workingBlocks.length} ${widget.workingBlocks.length == 1 ? 'meal' : 'meals'} scheduled',
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

          // 2. Action row (Source & Add meal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Text(
                  'Source: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    _sourceLabelForPath(
                      widget.workingSetupPath,
                      widget.workingCustomized,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('base-timeline-edit-add-meal-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: OptivusColors.roseAccent.withValues(
                      alpha: 0.18,
                    ),
                    foregroundColor: OptivusColors.roseAccent,
                    side: BorderSide(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OptivusRadii.sm),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Add meal',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: widget.isSaving ? null : widget.onAddMeal,
                ),
              ],
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

          // 4. Day summary bar
          EatingDaySummaryBar(
            blocks: widget.workingBlocks,
            selectedDay: widget.selectedDay,
            targetCalories: widget.targetCalories,
            targetProtein: widget.targetProtein,
          ),

          // 5. Hero interactive timeline
          Expanded(
            child: FullScreenTimelineScaffold(
              entries: entries,
              selectedDay: widget.selectedDay,
              onDayChanged: widget.onDayChanged,
              styleBuilder: (entry) => adapter.styleForEntry(entry),
              overlapPresentation: TimelineOverlapPresentation.frontAndExposed,
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
                    if (positioned.hasOverlap && !positioned.isFront) {
                      HapticFeedback.lightImpact();
                      widget.onFrontSelected?.call(positioned.entry.id);
                    } else {
                      widget.onEditBlock(block);
                    }
                  },
                );
              },
              accent: OptivusColors.roseAccent,
              visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
              stretchPolicy: TimelineStretchPolicy.constraintBased,
              emptyDayMessage: 'No meals on this day.',
            ),
          ),

          // 6. Optional compact photo preview card
          if (isPhotoSetup && widget.workingR2Key != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: widget.workingR2Key,
                assetId: widget.workingAssetId,
                title: 'Meal plan photo',
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
                key: const Key('base-timeline-eating-save-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: OptivusColors.roseAccent,
                  disabledBackgroundColor: OptivusColors.roseAccent.withValues(
                    alpha: 0.35,
                  ),
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
        ],
      ),
    );
  }
}
