import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class LiquidBlobButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final double height;
  final bool fullWidth;
  final IconData? icon;

  const LiquidBlobButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.height = 104.0,
    this.fullWidth = true,
    this.icon,
  });

  @override
  State<LiquidBlobButton> createState() => _LiquidBlobButtonState();
}

class _LiquidBlobButtonState extends State<LiquidBlobButton>
    with TickerProviderStateMixin {
  bool _pressed = false;
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0.0);
  Duration? _lastElapsed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastElapsed != null) {
        final dt = (elapsed - _lastElapsed!).inMicroseconds / 1e6;
        _time.value += dt;
      }
      _lastElapsed = elapsed;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active =
        widget.enabled && widget.onPressed != null && !widget.isLoading;
    final double capsuleH = widget.height * 0.54;
    final double capsuleInset = math.max(26.0, widget.height * 0.34);
    final double labelSize = (widget.height * 0.15)
        .clamp(20.0, 32.0)
        .toDouble();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: active ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed && active ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: widget.height,
          width: widget.fullWidth ? double.infinity : null,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer ambient glow
              Positioned(
                left: capsuleInset,
                right: capsuleInset,
                top: (widget.height - capsuleH) / 2 + 10,
                height: capsuleH,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(capsuleH),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF22DDE8,
                              ).withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 2,
                              offset: const Offset(-20, 10),
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFF1493,
                              ).withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 2,
                              offset: const Offset(20, 10),
                            ),
                          ]
                        : [],
                  ),
                ),
              ),

              // The Soft Transparent Liquid Blob
              Positioned(
                // Tight bounds so the liquid hugs the button closely
                left: capsuleInset - 24,
                right: capsuleInset - 24,
                top: (widget.height - capsuleH) / 2 - 16,
                bottom: (widget.height - capsuleH) / 2 - 16,
                child: ValueListenableBuilder<double>(
                  valueListenable: _time,
                  builder: (context, time, _) {
                    return CustomPaint(
                      painter: _SoftLiquidBlobPainter(
                        time: active ? time : 0,
                        disabled: !active,
                      ),
                    );
                  },
                ),
              ),

              // The Ultra-Transparent Glass Pill
              Container(
                height: capsuleH,
                width: widget.fullWidth ? double.infinity : null,
                margin: EdgeInsets.symmetric(horizontal: capsuleInset),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(capsuleH / 2),
                  // Extremely subtle drop shadow behind the pill
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(capsuleH / 2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(capsuleH / 2),
                        // Transparent border that's slightly brighter at top
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                          width: 1.0,
                        ),
                        // Very clear inside to let liquid show through
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
                        children: [
                          // Top sharp glossy reflection (like reference image)
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
                          // Subtle top right glow inside the glass
                          Positioned(
                            top: -10,
                            right: -10,
                            width: 60,
                            height: 40,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 12,
                                sigmaY: 12,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          // Text Layer
                          Center(
                            child: widget.isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        OptivusColors.textPrimary,
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.icon != null) ...[
                                            Icon(
                                              widget.icon,
                                              color: OptivusColors.textPrimary,
                                              size: labelSize + 2,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            widget.label,
                                            style: TextStyle(
                                              color: OptivusColors.textPrimary,
                                              fontSize: labelSize,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
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

class _SoftLiquidBlobPainter extends CustomPainter {
  final double time;
  final bool disabled;

  _SoftLiquidBlobPainter({required this.time, this.disabled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Generates a perfectly smooth, high-resolution organic path using a spatial deformation field.
    // This mathematically guarantees absolutely NO sharp edges or kinks.
    Path buildTightOrganicPath(double timeShift, double scale) {
      final t = (time * 1.6) + timeShift;
      final dx = w * 0.02 * scale; // Horizontal wobble
      final dy = h * 0.07 * scale; // Vertical wobble

      // Perfectly align the base blob shape to the glass pill
      final double glassPaddingX = 45.0;
      final double glassPaddingY = 25.0;
      final double pillH = h - glassPaddingY * 2;
      final double r = ((pillH / 2) + 2) * scale;

      final double maxCx = w / 2;
      final double cxLeft = math.min(glassPaddingX + pillH / 2, maxCx);
      final double cxRight = math.max(w - glassPaddingX - pillH / 2, maxCx);
      final double cy = h / 2;

      List<Offset> basePoints = [];
      final int edgePoints = 40;
      final int arcPoints = 50;

      // Top edge (left to right)
      for (int i = 0; i <= edgePoints; i++) {
        double progress = i / edgePoints;
        basePoints.add(Offset(cxLeft + (cxRight - cxLeft) * progress, cy - r));
      }
      // Right arc (top to bottom)
      for (int i = 1; i <= arcPoints; i++) {
        double progress = i / arcPoints;
        double angle = -math.pi / 2 + math.pi * progress;
        basePoints.add(
          Offset(cxRight + r * math.cos(angle), cy + r * math.sin(angle)),
        );
      }
      // Bottom edge (right to left)
      for (int i = 1; i <= edgePoints; i++) {
        double progress = i / edgePoints;
        basePoints.add(Offset(cxRight - (cxRight - cxLeft) * progress, cy + r));
      }
      // Left arc (bottom to top)
      for (int i = 1; i < arcPoints; i++) {
        double progress = i / arcPoints;
        double angle = math.pi / 2 + math.pi * progress;
        basePoints.add(
          Offset(cxLeft + r * math.cos(angle), cy + r * math.sin(angle)),
        );
      }

      final path = Path();

      // Continuous phase deformation field based on spatial coordinates
      Offset deform(Offset p) {
        final nx = p.dx / w;
        final ny = p.dy / h;
        final phaseX = nx * 3.14 + ny * 1.5;
        final phaseY = nx * 2.0 - ny * 3.14;
        return Offset(
          p.dx + math.sin(t + phaseX) * dx,
          p.dy + math.cos(t * 1.3 + phaseY) * dy,
        );
      }

      final startP = deform(basePoints[0]);
      path.moveTo(startP.dx, startP.dy);
      for (int i = 1; i < basePoints.length; i++) {
        final pt = deform(basePoints[i]);
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      return path;
    }

    final mainPath = buildTightOrganicPath(0.0, 1.0);

    if (disabled) {
      canvas.drawPath(
        mainPath,
        Paint()..color = const Color(0xFFD8DCE3).withValues(alpha: 0.82),
      );
      return;
    }

    final baseGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF22DDE8), // Cyan
        Color(0xFF6C73FF), // Violet
        Color(0xFFFF1493), // Pink
      ],
    ).createShader(Rect.fromLTRB(0, 0, w, 0));

    // 1. Soft Edge Under-Stroke
    // Drawing a blurred stroke of the exact same path behind the clip removes the harsh vector edge.
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..shader = baseGradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 2. Base Fill & Clip
    canvas.save();
    canvas.clipPath(mainPath);

    // Vibrant, fully opaque base
    canvas.drawRect(Rect.fromLTRB(0, 0, w, h), Paint()..shader = baseGradient);

    // 3. Moving Color Masses (Vibrant)
    final t2 = time * 0.8;
    // Cyan swirl
    canvas.drawCircle(
      Offset(
        w * 0.2 + math.cos(t2 * 0.7) * 20,
        h * 0.4 + math.sin(t2 * 1.1) * 15,
      ),
      h * 0.8,
      Paint()
        ..color = const Color(0xFF5DE2FF).withValues(alpha: 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    // Deep Violet center
    canvas.drawCircle(
      Offset(
        w * 0.5 + math.sin(t2 * 0.9) * 20,
        h * 0.6 + math.cos(t2 * 0.8) * 15,
      ),
      h * 1.2,
      Paint()
        ..color = const Color(0xFF6C73FF).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );
    // Hot Pink right
    canvas.drawCircle(
      Offset(
        w * 0.8 + math.cos(t2 * 1.1) * 15,
        h * 0.5 + math.sin(t2 * 0.7) * 20,
      ),
      h * 0.9,
      Paint()
        ..color = const Color(0xFFFF1493).withValues(alpha: 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    // 4. Deep Bottom Inner Shadow (3D Volume)
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24.0
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF101522).withValues(alpha: 0.7), // Dark shadow
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTRB(0, 0, w, h))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 5. Bright Top Inner Glow (3D Curve)
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.85), Colors.transparent],
          stops: const [0.0, 0.5],
        ).createShader(Rect.fromLTRB(0, 0, w, h))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 6. Strong Glossy Specular Highlight
    final highlightPath = buildTightOrganicPath(0.0, 0.95);
    canvas.drawPath(
      highlightPath.shift(const Offset(0, -3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.3),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTRB(0, 0, w, h))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SoftLiquidBlobPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.disabled != disabled;
}
