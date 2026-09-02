import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/widgets/glass_logo.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/animated_bot_avatar.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OptivusTheme.authOverlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCF8EE),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF6E6B4), // Soft warm golden hue
                Color(0xFFFCF8EE), // Extra light cream/off-white
              ],
              stops: [0.0, 0.5], // Fade evenly into white around middle
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 60),
                        const GlassLogo(),
                        const SizedBox(height: 28),

                        // Optivus Title
                        const Text(
                          'Optivus',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F111A), // Dark Navy/Black
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Yellow divider line
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD426), // Yellow accent
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Slogan
                        Text(
                          'PLAN. EXECUTE. BECOME.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Feature Card (AI-Powered Coach) - Liquid Style
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F9FC).withValues(
                                  alpha: 0.35,
                                ), // Glass background with #F4F9FC tint
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: OptivusColors.borderNeutral.withValues(
                                    alpha: 0.50,
                                  ),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: -2,
                                    offset: const Offset(-2, -2),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 220;
                                  final textBlock = Column(
                                    crossAxisAlignment: compact
                                        ? CrossAxisAlignment.center
                                        : CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'AI-Powered Coach',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F111A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Optimizing your daily workflow',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: compact
                                            ? TextAlign.center
                                            : TextAlign.start,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  );
                                  final check = Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  );

                                  if (compact) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const AnimatedBotAvatar(),
                                        const SizedBox(height: 10),
                                        textBlock,
                                        const SizedBox(height: 10),
                                        check,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      const AnimatedBotAvatar(),
                                      const SizedBox(width: 16),
                                      Expanded(child: textBlock),
                                      const SizedBox(width: 10),
                                      check,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Get Started Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AppButton(
                    text: 'Get Started',
                    onPressed: () {
                      context.push('/signup');
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Log In Text
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        "Already have an account?",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        key: const Key('welcome-login-link'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          context.go('/login');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFFFD426),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0F111A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
