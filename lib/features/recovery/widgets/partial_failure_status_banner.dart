import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PartialFailureStatusBanner extends ConsumerWidget {
  final Map<String, bool>? stageStatuses;
  final String? currentStage;
  final int projectedItemCount;
  final int failedItemCount;
  final VoidCallback? onResume;

  static const List<String> defaultStages = [
    'persistDraft',
    'persistBundle',
    'projectRoutines',
    'projectHabits',
    'updateProfile',
  ];

  const PartialFailureStatusBanner({
    super.key,
    this.stageStatuses,
    this.currentStage,
    this.projectedItemCount = 0,
    this.failedItemCount = 0,
    this.onResume,
  });

  static String _stageLabel(String stage) {
    return switch (stage) {
      'persistDraft' => 'Draft',
      'persistBundle' => 'Bundle',
      'projectRoutines' => 'Routines',
      'projectHabits' => 'Habits',
      'updateProfile' => 'Profile',
      _ => stage,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = defaultStages;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Partial Completion Detected',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 5-Stage Job Indicators
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: stages.map((stage) {
                  final isDone = stageStatuses?[stage] ?? false;
                  final isCurrent = currentStage == stage;

                  Color circleColor = Colors.grey.shade300;
                  IconData iconData = Icons.circle_outlined;
                  Color iconColor = Colors.grey.shade600;

                  if (isDone) {
                    circleColor = Colors.green.shade100;
                    iconData = Icons.check_circle;
                    iconColor = Colors.green.shade700;
                  } else if (isCurrent) {
                    circleColor = Colors.amber.shade200;
                    iconData = Icons.pending;
                    iconColor = Colors.amber.shade900;
                  }

                  return Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: circleColor,
                          ),
                          child: Icon(iconData, size: 18, color: iconColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stageLabel(stage),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          // Projected vs Failed counts
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Items: $projectedItemCount projected, $failedItemCount failed',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (onResume != null)
                ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
