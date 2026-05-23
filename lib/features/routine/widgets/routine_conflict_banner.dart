import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Collision alert banner shown when routine blocks overlap.
class RoutineConflictBanner extends StatelessWidget {
  final int conflictCount;
  final VoidCallback onResolve;

  const RoutineConflictBanner({
    super.key,
    required this.conflictCount,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    if (conflictCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OptivusColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OptivusColors.danger),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OptivusColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Collision alert! $conflictCount hard blocks overlap.',
              style: const TextStyle(
                  color: OptivusColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onResolve,
            child: const Text('Resolve with AI',
                style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          )
        ],
      ),
    );
  }
}
