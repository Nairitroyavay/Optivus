import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/widgets/glass_logo.dart';

/// Rare escape route for durable state that automatic resume cannot safely
/// reconcile. Normal interrupted onboarding never reaches this screen.
class OnboardingRecoveryScreen extends ConsumerWidget {
  const OnboardingRecoveryScreen({super.key});

  Future<void> _startOver(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start setup again?'),
        content: const Text(
          'Only choose this if retrying does not work. Your account will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Start Over'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(authProvider.notifier)
          .executeRecoveryAction(const ResetSetupSafelyAction());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canStartOver = auth.recoveryActions.any(
      (action) => action is ResetSetupSafelyAction,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6E6B4), Color(0xFFFCF8EE), Colors.white],
            stops: [0, .46, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    const GlassLogo(),
                    const SizedBox(height: 28),
                    const Text(
                      'We couldn’t finish loading\nyour setup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF171A22),
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Try again first. Optivus won’t reset or replace your saved progress automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF5D6470),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () => ref
                            .read(authProvider.notifier)
                            .retryBackendRestore(),
                        child: const Text('Try Again'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        if (canStartOver)
                          TextButton(
                            onPressed: () => _startOver(context, ref),
                            child: const Text('Start Over'),
                          ),
                        TextButton(
                          onPressed: () =>
                              ref.read(authProvider.notifier).logout(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: const Text(
                        'Technical details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        SelectableText(
                          auth.startupReasonCode ?? 'setup_requires_attention',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
