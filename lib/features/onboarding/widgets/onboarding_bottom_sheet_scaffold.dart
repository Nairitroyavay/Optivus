import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Standard modal bottom sheet scaffold for onboarding settings/details.
class OnboardingBottomSheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? bottomActions;
  final VoidCallback? onCancel;
  final bool hasPadding;

  const OnboardingBottomSheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.bottomActions,
    this.onCancel,
    this.hasPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: OptivusColors.borderNeutral.withValues(
                          alpha: 0.60,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            if (onCancel != null) {
                              onCancel!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: OptivusColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: OptivusColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 48,
                        ), // To balance the left Cancel button
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0x1A000000)),
                  Flexible(
                    child: Material(
                      type: MaterialType.transparency,
                      child: SingleChildScrollView(
                        padding: hasPadding
                            ? const EdgeInsets.fromLTRB(20, 16, 20, 24)
                            : EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            child,
                            if (bottomActions != null) ...[
                              const SizedBox(height: 16),
                              bottomActions!,
                            ],
                          ],
                        ),
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
