import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/widgets/glass_logo.dart';

class FinishingOnboardingScreen extends ConsumerStatefulWidget {
  const FinishingOnboardingScreen({super.key});

  @override
  ConsumerState<FinishingOnboardingScreen> createState() =>
      _FinishingOnboardingScreenState();
}

class _FinishingOnboardingScreenState
    extends ConsumerState<FinishingOnboardingScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authProvider.notifier).retryBackendRestore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _StartupStatusLayout(
      title: 'Finishing Optivus',
      message: 'Your setup is ready. We’re completing the last details.',
      showProgress: true,
    );
  }
}

class OnboardingReconnectScreen extends ConsumerWidget {
  const OnboardingReconnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StartupStatusLayout(
      title: 'We couldn’t reconnect yet',
      message:
          'Your saved setup has not been reset. Try again when you’re online.',
      primaryAction: FilledButton(
        onPressed: () => ref.read(authProvider.notifier).retryBackendRestore(),
        child: const Text('Try Again'),
      ),
      secondaryAction: TextButton(
        onPressed: () => ref.read(authProvider.notifier).logout(),
        child: const Text('Sign Out'),
      ),
    );
  }
}

class _StartupStatusLayout extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  const _StartupStatusLayout({
    required this.title,
    required this.message,
    this.showProgress = false,
    this.primaryAction,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GlassLogo(),
                    const SizedBox(height: 30),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF171A22),
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF5D6470),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFFE0AE00),
                        ),
                      ),
                    ],
                    if (primaryAction != null) ...[
                      const SizedBox(height: 30),
                      SizedBox(width: double.infinity, child: primaryAction),
                    ],
                    if (secondaryAction != null) ...[
                      const SizedBox(height: 8),
                      secondaryAction!,
                    ],
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
