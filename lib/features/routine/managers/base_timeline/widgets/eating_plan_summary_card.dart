import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_plan_freshness.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Clean, unified presentation summary for the configured Eating section.
///
/// Follows the Base Timeline context card design system shared with
/// Classes ([BaseTimelineSetupContextCard]) and Work ([WorkSetupProfileSummaryCard]):
/// - Outer container: glass background, 14px radius ([OptivusRadii.cardStandard]),
///   standard subtle border ([OptivusColors.borderStandard]), and 14×10 inner padding.
/// - Top row: Category in 10px uppercase accent color ([OptivusColors.roseAccent]) with
///   a domain icon, paired with status and goal badges.
/// - Middle row: 15px bold headline, 12px subline with truthful target representation
///   (custom target vs calculated from Body Basics), and non-destructive action button
///   (Plan settings or View photo).
/// - Bottom row: 11px schedule and source details with 13px muted icons.
/// - Integrated freshness warning if preferences drifted.
class EatingPlanSummaryCard extends StatelessWidget {
  final BaseTimelineSetup setup;
  final bool isStale;
  final EatingPlanFreshness? freshness;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRegenerate;
  final VoidCallback? onViewPhoto;

  const EatingPlanSummaryCard({
    super.key,
    required this.setup,
    this.isStale = false,
    this.freshness,
    this.onOpenSettings,
    this.onRegenerate,
    this.onViewPhoto,
  });

  EatingPlanFreshness get effectiveFreshness =>
      freshness ??
      (isStale ? EatingPlanFreshness.stale : EatingPlanFreshness.current);

