import 'dart:ui';
import 'package:flutter/material.dart';

/// A full-screen modal sheet wrapper with frosted glass background.
/// Use for detail views that should overlay the current tab without
/// hiding the tab bar completely.
class LiquidModalSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final VoidCallback? onClose;
  final Color topColor;

  const LiquidModalSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.topColor = const Color(0xFFFFF4D8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.7, 1.0],
          colors: [topColor, const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // Optional title bar
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Helper to show a liquid-styled modal bottom sheet.
Future<T?> showLiquidModalSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  double heightFactor = 0.85,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final height =
          (media.size.height - media.viewInsets.bottom) *
          heightFactor.clamp(0.4, 0.98);
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: SizedBox(height: height, child: builder(ctx)),
            ),
          ),
        ),
      );
    },
  );
}
