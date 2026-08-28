import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/widgets/auth_back_button.dart';
import 'package:optivus/widgets/glass_logo.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          key: const Key('auth-choice-background'),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [OptivusColors.onboardingTop, Color(0xFFFCF8EE)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              key: const Key('auth-choice-safe-content'),
              padding: const EdgeInsets.fromLTRB(
                AuthLayout.horizontalPadding,
                AuthLayout.backButtonTopInset,
                AuthLayout.horizontalPadding,
                AuthLayout.backButtonBottomInset,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuthBackButton(
                      onTap: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                  ),
                  const Spacer(flex: 2),
                  const SizedBox(
                    width: 92,
                    height: 92,
                    child: FittedBox(child: GlassLogo()),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Join the top 1%.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: OptivusColors.ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose how you want to begin.',
                    style: TextStyle(
                      color: OptivusColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  LiquidGlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _AuthChoiceButton(
                          key: const Key('auth-choice-create'),
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Create New Account',
                          onTap: () => context.push('/signup/create'),
                        ),
                        const SizedBox(height: 14),
                        _AuthChoiceButton(
                          key: const Key('auth-choice-google'),
                          label: 'Continue with Google',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Google sign-in is not configured yet.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Flexible(
                        child: Text(
                          'Already have an account?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: OptivusColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        key: const Key('auth-choice-login'),
                        onPressed: () => context.push('/login'),
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthChoiceButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _AuthChoiceButton({
    super.key,
    this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.78),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: onTap,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: OptivusColors.ink, size: 24),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
