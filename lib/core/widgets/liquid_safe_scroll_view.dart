import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_spacing.dart';

/// Scrollable content area with automatic bottom padding for the floating tab bar.
/// Replaces raw SingleChildScrollView + manual padding patterns.
class LiquidSafeScrollView extends StatelessWidget {
  final List<Widget> children;
  final double bottomPadding;
  final EdgeInsets padding;
  final ScrollController? controller;
  final CrossAxisAlignment crossAxisAlignment;
  final ScrollPhysics? physics;

  const LiquidSafeScrollView({
    super.key,
    required this.children,
    this.bottomPadding = OptivusSpacing.contentBottomPadding,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.controller,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding.copyWith(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          // SafeArea top spacing
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          ...children,
        ],
      ),
    );
  }
}
