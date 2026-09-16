import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Modal bottom sheet displaying all stored details for a Work / Business block.
class WorkDetailSheet extends StatelessWidget {
  final TimelineBlockDraft block;
  final VoidCallback? onEdit;
  final String? editLabel;

  const WorkDetailSheet({
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
      builder: (ctx) => WorkDetailSheet(
        block: block,
        onEdit: onEdit,
        editLabel: editLabel,
      ),
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
    final effectiveDept = block.effectiveWorkDepartmentOrProject;

    final contextLabel = WorkPresentationUtils.formatContext(
      block.workContextType,
    );
    final modeLabel = WorkPresentationUtils.formatMode(block.workMode);
    final blockKindLabel = WorkPresentationUtils.formatBlockKind(
      block.workBlockKind,
    );

    final durationMin = block.endMinute - block.startMinute;
    final durationStr = durationMin > 0
        ? (durationMin >= 60
              ? '${durationMin ~/ 60}h${durationMin % 60 > 0 ? ' ${durationMin % 60}m' : ''}'
              : '${durationMin}m')
        : '';

    final orgLabel = WorkPresentationUtils.organizationDetailLabel(
      block.workContextType,
    );
    final deptLabel = WorkPresentationUtils.departmentDetailLabel(
      block.workContextType,
    );
    final roleLabel = WorkPresentationUtils.roleDetailLabel(
      block.workContextType,
    );

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
                      color: OptivusColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.work_rounded,
                      color: OptivusColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        if (contextLabel.isNotEmpty ||
                            modeLabel.isNotEmpty ||
                            blockKindLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (contextLabel.isNotEmpty)
                                _buildBadge(
                                  contextLabel,
                                  OptivusColors.warning,
                                ),
                              if (modeLabel.isNotEmpty)
                                _buildBadge(
                                  modeLabel,
                                  OptivusColors.aquaAccent,
                                ),
                              if (blockKindLabel.isNotEmpty)
                                _buildBadge(
                                  blockKindLabel,
                                  OptivusColors.routineAccent,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close work details',
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
                value: durationStr.isNotEmpty
                    ? '${TimelineUtils.formatTimeRange(block.startMinute, block.endMinute)} ($durationStr)'
                    : TimelineUtils.formatTimeRange(
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
              if (block.workRole != null &&
                  block.workRole!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.badge_outlined,
                  label: roleLabel,
                  value: block.workRole!.trim(),
                ),
              ],
              if (block.workOrganization != null &&
                  block.workOrganization!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.business_rounded,
                  label: orgLabel,
                  value: block.workOrganization!.trim(),
                ),
              ],
              if (effectiveDept != null && effectiveDept.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.account_tree_outlined,
                  label: deptLabel,
                  value: effectiveDept.trim(),
                ),
              ],
              if (block.location != null &&
                  block.location!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: block.location!.trim(),
                ),
              ],
              if (block.notes != null && block.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: block.notes!.trim(),
                ),
              ],
              if (onEdit != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('work-detail-sheet-edit-block-button'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(editLabel ?? 'Edit this block'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OptivusColors.warning,
                      side: const BorderSide(color: OptivusColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit?.call();
                    },
                  ),
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
          width: 86,
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
