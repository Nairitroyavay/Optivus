import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/mock_app_state.dart';

/// Shows the coach archetype & personality settings modal.
void showCoachSettingsScreen(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF7F0FF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final profile = ref.watch(mockUserProfileProvider);

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
                    decoration: BoxDecoration(color: Colors.blueGrey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'COACH PERSONALITY CONFIGS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Customize Aura Persona',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: OptivusColors.textPrimary),
                ),
                const SizedBox(height: 16),

                // Name editor
                TextField(
                  controller: TextEditingController(text: profile.coachName),
                  decoration: const InputDecoration(labelText: 'Custom Coach Name', border: OutlineInputBorder()),
                  onSubmitted: (val) {
                    if (val.trim().isEmpty) return;
                    ref.read(mockUserProfileProvider.notifier).updateCoachPreferences(coachName: val.trim());
                  },
                ),
                const SizedBox(height: 16),

                // Style toggles Compassionate vs Direct
                const Text('COACHING DISCIPLINE ARCHETYPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildArchetypeBtn(ref, 'Compassionate', profile.coachStyle == 'Compassionate', () {
                      ref.read(mockUserProfileProvider.notifier).updateCoachPreferences(coachStyle: 'Compassionate');
                    }),
                    const SizedBox(width: 8),
                    _buildArchetypeBtn(ref, 'Direct / Stoic', profile.coachStyle == 'Direct', () {
                      ref.read(mockUserProfileProvider.notifier).updateCoachPreferences(coachStyle: 'Direct');
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Slip-up accountability
                const Text('SLIP-UP ACTION RESPONSE STYLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildArchetypeBtn(ref, 'Compassionate', profile.slipUpStyle == 'Compassionate', () {
                      ref.read(mockUserProfileProvider.notifier).updateCoachPreferences(slipUpStyle: 'Compassionate');
                    }),
                    const SizedBox(width: 8),
                    _buildArchetypeBtn(ref, 'Balanced Wisdom', profile.slipUpStyle == 'Balanced', () {
                      ref.read(mockUserProfileProvider.notifier).updateCoachPreferences(slipUpStyle: 'Balanced');
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aura Persona Settings Calibrated!'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: const Text('Save & Apply Persona', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildArchetypeBtn(WidgetRef ref, String label, bool isActive, VoidCallback onTap) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepPurple.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.deepPurple : OptivusColors.borderSoft, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.deepPurple : OptivusColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}
