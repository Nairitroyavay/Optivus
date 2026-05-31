import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showEditProfileSheet(BuildContext context, WidgetRef ref) {
  final profile = ref.read(mockUserProfileProvider);

  final nameController = TextEditingController(text: profile.displayName);
  final roleController = TextEditingController(text: profile.lifeRole);

  double currentHeight = profile.height;
  double currentWeight = profile.weight;

  showCustomBottomSheet(
    context: context,
    title: 'Edit Identity',
    subtitle: 'Profile & Body Metrics',
    child: StatefulBuilder(
      builder: (context, setState) {
        final double hMeters = currentHeight / 100.0;
        final double bmi = currentWeight / (hMeters * hMeters);
        String bmiCategory = 'Normal';
        Color bmiColor = OptivusColors.success;

        if (bmi < 18.5) {
          bmiCategory = 'Underweight';
          bmiColor = Colors.orange;
        } else if (bmi >= 25 && bmi < 30) {
          bmiCategory = 'Overweight';
          bmiColor = Colors.orangeAccent;
        } else if (bmi >= 30) {
          bmiCategory = 'Obese';
          bmiColor = OptivusColors.danger;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roleController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Primary Lifestyle Role',
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'BODY METRICS & ESTIMATES',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Height (cm)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${currentHeight.toInt()} cm',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: currentHeight,
                    min: 120,
                    max: 220,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => currentHeight = val.roundToDouble());
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weight (kg)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${currentWeight.toInt()} kg',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: currentWeight,
                    min: 30,
                    max: 150,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => currentWeight = val.roundToDouble());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Live BMI indicator card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bmiColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: bmiColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bmiColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monitor_weight_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated BMI: ${bmi.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: bmiColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Category: $bmiCategory | Balanced target range: 18.5–24.9',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.textSecondary,
                          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                final current = ref.read(mockUserProfileProvider);
                ref
                    .read(mockUserProfileProvider.notifier)
                    .updateProfile(
                      current.copyWith(
                        displayName: nameController.text.trim(),
                        lifeRole: roleController.text.trim(),
                      ),
                    );
                ref
                    .read(mockUserProfileProvider.notifier)
                    .updateBodyBasics(
                      height: currentHeight,
                      weight: currentWeight,
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Identity Profile updated successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}
