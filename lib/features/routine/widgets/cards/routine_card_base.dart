import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Shared glass card wrapper for all routine timeline cards.
///
/// Matches old Optivus `_EventCard` styling exactly:
/// - Border radius: 20
/// - Normal: white@0.55, border white@0.80 1.2px, shadow black@0.06
/// - isNow: accentColor@0.10, border accent@0.45 1.5px, glow shadow
/// - Press animation: scale 1.0→0.97
/// - Accent bar: 3.5px with glow shadow
class RoutineCardBase extends StatefulWidget {
  final Widget child;
  final Color railColor;
  final double? railHeight;
  final bool isCompleted;
  final bool isNow;
  final VoidCallback? onTap;

  const RoutineCardBase({
    super.key,
    required this.child,
    required this.railColor,
    this.railHeight,
    this.isCompleted = false,
    this.isNow = false,
    this.onTap,
  });

  @override
  State<RoutineCardBase> createState() => _RoutineCardBaseState();
}

class _RoutineCardBaseState extends State<RoutineCardBase>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine card styling based on state
    final Color bgColor;
    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow> shadows;

    if (widget.isCompleted) {
      bgColor = OptivusColors.success.withValues(alpha: 0.08);
      borderColor = OptivusColors.success;
      borderWidth = 1.2;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.55),
          blurRadius: 0,
          offset: const Offset(-1, -1),
        ),
      ];
    } else if (widget.isNow) {
      bgColor = widget.railColor.withValues(alpha: 0.10);
      borderColor = widget.railColor.withValues(alpha: 0.45);
      borderWidth = 1.5;
      shadows = [
        BoxShadow(
          color: widget.railColor.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.55),
          blurRadius: 0,
          offset: const Offset(-1, -1),
        ),
      ];
    } else {
      bgColor = Colors.white.withValues(alpha: 0.55);
      borderColor = Colors.white.withValues(alpha: 0.80);
      borderWidth = 1.2;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.55),
          blurRadius: 0,
          offset: const Offset(-1, -1),
        ),
      ];
    }

    final railColor = widget.isCompleted
        ? OptivusColors.success
        : widget.railColor;
    final accentRailHeight = (widget.railHeight ?? 42.0)
        .clamp(32.0, 64.0)
        .toDouble();

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _pressCtrl.forward();
      },
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: shadows,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accent bar — 3.5px with glow shadow
                    Container(
                      width: 3.5,
                      height: accentRailHeight,
                      margin: const EdgeInsets.only(right: 10, top: 2),
                      decoration: BoxDecoration(
                        color: railColor,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: railColor.withValues(alpha: 0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill-shaped action button used in cards.
class CardActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? icon;

  const CardActionButton({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 48;
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(120.0, 360.0).toDouble(),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
