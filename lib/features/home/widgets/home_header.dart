import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'home_glass_widgets.dart';
import 'sheets/home_notification_sheet.dart';

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
              _getFormattedDate().toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getTimeGreeting(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        Stack(
          children: [
            HomeIconPill(
              icon: Icons.notifications_none,
              accent: OptivusColors.textPrimary,
              onTap: () => HomeNotificationSheet.show(context),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: OptivusColors.homeAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
