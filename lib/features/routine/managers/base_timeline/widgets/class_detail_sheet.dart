import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

/// Modal bottom sheet displaying all stored details for a class block.
class ClassDetailSheet extends StatelessWidget {
  final ClassRoutineBlock block;

  const ClassDetailSheet({super.key, required this.block});

  static Future<void> show(BuildContext context, ClassRoutineBlock block) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ClassDetailSheet(block: block),
    );
  }

  String _formatDays(List<int> repeatDays) {
    if (repeatDays.isEmpty) return 'No days scheduled';
    final sorted = repeatDays.toSet().toList()..sort();
    if (sorted.length == 7) return 'Every day';
    if (sorted.length == 5 &&
        sorted[0] == 1 &&
        sorted[1] == 2 &&
        sorted[2] == 3 &&
        sorted[3] == 4 &&
        sorted[4] == 5) {
      return 'Mon – Fri';
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

    return SafeArea(
      bottom: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OptivusColors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: OptivusColors.blueAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.subject,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        if (block.courseCode.isNotEmpty ||
                            block.classType.isNotEmpty ||
                            block.section.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (block.courseCode.isNotEmpty)
                                _buildBadge(
                                  block.courseCode,
                                  OptivusColors.blueAccent,
                                ),
                              if (block.classType.isNotEmpty)
                                _buildBadge(
                                  block.classType,
                                  OptivusColors.routineAccent,
                                ),
                              if (block.section.isNotEmpty)
                                _buildBadge(
                                  block.section.toLowerCase().startsWith('sec')
                                      ? block.section
                                      : 'Sec ${block.section}',
                                  OptivusColors.aquaAccent,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: OptivusColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: OptivusColors.borderStandard, height: 1),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: TimelineUtils.formatTimeRange(
                  block.startMinute,
                  block.endMinute,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Days',
                value: _formatDays(block.repeatDays),
              ),
              if (block.room.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: block.room,
                ),
              ],
              if (block.professor.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Instructor',
                  value: block.professor,
                ),
              ],
              if (block.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: block.notes,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: OptivusColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