  @override
  Widget build(BuildContext context) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.eating);
    final origin = snapshot.origin;
    final hasSourcePhoto =
        origin == BaseSetupOrigin.photo ||
        snapshot.sourceR2Key != null ||
        snapshot.sourceAssetId != null ||
        setup.eatingPhotoR2Key != null ||
        setup.eatingPhotoAssetId != null ||
        setup.eatingSetupPath == 'has_routine' ||
        setup.eatingSetupPath == 'photo';

    final category = _categoryTitle(origin, hasSourcePhoto);
    final categoryIcon = _categoryIcon(origin, hasSourcePhoto);
    final badges = _resolveBadges(origin, hasSourcePhoto);
    final headline = _resolveHeadline(origin, hasSourcePhoto);
    final subline = _resolveSubline(origin, hasSourcePhoto);

    final actionLabel = _actionLabel(origin, hasSourcePhoto);
    final actionIcon = _actionIcon(origin, hasSourcePhoto);
    final onAction = _actionCallback(origin, hasSourcePhoto);
    final actionKey = _actionKey(origin, hasSourcePhoto);

    final scheduleDesc = EatingPresentationUtils.scheduleSummary(
      setup.eatingBlocks,
    );
    final sourceLabel = _sourceLabel(origin, hasSourcePhoto);
    final sourceIcon = _sourceIcon(origin, hasSourcePhoto);

    return Container(
      key: const Key('eating-plan-summary-card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(OptivusRadii.cardStandard),
        border: Border.all(
          color: OptivusColors.borderStandard.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header row: Category tag & Badges
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcon,
                          size: 12,
                          color: OptivusColors.roseAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: OptivusColors.roseAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    if (badges.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: badges.map((badge) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: OptivusColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          // 2. Headline, Subline & Action Button
          LayoutBuilder(
            builder: (context, constraints) {
              final textScaler = MediaQuery.textScalerOf(context);
              final hasLargeText = textScaler.scale(14) > 18;
              final isNarrow = constraints.maxWidth < 280;

              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OptivusColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (subline != null && subline.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              );

              final actionBtn = (actionLabel != null && onAction != null)
                  ? TextButton.icon(
                      key: actionKey,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: OptivusColors.roseAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: OptivusColors.roseAccent.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                      onPressed: onAction,
                      icon: Icon(
                        actionIcon ?? Icons.visibility_outlined,
                        size: 14,
                      ),
                      label: Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null;

              if (actionBtn == null) {
                return titleSection;
              }

              if (isNarrow || hasLargeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleSection,
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerLeft, child: actionBtn),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 8),
                  actionBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 6),

          // 3. Compact Schedule & Source Row
          LayoutBuilder(
            builder: (context, constraints) {
              final textScaler = MediaQuery.textScalerOf(context);
              final hasLargeText = textScaler.scale(14) > 18;
              final isVeryNarrow = constraints.maxWidth < 240;

              final scheduleWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 13,
                    color: OptivusColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      scheduleDesc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );

              final sourceWidget = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  Icon(sourceIcon, size: 13, color: OptivusColors.textMuted),
                  Text(
                    sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OptivusColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );

              if (isVeryNarrow || hasLargeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    scheduleWidget,
                    const SizedBox(height: 3),
                    sourceWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: scheduleWidget),
                  const SizedBox(width: 8),
                  sourceWidget,
                ],
              );
            },
          ),

          // 4. Stale plan warning notice if freshness drifted
          if (effectiveFreshness == EatingPlanFreshness.stale) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: OptivusColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: OptivusColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: OptivusColors.warning,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Your Eating Plan was generated from older preferences.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                  if (onRegenerate != null)
                    TextButton(
                      key: const Key('eating-summary-stale-regenerate-button'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: OptivusColors.warning,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onRegenerate,
                      child: const Text(
                        'Regenerate plan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (effectiveFreshness == EatingPlanFreshness.unknown) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: OptivusColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: OptivusColors.warning.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 14,
                    color: OptivusColors.warning,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Plan freshness couldn't be checked. Review Body Basics before regenerating.",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _categoryTitle(BaseSetupOrigin origin, bool hasSourcePhoto) {
    if (hasSourcePhoto) return 'Meal plan photo';
    if (origin == BaseSetupOrigin.manual) return 'Manual meal plan';
    if (origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual') {
      return 'Manual meal plan';
    }
    return 'Nutrition plan';
  }

  IconData _categoryIcon(BaseSetupOrigin origin, bool hasSourcePhoto) {
    if (hasSourcePhoto) return Icons.photo_library_outlined;
    if (origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual') {
      return Icons.edit_note_rounded;
    }
    return Icons.restaurant_rounded;
  }

  List<String> _resolveBadges(BaseSetupOrigin origin, bool hasSourcePhoto) {
    final isManual =
        origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual';
    final list = <String>[];
    if (hasSourcePhoto) {
      if (setup.eatingBlocks.isNotEmpty) {
        list.add('${setup.eatingBlocks.length} meals');
      }
      list.add('Photo synced');
      final coverage = _calculateMacroCoverage(setup.eatingBlocks);
      if (coverage != 'Not estimated' && coverage != 'None') {
        list.add('$coverage macros');
      }
    } else if (isManual) {
      list.add('Custom plan');
      if (setup.eatingBlocks.isNotEmpty) {
        list.add('${setup.eatingBlocks.length} meals');
      }
      final coverage = _calculateMacroCoverage(setup.eatingBlocks);
      if (coverage != 'Not estimated' && coverage != 'None') {
        list.add('$coverage macros');
      }
    } else {
      list.add(
        setup.eatingCustomized ? 'Customized' : 'Built for me',
      );
      if (setup.mealPlanningGoal != null &&
          setup.mealPlanningGoal!.trim().isNotEmpty) {
        list.add(_formatGoal(setup.mealPlanningGoal!));
      }
      if (setup.eatingBlocks.isNotEmpty) {
        list.add('${setup.eatingBlocks.length} meals');
      }
    }
    return list;
  }

  String _resolveHeadline(BaseSetupOrigin origin, bool hasSourcePhoto) {
    final isManual =
        origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual';
    if (hasSourcePhoto) {
      return 'Imported Meal Plan';
    } else if (isManual) {
      return 'Manual Eating Plan';
    } else {
      final goal = setup.mealPlanningGoal?.trim().toLowerCase();
      if (goal != null && goal.isNotEmpty) {
        return switch (goal) {
          'gain' => 'Weight Gain Plan',
          'lose' => 'Weight Loss Plan',
          'maintain' => 'Maintain Weight Plan',
          _ => '${_formatGoal(setup.mealPlanningGoal!)} Plan',
        };
      }
      return 'Daily Nutrition Plan';
    }
  }

  String? _resolveSubline(BaseSetupOrigin origin, bool hasSourcePhoto) {
    final isManual =
        origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual';
    if (hasSourcePhoto) {
      return 'Scanned meal schedule photo';
    } else if (isManual) {
      return 'Custom daily meal schedule';
    } else {
      final hasOverride = setup.hasTargetOverrides;
      final cal = setup.targetCaloriesOverride ?? setup.targetCalories;
      final prot = setup.targetProteinOverride ?? setup.targetProtein;
      final targetStr = (cal != null && prot != null)
          ? '$cal kcal · $prot g protein'
          : (cal != null
                ? '$cal kcal/day'
                : (prot != null ? '$prot g protein/day' : 'Not set'));
      return (cal != null || prot != null)
          ? (hasOverride
                ? '$targetStr (Custom target)'
                : '$targetStr (Calculated from Body Basics)')
          : 'Targets not configured';
    }
  }

  String? _actionLabel(BaseSetupOrigin origin, bool hasSourcePhoto) {
    if (hasSourcePhoto && onViewPhoto != null) {
      return 'View photo';
    }
    if (origin != BaseSetupOrigin.photo &&
        origin != BaseSetupOrigin.manual &&
        setup.eatingSetupPath != 'photo' &&
        setup.eatingSetupPath != 'manual' &&
        onOpenSettings != null) {
      return 'Plan settings';
    }
    return null;
  }

  IconData? _actionIcon(BaseSetupOrigin origin, bool hasSourcePhoto) {
    if (hasSourcePhoto && onViewPhoto != null) {
      return Icons.visibility_outlined;
    }
    if (origin != BaseSetupOrigin.photo &&
        origin != BaseSetupOrigin.manual &&
        setup.eatingSetupPath != 'photo' &&
        setup.eatingSetupPath != 'manual' &&
        onOpenSettings != null) {
      return Icons.tune_rounded;
    }
    return null;
  }

  VoidCallback? _actionCallback(BaseSetupOrigin origin, bool hasSourcePhoto) {
    if (hasSourcePhoto && onViewPhoto != null) {
      return onViewPhoto;
    }
    if (origin != BaseSetupOrigin.photo &&
        origin != BaseSetupOrigin.manual &&
        setup.eatingSetupPath != 'photo' &&
        setup.eatingSetupPath != 'manual' &&
        onOpenSettings != null) {
      return onOpenSettings;
    }
    return null;
  }

  Key? _actionKey(BaseSetupOrigin origin, bool hasSourcePhoto) {
    if (hasSourcePhoto && onViewPhoto != null) {
      return const Key('eating-summary-view-photo-button');
    }
    if (origin != BaseSetupOrigin.photo &&
        origin != BaseSetupOrigin.manual &&
        setup.eatingSetupPath != 'photo' &&
        setup.eatingSetupPath != 'manual' &&
        onOpenSettings != null) {
      return const Key('eating-summary-plan-settings-button');
    }
    return null;
  }

  String _sourceLabel(BaseSetupOrigin origin, bool hasSourcePhoto) {
    final isManual =
        origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual';
    if (hasSourcePhoto) return 'Meal plan photo';
    if (isManual) return 'Manual setup';
    return setup.eatingCustomized ? 'Built for me · Customized' : 'Built for me';
  }

  IconData _sourceIcon(BaseSetupOrigin origin, bool hasSourcePhoto) {
    final isManual =
        origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual';
    if (hasSourcePhoto) return Icons.photo_library_outlined;
    if (isManual) return Icons.edit_note_rounded;
    return Icons.auto_awesome_rounded;
  }

  String _formatGoal(String goal) {
    return switch (goal.trim().toLowerCase()) {
      'gain' => 'Gain weight',
      'lose' => 'Lose weight',
      'maintain' => 'Maintain weight',
      _ => goal,
    };
  }

  String _calculateMacroCoverage(List<TimelineBlockDraft> blocks) {
    if (blocks.isEmpty) return 'None';
    var hasCal = 0;
    var hasProt = 0;
    for (final b in blocks) {
      if (b.calories != null && b.calories! > 0) hasCal++;
      if (b.protein != null && b.protein! > 0) hasProt++;
    }
    if (hasCal == blocks.length && hasProt == blocks.length) {
      return 'Complete';
    }
    if (hasCal > 0 || hasProt > 0) {
      return 'Partial';
    }
    return 'Not estimated';
  }
}
