import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Shared back tab strip for overlapping timeline cards.
///
/// Implements Step 14's compact tab primitive:
/// - Clamped width (70.0..96.0)
/// - 18×18 circular accent icon container
/// - 11px w900 label
/// - 6px left/right padding, 5px icon-to-text gap
/// - Crisp ClipRect boundary with no floating pill shell
class TimelineBackTabStrip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final double width;
  final double height;
  final Key? labelKey;

  const TimelineBackTabStrip({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.width,
    required this.height,
    this.labelKey,
  });

  @override
  Widget build(BuildContext context) {
    final stripWidth = width.clamp(70.0, 96.0);

    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRect(
        child: SizedBox(
          width: stripWidth,
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 6),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 11),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    key: labelKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
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
