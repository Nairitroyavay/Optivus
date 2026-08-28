import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/auth_layout.dart';

/// Canonical back button for all Optivus Auth screens.
///
/// Uses the exact liquid-glass styling and geometry from the
/// "Join the top 1%" (Auth Choice) screen.
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            width: AuthLayout.backButtonSize,
            height: AuthLayout.backButtonSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: OptivusColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
