import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';

class TrackerSettingsScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final ValueChanged<TrackerDetailView> onOpenDetail;

  const TrackerSettingsScreen({
    super.key,
    required this.onBack,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(trackerSettingsProvider);
    final notifier = ref.read(trackerSettingsProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Tracker Settings',
      subtitle:
          'Manage active trackers, ordering, reminders, permissions, privacy, and reset flow.',
      accentColor: OptivusColors.trackerAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Active trackers',
          children: settings.activeTrackers.entries.map((entry) {
            return LiquidActionRow(
              icon: _iconFor(entry.key),
              title: entry.key,
              subtitle: entry.value
                  ? 'Visible in Tracking Center'
                  : 'Inactive / discover tracker',
              accentColor: OptivusColors.trackerAccent,
              trailing: Switch(
                value: entry.value,
                activeThumbColor: OptivusColors.trackerAccent,
                onChanged: (_) => notifier.toggleTracker(entry.key),
              ),
            );
          }).toList(),
        ),
        LiquidDetailSection(
          title: 'Tracker ordering',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: settings.trackerOrder
                  .map(
                    (tracker) => LiquidPill(
                      label: tracker,
                      color: OptivusColors.trackerAccent,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Drag ordering is prepared for the Android integration pass. This mock keeps the active list deterministic.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Tracker reminders',
          children: [
            LiquidActionRow(
              icon: Icons.water_drop_outlined,
              title: 'Hydration reminders',
              subtitle: 'Uses Profile notification quiet hours.',
              accentColor: OptivusColors.blueAccent,
              trailing: Switch(
                value: settings.hydrationReminders,
                activeThumbColor: OptivusColors.blueAccent,
                onChanged: notifier.setHydrationReminders,
              ),
            ),
            LiquidActionRow(
              icon: Icons.notifications_active_outlined,
              title: 'Reminder intensity',
              subtitle: 'Open Profile notification settings.',
              accentColor: OptivusColors.trackerAccent,
              onTap: () {
                ref
                    .read(profileDetailViewRequestProvider.notifier)
                    .state = const ProfileDetailTarget(
                  view: ProfileDetailView.notificationSettings,
                );
              },
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Permission and data sources',
          children: [
            LiquidActionRow(
              icon: Icons.data_usage_rounded,
              title: 'Usage Access',
              subtitle: 'Screen Time and focus-loss windows.',
              accentColor: OptivusColors.roseAccent,
              onTap: () => onOpenDetail(TrackerDetailView.usageAccessSetup),
            ),
            LiquidActionRow(
              icon: Icons.monitor_heart_outlined,
              title: 'Health Connect',
              subtitle: 'Steps, sleep, calories, workouts, heart rate.',
              accentColor: OptivusColors.success,
              onTap: () => onOpenDetail(TrackerDetailView.healthConnectSetup),
            ),
            LiquidActionRow(
              icon: Icons.location_on_outlined,
              title: 'Location + Mapbox',
              subtitle: 'Walk/run route maps and selected style.',
              accentColor: OptivusColors.trackerAccent,
              onTap: () => onOpenDetail(TrackerDetailView.locationMapboxSetup),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Privacy and reset',
          children: [
            LiquidActionRow(
              icon: Icons.visibility_off_outlined,
              title: 'Screen Time privacy',
              subtitle: settings.screenTimePrivacyHideNames
                  ? 'App names hidden. Categories only.'
                  : 'App names visible in mock insights.',
              accentColor: OptivusColors.roseAccent,
              trailing: Switch(
                value: settings.screenTimePrivacyHideNames,
                activeThumbColor: OptivusColors.roseAccent,
                onChanged: notifier.setScreenTimePrivacyHideNames,
              ),
            ),
            LiquidActionRow(
              icon: Icons.restart_alt_rounded,
              title: 'Reset tracker mock settings',
              subtitle:
                  'Restores active tracker toggles and reminder defaults.',
              accentColor: OptivusColors.danger,
              destructive: true,
              onTap: notifier.resetMockSettings,
            ),
          ],
        ),
      ],
    );
  }

  IconData _iconFor(String tracker) {
    return switch (tracker) {
      'Meditation' => Icons.self_improvement_rounded,
      'Money System' => Icons.savings_outlined,
      'Screen Time' => Icons.phone_android_rounded,
      'Fitness Center' => Icons.directions_run_rounded,
      'Hydration' => Icons.water_drop_outlined,
      'Nutrition later' => Icons.restaurant_outlined,
      'Sleep later' => Icons.bedtime_outlined,
      'Smoking later' => Icons.smoke_free_outlined,
      _ => Icons.track_changes_rounded,
    };
  }
}
