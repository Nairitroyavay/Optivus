import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/widgets/home_glass_widgets.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';

class ComingUpItemSheet extends ConsumerWidget {
  final String title;

  const ComingUpItemSheet({super.key, required this.title});

  static void show(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ComingUpItemSheet(title: title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String time = '';
    String subtitle = '';
    String? extraText;
    String? buttonText;
    VoidCallback? onButtonTap;

    if (title == 'Class') {
      time = '9:00 AM - 5:00 PM';
      subtitle = 'Hard block';
      extraText = 'Next free action: Gym at 6:30 PM';
    } else if (title == 'Gym') {
      time = '6:30 PM - 7:15 PM';
      subtitle = 'Tracker task';
      buttonText = 'Open Tracker';
      onButtonTap = () {
        Navigator.pop(context);
        ref.read(appNavigationProvider.notifier).goToTracker();
      };
    } else if (title == 'Tiny money save') {
      time = '9:45 PM';
      subtitle = 'Money System';
      buttonText = 'Save Now';
      onButtonTap = () {
        Navigator.pop(context);
        ref.read(appNavigationProvider.notifier).goToTracker();
        ref.read(trackerDetailViewRequestProvider.notifier).state =
            TrackerDetailTarget.view(TrackerDetailView.money);
      };
    } else {
      time = 'Scheduled time';
      subtitle = 'Routine item';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: OptivusColors.textSecondary,
                ),
              ),
              if (extraText != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    extraText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (buttonText != null) ...[
                HomeActionPill(
                  label: buttonText,
                  selected: true,
                  accent: title == 'Tiny money save'
                      ? OptivusColors.brandAccent
                      : OptivusColors.trackerAccent,
                  onTap: onButtonTap ?? () {},
                ),
                const SizedBox(height: 8),
              ],
              HomeActionPill(
                label: 'Close',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
