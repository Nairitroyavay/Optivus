import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showSystemDiagnosticsSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Developer Portal',
    subtitle: 'System Diagnostic Logs',
    child: const _SystemLogsConsole(),
  );
}

class _SystemLogsConsole extends StatefulWidget {
  const _SystemLogsConsole();

  @override
  State<_SystemLogsConsole> createState() => _SystemLogsConsoleState();
}

class _SystemLogsConsoleState extends State<_SystemLogsConsole> {
  final List<String> _mockLogs = [
    '[14:41:00 INFO] Initializing Riverpod global state manager...',
    '[14:41:01 INFO] Local Database Seed completed: 44 default active records',
    '[14:41:02 INFO] Flutter GPU engine attached: Metal Renderer API (120 FPS lock)',
    '[14:41:03 INFO] Edge-to-edge layout bounds validated in main.dart',
    '[14:41:05 DEBUG] mockPermissionProvider.locationGps toggled to mockConnected',
    '[14:41:12 INFO] Aura Cognitive Guard verified: 3/3 active goals within slots',
    '[14:41:18 DEBUG] mockCoachProvider triggered mock assistant responses',
    '[14:41:30 DEBUG] trackerMetricsNotifier fetched: 15 active metrics in layout',
    '[14:41:42 INFO] Screen Time app logging session active (TikTok blocked)',
    '[14:41:55 INFO] Garbage Collection performed: purged 4.2 MB transient buffers',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'LIVE SYSTEM HEALTH',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        LiquidGlassPanel(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthIndicator('RAM Heap', '48.2 MB', Colors.green),
              _buildHealthIndicator('Render Rate', '120 FPS', Colors.green),
              _buildHealthIndicator('State Nodes', '28 active', Colors.blue),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'DIAGNOSTIC LOG STREAM',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        Container(
          height: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: _mockLogs.length,
            itemBuilder: (context, index) {
              final log = _mockLogs[index];
              Color logColor = Colors.green;
              if (log.contains('DEBUG')) logColor = Colors.blueAccent;
              if (log.contains('WARNING')) logColor = Colors.orange;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    color: logColor,
                    height: 1.3,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _mockLogs.clear();
                    _mockLogs.add('[14:42:00 INFO] System log stream cleared by developer console.');
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Console logs cleared.'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: OptivusColors.brandAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: OptivusColors.brandAccent)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Export logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _mockLogs.join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All logs copied to clipboard!'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.brandAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Control Center', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

Widget _buildHealthIndicator(String label, String value, Color color) {
  return Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
      ),
    ],
  );
}
