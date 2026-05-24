import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class HomeHeader extends StatelessWidget {
  final String userName;

  const HomeHeader({super.key, required this.userName});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning, $userName';
    } else if (hour < 17) {
      return 'Good Afternoon, $userName';
    } else if (hour < 21) {
      return 'Good Evening, $userName';
    } else {
      return 'Wind down mode, $userName';
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTimeGreeting(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getFormattedDate(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.notifications_none,
              color: OptivusColors.textPrimary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}
