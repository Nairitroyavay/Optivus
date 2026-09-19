import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Modal bottom sheet displaying complete details for a Meal block on the Base Timeline.
class EatingMealDetailSheet extends StatelessWidget {
  final TimelineBlockDraft block;
  final VoidCallback? onEdit;
  final String? editLabel;

  const EatingMealDetailSheet({
    super.key,
    required this.block,
    this.onEdit,
    this.editLabel,
  });

  static Future<void> show(
    BuildContext context,
    TimelineBlockDraft block, {
    VoidCallback? onEdit,
    String? editLabel,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EatingMealDetailSheet(
        block: block,
        onEdit: onEdit,
        editLabel: editLabel,
      ),
    );
  }

  String _formatDays(List<int> repeatDays) {
    if (repeatDays.isEmpty) return 'No days scheduled';
    final sorted = repeatDays.toSet().toList()..sort();
    if (sorted.length == 7) return 'Every day (Mon – Sun)';
    if (sorted.length == 5 &&
        sorted[0] == 1 &&
        sorted[1] == 2 &&
        sorted[2] == 3 &&
        sorted[3] == 4 &&
        sorted[4] == 5) {
      return 'Weekdays (Mon – Fri)';
    }
    if (sorted.length == 2 && sorted[0] == 6 && sorted[1] == 7) {
      return 'Weekends (Sat, Sun)';
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return sorted
        .where((d) => d >= 1 && d <= 7)
        .map((d) => dayNames[d - 1])
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final title = block.title.trim().isNotEmpty
        ? block.title.trim()
        : EatingPresentationUtils.formatSlotName(
            block.mealSlot,
            block.mealCategory,
          );
    final slotLabel = EatingPresentationUtils.formatSlotName(
      block.mealSlot,
      block.mealCategory,
    );
    final dishes = block.dishes.where((d) => d.trim().isNotEmpty).toList();
    final calories = block.calories;
    final protein = block.protein;
    final location = block.location?.trim() ?? '';
    final notes = block.notes?.trim() ?? '';

    final durationMin = block.endMinute - block.startMinute;
    final durationStr = durationMin > 0
        ? (durationMin >= 60
              ? '${durationMin ~/ 60}h${durationMin % 60 > 0 ? ' ${durationMin % 60}m' : ''}'
              : '${durationMin}m')
        : '';

    return SafeArea(
      bottom: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Slot Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: OptivusColors.roseAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: OptivusColors.roseAccent.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: OptivusColors.roseAccent.withValues(
                                alpha: 0.25,
                              ),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            slotLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.roseAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Time & Duration
              _buildSectionHeader('Schedule & Timing', Icons.schedule_rounded),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: OptivusColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          size: 16,
                          color: OptivusColors.roseAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TimelineUtils.formatTimeRange(
                            block.startMinute,
                            block.endMinute,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        if (durationStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '($durationStr)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: OptivusColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDays(block.repeatDays),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Dishes
              _buildSectionHeader(
                'Dishes & Food Items',
                Icons.menu_book_rounded,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: OptivusColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: dishes.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dishes
                            .map(
                              (d) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: OptivusColors.roseAccent,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        d,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: OptivusColors.textPrimary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : const Text(
                        'No specific dishes listed.',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(height: 18),

              // Nutrition
              if (calories != null || protein != null) ...[
                _buildSectionHeader('Estimated Nutrition', Icons.bolt_rounded),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: OptivusColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (calories != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: OptivusColors.roseAccent.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: OptivusColors.roseAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '~$calories kcal',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: OptivusColors.roseAccent,
                                ),
                              ),
                            ),
                          if (calories != null && protein != null)
                            const SizedBox(width: 8),
                          if (protein != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: OptivusColors.blueAccent.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: OptivusColors.blueAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${protein.round()}g protein',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: OptivusColors.blueAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Estimates are calculated per meal and may vary based on portion sizes and cooking methods.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: OptivusColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Location
              if (location.isNotEmpty) ...[
                _buildSectionHeader('Location', Icons.place_outlined),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: OptivusColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Notes
              if (notes.isNotEmpty) ...[
                _buildSectionHeader('Notes & Reminders', Icons.notes_rounded),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: OptivusColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: OptivusColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Actions
              if (onEdit != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('eating-meal-detail-sheet-edit-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OptivusColors.roseAccent,
                      side: const BorderSide(color: OptivusColors.roseAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      editLabel ?? 'Edit this meal',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit!();
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: OptivusColors.roseAccent),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
