import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Full, truthful presentation summary for the configured Eating section.
///
/// Strictly obeys:
/// - Never transforms null targets or null preferences into fake defaults (2100 / 140 / 3).
/// - Differentiates Generated ("Built for me"), Photo ("Imported from meal plan"),
///   and Manual ("Manual plan").
/// - Flags customized generated plans truthfully ("Built for me · Customized").
/// - Detects stale generated plans (when preferences/body inputs drifted) with a Regenerate action.
/// - Secondary photo source display with a "View photo" action.
class EatingPlanSummaryCard extends StatelessWidget {
  final BaseTimelineSetup setup;
  final bool isStale;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRegenerate;
  final VoidCallback? onViewPhoto;

  const EatingPlanSummaryCard({
    super.key,
    required this.setup,
    this.isStale = false,
    this.onOpenSettings,
    this.onRegenerate,
    this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.eating);
    final origin = snapshot.origin;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 280;
                return Row(
                  children: [
                    Container(
                      width: isNarrow ? 30 : 34,
                      height: isNarrow ? 30 : 34,
                      decoration: BoxDecoration(
                        color: OptivusColors.roseAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: OptivusColors.roseAccent,
                        size: isNarrow ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isNarrow ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _planTitle(origin),
                            style: TextStyle(
                              fontSize: isNarrow ? 13 : 14,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _sourceDescription(origin),
                            style: TextStyle(
                              fontSize: isNarrow ? 11 : 12,
                              fontWeight: FontWeight.w500,
                              color: OptivusColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (origin == BaseSetupOrigin.generatedFromAnswers && onOpenSettings != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: OptivusColors.roseAccent,
                        ),
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: Text(
                          isNarrow ? 'Settings' : 'Plan settings >',
                          style: TextStyle(fontSize: isNarrow ? 11 : 12, fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (origin == BaseSetupOrigin.photo && onViewPhoto != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: OptivusColors.roseAccent,
                        ),
                        onPressed: onViewPhoto,
                        icon: const Icon(Icons.image_outlined, size: 14),
                        label: Text(
                          isNarrow ? 'Photo' : 'View photo >',
                          style: TextStyle(fontSize: isNarrow ? 11 : 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Stale generated plan notice
          if (isStale)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: OptivusColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: OptivusColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: OptivusColors.warning,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your Eating Plan was generated from older preferences.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                  if (onRegenerate != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: OptivusColors.warning,
                      ),
                      onPressed: onRegenerate,
                      child: const Text(
                        'Regenerate plan',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 1, color: Colors.white12),

          // Body content based on origin
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _buildBodyContent(context, origin),
          ),
        ],
      ),
    );
  }

  String _planTitle(BaseSetupOrigin origin) {
    return switch (origin) {
      BaseSetupOrigin.photo => 'IMPORTED EATING PLAN',
      BaseSetupOrigin.manual => 'MANUAL EATING PLAN',
      _ => 'YOUR EATING PLAN',
    };
  }

  String _sourceDescription(BaseSetupOrigin origin) {
    return switch (origin) {
      BaseSetupOrigin.photo => 'Meal plan photo',
      BaseSetupOrigin.manual => 'Created manually',
      _ => setup.eatingCustomized
          ? 'Built for me · Customized'
          : 'Built for me',
    };
  }

  Widget _buildBodyContent(BuildContext context, BaseSetupOrigin origin) {
    if (origin == BaseSetupOrigin.photo) {
      return _buildPhotoPlanDetails();
    } else if (origin == BaseSetupOrigin.manual) {
      return _buildManualPlanDetails();
    } else {
      return _buildGeneratedPlanDetails();
    }
  }

  Widget _buildGeneratedPlanDetails() {
    final cal = setup.targetCalories;
    final prot = setup.targetProtein;
    final targetStr = (cal != null && prot != null)
        ? '$cal kcal · $prot g protein'
        : (cal != null
            ? '$cal kcal/day'
            : (prot != null ? '$prot g protein/day' : 'Not set'));

    final goalStr = setup.mealPlanningGoal != null && setup.mealPlanningGoal!.trim().isNotEmpty
        ? _formatGoal(setup.mealPlanningGoal!)
        : 'Not set';

    final prefMeals = setup.mealsPerDay != null
        ? '${setup.mealsPerDay} meals/day'
        : 'Not set';

    final diet = EatingPresentationUtils.formatDiet(setup.foodType);
    final foodStyle = EatingPresentationUtils.formatFoodStyle(
      setup.eatingMode,
      setup.foodStyleCustomText,
    );

    final preferredTimes = EatingPresentationUtils.formatPreferredMealTimes(
      breakfast: setup.breakfastMinute,
      morningSnack: setup.extraSnackMinute,
      lunch: setup.lunchMinute,
      afternoonSnack: setup.snackMinute,
      dinner: setup.dinnerMinute,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Goal', goalStr),
        const SizedBox(height: 6),
        _buildInfoRow('Daily targets', targetStr),
        const SizedBox(height: 6),
        _buildInfoRow('Meal preference', prefMeals),
        const SizedBox(height: 6),
        _buildInfoRow('Diet', diet),
        const SizedBox(height: 6),
        _buildInfoRow('Food style', foodStyle),
        if (preferredTimes.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildInfoRow('Preferred times', preferredTimes),
        ],
      ],
    );
  }

  Widget _buildPhotoPlanDetails() {
    final scheduleDesc = EatingPresentationUtils.scheduleSummary(setup.eatingBlocks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Source', 'Meal plan photo'),
        const SizedBox(height: 6),
        _buildInfoRow('Schedule', scheduleDesc),
        const SizedBox(height: 6),
        _buildInfoRow('Nutrition estimates', _calculateMacroCoverage(setup.eatingBlocks)),
      ],
    );
  }

  Widget _buildManualPlanDetails() {
    final scheduleDesc = EatingPresentationUtils.scheduleSummary(setup.eatingBlocks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Source', 'Manual plan'),
        const SizedBox(height: 6),
        _buildInfoRow('Schedule', scheduleDesc),
        const SizedBox(height: 6),
        _buildInfoRow('Nutrition estimates', _calculateMacroCoverage(setup.eatingBlocks)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = constraints.maxWidth < 280 ? 90.0 : 120.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
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
