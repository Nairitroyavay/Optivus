import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/models/permission_status.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showWearableConnectSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Wearable Sync',
    subtitle: 'Health SDK Connections',
    child: StatefulBuilder(
      builder: (context, setState) {
        final permissions = ref.watch(mockPermissionProvider);
        bool isSyncing = false;
        bool hasSynced = false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'NATIVE INTEGRATIONS',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    activeTrackColor: OptivusColors.success,
                    title: const Text('Google Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Read dynamic active steps & calorie metrics', style: TextStyle(fontSize: 10)),
                    value: permissions.healthConnect == PermissionConnectionState.mockConnected,
                    onChanged: (val) {
                      ref.read(mockPermissionProvider.notifier).toggleHealthConnectPermission();
                    },
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    activeTrackColor: OptivusColors.success,
                    title: const Text('Apple Health / WatchKit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Read resting heart rate & sleep staging', style: TextStyle(fontSize: 10)),
                    value: permissions.locationGps == PermissionConnectionState.mockConnected,
                    onChanged: (val) {
                      ref.read(mockPermissionProvider.notifier).toggleLocationGpsPermission();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SYNC RULES',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Automatic Sync Interval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButton<String>(
                    value: 'Real-time',
                    underline: const SizedBox(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.brandAccent, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'Real-time', child: Text('Real-time')),
                      DropdownMenuItem(value: 'Hourly', child: Text('Hourly')),
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                    ],
                    onChanged: (val) {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            StatefulBuilder(
              builder: (context, setLocalState) {
                if (isSyncing) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(strokeWidth: 3, color: OptivusColors.brandAccent),
                          SizedBox(height: 12),
                          Text('Aggregating hardware steps & heart rate streams...', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  );
                }

                if (hasSynced) {
                  return LiquidGlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle, color: OptivusColors.success, size: 16),
                            SizedBox(width: 8),
                            Text('Sync Successful!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.success)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('• Raw Steps Collected: 12,456 steps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const Text('• Avg HR: 72 BPM | Heart rate variability: 62 ms', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const Text('• Total Active Calories: 482 kcal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const Text('• Deep Sleep Sleep staging: 2h 45m', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: OptivusColors.brandAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: OptivusColors.brandAccent, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.sync),
                  label: const Text('Trigger Core Sync Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setLocalState(() => isSyncing = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (context.mounted) {
                        setLocalState(() {
                          isSyncing = false;
                          hasSynced = true;
                        });
                      }
                    });
                  },
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
