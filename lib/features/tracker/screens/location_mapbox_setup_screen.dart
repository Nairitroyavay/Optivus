import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';

class LocationMapboxSetupScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const LocationMapboxSetupScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(profileSettingsProvider);
    final location = settings.permissions.firstWhere(
      (p) => p.type == ProfilePermissionType.location,
    );
    final mapbox = settings.services.firstWhere(
      (s) => s.type == ConnectedServiceType.mapbox,
    );

    return LiquidDetailScaffold(
      eyebrow: 'Phone data source',
      title: 'Location + Mapbox',
      subtitle: 'Walk and run route tracking with Mapbox route previews.',
      accentColor: OptivusColors.trackerAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Status',
          children: [
            LiquidActionRow(
              icon: Icons.location_on_outlined,
              title: 'Location permission: ${location.status.label}',
              subtitle: 'Last checked ${location.lastChecked}',
              accentColor: location.status == ProfileConnectionStatus.connected
                  ? OptivusColors.success
                  : OptivusColors.warning,
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .togglePermission(ProfilePermissionType.location),
            ),
            LiquidActionRow(
              icon: Icons.map_outlined,
              title: 'Mapbox service: ${mapbox.status.label}',
              subtitle:
                  'Selected style: ${mapbox.selectedStyle ?? 'Default map style'}',
              accentColor: OptivusColors.trackerAccent,
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .recheckService(ConnectedServiceType.mapbox),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Actions',
          children: [
            LiquidActionRow(
              icon: Icons.settings_outlined,
              title: 'Allow Location / Open Settings',
              subtitle: 'Native permission connects in backend/native pass.',
              accentColor: OptivusColors.trackerAccent,
              onTap: () {},
            ),
            LiquidActionRow(
              icon: Icons.route_outlined,
              title: 'Test Mapbox config',
              subtitle: 'Mock recheck updates the last checked timestamp.',
              accentColor: OptivusColors.info,
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .recheckService(ConnectedServiceType.mapbox),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'What this powers',
          children: const [
            Text(
              'Outdoor Walk, Outdoor Run, route map preview, pace by segment, selected map style, and future route proof cards.',
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
