import 'package:flutter/material.dart';
import 'package:optivus/core/timeline/widgets/timeline_card_chrome.dart';

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
    return TimelineCardChrome(
      baseColor: baseColor,
      isFront: isFront,
      hasOverlap: hasOverlap,
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
  }
}
