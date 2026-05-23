import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showOverloadLimitsSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Commitment Safety',
    subtitle: 'Overload Limits Configurator',
    child: StatefulBuilder(
      builder: (context, setState) {
        double maxGoals = 3.0; // Restrict active goals
        double maxRoutines = 8.0;
        double maxFocusHours = 4.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'DAILY CAP LIMITS',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Maximum Active Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${maxGoals.toInt()} active', style: const TextStyle(fontWeight: FontWeight.w900, color: OptivusColors.brandAccent)),
                    ],
                  ),
                  Slider(
                    value: maxGoals,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => maxGoals = val);
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Maximum Routine Habits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${maxRoutines.toInt()} items', style: const TextStyle(fontWeight: FontWeight.w900, color: OptivusColors.brandAccent)),
                    ],
                  ),
                  Slider(
                    value: maxRoutines,
                    min: 4,
                    max: 15,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => maxRoutines = val.roundToDouble());
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Maximum Focus Hours cap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${maxFocusHours.toInt()} hours', style: const TextStyle(fontWeight: FontWeight.w900, color: OptivusColors.brandAccent)),
                    ],
                  ),
                  Slider(
                    value: maxFocusHours,
                    min: 2,
                    max: 8,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => maxFocusHours = val.roundToDouble());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Load state widget gauge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.shield_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Active Guard Shield: ENABLED',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Restricts your daily layout to prevent planning too many tasks, keeping cognitive burnouts at zero.',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Overload guard parameters locked.'), behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Confirm Overload Safeguard', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}
