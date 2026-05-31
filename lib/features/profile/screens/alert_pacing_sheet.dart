import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showAlertPacingSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Attention Management',
    subtitle: 'Alert Pacing & Quiet Hours',
    child: StatefulBuilder(
      builder: (context, setState) {
        double pacingIntensity =
            1.0; // 0: Gentle, 1: Balanced, 2: Focus Focused
        double quietHoursStart = 22.0; // 10 PM
        double quietHoursEnd = 7.0; // 7 AM
        bool blockWeekends = true;

        String intensityLabel = 'Standard Balance';
        String intensityDesc =
            'Summarized reports 3 times a day. Minimal micro-intrusiveness.';
        if (pacingIntensity < 0.5) {
          intensityLabel = 'Gentle Whisper';
          intensityDesc =
              'No direct alerts. Reports only show up inside the Daily Dashboard.';
        } else if (pacingIntensity > 1.5) {
          intensityLabel = 'Extreme Accountability';
          intensityDesc =
              'Immediate alert ping when habits go overdue. AI Coach check-ins active.';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ALERT INTEGRITY MODE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pacing level',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        intensityLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: pacingIntensity,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => pacingIntensity = val);
                    },
                  ),
                  Text(
                    intensityDesc,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: OptivusColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'QUIET BOUNDARIES',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quiet hours start',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${quietHoursStart.toInt()}:00',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: quietHoursStart,
                    min: 18,
                    max: 24,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => quietHoursStart = val.roundToDouble());
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quiet hours end',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '0${quietHoursEnd.toInt()}:00',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: quietHoursEnd,
                    min: 4,
                    max: 10,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => quietHoursEnd = val.roundToDouble());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SwitchListTile.adaptive(
                activeTrackColor: OptivusColors.brandAccent,
                title: const Text(
                  'Block Weekend Coaching Pings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'Absolute silence from Friday 20:00 to Monday 08:00',
                  style: TextStyle(fontSize: 10),
                ),
                value: blockWeekends,
                onChanged: (val) => setState(() => blockWeekends = val),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert pacing filters applied.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Confirm Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}
