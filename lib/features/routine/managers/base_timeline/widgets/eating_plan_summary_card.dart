import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_plan_freshness.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_setup_context_card.dart';
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
/// - Context summary only (freshness warnings are owned by [EatingCurrentSetupView]).
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
    return KeyedSubtree(
      key: const Key('eating-plan-summary-card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: BaseTimelineSetupContextCard(
          category: category,
          title: headline,
          subtitle: subline,
          accent: OptivusColors.roseAccent,
          icon: categoryIcon,
          badges: badges,
          actionLabel: actionLabel,
          actionIcon: actionIcon,
          actionKey: hasSourcePhoto
              ? const Key('eating-summary-view-photo-button')
              : const Key('eating-summary-plan-settings-button'),
          onAction: onAction,
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _EatingContextLine(
                icon: Icons.event_note_rounded,
                text: EatingPresentationUtils.scheduleSummary(
                  setup.eatingBlocks,
                ),
              ),
              const SizedBox(height: 3),
              _EatingContextLine(
                icon: _sourceIcon(origin, hasSourcePhoto),
                text: _sourceLabel(origin, hasSourcePhoto),
              ),
            ],
          ),
        ),
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
      list.add(setup.eatingCustomized ? 'Customized' : 'Built for me');
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
      final target = (cal != null && prot != null)
          ? '$cal kcal · $prot g protein'
          : (cal != null
                ? '$cal kcal/day'
                : (prot != null ? '$prot g protein/day' : 'Not set'));
      return (cal != null || prot != null)
          ? (hasOverride
                ? '$target (Custom target)'
                : '$target (Calculated from Body Basics)')
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

  String _sourceLabel(BaseSetupOrigin origin, bool hasSourcePhoto) {
    final isManual =
        origin == BaseSetupOrigin.manual || setup.eatingSetupPath == 'manual';
    if (hasSourcePhoto) return 'Meal plan photo';
    if (isManual) return 'Manual setup';
    return setup.eatingCustomized
        ? 'Built for me · Customized'
        : 'Built for me';
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

class _EatingContextLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EatingContextLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: OptivusColors.textMuted),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: OptivusColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
