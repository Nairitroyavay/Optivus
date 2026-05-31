import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

void showGoalWeeklyReviewScreen(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFECEC),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AURA GUIDED WEEKLY REFLECTION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Align Systems & Identities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reflecting weekly keeps your habits aligned with who you want to become. Aura has analyzed your tracker scores and routine punctuality records:',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: OptivusColors.textBody,
              ),
            ),
            const SizedBox(height: 16),
            // Metrics summary bullet points
            _buildReflectionBullet('Habit Consistency Index: 92% (Excellent)'),
            _buildReflectionBullet('Completed Gym Proof: 5 / 7 Days'),
            _buildReflectionBullet(
              'Skipped Bad Habit multi-spends: Saved ₹240 this week!',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Weekly review locked! Identity streaks verified.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Complete Guided Review',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildReflectionBullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      children: [
        const Icon(Icons.stars, color: Colors.orange, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
