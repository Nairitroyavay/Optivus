import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';

/// Glass filter dropdown — exact replica of old Optivus GlassFilterDropdown.
///
/// A frosted-glass pill that opens a dropdown overlay with backdrop blur,
/// GlassHighlightPainter rim highlights, and rainbow prism corner.
class RoutineGlassFilter extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<RoutineFilterOption> options;
  final double width;

  const RoutineGlassFilter({
    super.key,
    required this.selected,
    required this.onSelected,
    this.options = primaryFilters,
    this.width = 190,
  });

  @override
  State<RoutineGlassFilter> createState() => _RoutineGlassFilterState();
}

class _RoutineGlassFilterState extends State<RoutineGlassFilter>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _anim.dispose();
    super.dispose();
  }

  void _openDropdown() {
    _overlay = OverlayEntry(
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeDropdown,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: ScaleTransition(
                  scale: _fade,
                  alignment: Alignment.topRight,
                  child: _buildSheet(),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    _anim.forward();
  }

  void _closeDropdown({bool immediate = false}) async {
    if (_overlay == null) return;
    if (!immediate && mounted) {
      await _anim.reverse();
    }
    _overlay?.remove();
    _overlay = null;
  }

  void _select(String key) {
    _closeDropdown();
    widget.onSelected(key);
  }

  Widget _buildSheet() {
    const double outerR = 22.0;
    const double rim = 8.0;
    const double innerR = outerR - rim + 2;

    final rows = widget.options.asMap().entries.map((entry) {
      final idx = entry.key;
      final f = entry.value;
      final isSelected = widget.selected == f.key;
      final isLast = idx == primaryFilters.length - 1;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(f.key),
        child: Container(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Text(
                      f.emoji,
                      style: const TextStyle(
                        fontSize: 15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: OptivusColors.ink.withValues(
                            alpha: isSelected ? 1.0 : 0.80,
                          ),
                          letterSpacing: -0.1,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: OptivusColors.ink.withValues(alpha: 0.85),
                      ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: Colors.white.withValues(alpha: 0.30),
                  indent: 14,
                  endIndent: 14,
                ),
            ],
          ),
        ),
      );
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerR),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // Content column — drives height
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: rows),
                ),
                // Transparent tint overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(outerR),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
                // Glass rim highlights
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GlassHighlightPainter(
                        outerR: outerR,
                        innerR: innerR,
                        rim: rim,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final selectedOption = widget.options.firstWhere(
      (f) => f.key == widget.selected,
      orElse: () => widget.options.first,
    );

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () => _overlay == null ? _openDropdown() : _closeDropdown(),
        child: Container(
          color: Colors.transparent,
          child: _LiquidGlassPill(
            label: selectedOption.label,
            width: widget.width,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LiquidGlassPill — the frosted-glass trigger pill (190×40)
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidGlassPill extends StatelessWidget {
  final String label;
  final double width;
  const _LiquidGlassPill({required this.label, required this.width});

  static const double outerR = 20.0;
  static const double rim = 7.0;
  static const double innerR = outerR - rim + 2; // 15

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              // Inner transparent face
              Padding(
                padding: const EdgeInsets.all(rim),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(innerR),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: OptivusColors.routineInkDark,
                          letterSpacing: -0.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: OptivusColors.routineInkDark,
                      ),
                    ],
                  ),
                ),
              ),
              // Glass highlight overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlassHighlightPainter(
                      outerR: outerR,
                      innerR: innerR,
                      rim: rim,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// GlassHighlightPainter — outer/inner sweeps + rainbow prism corner
// Exact copy from old Optivus glass_filter_dropdown.dart
// ─────────────────────────────────────────────────────────────────────────────

class GlassHighlightPainter extends CustomPainter {
  final double outerR;
  final double innerR;
  final double rim;

  const GlassHighlightPainter({
    required this.outerR,
    required this.innerR,
    required this.rim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(outerR),
    );

    final innerRect = Rect.fromLTWH(
      rim,
      rim,
      size.width - rim * 2,
      size.height - rim * 2,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerR),
    );

    // Outer Edge White Sweep (Top left)
    final outerSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.transparent, Colors.white24],
        stops: [0.0, 0.4, 1.0],
      ).createShader(outerRect);
    canvas.drawRRect(outerRRect, outerSweepPaint);

    // Inner Edge Sweep
    final innerSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.1),
        ],
      ).createShader(innerRect);
    canvas.drawRRect(innerRRect, innerSweepPaint);

    // Thick Glare inside the rim (top-left)
    final glarePath = Path()
      ..addArc(
        Rect.fromLTWH(rim * 0.4, rim * 0.4, outerR * 2.5, outerR * 2.5),
        3.14,
        1.57,
      );
    canvas.drawPath(
      glarePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 0.7
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Rainbow prism at bottom-right corner of the rim
    final donut = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outerRRect),
      Path()..addRRect(innerRRect),
    );
    canvas.save();
    canvas.clipPath(donut);

    // White base glow
    canvas.drawCircle(
      Offset(size.width - rim * 1.5, size.height - rim * 1.5),
      25,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Blue prism
    canvas.drawCircle(
      Offset(size.width - 5, size.height - 15),
      20,
      Paint()
        ..color = OptivusColors.routinePrismBlue.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Amber prism
    canvas.drawCircle(
      Offset(size.width - 25, size.height - 5),
      20,
      Paint()
        ..color = OptivusColors.routinePrismYellow.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Pink prism
    canvas.drawCircle(
      Offset(size.width - 15, size.height - 30),
      20,
      Paint()
        ..color = OptivusColors.routinePrismPink.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Inner shadow for refraction depth
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 1.8
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.6, 1.0],
        ).createShader(outerRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlassHighlightPainter oldDelegate) {
    return outerR != oldDelegate.outerR || rim != oldDelegate.rim;
  }
}
