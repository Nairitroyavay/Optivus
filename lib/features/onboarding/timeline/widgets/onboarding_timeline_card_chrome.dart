import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared frosted glass card chrome representing the Step 4 golden visual reference.
///
/// Encapsulates the luminous accent gradient, white highlight borders,
/// dynamic backdrop filter blur, and elevation glow drop shadow.
class OnboardingTimelineCardChrome extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final bool isFront;
  final bool hasOverlap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const OnboardingTimelineCardChrome({
    super.key,
    required this.child,
    required this.baseColor,
    this.isFront = true,
    this.hasOverlap = false,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24);

    return Container(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        color: Colors.white.withValues(
          alpha: hasOverlap ? (isFront ? 0.72 : 0.58) : 0.42,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: isFront ? 0.26 : 0.18),
            baseColor.withValues(alpha: isFront ? 0.08 : 0.04),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isFront ? 0.96 : 0.82),
          width: isFront ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: isFront ? 0.18 : 0.09),
            blurRadius: isFront ? 14 : 10,
            offset: Offset(0, isFront ? 5 : 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}
