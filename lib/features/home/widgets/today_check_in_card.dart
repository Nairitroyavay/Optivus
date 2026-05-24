import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'home_glass_widgets.dart';

class TodayCheckInCard extends ConsumerWidget {
  final List<CheckInItem> checkIns;

  const TodayCheckInCard({super.key, required this.checkIns});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (checkIns.isEmpty) return const SizedBox.shrink();

    return HomeGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today Check-in',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...checkIns.map((item) => _buildCheckInRow(context, ref, item)),
        ],
      ),
    );
  }

  Widget _buildCheckInRow(
    BuildContext context,
    WidgetRef ref,
    CheckInItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: item.options.map((option) {
              final isSelected = item.selectedOption == option;
              return InkWell(
                onTap: () {
                  ref
                      .read(homeDashboardProvider.notifier)
                      .completeCheckIn(item.id, option);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? OptivusColors.brandAccent
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? OptivusColors.brandAccent
                          : Colors.white,
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : OptivusColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
