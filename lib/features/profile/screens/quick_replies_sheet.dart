import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showQuickRepliesSheet(BuildContext context, WidgetRef ref) {
  // Simulating the quick replies list locally inside stateful widget wrapper
  showCustomBottomSheet(
    context: context,
    title: 'Interaction Presets',
    subtitle: 'Custom Coach Quick-Replies',
    child: const _QuickRepliesManager(),
  );
}

class _QuickRepliesManager extends StatefulWidget {
  const _QuickRepliesManager();

  @override
  State<_QuickRepliesManager> createState() => _QuickRepliesManagerState();
}

class _QuickRepliesManagerState extends State<_QuickRepliesManager> {
  final List<String> _repliesList = [
    'Hello!',
    'I am feeling tired...',
    'Water logged!',
    'Verify Gym Proof',
    'Dump overthinking thoughts',
  ];

  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CURRENT CHIPS IN ROTATION',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        LiquidGlassPanel(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _repliesList)
                Chip(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  side: const BorderSide(color: OptivusColors.borderSoft),
                  label: Text(
                    r,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: OptivusColors.brandAccent,
                    ),
                  ),
                  deleteIcon: const Icon(
                    Icons.cancel,
                    size: 14,
                    color: OptivusColors.danger,
                  ),
                  onDeleted: () {
                    setState(() {
                      _repliesList.remove(r);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted chip suggestion: "$r"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ADD CUSTOM DIALOG PRESET',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        LiquidGlassPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type customized quick reply...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OptivusColors.brandAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final val = _textController.text.trim();
                  if (val.isNotEmpty) {
                    setState(() {
                      _repliesList.add(val);
                    });
                    _textController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added new chip suggestion: "$val"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Add Chip',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
              const SnackBar(
                content: Text('Coach dialogue chips calibrated.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text(
            'Back to Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
