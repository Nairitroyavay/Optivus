import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/goal_models.dart';

void showAddGoalScreen(BuildContext context, WidgetRef ref) {
  final activeGoals = ref.read(mockGoalProvider);
  final isLimitReached = activeGoals.length >= 3;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFECEC),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      final identityController = TextEditingController();
      final purposeController = TextEditingController();
      final proofController = TextEditingController();

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                'CREATE NEW IDENTITY FOCUS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              const Text(
                'Define a new identity standard.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              if (isLimitReached) ...[
                // Safeguard warning banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OptivusColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: OptivusColors.danger),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: OptivusColors.danger, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'COGNITIVE OVERLOAD SYSTEM ACTIVE:\n\nYou already have 3 active identity focuses. Setting a 4th goal causes attention dispersion and drops consistency rates by 68%. Aura blocks adding more than 3 active targets to protect habit momentum.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, height: 1.35, color: OptivusColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                TextField(
                  controller: identityController,
                  decoration: const InputDecoration(labelText: 'Identity Title (e.g., Sleek Coder)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: purposeController,
                  decoration: const InputDecoration(labelText: 'Purpose statement (Why?)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proofController,
                  decoration: const InputDecoration(labelText: 'Daily proof action (standard version)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLimitReached ? Colors.grey : OptivusColors.brandAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLimitReached
                        ? null
                        : () {
                            final idTitle = identityController.text.trim();
                            final purpose = purposeController.text.trim();
                            final proofAct = proofController.text.trim();

                            if (idTitle.isEmpty || purpose.isEmpty || proofAct.isEmpty) return;

                            final newG = GoalModel(
                              id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
                              identityTitle: idTitle,
                              purposeStatement: purpose,
                              dailyProof: GoalProof(
                                id: 'proof-${DateTime.now().millisecondsSinceEpoch}',
                                title: proofAct,
                                tinyVersion: 'Tiny version: do 2 minutes',
                                normalVersion: proofAct,
                                strongVersion: 'Strong: do 2x duration',
                              ),
                            );

                            ref.read(mockGoalProvider.notifier).addGoal(newG);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sleek Identity Focus Added!'), behavior: SnackBarBehavior.floating),
                            );
                          },
                    child: const Text('Create Focus', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    },
  );
}
