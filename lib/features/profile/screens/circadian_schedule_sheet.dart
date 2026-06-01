// Legacy Profile sheet. Active timeline controls live in Routine.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showCircadianScheduleSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Biological Rhythm',
    subtitle: 'Circadian Schedule Offsets',
    child: StatefulBuilder(
      builder: (context, setState) {
        String sleepTime = '22:30';
        String wakeTime = '06:30';
        double offsetMinutes = 30.0; // Dynamic timeline padding

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SLEEP-WAKE CIRCADIAN BOUNDARIES',
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
                        'Target sleep boundary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      DropdownButton<String>(
                        value: sleepTime,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: OptivusColors.brandAccent,
                          fontSize: 13,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '21:30',
                            child: Text('21:30'),
                          ),
                          DropdownMenuItem(
                            value: '22:00',
                            child: Text('22:00'),
                          ),
                          DropdownMenuItem(
                            value: '22:30',
                            child: Text('22:30'),
                          ),
                          DropdownMenuItem(
                            value: '23:00',
                            child: Text('23:00'),
                          ),
                          DropdownMenuItem(
                            value: '23:30',
                            child: Text('23:30'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => sleepTime = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Target wake boundary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      DropdownButton<String>(
                        value: wakeTime,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: OptivusColors.brandAccent,
                          fontSize: 13,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '05:30',
                            child: Text('05:30'),
                          ),
                          DropdownMenuItem(
                            value: '06:00',
                            child: Text('06:00'),
                          ),
                          DropdownMenuItem(
                            value: '06:30',
                            child: Text('06:30'),
                          ),
                          DropdownMenuItem(
                            value: '07:00',
                            child: Text('07:00'),
                          ),
                          DropdownMenuItem(
                            value: '07:30',
                            child: Text('07:30'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => wakeTime = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'WAKING TIMELINE BUFFER',
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
                        'Buffer delay padding',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${offsetMinutes.toInt()} min',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: offsetMinutes,
                    min: 0,
                    max: 90,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => offsetMinutes = val);
                    },
                  ),
                  const Text(
                    'Shifts routines dynamically to fit your real chemical sleep inertia window.',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: OptivusColors.textSecondary,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Circadian Offset aligned: Wake boundary $wakeTime +${offsetMinutes.toInt()}m padding.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Align Chrono-Schedule',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}
