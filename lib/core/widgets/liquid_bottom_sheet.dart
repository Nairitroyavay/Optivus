import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';

/// Shows a glass-styled modal bottom sheet with drag handle and rounded top corners.
/// Use this instead of raw showModalBottomSheet for consistent styling.
Future<T?> showLiquidBottomSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          OptivusColors.borderNeutral.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
