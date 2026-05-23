import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

/// UPI ₹10 daily micro-savings sandbox card.
class UpiSavingsCard extends ConsumerWidget {
  const UpiSavingsCard({super.key});

  void _triggerMockUPIPayment(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(text: '10.0');
    final descController =
        TextEditingController(text: 'Skipped junk coffee savings');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE8FCFF),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.payment, color: OptivusColors.brandAccent),
              SizedBox(width: 10),
              Text('SANDBOX UPI TRANS',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Simulate moving ₹10 target from consumption into daily savings.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: OptivusColors.textBody),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Pledge Reason',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: OptivusColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: OptivusColors.brandAccent,
                  foregroundColor: Colors.white),
              onPressed: () {
                final amt =
                    double.tryParse(amountController.text) ?? 10.0;
                final desc = descController.text.trim();
                if (desc.isEmpty) return;

                ref
                    .read(mockTrackerProvider.notifier)
                    .logSaving(amt, desc, isConfirmed: true);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Mock UPI payment of ₹$amt verified! Saved successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Simulate Paid',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockTrackerProvider);

    return LiquidGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹10 Daily Micro-Savings',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'Confirmed Saved: ₹${state.moneyGoal.totalConfirmedSaved} | Streak: ${state.moneyGoal.streakDays} Days',
                    style: const TextStyle(
                        fontSize: 11,
                        color: OptivusColors.textSecondary),
                  ),
                ],
              ),
              const Icon(Icons.savings_outlined,
                  color: Colors.teal, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.security, size: 16),
            label: const Text('Trigger Safe UPI Deposit',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _triggerMockUPIPayment(context, ref),
          ),
        ],
      ),
    );
  }
}
