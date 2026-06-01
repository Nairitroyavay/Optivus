// Legacy Profile sheet. Active privacy controls live in PrivacySecurityScreen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showBiometricSecuritySheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Biometric Access',
    subtitle: 'Security & App Lock PIN',
    child: StatefulBuilder(
      builder: (context, setState) {
        bool biometricEnabled = true;
        bool pinEnabled = false;
        String pinStatusText = 'PIN not configured';
        List<int> typedPin = [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BIOMETRIC AUTHS',
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
                  'Face ID / Touch ID SDK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'Unlock app using biometric hardware credential',
                  style: TextStyle(fontSize: 10),
                ),
                value: biometricEnabled,
                onChanged: (val) => setState(() => biometricEnabled = val),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '4-DIGIT SECURE PIN LOCK',
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
                  SwitchListTile.adaptive(
                    activeTrackColor: OptivusColors.brandAccent,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Secure PIN Code Lock',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Required on app startup if biometric fails',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: pinEnabled,
                    onChanged: (val) {
                      setState(() {
                        pinEnabled = val;
                        if (!val) {
                          typedPin.clear();
                          pinStatusText = 'PIN deactivated';
                        } else {
                          pinStatusText = 'Enter 4 digits below';
                        }
                      });
                    },
                  ),
                  if (pinEnabled) ...[
                    const Divider(),
                    Center(
                      child: Text(
                        pinStatusText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 4 pin dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < typedPin.length;
                        return Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? OptivusColors.brandAccent
                                : Colors.grey.shade300,
                            border: Border.all(
                              color: filled
                                  ? OptivusColors.brandAccent
                                  : Colors.grey.shade400,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    // Grid dialpad
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.8,
                          ),
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          return IconButton(
                            icon: const Icon(Icons.clear_all),
                            onPressed: () => setState(() => typedPin.clear()),
                          );
                        }
                        if (index == 11) {
                          return IconButton(
                            icon: const Icon(Icons.backspace),
                            onPressed: () {
                              if (typedPin.isNotEmpty) {
                                setState(() => typedPin.removeLast());
                              }
                            },
                          );
                        }
                        final num = index == 10 ? 0 : index + 1;
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.8,
                            ),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (typedPin.length < 4) {
                              setState(() {
                                typedPin.add(num);
                                if (typedPin.length == 4) {
                                  pinStatusText =
                                      'PIN setup complete: ${typedPin.join()}';
                                }
                              });
                            }
                          },
                          child: Text(
                            '$num',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
                    content: Text('App Lock authentication settings active.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Save Security Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}
