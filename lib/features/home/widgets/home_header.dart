import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'home_glass_widgets.dart';
import 'sheets/home_notification_sheet.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final bool showDemoNotifications;

  const HomeHeader({
    super.key,
    required this.userName,
    this.showDemoNotifications = false,
  });

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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getFormattedDate().toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            HomeIconPill(
              icon: Icons.notifications_none,
              accent: OptivusColors.textPrimary,
              onTap: showDemoNotifications
                  ? () => HomeNotificationSheet.show(context)
                  : null,
            ),
            if (showDemoNotifications)
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
