import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_bottom_sheet.dart';
import 'package:optivus/core/widgets/liquid_buttons.dart';

void showSaveViaUpiFlow(BuildContext context, VoidCallback onSaved) {
  showLiquidBottomSheet(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Save via UPI',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: OptivusColors.ink),
          ),
          const SizedBox(height: 16),
          const Text(
          'Choose Destination',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink),
        ),
        const SizedBox(height: 12),
        _buildMockOption(context, 'My Second Bank Account', true),
        _buildMockOption(context, 'Family Account', false),
        _buildMockOption(context, 'Custom UPI ID', false),
        const SizedBox(height: 24),
        const Text(
          'Choose App',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAppChip('Google Pay'),
            _buildAppChip('PhonePe'),
            _buildAppChip('Paytm'),
            _buildAppChip('BHIM'),
          ],
        ),
        const SizedBox(height: 32),
        LiquidPrimaryButton(
          label: 'Mock Payment Success',
          onPressed: () {
            Navigator.pop(context);
            onSaved();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved ₹10. Streak updated. Finance pillar completed.'),
                backgroundColor: OptivusColors.success,
              ),
            );
          },
        ),
        ],
      ),
    ),
  );
}

void showIAlreadySavedFlow(BuildContext context, VoidCallback onSaved) {
  showLiquidBottomSheet(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'I already saved',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: OptivusColors.ink),
          ),
          const SizedBox(height: 16),
          const Text(
          'Amount',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAmountChip('₹10', true),
            _buildAmountChip('₹25', false),
            _buildAmountChip('₹50', false),
            _buildAmountChip('₹100', false),
            _buildAmountChip('Custom', false),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Method',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildAppChip('UPI'),
            _buildAppChip('Cash'),
            _buildAppChip('Bank Transfer'),
          ],
        ),
        const SizedBox(height: 32),
        LiquidPrimaryButton(
          label: 'Mark Saved',
          onPressed: () {
            Navigator.pop(context);
            onSaved();
          },
        ),
        ],
      ),
    ),
  );
}

void showSkipTodayFlow(BuildContext context, VoidCallback onSkipped) {
  showLiquidBottomSheet(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Skip today',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: OptivusColors.ink),
          ),
          const SizedBox(height: 16),
          const Text(
          'Reason',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink),
        ),
        const SizedBox(height: 12),
        _buildMockOption(context, 'No money today', true),
        _buildMockOption(context, 'Forgot', false),
        _buildMockOption(context, 'Spent on emergency', false),
        _buildMockOption(context, 'Do not want to say', false),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OptivusColors.routineTop.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OptivusColors.routineAccent.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'You skipped today. Save ₹5 tiny version if possible.',
            style: TextStyle(
              color: OptivusColors.routineInkDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),
        LiquidPrimaryButton(
          label: 'Save tiny amount ₹5',
          onPressed: () {
            Navigator.pop(context);
            showIAlreadySavedFlow(context, () {});
          },
        ),
        const SizedBox(height: 12),
        LiquidOutlineButton(
          label: 'Move to tomorrow (Skip)',
          onPressed: () {
            Navigator.pop(context);
            onSkipped();
          },
        ),
        ],
      ),
    ),
  );
}

Widget _buildMockOption(BuildContext context, String text, bool isSelected) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: isSelected ? OptivusColors.trackerAccent.withValues(alpha: 0.1) : Colors.transparent,
      border: Border.all(
        color: isSelected ? OptivusColors.trackerAccent : OptivusColors.borderSoft,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isSelected ? OptivusColors.trackerAccent : OptivusColors.sub,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: OptivusColors.ink,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildAppChip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: OptivusColors.borderSoft),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: OptivusColors.ink,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Widget _buildAmountChip(String amount, bool isSelected) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: isSelected ? OptivusColors.trackerAccent.withValues(alpha: 0.1) : Colors.transparent,
      border: Border.all(
        color: isSelected ? OptivusColors.trackerAccent : OptivusColors.borderSoft,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      amount,
      style: TextStyle(
        color: isSelected ? OptivusColors.trackerAccent : OptivusColors.ink,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
