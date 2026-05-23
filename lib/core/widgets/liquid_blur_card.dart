import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// A blur-backed container card variant using BackdropFilter.
/// Use for sections that need frosted-glass appearance over gradients.
class LiquidBlurCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double blurSigma;
  final Color? backgroundColor;
  final Border? border;
  final bool showScrews;

  const LiquidBlurCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24.0,
    this.blurSigma = 16.0,
    this.backgroundColor,
    this.border,
    this.showScrews = false,
  });

  Widget _buildScrew() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.785, // 45 degrees
          child: Container(
            width: 10,
            height: 1,
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: padding,
                child: child,
              ),
              if (showScrews) ...[
                Positioned(top: 12, left: 12, child: _buildScrew()),
                Positioned(top: 12, right: 12, child: _buildScrew()),
                Positioned(bottom: 12, left: 12, child: _buildScrew()),
                Positioned(bottom: 12, right: 12, child: _buildScrew()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A tinted blur card with accent glow for highlighted sections.
class LiquidBlurCardAccented extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsets padding;

  const LiquidBlurCardAccented({
    super.key,
    required this.child,
    this.accentColor = OptivusColors.brandAccent,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
