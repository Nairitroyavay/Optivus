import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Cognitive overload protection alert banner shown when ≥2 goals
/// are set to "strong" (Overload) difficulty.
class OverloadProtectionAlert extends StatelessWidget {
  final int overloadCount;

  const OverloadProtectionAlert({super.key, required this.overloadCount});

  @override
  Widget build(BuildContext context) {
    if (overloadCount < 2) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OptivusColors.danger, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: OptivusColors.danger,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COGNITIVE OVERLOAD SYSTEM ON',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.danger,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You have locked $overloadCount "OVERLOAD" targets today. Doing this triggers rapid high-intensity fatigue. Aura recommends shifting at least one goal to "Tiny" to preserve long-term habit momentum.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
