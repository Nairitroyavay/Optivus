import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';

class HealthConnectSetupScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const HealthConnectSetupScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref
        .watch(profileSettingsProvider)
        .permissions
        .firstWhere((p) => p.type == ProfilePermissionType.healthConnect);

    return LiquidDetailScaffold(
      eyebrow: 'Phone data source',
      title: 'Health Connect',
      subtitle:
          'Connect health data for steps, sleep, calories, workouts, and heart rate.',
      accentColor: OptivusColors.success,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Connection status',
          children: [
            LiquidActionRow(
              icon: permission.status == ProfileConnectionStatus.connected
                  ? Icons.check_circle_rounded
                  : Icons.health_and_safety_outlined,
              title: permission.status.label,
              subtitle: 'Last checked ${permission.lastChecked}',
              accentColor:
                  permission.status == ProfileConnectionStatus.connected
                  ? OptivusColors.success
                  : OptivusColors.warning,
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .togglePermission(ProfilePermissionType.healthConnect),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Data permissions checklist',
          children: const [
            _ChecklistRow(label: 'Steps'),
            _ChecklistRow(label: 'Sleep'),
            _ChecklistRow(label: 'Calories'),
            _ChecklistRow(label: 'Workouts'),
            _ChecklistRow(label: 'Heart rate'),
          ],
        ),
        LiquidDetailSection(
          title: 'Privacy note',
          children: const [
            Text(
              'Health Connect data stays consent-based. Optivus should request only the data types needed by active trackers and can work with manual tracker entry when disconnected.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;

  const _ChecklistRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: OptivusColors.success.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
