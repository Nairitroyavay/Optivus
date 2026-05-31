import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showSavingsSweepSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Financial Accountability',
    subtitle: 'Habit Failure Savings Sweep',
    child: StatefulBuilder(
      builder: (context, setState) {
        bool sweepEnabled = true;
        double sweepAmount = 1.50; // $1.50 per failure
        String destinationVault = 'Focus Treasury';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'HABIT FAILURE CONVERTERS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SwitchListTile.adaptive(
                activeTrackColor: OptivusColors.brandAccent,
                title: const Text(
                  'Enable Savings Sweep Tax',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'Failing a target routine sweeps real micro-savings into a lockbox',
                  style: TextStyle(fontSize: 10),
                ),
                value: sweepEnabled,
                onChanged: (val) => setState(() => sweepEnabled = val),
              ),
            ),
            const SizedBox(height: 20),
            if (sweepEnabled) ...[
              const Text(
                'SWEEP DETAILS',
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
                          'Fine Amount per slip-up',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '\$${sweepAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.brandAccent,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: sweepAmount,
                      min: 0.50,
                      max: 5.00,
                      divisions: 9,
                      activeColor: OptivusColors.brandAccent,
                      onChanged: (val) {
                        setState(() => sweepAmount = val);
                      },
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Destination Vault Box',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        DropdownButton<String>(
                          value: destinationVault,
                          underline: const SizedBox(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.brandAccent,
                            fontSize: 13,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Cognitive Fund',
                              child: Text('Cognitive Fund'),
                            ),
                            DropdownMenuItem(
                              value: 'Piggy Bank',
                              child: Text('Piggy Bank'),
                            ),
                            DropdownMenuItem(
                              value: 'Focus Treasury',
                              child: Text('Focus Treasury'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => destinationVault = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Sparkline graph dynamic representation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Accumulated Total (This Week)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                        Text(
                          '\$14.50',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: CustomPaint(painter: _MockSparklinePainter()),
                    ),
                  ],
                ),
              ),
            ],
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
                    content: Text(
                      'Savings sweep accountability tax rule saved.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Save Sweep Rules',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MockSparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.6, size.height * 0.75),
      Offset(size.width * 0.8, size.height * 0.45),
      Offset(size.width, size.height * 0.1),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
