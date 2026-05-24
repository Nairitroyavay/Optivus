import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'home_glass_widgets.dart';

class CoachTipCard extends ConsumerWidget {
  final CoachTip? tip;

  const CoachTipCard({super.key, this.tip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tip == null) return const SizedBox.shrink();

    return HomeGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${tip!.coachName}:',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tip!.message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              HomeActionPill(
                label: 'Ask Coach',
                compact: true,
                selected: true,
                onTap: () {
                  ref.read(appNavigationProvider.notifier).goToCoach();
                },
              ),
              const SizedBox(width: 8),
              HomeActionPill(
                label: 'Improve Plan',
                compact: true,
                onTap: () {
                  ref.read(appNavigationProvider.notifier).goToRoutine();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
