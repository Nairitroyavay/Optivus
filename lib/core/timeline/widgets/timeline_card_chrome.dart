import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared frosted glass card chrome for timeline cards.
///
/// Encapsulates luminous accent gradient, white highlight borders,
/// dynamic backdrop filter blur, and elevation glow drop shadow.
class TimelineCardChrome extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final TimelineCardSurfaceMode surfaceMode;
  final bool isFront;
  final bool hasOverlap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool useGroupedBackdrop;

  const TimelineCardChrome({
    super.key,
    required this.child,
    required this.baseColor,
    this.surfaceMode = TimelineCardSurfaceMode.accentTinted,
    this.isFront = true,
    this.hasOverlap = false,
    this.borderRadius,
    this.padding,
    this.useGroupedBackdrop = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24);
    final neutralSurface = surfaceMode == TimelineCardSurfaceMode.neutralGlass;

    return Container(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        color: Colors.white.withValues(
          alpha: hasOverlap ? (isFront ? 0.72 : 0.58) : 0.42,
        ),
        gradient: neutralSurface
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isFront ? 0.34 : 0.26),
                  Colors.white.withValues(alpha: isFront ? 0.12 : 0.08),
                ],
              )
            : LinearGradient(
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
            color: neutralSurface
                ? Colors.black.withValues(alpha: isFront ? 0.10 : 0.06)
                : baseColor.withValues(alpha: isFront ? 0.18 : 0.09),
            blurRadius: isFront ? 14 : 10,
            offset: Offset(0, isFront ? 5 : 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: useGroupedBackdrop
            ? BackdropFilter.grouped(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: padding != null
                    ? Padding(padding: padding!, child: child)
                    : child,
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: padding != null
                    ? Padding(padding: padding!, child: child)
                    : child,
              ),
      ),
    );
  }
}

enum TimelineCardSurfaceMode { accentTinted, neutralGlass }
