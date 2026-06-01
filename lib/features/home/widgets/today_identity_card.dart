import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'home_glass_widgets.dart';

class TodayIdentityCard extends StatelessWidget {
  final IdentityFocus? identity;
  final VoidCallback? onTap;

  const TodayIdentityCard({super.key, this.identity, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (identity == null) {
      return const SizedBox.shrink();
    }

    final focusTitle = identity!.secondaryIdentity != null
        ? '${identity!.primaryIdentity} + ${identity!.secondaryIdentity}'
        : identity!.primaryIdentity;

    return GestureDetector(
      onTap: onTap,
      child: HomeGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: OptivusColors.homeAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today you are building',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: OptivusColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              focusTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: OptivusColors.homeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 14,
                    color: OptivusColors.homeAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Proof: ${identity!.primaryProof}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
