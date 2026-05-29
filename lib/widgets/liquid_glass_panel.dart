import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hasScrews; // Enables corner pins like a physical acrylic plaque

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32.0),
    this.hasScrews = false,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = 24.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: OptivusColors.homeCardTint.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.02),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 3,
                  left: 18,
                  right: 18,
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.8),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasScrews) ..._buildScrews(),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builder method for the four acrylic glass screws/pins
  List<Widget> _buildScrews() {
    const double inset = 16.0;
    return [
      _buildScrew(top: inset, left: inset),
      _buildScrew(top: inset, right: inset),
      _buildScrew(bottom: inset, left: inset),
      _buildScrew(bottom: inset, right: inset),
    ];
  }

  Widget _buildScrew({double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // Solid bright white core
          boxShadow: [
            // Outset soft glow
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 8,
              spreadRadius: 1,
            ),
            // Sharp inner core shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
            // Outer drop shadow for elevation
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
      ),
    );
  }
}

