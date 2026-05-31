import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';

class UsageAccessSetupScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const UsageAccessSetupScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(trackerSettingsProvider);
    final permission = ref
        .watch(profileSettingsProvider)
        .permissions
        .firstWhere((p) => p.type == ProfilePermissionType.usageAccess);

    return LiquidDetailScaffold(
      eyebrow: 'Phone data source',
      title: 'Usage Access Setup',
      subtitle:
          'Used for Screen Time Tracker, doom scrolling risk, and app usage insights.',
      accentColor: OptivusColors.roseAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Current status',
          children: [
            Row(
              children: [
                Icon(
                  permission.status == ProfileConnectionStatus.connected
                      ? Icons.check_circle_rounded
                      : Icons.lock_outline_rounded,
                  color: permission.status == ProfileConnectionStatus.connected
                      ? OptivusColors.success
                      : OptivusColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${permission.status.label} · last checked ${permission.lastChecked}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Android live permission state will be the source of truth. Firestore stores only the last known status.',
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
          title: 'Actions',
          children: [
            LiquidActionRow(
              icon: Icons.settings_applications_outlined,
              title: 'Open Android Usage Access Settings',
              subtitle: 'Frontend placeholder for native intent.',
              accentColor: OptivusColors.roseAccent,
              onTap: () {},
            ),
            LiquidActionRow(
              icon: Icons.refresh_rounded,
              title: 'I enabled it / recheck',
              subtitle: 'Mock live check toggles this permission state.',
              accentColor: OptivusColors.trackerAccent,
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .togglePermission(ProfilePermissionType.usageAccess),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Privacy mode',
          children: [
            LiquidActionRow(
              icon: Icons.visibility_outlined,
              title: settings.screenTimePrivacyHideNames
                  ? 'Categories only'
                  : 'Show app names',
              subtitle: settings.screenTimePrivacyHideNames
                  ? 'Example: Social app 3h 20m'
                  : 'Example: Instagram 3h 20m',
              accentColor: OptivusColors.roseAccent,
              trailing: Switch(
                value: settings.screenTimePrivacyHideNames,
                activeThumbColor: OptivusColors.roseAccent,
                onChanged: ref
                    .read(trackerSettingsProvider.notifier)
                    .setScreenTimePrivacyHideNames,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
